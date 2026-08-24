import uuid
from decimal import Decimal
from django.shortcuts import render
from django.utils import timezone
from django.views import View
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Notification, User, WalletTransaction
from apps.accounts.serializers import UserSerializer, WalletTransactionSerializer
from apps.deliveries.models import DeliveryTask
from apps.deliveries.serializers import DeliveryTaskSerializer
from apps.products.models import Product
from apps.products.serializers import ProductSerializer
from apps.subscriptions.models import Subscription, VacationPause
from apps.subscriptions.serializers import SubscriptionSerializer
from apps.core.permissions import IsAdminOrStaff, IsAdminOrHubManager


class AdminConsoleHTMLView(View):
    def get(self, request):
        return render(request, "admin_console.html")


class AdminCustomerListView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        from apps.subscriptions.models import Subscription
        customers = User.objects.filter(role=User.Roles.CUSTOMER).select_related("assigned_hub").order_by("-date_joined")
        data = []
        for c in customers:
            active_subs_count = Subscription.objects.filter(customer=c, status=Subscription.Statuses.ACTIVE).count()
            data.append({
                "id": c.id,
                "username": c.username,
                "first_name": c.first_name,
                "last_name": c.last_name,
                "full_name": f"{c.first_name} {c.last_name}".strip() or c.username,
                "phone": c.phone,
                "email": c.email,
                "address": c.address,
                "city": c.city,
                "wallet_balance": str(c.wallet_balance),
                "active_subscriptions_count": active_subs_count,
                "assigned_hub": c.assigned_hub.name if c.assigned_hub else "Kodad Depot",
                "assigned_hub_code": c.assigned_hub.hub_code if c.assigned_hub else "HUB-KDD-01",
                "delivery_slot_preference": c.delivery_slot_preference,
                "delivery_instructions": c.delivery_instructions,
                "date_joined": c.date_joined.strftime("%d %b %Y"),
            })
        return Response(data)

    def post(self, request):
        from apps.accounts.models import CustomerAddress
        from apps.deliveries.models import LocationHub
        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()
        raw_phone = request.data.get("phone", "").strip()
        email = request.data.get("email", "").strip()
        address = request.data.get("address", "").strip()
        city = request.data.get("city", "Kodad").strip()
        hub_id = request.data.get("hub_id")
        slot_pref = request.data.get("delivery_slot_preference", "05:30 AM - 07:00 AM")
        instructions = request.data.get("delivery_instructions", "Leave at doorstep milk basket")
        initial_wallet = request.data.get("initial_wallet_balance", "500.00")

        if not first_name:
            return Response({"detail": "Customer First Name is mandatory."}, status=status.HTTP_400_BAD_REQUEST)
        if not address:
            return Response({"detail": "Delivery Address is mandatory."}, status=status.HTTP_400_BAD_REQUEST)

        phone_digits = "".join(filter(str.isdigit, raw_phone))
        if len(phone_digits) < 10:
            return Response({"detail": "Please enter a valid 10-digit mobile number for the customer."}, status=status.HTTP_400_BAD_REQUEST)
        last_10 = phone_digits[-10:]
        clean_phone = f"+91 {last_10}"

        if User.objects.filter(phone__endswith=last_10).exists():
            return Response({"detail": f"A customer account with mobile number {clean_phone} already exists."}, status=status.HTTP_400_BAD_REQUEST)

        username = f"cust_{last_10}"
        if User.objects.filter(username=username).exists():
            username = f"cust_{last_10}_{User.objects.count() + 1}"

        assigned_hub = None
        if hub_id:
            assigned_hub = LocationHub.objects.filter(pk=hub_id).first() or LocationHub.objects.filter(hub_code=str(hub_id)).first()
        if not assigned_hub:
            assigned_hub = LocationHub.objects.first()

        try:
            wallet_amount = Decimal(str(initial_wallet or "500.00"))
        except Exception:
            wallet_amount = Decimal("500.00")

        customer = User.objects.create(
            username=username,
            first_name=first_name,
            last_name=last_name,
            phone=clean_phone,
            email=email or f"{username}@milkdrop.in",
            address=address,
            city=city,
            role=User.Roles.CUSTOMER,
            assigned_hub=assigned_hub,
            wallet_balance=wallet_amount,
            delivery_slot_preference=slot_pref,
            delivery_instructions=instructions,
        )
        customer.set_password(uuid.uuid4().hex)
        customer.save()

        # Log initial wallet transaction
        if wallet_amount > 0:
            WalletTransaction.objects.create(
                user=customer,
                amount=wallet_amount,
                transaction_type=WalletTransaction.Types.CREDIT,
                description="🎁 Welcome Initial Wallet Balance",
            )

        # Create primary CustomerAddress
        CustomerAddress.objects.create(
            user=customer,
            address_type="HOME",
            street_address=address,
            city=city,
            pincode="508206",
            latitude=assigned_hub.latitude if assigned_hub else 16.9950,
            longitude=assigned_hub.longitude if assigned_hub else 79.9670,
            delivery_instructions=instructions,
            is_default=True,
        )

        return Response({
            "message": f"Customer '{first_name} {last_name}' registered successfully!",
            "id": customer.id,
            "username": customer.username,
            "full_name": f"{customer.first_name} {customer.last_name}".strip(),
            "phone": customer.phone,
            "wallet_balance": str(customer.wallet_balance),
        }, status=status.HTTP_201_CREATED)


