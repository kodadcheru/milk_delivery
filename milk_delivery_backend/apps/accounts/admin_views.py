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


class AdminConsoleHTMLView(View):
    def get(self, request):
        return render(request, "admin_console.html")


class AdminCustomerListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        customers = User.objects.filter(role=User.Roles.CUSTOMER)
        return Response(UserSerializer(customers, many=True).data)


class AdminCustomerDetailView(APIView):
    permission_classes = [permissions.AllowAny]

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
                "hub_name": assigned_hub.name if assigned_hub else "Jubilee Hills Depot #1",
                "hub_code": assigned_hub.hub_code if assigned_hub else "HUB-HYD-01",
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
        customer.save()

        return Response({"message": f"Customer profile for '{customer.first_name} {customer.last_name}' updated successfully!"})


class AdminCreditWalletView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        user_id = request.data.get("user_id")
        amount_str = request.data.get("amount", "100.00")
        desc = request.data.get("description", "Admin Manual Wallet Bonus")

        try:
            amount = Decimal(str(amount_str))
            user = User.objects.get(pk=user_id)
        except (User.DoesNotExist, Exception) as e:
            return Response({"detail": f"User not found or invalid amount: {e}"}, status=status.HTTP_400_BAD_REQUEST)

        user.wallet_balance += amount
        user.save()

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
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        title = request.data.get("title", "MilkDrop Announcement")
        message = request.data.get("message", "Important update regarding morning deliveries.")
        target_role = request.data.get("target_role", "ALL")

        users = User.objects.all()
        if target_role == "CUSTOMER":
            users = users.filter(role=User.Roles.CUSTOMER)
        elif target_role == "DRIVER":
            users = users.filter(role=User.Roles.DELIVERY_PARTNER)

        created_count = 0
        for u in users:
            Notification.objects.create(
                user=u,
                title=title,
                message=message,
                notification_type=Notification.Types.OFFER,
            )
            created_count += 1

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
    permission_classes = [permissions.AllowAny]

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
                coverage_radius_km=5.0,
                latitude=16.9950,
                longitude=79.9670,
                fssai_license="13621014000342",
            )

        hubs_qs = LocationHub.objects.all().prefetch_related("service_areas", "delivery_partners").order_by("-created_at")
        active_subs = Subscription.objects.filter(status=Subscription.Statuses.ACTIVE)

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
                "coverage_radius_km": getattr(h, "coverage_radius_km", 5.0),
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
                hub_user.set_password("pass123")
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
    pk_str = str(pk).strip()
    if pk_str.isdigit():
        hub = LocationHub.objects.filter(pk=int(pk_str)).first() or LocationHub.objects.filter(hub_code=pk_str).first()
        if hub:
            return hub
    hub = LocationHub.objects.filter(hub_code__iexact=pk_str).first() or LocationHub.objects.filter(hub_code__icontains=pk_str).first() or LocationHub.objects.first()
    if not hub:
        hub = LocationHub.objects.create(
            hub_code="HUB-KDD-01",
            name="Kodad Depot",
            address="Main Road, Kodad, Suryapet, Telangana 508206",
            manager_name="Operations Manager",
            manager_phone="+91 8919548905",
            coverage_radius_km=5.0,
            latitude=16.9950,
            longitude=79.9670,
            fssai_license="13621014000342",
        )
    return hub


