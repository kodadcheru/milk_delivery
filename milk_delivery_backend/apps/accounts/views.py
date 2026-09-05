from decimal import Decimal
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.pagination import StandardResultsSetPagination
from apps.accounts.models import Notification, User, WalletTransaction
from apps.accounts.serializers import (
    NotificationSerializer,
    RegisterSerializer,
    UserSerializer,
    WalletTopUpSerializer,
    WalletTransactionSerializer,
)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def perform_create(self, serializer):
        user = serializer.save()
        if user.address:
            from apps.accounts.models import CustomerAddress
            CustomerAddress.objects.get_or_create(
                customer=user,
                is_default=True,
                defaults={
                    'address_type': 'HOME',
                    'street_address': user.address,
                    'city': user.city or 'Kodad',
                    'pincode': getattr(user, 'pincode', '508206'),
                    'latitude': user.latitude or 17.001734,
                    'longitude': user.longitude or 79.9625,
                    'delivery_instructions': '',
                }
            )


class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class WalletBalanceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(
            {
                "wallet_balance": str(request.user.wallet_balance),
                "currency": "INR",
            }
        )


class WalletTopUpView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = WalletTopUpSerializer(data=request.data)
        if serializer.is_valid():
            amount = serializer.validated_data["amount"]
            desc = serializer.validated_data["description"]
            payment_method = serializer.validated_data.get("payment_method", "UPI")
            payment_ref = serializer.validated_data.get("payment_reference", "").strip()

            if amount > Decimal("10000.00"):
                return Response({"detail": "Maximum single top-up limit is ₹10,000.00."}, status=status.HTTP_400_BAD_REQUEST)

            if not payment_ref or len(payment_ref) < 6:
                return Response({"detail": "Valid payment transaction/UTR reference is required for recharge."}, status=status.HTTP_400_BAD_REQUEST)

            # Prevent duplicate top-ups with the same transaction reference
            if WalletTransaction.objects.filter(description__icontains=payment_ref).exists():
                return Response({"detail": "This payment reference has already been processed."}, status=status.HTTP_400_BAD_REQUEST)

            user = request.user

            with transaction.atomic():
                User.objects.filter(pk=user.pk).update(wallet_balance=F("wallet_balance") + amount)
                user.refresh_from_db()

            tx_desc = f"{desc} via {payment_method}"
            if payment_ref:
                tx_desc += f" (Ref: {payment_ref})"

            tx = WalletTransaction.objects.create(
                user=user,
                amount=amount,
                transaction_type=WalletTransaction.Types.CREDIT,
                description=tx_desc,
            )

            # Auto-generate Notification for Wallet Top Up
            Notification.objects.create(
                user=user,
                title="⚡ Wallet Recharged",
                message=f"₹{amount} credited to your prepaid wallet via {desc}. New balance: ₹{user.wallet_balance}",
                notification_type=Notification.Types.WALLET,
            )

            return Response(
                {
                    "message": "Top-up successful",
                    "new_balance": str(user.wallet_balance),
                    "transaction": WalletTransactionSerializer(tx).data,
                },
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class WalletTransactionListView(generics.ListAPIView):
    serializer_class = WalletTransactionSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        return WalletTransaction.objects.filter(user=self.request.user).order_by("-created_at")


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user).order_by("-created_at")


class NotificationMarkReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk=None):
        if pk:
            try:
                notif = Notification.objects.get(pk=pk, user=request.user)
                notif.is_read = True
                notif.save()
                return Response({"message": "Marked as read"})
            except Notification.DoesNotExist:
                return Response({"detail": "Notification not found"}, status=status.HTTP_404_NOT_FOUND)
        else:
            Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
            return Response({"message": "All notifications marked as read"})