class AdminCustomerDetailView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request, pk):
        from apps.accounts.models import User
        from apps.subscriptions.models import Subscription
        from apps.deliveries.models import DeliveryTask

        customer = User.objects.filter(pk=pk).first()
        if not customer:
            return Response({"detail": f"Customer/User #{pk} not found"}, status=status.HTTP_404_NOT_FOUND)

        subs = Subscription.objects.filter(customer=customer).select_related("product", "hub", "customer__assigned_hub").order_by("-created_at")
        subs_data = []
        for s in subs:
            assigned_hub = s.hub or s.customer.assigned_hub
            subs_data.append({
                "id": s.id,
                "product_name": s.product.name,
                "product_image": s.product.image_url,
                "product_price": float(s.product.price_per_unit),
                "unit_quantity": s.product.unit_quantity or s.product.unit,
                "quantity": s.quantity,
                "frequency": s.schedule_type,
                "status": s.status,
                "hub_name": assigned_hub.name if assigned_hub else "Kodad Depot",
                "hub_code": assigned_hub.hub_code if assigned_hub else "HUB-KDD-01",
                "start_date": str(s.start_date),
                "monthly_value": float(s.product.price_per_unit * s.quantity * 30),
                "created_at": s.created_at.strftime("%d %b %Y"),
            })

        tasks = DeliveryTask.objects.filter(subscription__customer=customer).select_related("subscription__product", "driver").order_by("-delivery_date")[:15]
        tasks_data = []
        for t in tasks:
            driver_name = f"{t.driver.first_name} {t.driver.last_name}".strip() if t.driver else "Unassigned"
            tasks_data.append({
                "id": t.id,
                "delivery_date": str(t.delivery_date),
                "slot_time": t.slot_time,
                "status": t.status,
                "product_name": t.subscription.product.name if t.subscription else "Dairy Item",
                "quantity": t.subscription.quantity if t.subscription else 1,
                "driver_name": driver_name,
                "proof_image_url": t.proof_image_url,
                "delivered_at": t.delivered_at.strftime("%I:%M %p") if t.delivered_at else "",
            })

        return Response({
            "customer": {
                "id": customer.id,
                "username": customer.username,
                "first_name": customer.first_name,
                "last_name": customer.last_name,
                "full_name": f"{customer.first_name} {customer.last_name}".strip() or customer.username,
                "phone": customer.phone,
                "email": customer.email,
                "address": customer.address,
                "city": customer.city,
                "wallet_balance": str(customer.wallet_balance),
                "delivery_instructions": customer.delivery_instructions,
                "delivery_slot_preference": customer.delivery_slot_preference,
                "latitude": float(customer.latitude) if customer.latitude else 16.9950,
                "longitude": float(customer.longitude) if customer.longitude else 79.9670,
                "date_joined": customer.date_joined.strftime("%d %b %Y"),
                "is_active": customer.is_active,
            },
            "subscriptions": subs_data,
            "deliveries": tasks_data,
        })

    def patch(self, request, pk):
        from apps.accounts.models import User
        customer = User.objects.filter(pk=pk, role=User.Roles.CUSTOMER).first()
        if not customer:
            return Response({"detail": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

        if "first_name" in request.data: customer.first_name = request.data["first_name"].strip()
        if "last_name" in request.data: customer.last_name = request.data["last_name"].strip()
        if "phone" in request.data: customer.phone = request.data["phone"].strip()
        if "email" in request.data: customer.email = request.data["email"].strip()
        if "address" in request.data: customer.address = request.data["address"].strip()
        if "city" in request.data: customer.city = request.data["city"].strip()
        if "delivery_instructions" in request.data: customer.delivery_instructions = request.data["delivery_instructions"].strip()
        if "delivery_slot_preference" in request.data: customer.delivery_slot_preference = request.data["delivery_slot_preference"].strip()
        if "is_active" in request.data: customer.is_active = bool(request.data["is_active"])
        customer.save()

        return Response({"message": f"Customer profile for '{customer.first_name} {customer.last_name}' updated successfully!"})

    def delete(self, request, pk):
        from apps.accounts.models import User
        from apps.subscriptions.models import Subscription
        customer = User.objects.filter(pk=pk, role=User.Roles.CUSTOMER).first()
        if not customer:
            return Response({"detail": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

        name = f"{customer.first_name} {customer.last_name}".strip() or customer.username
        Subscription.objects.filter(customer=customer).update(status=Subscription.Statuses.CANCELLED)
        customer.delete()
        return Response({"message": f"Customer account '{name}' deleted successfully."})


class AdminCreditWalletView(APIView):
    permission_classes = [IsAdminOrStaff]

    def post(self, request):
        user_id = request.data.get("user_id")
        if not user_id:
            return Response({"error": "user_id is required"}, status=status.HTTP_400_BAD_REQUEST)

        amount_str = request.data.get("amount", "100.00")
        desc = request.data.get("description", "Admin Manual Wallet Bonus")

        try:
            amount = Decimal(str(amount_str))
            user = User.objects.get(pk=user_id)
        except (User.DoesNotExist, Exception) as e:
            return Response({"detail": f"User not found or invalid amount: {e}"}, status=status.HTTP_400_BAD_REQUEST)

        if amount <= 0:
            return Response({"error": "Credit amount must be a positive value."}, status=status.HTTP_400_BAD_REQUEST)

        from django.db.models import F
        User.objects.filter(pk=user.pk).update(wallet_balance=F("wallet_balance") + amount)
        user.refresh_from_db(fields=["wallet_balance"])

        tx = WalletTransaction.objects.create(
            user=user,
            amount=amount,
            transaction_type=WalletTransaction.Types.CREDIT,
            description=f"🎁 {desc}",
        )

        Notification.objects.create(
            user=user,
            title="🎁 Wallet Credit Adjustment",
            message=f"₹{amount} credited to your wallet by Admin. Reason: {desc}. New Balance: ₹{user.wallet_balance}",
            notification_type=Notification.Types.WALLET,
        )

        return Response(
            {
                "message": f"Successfully credited ₹{amount} to {user.username}'s wallet",
                "new_balance": str(user.wallet_balance),
                "transaction": WalletTransactionSerializer(tx).data,
            },
            status=status.HTTP_200_OK,
        )


class AdminBroadcastNotificationView(APIView):
    permission_classes = [IsAdminOrStaff]

    def post(self, request):
        title = request.data.get("title", "MilkDrop Announcement")
        message = request.data.get("message", "Important update regarding morning deliveries.")
        target_role = request.data.get("target_role", "ALL")
        notification_type = request.data.get("notification_type", Notification.Types.OFFER)
        target_screen = request.data.get("target_screen", "")
        target_param = request.data.get("target_param", "")

        users = User.objects.all()
        if target_role == "CUSTOMER":
            users = users.filter(role=User.Roles.CUSTOMER)
        elif target_role == "DRIVER":
            users = users.filter(role=User.Roles.DELIVERY_PARTNER)

        notifs = [
            Notification(
                user=u,
                title=title,
                message=message,
                notification_type=notification_type,
                target_screen=target_screen,
                target_param=target_param,
            )
            for u in users
        ]
        Notification.objects.bulk_create(notifs, batch_size=1000)
        created_count = len(notifs)

        return Response(
            {
                "message": f"Broadcast sent successfully to {created_count} user(s).",
                "count": created_count,
            },
            status=status.HTTP_200_OK,
        )


def generate_hub_code(name, address):
    from apps.deliveries.models import LocationHub
    import re

    RTC_LOCATION_CODES = {
        "kodad": "KDD",
        "suryapet": "SYP",
        "huzurnagar": "HZNR",
        "munagala": "MNGL",
        "miryalaguda": "MRGA",
        "jaggaiahpeta": "JPT",
        "nandigama": "NDGM",
        "khammam": "KMM",
        "nalgonda": "NLG",
        "vijayawada": "BZA",
        "guntur": "GNT",
        "warangal": "WGL",
        "karimnagar": "KRMR",
        "mahbubnagar": "MBNR",
        "nizamabad": "NZB",
        "jubilee": "JBL",
        "banjara": "BNJ",
        "madhapur": "MDP",
        "gachibowli": "GCB",
        "kukatpally": "KPB",
        "kondapur": "KND",
        "miyapur": "MYP",
        "uppal": "UPL",
        "dilsukhnagar": "DSNR",
        "begumpet": "BMT",
        "somajiguda": "SMG",
        "ameerpet": "AMP",
        "punjagutta": "PJG",
        "manikonda": "MNK",
        "chanda nagar": "CNG",
        "secunderabad": "SC",
        "hyderabad": "HYD",
    }

    full_text = f"{name} {address}".lower()
    matched_code = None

    for loc, code in RTC_LOCATION_CODES.items():
        if loc in full_text:
            matched_code = code
            break

    if not matched_code:
        words = re.findall(r'[a-zA-Z]+', name)
        first_word = words[0].upper() if words else "DEPOT"
        if len(first_word) >= 3:
            consonants = "".join([c for c in first_word if c not in "AEIOU"])
            matched_code = (consonants[:3] if len(consonants) >= 3 else first_word[:3]).upper()
        else:
            matched_code = first_word.upper()

    prefix = f"HUB-{matched_code}-"
    existing = LocationHub.objects.filter(hub_code__startswith=prefix).values_list("hub_code", flat=True)
    max_num = 0
    for c in existing:
        try:
            num = int(c.split("-")[-1])
            if num > max_num:
                max_num = num
        except (ValueError, IndexError):
            pass

    next_num = max_num + 1
    return f"HUB-{matched_code}-{next_num:02d}"


class AdminHubsView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def get(self, request):
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub
        from apps.subscriptions.models import Subscription

        if not LocationHub.objects.exists():
            LocationHub.objects.create(
                hub_code="HUB-KDD-01",
                name="Kodad Depot",
                address="Main Road, Kodad, Suryapet, Telangana 508206",
                manager_name="Operations Manager",
                manager_phone="+91 8919548905",
                coverage_radius_km=25.0,
                latitude=16.9950,
                longitude=79.9670,
                fssai_license="13621014000342",
            )
            LocationHub.objects.create(
                hub_code="HUB-HYD-01",
                name="Hyderabad Central Depot",
                address="Road No 36, Jubilee Hills, Hyderabad 500033",
                manager_name="Regional Operations Manager",
                manager_phone="+91 8919548905",
                coverage_radius_km=25.0,
                latitude=17.4319,
                longitude=78.4073,
                fssai_license="13621014000343",
            )

        user = request.user
        hubs_qs = LocationHub.objects.all().prefetch_related("service_areas", "delivery_partners").order_by("-created_at")
        
        # Scope to provider's assigned hub
        if user.role in (User.Roles.HUB_MANAGER, 'PROVIDER') and getattr(user, 'assigned_hub', None):
            hubs_qs = hubs_qs.filter(id=user.assigned_hub_id)

        active_subs = Subscription.objects.filter(status=Subscription.Statuses.ACTIVE)
        if user.role in (User.Roles.HUB_MANAGER, 'PROVIDER') and getattr(user, 'assigned_hub', None):
            from django.db.models import Q
            active_subs = active_subs.filter(Q(hub=user.assigned_hub) | Q(customer__assigned_hub=user.assigned_hub))

        total_sub_count = active_subs.count() or 0
        total_vol = sum(s.quantity for s in active_subs) or 0

        hubs_data = []
        for idx, h in enumerate(hubs_qs, 1):
            service_areas_count = h.service_areas.count()
            real_boys = h.delivery_partners.filter(role=User.Roles.DELIVERY_PARTNER).count()

            hubs_data.append({
                "id": h.hub_code,
                "hub_code": h.hub_code,
                "db_id": h.id,
                "name": h.name,
                "address": h.address,
                "manager_name": h.manager_name,
                "manager_phone": h.manager_phone,
                "manager": f"{h.manager_name} ({h.manager_phone})",
                "subscribers_count": total_sub_count,
                "daily_volume_liters": total_vol,
                "active_delivery_boys": real_boys,
                "salary_per_boy": 15000,
                "status": "OPERATIONAL",
                "fssai_license": h.fssai_license,
                "coverage_radius_km": getattr(h, "coverage_radius_km", 8.5),
                "bank_name": getattr(h, "bank_name", "State Bank of India"),
                "bank_account_number": getattr(h, "bank_account_number", "389201948210"),
                "bank_ifsc": getattr(h, "bank_ifsc", "SBIN0004892"),
                "bank_account_holder": getattr(h, "bank_account_holder", "Srinuvasa Reddy"),
                "upi_id": getattr(h, "upi_id", "8885199878@upi"),
                "bank_account": f"{getattr(h, 'bank_name', 'State Bank of India')} • A/C ending in {str(getattr(h, 'bank_account_number', '389201948210'))[-4:]}",
                "service_areas_count": service_areas_count,
                "latitude": h.latitude,
                "longitude": h.longitude,
                "lat": h.latitude,
                "lng": h.longitude,
            })

        return Response(hubs_data)

    def post(self, request):
        from apps.deliveries.models import LocationHub

        name = request.data.get("name", "").strip()
        address = request.data.get("address", "").strip()
        manager_name = request.data.get("manager_name", "").strip()
        raw_phone = request.data.get("manager_phone", "").strip()
        fssai = request.data.get("fssai_license", "").strip()
        radius = float(request.data.get("coverage_radius_km", 5.0))

        # Strict Mandatory Field Validation (Except FSSAI)
        if not name:
            return Response({"detail": "Depot Name is mandatory."}, status=status.HTTP_400_BAD_REQUEST)
        if not address:
            return Response({"detail": "Depot Physical Address is mandatory."}, status=status.HTTP_400_BAD_REQUEST)
        if not manager_name:
            return Response({"detail": "Hub Manager Full Name is mandatory."}, status=status.HTTP_400_BAD_REQUEST)
        if not raw_phone:
            return Response({"detail": "Hub Mobile Number is mandatory."}, status=status.HTTP_400_BAD_REQUEST)

        phone_digits = "".join(filter(str.isdigit, raw_phone))
        if len(phone_digits) < 10:
            return Response({"detail": "Please enter a valid 10-digit mobile number for the Hub Manager."}, status=status.HTTP_400_BAD_REQUEST)
        clean_phone = f"+91 {phone_digits[-10:]}"

        try:
            lat = float(request.data.get("latitude", 0))
            lng = float(request.data.get("longitude", 0))
            if lat == 0 and lng == 0:
                raise ValueError("Invalid GPS coordinates")
        except (ValueError, TypeError):
            return Response({"detail": "Valid GPS Latitude and Longitude are mandatory (pick location on Google Map)."}, status=status.HTTP_400_BAD_REQUEST)

        hub_code = request.data.get("hub_code", "").strip().upper()
        if not hub_code or hub_code == "AUTO":
            hub_code = generate_hub_code(name, address)

        hub, created = LocationHub.objects.get_or_create(
            hub_code=hub_code,
            defaults={
                "name": name,
                "address": address,
                "manager_name": manager_name,
                "manager_phone": clean_phone,
                "fssai_license": fssai,
                "coverage_radius_km": radius,
                "latitude": lat,
                "longitude": lng,
            }
        )
        if not created:
            hub.name = name
            hub.address = address
            hub.manager_name = manager_name
            hub.manager_phone = clean_phone
            hub.fssai_license = fssai
            hub.coverage_radius_km = radius
            hub.latitude = lat
            hub.longitude = lng
            hub.save()

        # Auto provision/link Hub Manager User for phone login
        clean_mgr_digits = "".join(filter(str.isdigit, clean_phone))
        mgr_last_10 = clean_mgr_digits[-10:] if len(clean_mgr_digits) >= 10 else clean_mgr_digits
        if mgr_last_10:
            from apps.accounts.models import User
            from decimal import Decimal
            hub_user = (
                User.objects.filter(phone__endswith=mgr_last_10).first()
                or User.objects.filter(username=f"hub_{hub.hub_code.lower()}").first()
            )
            if not hub_user:
                hub_user = User.objects.create(
                    username=f"hub_{hub.hub_code.lower()}",
                    phone=f"+91 {mgr_last_10}",
                    first_name=manager_name or name,
                    last_name="Hub Manager",
                    email=f"hub_{hub.hub_code.lower()}@milkdrop.in",
                    role=User.Roles.HUB_MANAGER,
                    is_staff=True,
                    assigned_hub=hub,
                    wallet_balance=Decimal("10000.00"),
                )
                hub_user.set_password(uuid.uuid4().hex)
            else:
                hub_user.assigned_hub = hub
                hub_user.is_staff = True
                if hub_user.role not in [User.Roles.ADMIN, User.Roles.HUB_MANAGER, "PROVIDER", "HUB_MANAGER"]:
                    hub_user.role = User.Roles.HUB_MANAGER
            hub_user.save()

        return Response({
            "message": f"Location Hub '{name}' ({hub_code}) registered successfully!",
            "id": hub.hub_code,
            "db_id": hub.id,
            "name": hub.name,
            "hub_code": hub.hub_code,
            "coverage_radius_km": hub.coverage_radius_km,
        }, status=status.HTTP_201_CREATED)


def _resolve_hub_by_pk_or_code(pk):
    from apps.deliveries.models import LocationHub
    if pk is None:
        return None
    pk_str = str(pk).strip()
    if not pk_str:
        return None
    if pk_str.isdigit():
        hub = LocationHub.objects.filter(pk=int(pk_str)).first()
        if hub:
            return hub
    return (
        LocationHub.objects.filter(hub_code__iexact=pk_str).first()
        or LocationHub.objects.filter(hub_code__icontains=pk_str).first()
    )


class AdminHubDetailView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def get(self, request, pk):
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub, ServiceArea, DeliveryTask

        hub = _resolve_hub_by_pk_or_code(pk)
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        assigned_drivers = User.objects.filter(role=User.Roles.DELIVERY_PARTNER, assigned_hub=hub)
        available_drivers = User.objects.filter(role=User.Roles.DELIVERY_PARTNER).exclude(assigned_hub=hub)

        assigned_data = []
        for d in assigned_drivers:
            stops = DeliveryTask.objects.filter(driver=d).count()
            salary_val = getattr(d, "monthly_salary", 0) or 0
            assigned_data.append({
                "id": d.id,
                "name": f"{d.first_name} {d.last_name}".strip() or d.username,
                "phone": d.phone or "",
                "salary": f"₹{int(salary_val):,} / mo",
                "raw_salary": float(salary_val),
                "driver_status": getattr(d, "driver_status", "AVAILABLE") or "AVAILABLE",
                "assigned_stops": stops,
            })

        available_data = []
        for d in available_drivers:
            salary_val = getattr(d, "monthly_salary", 0) or 0
            available_data.append({
                "id": d.id,
                "name": f"{d.first_name} {d.last_name}".strip() or d.username,
                "phone": d.phone or "",
                "current_hub": d.assigned_hub.name if d.assigned_hub else "Unassigned Pool",
                "salary": f"₹{int(salary_val):,} / mo",
            })

        service_areas = ServiceArea.objects.filter(hub=hub)
        sa_data = [{
            "id": sa.id,
            "name": sa.name,
            "pincodes": sa.pincodes or "",
            "radius_km": getattr(sa, "radius_km", 5.0) or 5.0,
            "status": getattr(sa, "status", "ACTIVE"),
            "households": getattr(sa, "active_households", 0) or 0,
        } for sa in service_areas]

        created_at_str = hub.created_at.isoformat() if getattr(hub, "created_at", None) else None

        return Response({
            "hub": {
                "id": hub.hub_code,
                "db_id": hub.id,
                "hub_code": hub.hub_code,
                "name": hub.name,
                "address": hub.address,
                "manager_name": hub.manager_name or "",
                "manager_phone": hub.manager_phone or "",
                "fssai_license": hub.fssai_license or "",
                "coverage_radius_km": float(getattr(hub, "coverage_radius_km", 8.5) or 8.5),
                "bank_name": getattr(hub, "bank_name", "State Bank of India") or "State Bank of India",
                "bank_account_number": str(getattr(hub, "bank_account_number", "389201948210") or "389201948210"),
                "bank_ifsc": getattr(hub, "bank_ifsc", "SBIN0004892") or "SBIN0004892",
                "bank_account_holder": getattr(hub, "bank_account_holder", "Srinuvasa Reddy") or "Srinuvasa Reddy",
                "upi_id": getattr(hub, "upi_id", "8885199878@upi") or "8885199878@upi",
                "bank_account": f"{getattr(hub, 'bank_name', 'State Bank of India')} • A/C ending in {str(getattr(hub, 'bank_account_number', '389201948210'))[-4:]}",
                "latitude": float(hub.latitude or 0.0),
                "longitude": float(hub.longitude or 0.0),
                "created_at": created_at_str,
            },
            "assigned_drivers": assigned_data,
            "available_drivers": available_data,
            "service_areas": sa_data,
        })

    def patch(self, request, pk):
        hub = _resolve_hub_by_pk_or_code(pk)
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        if "name" in request.data: hub.name = request.data["name"]
        if "hub_code" in request.data and request.data["hub_code"].strip(): 
            hub.hub_code = request.data["hub_code"].strip().upper()
        if "address" in request.data: hub.address = request.data["address"]
        if "manager_name" in request.data: hub.manager_name = request.data["manager_name"]
        if "manager_phone" in request.data: hub.manager_phone = request.data["manager_phone"]
        if "fssai_license" in request.data: hub.fssai_license = request.data["fssai_license"]
        if "coverage_radius_km" in request.data and request.data["coverage_radius_km"] is not None:
            hub.coverage_radius_km = float(request.data["coverage_radius_km"])
        if "bank_name" in request.data: hub.bank_name = str(request.data["bank_name"]).strip()
        if "bank_account_number" in request.data: hub.bank_account_number = str(request.data["bank_account_number"]).strip()
        if "bank_ifsc" in request.data: hub.bank_ifsc = str(request.data["bank_ifsc"]).strip().upper()
        if "bank_account_holder" in request.data: hub.bank_account_holder = str(request.data["bank_account_holder"]).strip()
        if "upi_id" in request.data: hub.upi_id = str(request.data["upi_id"]).strip()
        if "latitude" in request.data and request.data["latitude"] is not None:
            hub.latitude = float(request.data["latitude"])
        if "longitude" in request.data and request.data["longitude"] is not None:
            hub.longitude = float(request.data["longitude"])
        hub.save()

        try:
            from apps.core.consumers import broadcast_hub_event
            broadcast_hub_event(hub.hub_code, "hub_updated", {"hub_code": hub.hub_code, "name": hub.name})
        except Exception:
            pass

        return Response({
            "message": f"Hub '{hub.name}' updated successfully!",
            "hub_code": hub.hub_code,
            "coverage_radius_km": hub.coverage_radius_km,
            "bank_name": hub.bank_name,
            "bank_account_number": hub.bank_account_number,
            "bank_ifsc": hub.bank_ifsc,
            "bank_account_holder": hub.bank_account_holder,
            "upi_id": hub.upi_id,
            "bank_account": f"{hub.bank_name} • A/C ending in {str(hub.bank_account_number)[-4:]}",
        })

    def delete(self, request, pk):
        hub = _resolve_hub_by_pk_or_code(pk)
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        name = hub.name
        hub.delete()
        return Response({"message": f"Hub '{name}' removed from operations."})


class AdminHubAssignDriverView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def post(self, request, pk):
        from apps.accounts.models import User

        hub = _resolve_hub_by_pk_or_code(pk)
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        driver_id = request.data.get("driver_id")
        action = request.data.get("action", "assign")

        driver = User.objects.filter(pk=driver_id, role=User.Roles.DELIVERY_PARTNER).first()
        if not driver:
            return Response({"detail": "Delivery partner not found"}, status=status.HTTP_404_NOT_FOUND)

        if action == "unassign":
            driver.assigned_hub = None
            driver.save()
            msg = f"Delivery partner '{driver.first_name} {driver.last_name}' unassigned from '{hub.name}' and returned to general pool."
        else:
            driver.assigned_hub = hub
            driver.address = hub.address
            driver.save()
            msg = f"Delivery partner '{driver.first_name} {driver.last_name}' successfully allocated to '{hub.name}'!"

        return Response({"message": msg})


class AdminHubCleanupView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def post(self, request):
        from apps.deliveries.models import LocationHub
        from collections import defaultdict

        # Find and remove duplicate hubs by name or hub_code
        seen_codes = set()
        seen_names = set()
        deleted_count = 0

        for hub in LocationHub.objects.all().order_by("id"):
            clean_name = hub.name.strip().lower()
            clean_code = hub.hub_code.strip().upper()
            if clean_code in seen_codes or clean_name in seen_names:
                hub.delete()
                deleted_count += 1
            else:
                seen_codes.add(clean_code)
                seen_names.add(clean_name)

        remaining_count = LocationHub.objects.count()
        return Response({
            "message": f"Deduplication complete. Removed {deleted_count} duplicate hub(s). {remaining_count} unique hub(s) remaining.",
            "deleted_count": deleted_count,
            "remaining_count": remaining_count,
        })


class AdminSubscriptionsListView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        from django.db.models import Q
        hub_id = request.query_params.get("hub_id")
        subs = Subscription.objects.all().select_related("customer", "product", "hub", "customer__assigned_hub").order_by("-created_at")

        if hub_id:
            subs = subs.filter(Q(hub_id=hub_id) | Q(customer__assigned_hub_id=hub_id))

        data = []
        for s in subs:
            assigned_hub = s.hub or s.customer.assigned_hub
            data.append({
                "id": s.id,
                "customer_id": s.customer_id,
                "customer_name": f"{s.customer.first_name or s.customer.username} {s.customer.last_name or ''}".strip(),
                "customer_phone": s.customer.phone or "+91 9876543210",
                "customer_address": s.delivery_address or (s.customer.address if s.customer else "") or "Kodad, Telangana",
                "product_id": s.product_id,
                "product_name": s.product.name,
                "quantity": s.quantity,
                "pack_size": s.pack_size or (s.product.unit_quantity if s.product else "1 Litre"),
                "delivery_slot": s.delivery_slot or "05:30 AM - 07:00 AM",
                "schedule_type": s.schedule_type,
                "frequency": s.schedule_type,
                "status": s.status,
                "hub_id": assigned_hub.id if assigned_hub else None,
                "hub_name": assigned_hub.name if assigned_hub else "Kodad Hub Depot",
                "hub_code": assigned_hub.hub_code if assigned_hub else "HUB-KOD-01",
                "start_date": str(s.start_date),
                "created_at": s.created_at.strftime("%d %b %Y"),
                "estimated_monthly_value": float(s.product.price_per_unit * s.quantity * 30),
            })
        return Response(data)


class AdminSubscriptionDetailView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request, pk):
        from apps.deliveries.models import DeliveryTask
        from apps.subscriptions.models import VacationPause

        try:
            s = Subscription.objects.select_related("customer", "product", "hub", "customer__assigned_hub").get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        assigned_hub = s.hub or s.customer.assigned_hub
        tasks = DeliveryTask.objects.filter(subscription=s).select_related("driver").order_by("-delivery_date", "-id")[:40]
        vacations = VacationPause.objects.filter(subscription=s).order_by("-start_date")

        tasks_data = []
        for t in tasks:
            driver_name = f"{t.driver.first_name or t.driver.username} {t.driver.last_name or ''}".strip() if t.driver else "Unassigned"
            tasks_data.append({
                "id": t.id,
                "delivery_date": str(t.delivery_date),
                "slot_time": t.slot_time,
                "status": t.status,
                "driver_id": t.driver_id,
                "driver_name": driver_name,
                "driver_phone": t.driver.phone if t.driver else "",
                "proof_image_url": t.proof_image_url or "",
                "delivered_at": t.delivered_at.strftime("%d %b %Y, %I:%M %p") if t.delivered_at else None,
            })

        vacations_data = []
        for v in vacations:
            vacations_data.append({
                "id": v.id,
                "start_date": str(v.start_date),
                "end_date": str(v.end_date),
                "reason": getattr(v, "reason", "Vacation Mode"),
                "created_at": v.created_at.strftime("%d %b %Y") if hasattr(v, "created_at") else "",
            })

        daily_cost = float(s.product.price_per_unit * s.quantity)
        data = {
            "id": s.id,
            "status": s.status,
            "schedule_type": s.schedule_type,
            "quantity": s.quantity,
            "pack_size": s.pack_size or (s.product.unit_quantity if s.product else "1 Litre"),
            "delivery_slot": s.delivery_slot or "05:30 AM - 07:00 AM",
            "delivery_address": s.delivery_address or (s.customer.address if s.customer else "") or "Doorstep Delivery Address",
            "delivery_instructions": s.delivery_instructions or "",
            "start_date": str(s.start_date),
            "end_date": str(getattr(s, "end_date", "")) if getattr(s, "end_date", None) else None,
            "created_at": s.created_at.strftime("%d %b %Y, %I:%M %p") if s.created_at else "",
            "daily_cost": daily_cost,
            "estimated_monthly_value": float(daily_cost * 30),
            "customer": {
                "id": s.customer.id,
                "username": s.customer.username,
                "name": f"{s.customer.first_name or s.customer.username} {s.customer.last_name or ''}".strip(),
                "phone": s.customer.phone or "+91 9876543210",
                "email": s.customer.email or "customer@milkdrop.in",
                "wallet_balance": float(getattr(s.customer, "wallet_balance", 0.0) or 0.0),
                "address": s.customer.address or "Doorstep Delivery Address",
                "slot_preference": s.customer.delivery_slot_preference or "05:30 AM - 07:00 AM",
            },
            "product": {
                "id": s.product.id,
                "name": s.product.name,
                "category": getattr(s.product.category, "name", "Dairy") if getattr(s.product, "category", None) else "Dairy",
                "price_per_unit": float(s.product.price_per_unit),
                "unit_quantity": s.product.unit_quantity,
                "image_url": getattr(s.product, "image_url", ""),
            },
            "hub": {
                "id": assigned_hub.id if assigned_hub else None,
                "name": assigned_hub.name if assigned_hub else "Kodad Hub Depot",
                "hub_code": assigned_hub.hub_code if assigned_hub else "HUB-KOD-01",
                "manager_name": getattr(assigned_hub, "manager_name", "Operations Manager"),
                "manager_phone": getattr(assigned_hub, "manager_phone", ""),
            },
            "tasks": tasks_data,
            "vacation_pauses": vacations_data,
        }
        return Response(data)

    def patch(self, request, pk):
        from apps.deliveries.models import DeliveryTask

        try:
            s = Subscription.objects.get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        if "delivery_slot" in request.data:
            s.delivery_slot = request.data["delivery_slot"]
            # Sync pending tasks
            DeliveryTask.objects.filter(subscription=s, status=DeliveryTask.Statuses.PENDING).update(slot_time=s.delivery_slot)

        if "quantity" in request.data:
            try:
                s.quantity = int(request.data["quantity"])
            except ValueError:
                pass

        if "delivery_address" in request.data:
            s.delivery_address = request.data["delivery_address"]

        if "delivery_instructions" in request.data:
            s.delivery_instructions = request.data["delivery_instructions"]

        if "schedule_type" in request.data:
            s.schedule_type = request.data["schedule_type"]

        s.save()
        return Response({"detail": "Subscription updated successfully", "id": s.id, "delivery_slot": s.delivery_slot})


class AdminSubscriptionToggleView(APIView):
    permission_classes = [IsAdminOrStaff]

    def post(self, request, pk):
        from apps.deliveries.models import DeliveryTask
        from datetime import date, timedelta

        try:
            sub = Subscription.objects.get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get("action", "toggle")
        prev_status = sub.status

        if action == "pause":
            sub.status = Subscription.Statuses.PAUSED
        elif action in ("resume", "reactivate"):
            sub.status = Subscription.Statuses.ACTIVE
        elif action == "cancel":
            sub.status = Subscription.Statuses.CANCELLED
        else:
            sub.status = Subscription.Statuses.PAUSED if sub.status == Subscription.Statuses.ACTIVE else Subscription.Statuses.ACTIVE
        sub.save()

        if sub.status == Subscription.Statuses.CANCELLED:
            DeliveryTask.objects.filter(
                subscription=sub,
                status=DeliveryTask.Statuses.PENDING,
            ).update(status=DeliveryTask.Statuses.SKIPPED)
        elif prev_status == Subscription.Statuses.CANCELLED and sub.status == Subscription.Statuses.ACTIVE:
            tomorrow = date.today() + timedelta(days=1)
            if not DeliveryTask.objects.filter(subscription=sub, delivery_date=tomorrow).exists():
                DeliveryTask.objects.create(
                    subscription=sub,
                    hub=sub.hub,
                    delivery_date=tomorrow,
                    slot_time=sub.delivery_slot or '06:00 AM',
                    status=DeliveryTask.Statuses.PENDING,
                )

        return Response({
            "message": f"Subscription #{sub.id} status updated to {sub.status}",
            "status": sub.status,
        })


class AdminFleetListView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def get(self, request):
        from apps.accounts.models import User
        from apps.deliveries.models import DeliveryTask

        hub_id = request.query_params.get("hub_id")
        drivers = User.objects.filter(role=User.Roles.DELIVERY_PARTNER).select_related("assigned_hub")

        # Hub managers can only see drivers at their own hub
        if hub_id:
            drivers = drivers.filter(assigned_hub_id=hub_id)
        elif hasattr(request.user, 'role') and request.user.role in (User.Roles.HUB_MANAGER, 'PROVIDER') and request.user.assigned_hub:
            drivers = drivers.filter(assigned_hub=request.user.assigned_hub)

        fleet_data = []
        for d in drivers:
            assigned_tasks = DeliveryTask.objects.filter(driver=d)
            total_stops = assigned_tasks.count()
            completed_stops = assigned_tasks.filter(status=DeliveryTask.Statuses.DELIVERED).count()

            hub_name = d.assigned_hub.name if d.assigned_hub else "Unassigned"
            hub_code = d.assigned_hub.hub_code if d.assigned_hub else "—"

            fleet_data.append({
                "id": d.id,
                "first_name": d.first_name,
                "last_name": d.last_name,
                "name": f"{d.first_name} {d.last_name}".strip() or d.username,
                "phone": d.phone or "—",
                "hub": hub_name,
                "hub_id": d.assigned_hub_id,
                "hub_code": hub_code,
                "raw_salary": float(d.monthly_salary),
                "driver_status": d.driver_status,
                "latitude": float(d.latitude) if d.latitude else 17.001734,
                "longitude": float(d.longitude) if d.longitude else 79.9625,
                "lat": float(d.latitude) if d.latitude else 17.001734,
                "lng": float(d.longitude) if d.longitude else 79.9625,
                "assigned_stops": total_stops,
                "completed_stops": completed_stops,
                "salary": f"₹{int(d.monthly_salary):,} / month",
                "bottles_collected": assigned_tasks.filter(status=DeliveryTask.Statuses.DELIVERED).count(),
                "last_location_updated": d.last_location_updated.isoformat() if d.last_location_updated else None,
            })

        return Response(fleet_data)


class AdminFleetDetailView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def patch(self, request, pk):
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub

        driver = User.objects.filter(pk=pk, role=User.Roles.DELIVERY_PARTNER).first()
        if not driver:
            return Response({"detail": "Driver not found"}, status=status.HTTP_404_NOT_FOUND)

        if "first_name" in request.data: driver.first_name = request.data["first_name"]
        if "last_name" in request.data: driver.last_name = request.data["last_name"]
        if "phone" in request.data: driver.phone = request.data["phone"]
        if "driver_status" in request.data: driver.driver_status = request.data["driver_status"]
        if "monthly_salary" in request.data: driver.monthly_salary = Decimal(str(request.data["monthly_salary"]))
        
        if "hub_id" in request.data:
            hub = LocationHub.objects.filter(id=request.data["hub_id"]).first()
            if hub:
                driver.assigned_hub = hub
                driver.address = hub.address

        driver.save()
        return Response({"message": f"Delivery partner '{driver.first_name} {driver.last_name}' updated successfully!"})

    def delete(self, request, pk):
        from apps.accounts.models import User
        driver = User.objects.filter(pk=pk, role=User.Roles.DELIVERY_PARTNER).first()
        if not driver:
            return Response({"detail": "Driver not found"}, status=status.HTTP_404_NOT_FOUND)

        name = f"{driver.first_name} {driver.last_name}".strip() or driver.username
        driver.delete()
        return Response({"message": f"Delivery partner '{name}' removed from fleet."})


class HubDriverCreateView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def post(self, request):
        from django.contrib.auth.hashers import make_password
        from apps.accounts.models import User
        from apps.deliveries.models import LocationHub

        first_name = request.data.get("first_name", "Delivery").strip()
        last_name = request.data.get("last_name", "Partner").strip()
        raw_phone = request.data.get("phone", "").strip()
        hub_id = request.data.get("hub_id")
        salary = float(request.data.get("monthly_salary", 15000.0))
        address = request.data.get("address", "").strip()
        city = request.data.get("city", "").strip()

        phone_digits = "".join(filter(str.isdigit, raw_phone))
        if len(phone_digits) < 10:
            return Response({"detail": "Valid 10-digit phone number is required."}, status=status.HTTP_400_BAD_REQUEST)
        clean_phone = f"+91 {phone_digits[-10:]}"

        hub = None
        if hub_id:
            hub = LocationHub.objects.filter(id=hub_id).first()
        if not hub and hasattr(request.user, 'assigned_hub') and request.user.assigned_hub:
            hub = request.user.assigned_hub
        if not hub:
            hub = LocationHub.objects.first()

        raw_lat = request.data.get("latitude")
        raw_lng = request.data.get("longitude")
        lat = Decimal(str(raw_lat)) if raw_lat else (hub.latitude if hub else Decimal("16.9950"))
        lng = Decimal(str(raw_lng)) if raw_lng else (hub.longitude if hub else Decimal("79.9670"))

        if not address and hub:
            address = hub.address
        if not city and hub:
            city = hub.name.split()[0]

        uname = f"driver_{clean_phone.replace(' ', '').replace('+', '')[-6:]}"

        driver, created = User.objects.get_or_create(
            phone=clean_phone,
            defaults={
                "username": uname,
                "first_name": first_name,
                "last_name": last_name,
                "password": make_password(uuid.uuid4().hex),
                "role": User.Roles.DELIVERY_PARTNER,
                "assigned_hub": hub,
                "monthly_salary": Decimal(str(salary)),
                "address": address or "Depot Operations Base",
                "city": city or "Kodad",
                "latitude": lat,
                "longitude": lng,
                "driver_status": "ACTIVE",
            }
        )

        if not created:
            driver.first_name = first_name
            driver.last_name = last_name
            driver.assigned_hub = hub
            driver.monthly_salary = Decimal(str(salary))
            if address: driver.address = address
            if city: driver.city = city
            driver.latitude = lat
            driver.longitude = lng
            driver.save()

        return Response({
            "message": f"Delivery partner {first_name} {last_name} successfully onboarded and affiliated with {hub.name if hub else 'Depot'}.",
            "driver_id": driver.id,
            "hub_name": hub.name if hub else "Depot",
            "salary": f"₹{int(salary):,} / month",
            "latitude": float(driver.latitude),
            "longitude": float(driver.longitude),
        }, status=status.HTTP_201_CREATED)


class ServiceAreaListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from apps.deliveries.models import ServiceArea
        from apps.deliveries.serializers import ServiceAreaSerializer
        areas = ServiceArea.objects.all().select_related("hub")
        return Response(ServiceAreaSerializer(areas, many=True).data)


class ServiceAreaCheckView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from apps.deliveries.models import ServiceArea
        from apps.deliveries.serializers import ServiceAreaSerializer
        pincode = request.data.get("pincode", "").strip()
        address = request.data.get("address", "").strip().lower()

        areas = ServiceArea.objects.filter(status=ServiceArea.Statuses.ACTIVE)

        matched_area = None
        for a in areas:
            if pincode and pincode in a.pincodes:
                matched_area = a
                break
            if address and (a.name.lower() in address or any(pin.strip() in address for pin in a.pincodes.split(","))):
                matched_area = a
                break

        if matched_area:
            return Response({
                "serviceable": True,
                "message": f"🎉 Great news! We deliver 100% fresh morning milk to {matched_area.name} from {matched_area.hub.name if matched_area.hub else 'Central Depot'}.",
                "area": ServiceAreaSerializer(matched_area).data,
            })

        return Response({
            "serviceable": False,
            "message": "We are currently expanding to your neighborhood! Join our priority waitlist to get ₹500 free milk credits upon launch.",
            "nearby_active_hubs": ["Jubilee Hills Depot #1 (500033)", "Banjara Hills Depot #2 (500034)", "Madhapur Tech Enclave #3 (500081)"],
        })


class AdminServiceAreaManageView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def post(self, request):
        from apps.deliveries.models import LocationHub, ServiceArea
        from apps.deliveries.serializers import ServiceAreaSerializer

        name = request.data.get("name")
        pincodes = request.data.get("pincodes")
        hub_id = request.data.get("hub_id")
        radius = float(request.data.get("radius_km", 5.0))
        status_val = request.data.get("status", "ACTIVE")
        popular = request.data.get("popular_societies", "Residential Gated Enclaves")

        hub = LocationHub.objects.filter(id=hub_id).first() if hub_id else None

        area = ServiceArea.objects.create(
            name=name,
            pincodes=pincodes,
            hub=hub,
            radius_km=radius,
            status=status_val,
            popular_societies=popular,
        )

        return Response(ServiceAreaSerializer(area).data, status=status.HTTP_201_CREATED)


class AdminCustomerTransactionsView(APIView):
    permission_classes = [IsAdminOrStaff]

    def get(self, request, user_id):
        from apps.accounts.models import User, WalletTransaction

        user = User.objects.filter(pk=user_id).first()
        if not user:
            return Response({"detail": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

        txs = WalletTransaction.objects.filter(user=user).order_by("-created_at")

        data = []
        for t in txs:
            data.append({
                "id": t.id,
                "amount": str(t.amount),
                "type": t.transaction_type,
                "description": t.description,
                "created_at": t.created_at.strftime("%b %d, %Y • %I:%M %p"),
            })

        return Response({
            "customer_id": user.id,
            "customer_name": f"{user.first_name} {user.last_name}".strip() or user.username,
            "wallet_balance": str(user.wallet_balance),
            "transactions": data,
        })


class AdminSubscriptionCreateView(APIView):
    permission_classes = [IsAdminOrStaff]

    def post(self, request):
        from datetime import date
        from apps.accounts.models import User
        from apps.products.models import Product
        from apps.subscriptions.models import Subscription
        from apps.deliveries.models import DeliveryTask

        customer_id = request.data.get("customer_id")
        product_id = request.data.get("product_id")
        quantity = int(request.data.get("quantity", 1))
        schedule_type = request.data.get("schedule_type", "DAILY")
        start_date_str = request.data.get("start_date") or str(date.today())

        customer = User.objects.filter(id=customer_id).first()
        if not customer:
            return Response({"detail": "Customer not found"}, status=status.HTTP_400_BAD_REQUEST)

        product = Product.objects.filter(id=product_id).first()
        if not product:
            return Response({"detail": "Product not found"}, status=status.HTTP_400_BAD_REQUEST)

        from apps.deliveries.hub_resolver import find_hub_for_location
        from apps.deliveries.models import LocationHub
        hub = (
            customer.assigned_hub
            or find_hub_for_location(latitude=customer.latitude, longitude=customer.longitude)
            or LocationHub.objects.first()
        )

        delivery_slot = request.data.get("delivery_slot") or customer.delivery_slot_preference or "05:30 AM - 07:00 AM"

        sub = Subscription.objects.create(
            customer=customer,
            product=product,
            hub=hub,
            quantity=quantity,
            schedule_type=schedule_type,
            start_date=start_date_str,
            delivery_slot=delivery_slot,
            status=Subscription.Statuses.ACTIVE,
        )

        # Automatically schedule first delivery task
        driver = User.objects.filter(role=User.Roles.DELIVERY_PARTNER, assigned_hub=hub).first() or User.objects.filter(role=User.Roles.DELIVERY_PARTNER).first()
        DeliveryTask.objects.create(
            subscription=sub,
            hub=hub,
            driver=driver,
            delivery_date=date.today(),
            slot_time=delivery_slot,
            status=DeliveryTask.Statuses.PENDING,
        )

        return Response({
            "message": f"Subscription #{sub.id} created successfully for {customer.username} ({quantity}x {product.name})",
            "subscription_id": sub.id,
        }, status=status.HTTP_201_CREATED)


class AdminProductStockToggleView(APIView):
    permission_classes = [IsAdminOrStaff]

    def post(self, request, pk):
        from apps.products.models import Product
        product = Product.objects.filter(pk=pk).first()
        if not product:
            return Response({"detail": "Product not found"}, status=status.HTTP_404_NOT_FOUND)

        product.is_available = not product.is_available
        product.save()

        return Response({
            "id": product.id,
            "name": product.name,
            "is_available": product.is_available,
            "status": "In Stock" if product.is_available else "Out of Stock",
        })


class AdminHubRebalanceView(APIView):
    permission_classes = [IsAdminOrHubManager]

    def post(self, request, hub_code):
        from apps.deliveries.models import LocationHub, DeliveryTask
        from apps.accounts.models import User

        hub = LocationHub.objects.filter(hub_code=hub_code).first()
        if not hub:
            return Response({"detail": f"Hub {hub_code} not found"}, status=status.HTTP_404_NOT_FOUND)

        active_drivers = list(User.objects.filter(role=User.Roles.DELIVERY_PARTNER, assigned_hub=hub))
        if not active_drivers:
            return Response({"detail": f"No drivers assigned to hub {hub.name}. Assign drivers first."}, status=status.HTTP_400_BAD_REQUEST)

        from datetime import date
        tasks = list(DeliveryTask.objects.filter(hub=hub, status=DeliveryTask.Statuses.PENDING))
        if not tasks:
            return Response({"message": f"No pending delivery tasks found for hub {hub.name}."}, status=status.HTTP_200_OK)

        if active_drivers and tasks:
            driver_counts = {d.id: 0 for d in active_drivers}
            for idx, task in enumerate(tasks):
                assigned_driver = active_drivers[idx % len(active_drivers)]
                task.driver = assigned_driver
                task.hub = hub
                task.save()
                driver_counts[assigned_driver.id] += 1

            # Send in-app notification to each driver
            for driver in active_drivers:
                count = driver_counts.get(driver.id, 0)
                if count > 0:
                    Notification.objects.create(
                        user=driver,
                        title="🥛 Morning Route Balanced & Assigned",
                        message=f"You have been assigned {count} morning delivery stops by {hub.name} dispatch.",
                        notification_type=Notification.Types.DELIVERY,
                    )

            try:
                from apps.core.consumers import broadcast_hub_event
                broadcast_hub_event(hub.hub_code, "route_rebalanced", {
                    "hub_code": hub.hub_code,
                    "tasks_count": len(tasks),
                })
            except Exception:
                pass

        return Response({
            "message": f"Successfully rebalanced {len(tasks)} delivery tasks across {len(active_drivers)} active delivery boys at {hub.name}.",
            "hub_code": hub_code,
            "drivers_count": len(active_drivers),
            "rebalanced_tasks": len(tasks),
        })


class AdminBottleReturnsView(APIView):
    """List all bottle returns for admin web console."""
    permission_classes = [IsAdminOrHubManager]

    def get(self, request):
        from apps.deliveries.models import BottleReturn
        returns = BottleReturn.objects.select_related("customer", "driver", "hub", "product").all()

        hub_id = request.query_params.get("hub_id")
        if hub_id:
            returns = returns.filter(hub_id=hub_id)

        data = []
        for r in returns:
            cust_name = f"{r.customer.first_name} {r.customer.last_name}".strip() or r.customer.username if r.customer else ""
            driver_name = f"{r.driver.first_name} {r.driver.last_name}".strip() or r.driver.username if r.driver else ""
            data.append({
                "id": r.id,
                "customer_name": cust_name,
                "driver_name": driver_name,
                "hub_name": r.hub.name if r.hub else "",
                "product_name": r.product.name if r.product else "",
                "bottles_count": r.quantity,
                "deposit_amount": str(r.deposit_amount),
                "status": r.status,
                "collected_date": str(r.collected_date) if r.collected_date else None,
                "returned_date": str(r.returned_date) if r.returned_date else None,
                "notes": r.notes,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            })
        return Response(data)


class AdminPayoutsView(APIView):
    """List, settle, or generate provider payouts for admin web console."""
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        from apps.deliveries.models import ProviderPayout
        payouts = ProviderPayout.objects.select_related("hub", "manager").all().order_by("-created_at")

        data = []
        for p in payouts:
            provider_name = f"{p.manager.first_name} {p.manager.last_name}".strip() if p.manager and p.manager.first_name else (p.manager.username if p.manager else "Hub Operator")
            data.append({
                "id": p.id,
                "hub_id": p.hub_id,
                "hub_name": p.hub.name if p.hub else "Main Depot",
                "provider_name": provider_name,
                "period_start": str(p.period_start),
                "period_end": str(p.period_end),
                "total_deliveries": p.total_deliveries,
                "total_revenue": str(p.total_revenue),
                "driver_salaries": str(p.driver_salaries),
                "platform_commission": str(p.platform_commission),
                "amount": str(p.net_payout),
                "status": p.status,
                "payment_reference": p.payment_reference or f"PAY-KOD-{p.id:04d}",
                "notes": p.notes or "Hub Operator Monthly Settlement",
                "settled_at": p.paid_at.isoformat() if p.paid_at else None,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            })
        return Response(data)

    def post(self, request):
        from apps.deliveries.models import ProviderPayout, LocationHub, DeliveryTask
        from django.utils import timezone
        import random

        action = request.data.get("action")
        payout_id = request.data.get("payout_id")

        if action == "settle" and payout_id:
            try:
                payout = ProviderPayout.objects.get(pk=payout_id)
            except ProviderPayout.DoesNotExist:
                return Response({"detail": "Payout record not found"}, status=status.HTTP_404_NOT_FOUND)

            ref = request.data.get("payment_reference") or f"NEFT-KOD-{random.randint(100000, 999999)}"
            payout.status = ProviderPayout.Statuses.COMPLETED
            payout.paid_at = timezone.now()
            payout.payment_reference = ref
            payout.notes = request.data.get("notes") or f"Settled via Bank NEFT Ref #{ref}"
            payout.save()

            return Response({
                "message": f"Payout #{payout.id} marked as SETTLED successfully!",
                "payout_id": payout.id,
                "status": payout.status,
                "payment_reference": payout.payment_reference,
            })

        elif action == "generate":
            # Automatically calculate and generate payout settlements for all active hubs
            today = date.today()
            period_start = today.replace(day=1)
            period_end = today
            commission_rate = Decimal("0.05")

            hubs = LocationHub.objects.all()
            generated_count = 0

            for hub in hubs:
                if ProviderPayout.objects.filter(hub=hub, period_start=period_start, period_end=period_end).exists():
                    continue

                completed_tasks = DeliveryTask.objects.filter(
                    hub=hub,
                    delivery_date__gte=period_start,
                    delivery_date__lte=period_end,
                    status=DeliveryTask.Statuses.DELIVERED,
                ).select_related("subscription__product")

                total_deliveries = completed_tasks.count()
                total_revenue = Decimal("0.00")
                for t in completed_tasks:
                    if t.subscription and t.subscription.product:
                        total_revenue += Decimal(str(t.subscription.product.price_per_unit)) * t.subscription.quantity

                if total_deliveries == 0 and total_revenue == Decimal("0.00"):
                    # Generate a default initial settlement batch if hub is active
                    total_deliveries = 15
                    total_revenue = Decimal("5250.00")

                hub_drivers = User.objects.filter(
                    role=User.Roles.DELIVERY_PARTNER,
                    assigned_hub=hub,
                )
                driver_salaries = sum(getattr(d, "monthly_salary", Decimal("0.00")) for d in hub_drivers) or Decimal("1500.00")
                platform_commission = total_revenue * commission_rate
                net_payout = max(Decimal("500.00"), total_revenue - driver_salaries - platform_commission)

                manager = User.objects.filter(
                    role__in=[User.Roles.HUB_MANAGER, "PROVIDER"],
                    assigned_hub=hub,
                ).first()

                ref_code = f"PAY-KOD-{random.randint(1000, 9999)}"
                ProviderPayout.objects.create(
                    hub=hub,
                    manager=manager,
                    period_start=period_start,
                    period_end=period_end,
                    total_deliveries=total_deliveries,
                    total_revenue=total_revenue,
                    driver_salaries=driver_salaries,
                    platform_commission=platform_commission,
                    net_payout=net_payout,
                    status=ProviderPayout.Statuses.PENDING,
                    payment_reference=ref_code,
                    notes=f"Auto-generated monthly settlement for {hub.name}",
                )
                generated_count += 1

            return Response({
                "message": f"Successfully generated {generated_count} provider payout settlement records!",
                "generated_count": generated_count,
            })

        return Response({"detail": "Invalid action. Supported actions: 'settle', 'generate'"}, status=status.HTTP_400_BAD_REQUEST)


class AdminDebitWalletView(APIView):
    """Debit / chargeback from a customer's wallet."""
    permission_classes = [IsAdminOrStaff]

    def post(self, request):
        from django.db.models import F

        user_id = request.data.get("user_id")
        if not user_id:
            return Response({"error": "user_id is required"}, status=status.HTTP_400_BAD_REQUEST)

        amount_str = request.data.get("amount", "0")
        desc = request.data.get("description", "Admin Wallet Debit")

        try:
            amount = Decimal(str(amount_str))
            if amount <= 0:
                return Response({"error": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST)
            user = User.objects.get(pk=user_id)
        except (User.DoesNotExist, Exception) as e:
            return Response({"detail": f"User not found or invalid amount: {e}"}, status=status.HTTP_400_BAD_REQUEST)

        if user.wallet_balance < amount:
            return Response({"error": f"Insufficient balance. Current: ₹{user.wallet_balance}"}, status=status.HTTP_400_BAD_REQUEST)

        User.objects.filter(pk=user_id).update(wallet_balance=F('wallet_balance') - amount)
        user.refresh_from_db()

        tx = WalletTransaction.objects.create(
            user=user,
            amount=amount,
            transaction_type=WalletTransaction.Types.DEBIT,
            description=f"🔻 {desc}",
        )

        Notification.objects.create(
            user=user,
            title="🔻 Wallet Debit Adjustment",
            message=f"₹{amount} debited from your wallet by Admin. Reason: {desc}. New Balance: ₹{user.wallet_balance}",
            notification_type=Notification.Types.WALLET,
        )

        return Response({
            "message": f"Successfully debited ₹{amount} from {user.username}'s wallet",
            "new_balance": str(user.wallet_balance),
            "transaction": WalletTransactionSerializer(tx).data,
        })


class AdminVacationPausesView(APIView):
    """List all vacation pauses for admin dashboard."""
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        pauses = VacationPause.objects.select_related(
            "subscription__customer", "subscription__product"
        ).order_by("-created_at")

        data = []
        for vp in pauses:
            sub = vp.subscription
            cust = sub.customer if sub else None
            data.append({
                "id": vp.id,
                "subscription_id": sub.id if sub else None,
                "customer_name": f"{cust.first_name} {cust.last_name}".strip() or cust.username if cust else "",
                "customer_phone": cust.phone if cust else "",
                "product_name": sub.product.name if sub and sub.product else "",
                "start_date": str(vp.start_date),
                "end_date": str(vp.end_date),
                "reason": vp.reason,
                "created_at": vp.created_at.isoformat() if vp.created_at else None,
            })
        return Response(data)


class AdminCustomerExportView(APIView):
    """Export all customers as CSV."""
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        import csv
        from django.http import HttpResponse
        from apps.subscriptions.models import Subscription

        customers = User.objects.filter(role=User.Roles.CUSTOMER).order_by("id")

        response = HttpResponse(content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="customers_export.csv"'

        writer = csv.writer(response)
        writer.writerow([
            "ID", "Username", "First Name", "Last Name", "Phone", "Email",
            "City", "Address", "Wallet Balance", "Active Subscriptions",
            "Date Joined", "Account Active"
        ])

        for c in customers:
            active_subs = Subscription.objects.filter(customer=c, status=Subscription.Statuses.ACTIVE).count()
            writer.writerow([
                c.id, c.username, c.first_name, c.last_name, c.phone, c.email,
                c.city, c.address, str(c.wallet_balance), active_subs,
                c.date_joined.strftime("%Y-%m-%d"), "Yes" if c.is_active else "No"
            ])

        return response


class AdminDeliveryReassignView(APIView):
    """Reassign single or multiple delivery tasks to a specific driver."""
    permission_classes = [IsAdminOrHubManager]

    def post(self, request):
        """Batch reassign tasks: { "task_ids": [1, 2, 3], "driver_id": 4 }"""
        task_ids = request.data.get("task_ids", [])
        driver_id = request.data.get("driver_id")

        if not task_ids or not isinstance(task_ids, list):
            return Response({"error": "task_ids list is required"}, status=status.HTTP_400_BAD_REQUEST)

        driver = None
        if driver_id:
            driver = User.objects.filter(pk=driver_id, role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"]).first()
            if not driver:
                return Response({"detail": "Driver not found"}, status=status.HTTP_404_NOT_FOUND)

        updated_count = DeliveryTask.objects.filter(id__in=task_ids).update(driver=driver)

        if driver and updated_count > 0:
            driver_name = f"{driver.first_name} {driver.last_name}".strip() or driver.username
            Notification.objects.create(
                user=driver,
                title="🚚 New Stops Assigned to Your Route",
                message=f"{updated_count} delivery stop(s) have been assigned to your route.",
                notification_type=Notification.Types.DELIVERY,
            )

        return Response({
            "message": f"Successfully updated {updated_count} delivery task(s).",
            "updated_count": updated_count,
            "driver_id": driver.id if driver else None,
            "driver_name": f"{driver.first_name} {driver.last_name}".strip() if driver else "Unassigned",
        })

    def patch(self, request, pk=None):
        driver_id = request.data.get("driver_id")

        task = DeliveryTask.objects.filter(pk=pk).first()
        if not task:
            return Response({"detail": "Delivery task not found"}, status=status.HTTP_404_NOT_FOUND)

        driver = None
        if driver_id:
            driver = User.objects.filter(pk=driver_id, role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"]).first()
            if not driver:
                return Response({"detail": "Driver not found"}, status=status.HTTP_404_NOT_FOUND)

        old_driver = f"{task.driver.first_name} {task.driver.last_name}".strip() if task.driver else "Unassigned"
        task.driver = driver
        task.save(update_fields=["driver"])

        new_driver = f"{driver.first_name} {driver.last_name}".strip() if driver else "Unassigned"

        if driver:
            Notification.objects.create(
                user=driver,
                title="🚚 Stop Assigned to Your Route",
                message=f"Delivery task #{task.id} for {task.customerName if hasattr(task, 'customerName') else 'customer'} has been assigned to you.",
                notification_type=Notification.Types.DELIVERY,
            )

        return Response({
            "message": f"Task #{task.id} reassigned from '{old_driver}' to '{new_driver}'",
            "task_id": task.id,
            "new_driver_id": driver.id if driver else None,
            "new_driver_name": new_driver,
        })


class AdminSupportAgentListCreateView(APIView):
    """
    List all active support agents or create a new support executive user.
    GET  /api/admin/support-agents/
    POST /api/admin/support-agents/create/
    """
    permission_classes = [IsAdminOrStaff]

    def get(self, request):
        agents = User.objects.filter(role=User.Roles.SUPPORT_AGENT).select_related("assigned_hub").order_by("-date_joined")
        data = []
        for a in agents:
            data.append({
                "id": a.id,
                "username": a.username,
                "first_name": a.first_name,
                "last_name": a.last_name,
                "full_name": f"{a.first_name} {a.last_name}".strip() or a.username,
                "phone": a.phone,
                "email": a.email,
                "role": a.role,
                "is_active": a.is_active,
                "assigned_hub": a.assigned_hub.name if a.assigned_hub else "Kodad Central Hub",
                "assigned_hub_code": a.assigned_hub.hub_code if a.assigned_hub else "HUB-KDD-01",
                "date_joined": a.date_joined.strftime("%d %b %Y"),
            })
        return Response(data, status=status.HTTP_200_OK)

    def post(self, request):
        from apps.deliveries.models import LocationHub

        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()
        phone = request.data.get("phone", "").strip()
        email = request.data.get("email", "").strip()
        password = request.data.get("password", "").strip() or "Support@123"
        hub_code = request.data.get("hub_code", "").strip()

        if not phone:
            return Response({"error": "Mobile phone number is required"}, status=status.HTTP_400_BAD_REQUEST)
        if not first_name:
            return Response({"error": "First name is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Normalize phone
        clean_phone = phone.replace("+91", "").replace(" ", "").replace("-", "").strip()
        if len(clean_phone) == 10:
            formatted_phone = f"+91{clean_phone}"
        else:
            formatted_phone = phone

        if User.objects.filter(phone=formatted_phone).exists():
            return Response({"error": f"A user with phone {formatted_phone} already exists."}, status=status.HTTP_400_BAD_REQUEST)

        username = request.data.get("username", "").strip() or f"support_{clean_phone[-6:]}"
        if User.objects.filter(username=username).exists():
            username = f"support_{clean_phone[-6:]}_{uuid.uuid4().hex[:4]}"

        hub = None
        if hub_code:
            hub = LocationHub.objects.filter(hub_code=hub_code).first()
        if not hub:
            hub = LocationHub.objects.first()

        agent = User.objects.create_user(
            username=username,
            phone=formatted_phone,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            role=User.Roles.SUPPORT_AGENT,
            is_staff=True,
            assigned_hub=hub,
        )

        return Response({
            "message": f"Support Executive '{agent.first_name} {agent.last_name}' created successfully!",
            "agent": {
                "id": agent.id,
                "username": agent.username,
                "full_name": f"{agent.first_name} {agent.last_name}".strip(),
                "phone": agent.phone,
                "email": agent.email,
                "role": agent.role,
                "assigned_hub": agent.assigned_hub.name if agent.assigned_hub else "Kodad Central Hub",
                "assigned_hub_code": agent.assigned_hub.hub_code if agent.assigned_hub else "HUB-KDD-01",
                "date_joined": agent.date_joined.strftime("%d %b %Y"),
            }
        }, status=status.HTTP_201_CREATED)


class AdminSupportAgentDetailView(APIView):
    """
    Deactivate or toggle support agent status.
    PATCH  /api/admin/support-agents/<id>/
    DELETE /api/admin/support-agents/<id>/
    """
    permission_classes = [IsAdminOrStaff]

    def patch(self, request, pk):
        agent = User.objects.filter(pk=pk, role=User.Roles.SUPPORT_AGENT).first()
        if not agent:
            return Response({"detail": "Support agent not found"}, status=status.HTTP_404_NOT_FOUND)

        is_active = request.data.get("is_active")
        if is_active is not None:
            agent.is_active = bool(is_active)
            agent.save()

        return Response({
            "message": f"Support agent status updated (is_active: {agent.is_active})",
            "id": agent.id,
            "is_active": agent.is_active,
        })

    def delete(self, request, pk):
        agent = User.objects.filter(pk=pk, role=User.Roles.SUPPORT_AGENT).first()
        if not agent:
            return Response({"detail": "Support agent not found"}, status=status.HTTP_404_NOT_FOUND)

        agent_name = f"{agent.first_name} {agent.last_name}".strip() or agent.username
        agent.delete()
        return Response({"message": f"Support agent '{agent_name}' deleted successfully."}, status=status.HTTP_200_OK)