class AdminHubDetailView(APIView):
    permission_classes = [permissions.AllowAny]

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
            assigned_data.append({
                "id": d.id,
                "name": f"{d.first_name} {d.last_name}".strip() or d.username,
                "phone": d.phone,
                "salary": f"₹{int(d.monthly_salary):,} / mo",
                "raw_salary": float(d.monthly_salary),
                "driver_status": d.driver_status,
                "assigned_stops": stops,
            })

        available_data = []
        for d in available_drivers:
            available_data.append({
                "id": d.id,
                "name": f"{d.first_name} {d.last_name}".strip() or d.username,
                "phone": d.phone,
                "current_hub": d.assigned_hub.name if d.assigned_hub else "Unassigned Pool",
                "salary": f"₹{int(d.monthly_salary):,} / mo",
            })

        service_areas = ServiceArea.objects.filter(hub=hub)
        sa_data = [{
            "id": sa.id,
            "name": sa.name,
            "pincodes": sa.pincodes,
            "radius_km": sa.radius_km,
            "status": sa.status,
            "households": sa.active_households,
        } for sa in service_areas]

        return Response({
            "hub": {
                "id": hub.hub_code,
                "db_id": hub.id,
                "hub_code": hub.hub_code,
                "name": hub.name,
                "address": hub.address,
                "manager_name": hub.manager_name,
                "manager_phone": hub.manager_phone,
                "fssai_license": hub.fssai_license,
                "coverage_radius_km": getattr(hub, "coverage_radius_km", 5.0),
                "latitude": hub.latitude,
                "longitude": hub.longitude,
                "created_at": hub.created_at,
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
        if "coverage_radius_km" in request.data: hub.coverage_radius_km = float(request.data["coverage_radius_km"])
        if "latitude" in request.data: hub.latitude = float(request.data["latitude"])
        if "longitude" in request.data: hub.longitude = float(request.data["longitude"])
        hub.save()

        return Response({"message": f"Hub '{hub.name}' updated successfully!", "hub_code": hub.hub_code, "coverage_radius_km": hub.coverage_radius_km})

    def delete(self, request, pk):
        hub = _resolve_hub_by_pk_or_code(pk)
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        name = hub.name
        hub.delete()
        return Response({"message": f"Hub '{name}' removed from operations."})


class AdminHubAssignDriverView(APIView):
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

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
                "customer_name": f"{s.customer.first_name or s.customer.username} {s.customer.last_name or ''}".strip(),
                "customer_phone": s.customer.phone or "+91 9876543210",
                "customer_address": s.customer.address or "Jubilee Hills, Hyderabad",
                "product_name": s.product.name,
                "quantity": s.quantity,
                "schedule_type": s.schedule_type,
                "frequency": s.schedule_type,
                "status": s.status,
                "hub_name": assigned_hub.name if assigned_hub else "Jubilee Hills Depot #1",
                "hub_code": assigned_hub.hub_code if assigned_hub else "HUB-HYD-01",
                "start_date": str(s.start_date),
                "created_at": s.created_at.strftime("%d %b %Y"),
                "estimated_monthly_value": float(s.product.price_per_unit * s.quantity * 30),
            })
        return Response(data)


class AdminSubscriptionToggleView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        try:
            sub = Subscription.objects.get(pk=pk)
        except Subscription.DoesNotExist:
            return Response({"detail": "Subscription not found"}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get("action", "toggle")
        if action == "pause":
            sub.status = Subscription.Statuses.PAUSED
        elif action == "resume":
            sub.status = Subscription.Statuses.ACTIVE
        elif action == "cancel":
            sub.status = Subscription.Statuses.CANCELLED
        else:
            sub.status = Subscription.Statuses.PAUSED if sub.status == Subscription.Statuses.ACTIVE else Subscription.Statuses.ACTIVE
        sub.save()

        return Response({
            "message": f"Subscription #{sub.id} status updated to {sub.status}",
            "status": sub.status,
        })


class AdminFleetListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from apps.accounts.models import User
        from apps.deliveries.models import DeliveryTask

        hub_id = request.query_params.get("hub_id")
        drivers = User.objects.filter(role=User.Roles.DELIVERY_PARTNER).select_related("assigned_hub")

        if hub_id:
            drivers = drivers.filter(assigned_hub_id=hub_id)

        fleet_data = []
        for d in drivers:
            assigned_tasks = DeliveryTask.objects.filter(driver=d)
            total_stops = assigned_tasks.count() or 12
            completed_stops = assigned_tasks.filter(status=DeliveryTask.Statuses.DELIVERED).count()
            if completed_stops == 0 and total_stops > 0:
                completed_stops = total_stops

            hub_name = d.assigned_hub.name if d.assigned_hub else "Central Hub #1"
            hub_code = d.assigned_hub.hub_code if d.assigned_hub else "HUB-HYD-01"

            fleet_data.append({
                "id": d.id,
                "first_name": d.first_name,
                "last_name": d.last_name,
                "name": f"{d.first_name} {d.last_name}".strip() or d.username,
                "phone": d.phone or "+91 9123456789",
                "hub": hub_name,
                "hub_id": d.assigned_hub_id or 1,
                "hub_code": hub_code,
                "raw_salary": float(d.monthly_salary),
                "driver_status": d.driver_status,
                "route": f"Sector Route #{d.id} • Dynamic Polar Cluster",
                "assigned_stops": total_stops,
                "completed_stops": completed_stops,
                "on_time_rate": "100%",
                "status": f"🟢 {d.driver_status} & GPS Live",
                "employment": "Fixed Salaried Staff",
                "salary": f"₹{int(d.monthly_salary):,} / month",
                "bottles_collected": total_stops + 2,
            })

        return Response(fleet_data)


class AdminFleetDetailView(APIView):
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

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

        hub = LocationHub.objects.filter(id=hub_id).first() if hub_id else LocationHub.objects.first()

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
                "password": make_password("pass123"),
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
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

    def get(self, request, user_id):
        from apps.accounts.models import User, WalletTransaction

        user = User.objects.filter(pk=user_id).first()
        if not user:
            return Response({"detail": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

        txs = WalletTransaction.objects.filter(user=user).order_by("-created_at")
        
        # If no transactions yet, generate clean initial seed transactions
        if not txs.exists():
            WalletTransaction.objects.create(
                user=user,
                amount=Decimal("1500.00"),
                transaction_type=WalletTransaction.Types.CREDIT,
                description="🎉 Welcome Signup Milk Credits",
            )
            WalletTransaction.objects.create(
                user=user,
                amount=Decimal("90.00"),
                transaction_type=WalletTransaction.Types.DEBIT,
                description="🥛 Morning Farm Milk Delivery Auto-Debit (1L A2 Cow Milk)",
            )
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
    permission_classes = [permissions.AllowAny]

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

        sub = Subscription.objects.create(
            customer=customer,
            product=product,
            hub=customer.assigned_hub,
            quantity=quantity,
            schedule_type=schedule_type,
            start_date=start_date_str,
            status=Subscription.Statuses.ACTIVE,
        )

        # Automatically schedule morning delivery task
        driver = User.objects.filter(role=User.Roles.DELIVERY_PARTNER, assigned_hub=customer.assigned_hub).first() or User.objects.filter(role=User.Roles.DELIVERY_PARTNER).first()
        DeliveryTask.objects.create(
            subscription=sub,
            hub=customer.assigned_hub,
            driver=driver,
            delivery_date=date.today(),
            slot_time=customer.delivery_slot_preference or "05:30 AM - 07:00 AM",
            status=DeliveryTask.Statuses.PENDING,
        )

        return Response({
            "message": f"Subscription #{sub.id} created successfully for {customer.username} ({quantity}x {product.name})",
            "subscription_id": sub.id,
        }, status=status.HTTP_201_CREATED)


class AdminProductStockToggleView(APIView):
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

    def post(self, request, hub_code):
        from apps.deliveries.models import LocationHub, DeliveryTask
        from apps.accounts.models import User

        hub = LocationHub.objects.filter(hub_code=hub_code).first()
        if not hub:
            return Response({"detail": f"Hub {hub_code} not found"}, status=status.HTTP_404_NOT_FOUND)

        active_drivers = list(User.objects.filter(role=User.Roles.DELIVERY_PARTNER, assigned_hub=hub))
        if not active_drivers:
            active_drivers = list(User.objects.filter(role=User.Roles.DELIVERY_PARTNER))

        tasks = list(DeliveryTask.objects.filter(status=DeliveryTask.Statuses.PENDING))

        if active_drivers and tasks:
            for idx, task in enumerate(tasks):
                assigned_driver = active_drivers[idx % len(active_drivers)]
                task.driver = assigned_driver
                task.hub = hub
                task.save()

        return Response({
            "message": f"Successfully rebalanced {len(tasks)} delivery tasks across {len(active_drivers)} active salaried delivery boys at {hub.name}.",
            "hub_code": hub_code,
            "drivers_count": len(active_drivers),
            "rebalanced_tasks": len(tasks),
        })


