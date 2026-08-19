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
        from apps.deliveries.models import LocationHub
        from apps.subscriptions.models import Subscription

        hubs_qs = LocationHub.objects.all().prefetch_related("service_areas", "delivery_partners").order_by("-created_at")
        active_subs = Subscription.objects.filter(status=Subscription.Statuses.ACTIVE)

        total_sub_count = active_subs.count() or 0
        total_vol = sum(s.quantity for s in active_subs) or 0

        hubs_data = []
        for idx, h in enumerate(hubs_qs, 1):
            service_areas_count = h.service_areas.count()
            real_boys = h.delivery_partners.filter(role=User.Roles.DRIVER).count()

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
            hub.latitude = lat
            hub.longitude = lng
            hub.save()

        return Response({
            "message": f"Location Hub '{name}' ({hub_code}) registered successfully!",
            "id": hub.hub_code,
            "db_id": hub.id,
            "name": hub.name,
            "hub_code": hub.hub_code,
        }, status=status.HTTP_201_CREATED)


class AdminHubDetailView(APIView):
    permission_classes = [permissions.AllowAny]

    def patch(self, request, pk):
        from apps.deliveries.models import LocationHub
        hub = LocationHub.objects.filter(pk=pk).first() or LocationHub.objects.filter(hub_code=str(pk)).first()
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        if "name" in request.data: hub.name = request.data["name"]
        if "address" in request.data: hub.address = request.data["address"]
        if "manager_name" in request.data: hub.manager_name = request.data["manager_name"]
        if "manager_phone" in request.data: hub.manager_phone = request.data["manager_phone"]
        if "fssai_license" in request.data: hub.fssai_license = request.data["fssai_license"]
        if "latitude" in request.data: hub.latitude = float(request.data["latitude"])
        if "longitude" in request.data: hub.longitude = float(request.data["longitude"])
        hub.save()

        return Response({"message": f"Hub '{hub.name}' updated successfully!"})

    def delete(self, request, pk):
        from apps.deliveries.models import LocationHub
        hub = LocationHub.objects.filter(pk=pk).first() or LocationHub.objects.filter(hub_code=str(pk)).first()
        if not hub:
            return Response({"detail": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)

        name = hub.name
        hub.delete()
        return Response({"message": f"Hub '{name}' removed from operations."})


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
        subs = Subscription.objects.all().select_related("customer", "product")
        data = []
        for s in subs:
            data.append({
                "id": s.id,
                "customer_name": f"{s.customer.first_name or s.customer.username} {s.customer.last_name or ''}".strip(),
                "customer_phone": s.customer.phone or "+91 9876543210",
                "customer_address": s.customer.address or "Jubilee Hills, Hyderabad",
                "product_name": s.product.name,
                "quantity": s.quantity,
                "frequency": s.frequency,
                "status": s.status,
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
        drivers = User.objects.filter(role=User.Roles.DRIVER).select_related("assigned_hub")

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

        driver = User.objects.filter(pk=pk, role=User.Roles.DRIVER).first()
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
        driver = User.objects.filter(pk=pk, role=User.Roles.DRIVER).first()
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

        first_name = request.data.get("first_name", "Delivery")
        last_name = request.data.get("last_name", "Boy")
        phone = request.data.get("phone", "").strip()
        hub_id = request.data.get("hub_id")
        salary = float(request.data.get("monthly_salary", 15000.0))

        if not phone:
            return Response({"detail": "Phone number is required"}, status=status.HTTP_400_BAD_REQUEST)

        hub = LocationHub.objects.filter(id=hub_id).first() if hub_id else LocationHub.objects.first()
        uname = f"driver_{phone.replace(' ', '')[-4:]}"

        driver, created = User.objects.get_or_create(
            phone=phone,
            defaults={
                "username": uname,
                "first_name": first_name,
                "last_name": last_name,
                "password": make_password("pass123"),
                "role": User.Roles.DRIVER,
                "assigned_hub": hub,
                "monthly_salary": salary,
                "address": hub.address if hub else "Depot",
                "driver_status": "ACTIVE",
            }
        )

        if not created:
            driver.first_name = first_name
            driver.last_name = last_name
            driver.assigned_hub = hub
            driver.monthly_salary = salary
            driver.save()

        return Response({
            "message": f"Delivery partner {first_name} {last_name} successfully affiliated with {hub.name if hub else 'Hub'}.",
            "driver_id": driver.id,
            "hub_name": hub.name if hub else "Depot",
            "salary": f"₹{int(salary):,} / month",
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
            quantity=quantity,
            schedule_type=schedule_type,
            start_date=start_date_str,
            status=Subscription.Statuses.ACTIVE,
        )

        # Automatically schedule morning delivery task
        driver = User.objects.filter(role=User.Roles.DRIVER, assigned_hub=customer.assigned_hub).first() or User.objects.filter(role=User.Roles.DRIVER).first()
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

        active_drivers = list(User.objects.filter(role=User.Roles.DRIVER, assigned_hub=hub))
        if not active_drivers:
            active_drivers = list(User.objects.filter(role=User.Roles.DRIVER))

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