class RobustTokenObtainPairView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from django.contrib.auth import authenticate
        from rest_framework_simplejwt.tokens import RefreshToken

        username_input = request.data.get("username", "").strip()
        password_input = request.data.get("password", "")

        if not username_input or not password_input:
            return Response(
                {"detail": "Username and password are required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Standard Django Authentication
        user = authenticate(request, username=username_input, password=password_input)

        # Try matching phone or email
        if not user:
            clean_phone = username_input.replace(" ", "").replace("-", "").replace("+91", "").strip()
            user_candidate = (
                User.objects.filter(phone__icontains=clean_phone).first()
                or User.objects.filter(email__iexact=username_input).first()
                or User.objects.filter(username__iexact=username_input).first()
            )
            if user_candidate and user_candidate.check_password(password_input):
                user = user_candidate

        if not user:
            return Response(
                {"detail": "Invalid credentials. Please verify your username and password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        refresh = RefreshToken.for_user(user)
        return Response({
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": UserSerializer(user).data,
        })


class DriverLocationUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        lat = request.data.get("latitude")
        lng = request.data.get("longitude")
        status_val = request.data.get("status", "ON_DUTY")

        if lat is not None and lng is not None:
            user.latitude = Decimal(str(lat))
            user.longitude = Decimal(str(lng))
            user.driver_status = status_val
            user.last_location_updated = timezone.now()
            user.save(update_fields=["latitude", "longitude", "driver_status", "last_location_updated"])

            try:
                from apps.core.consumers import broadcast_hub_event
                hub_code = getattr(user.assigned_hub, "hub_code", "HUB-KDD-01") if user.assigned_hub else "HUB-KDD-01"
                broadcast_hub_event(hub_code, "fleet_updated", {
                    "driver_id": user.id,
                    "driver_name": f"{user.first_name} {user.last_name}".strip() or user.username,
                    "latitude": float(user.latitude),
                    "longitude": float(user.longitude),
                    "status": user.driver_status,
                })
            except Exception:
                pass

        return Response({
            "message": "Driver location updated successfully",
            "driver_id": user.id,
            "driver_name": f"{user.first_name} {user.last_name}".strip() or user.username,
            "latitude": float(user.latitude) if user.latitude else 17.001734,
            "longitude": float(user.longitude) if user.longitude else 79.9625,
            "driver_status": user.driver_status,
            "last_location_updated": user.last_location_updated.isoformat() if user.last_location_updated else None,
        })


class DriverLocationByOrderView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, order_id):
        from apps.deliveries.models import LiveOrder, DeliveryTask
        from apps.accounts.models import User

        driver = None
        task = None
        order = None

        # 1. Look up by LiveOrder ID
        order = LiveOrder.objects.filter(id=order_id).select_related('driver', 'hub').first()
        if order and order.driver:
            driver = order.driver

        # 2. Look up by DeliveryTask ID (e.g. "TASK-12", "12")
        if not driver:
            clean_id = str(order_id).replace("TASK-", "").replace("TASK#", "").replace("#", "").strip()
            if clean_id.isdigit():
                task = DeliveryTask.objects.filter(id=int(clean_id)).select_related('driver', 'hub').first()
                if task and task.driver:
                    driver = task.driver

        # 3. Direct driver user ID
        if not driver and str(order_id).isdigit():
            driver = User.objects.filter(id=int(order_id), role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"]).first()

        # 4. Fallback to active customer delivery driver or hub driver
        if not driver and request.user.is_authenticated:
            # Check today's pending/active delivery task for this customer
            cust_task = DeliveryTask.objects.filter(
                subscription__customer=request.user,
                delivery_date=timezone.now().date(),
            ).exclude(status=DeliveryTask.Statuses.DELIVERED).select_related('driver').first()
            if cust_task and cust_task.driver:
                driver = cust_task.driver
            elif getattr(request.user, "assigned_hub", None):
                driver = User.objects.filter(
                    role__in=[User.Roles.DELIVERY_PARTNER, "DRIVER"],
                    assigned_hub=request.user.assigned_hub,
                    driver_status="ACTIVE",
                ).first()

        # Calculate dynamic drops ahead if task exists
        drops_ahead = 0
        task_status = getattr(task, 'status', None)
        task_hub = getattr(task, 'hub', None)
        if not task_hub and task and task.subscription:
            task_hub = getattr(task.subscription, 'hub', None)
        if not task_hub and order and getattr(order, 'hub', None):
            task_hub = order.hub
        if not task_hub and getattr(driver, 'assigned_hub', None):
            task_hub = driver.assigned_hub

        if task and driver:
            drops_ahead = DeliveryTask.objects.filter(
                driver=driver,
                delivery_date=task.delivery_date,
                status__in=[DeliveryTask.Statuses.PENDING, DeliveryTask.Statuses.PICKED_UP, DeliveryTask.Statuses.ON_THE_WAY],
                id__lt=task.id,
            ).count()

        lat = float(driver.latitude) if (driver.latitude and float(driver.latitude) != 0.0) else (float(task_hub.latitude) if task_hub and task_hub.latitude else 0.0)
        lng = float(driver.longitude) if (driver.longitude and float(driver.longitude) != 0.0) else (float(task_hub.longitude) if task_hub and task_hub.longitude else 0.0)

        return Response({
            "driver_id": driver.id,
            "driver_name": f"{driver.first_name} {driver.last_name}".strip() or driver.username,
            "driver_phone": driver.phone or "",
            "latitude": lat,
            "longitude": lng,
            "driver_status": driver.driver_status or "ACTIVE",
            "task_status": task_status or "PENDING",
            "drops_ahead": drops_ahead,
            "hub_name": task_hub.name if task_hub else "",
            "hub_latitude": float(task_hub.latitude) if task_hub and task_hub.latitude else lat,
            "hub_longitude": float(task_hub.longitude) if task_hub and task_hub.longitude else lng,
            "vehicle_number": driver.vehicle_number or "",
            "last_location_updated": driver.last_location_updated.isoformat() if driver.last_location_updated else timezone.now().isoformat(),
        })

