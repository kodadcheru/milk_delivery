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
                user=user,
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
            payment_ref = serializer.validated_data.get("payment_reference", "")

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
        from apps.deliveries.models import LiveOrder
        order = LiveOrder.objects.filter(id=order_id).select_related('driver').first()
        if not order or not order.driver:
            return Response({"detail": "Order or driver not found"}, status=status.HTTP_404_NOT_FOUND)
        driver = order.driver
        return Response({
            "driver_id": driver.id,
            "driver_name": f"{driver.first_name} {driver.last_name}".strip() or driver.username,
            "latitude": float(driver.latitude) if driver.latitude else 17.001734,
            "longitude": float(driver.longitude) if driver.longitude else 79.9625,
            "driver_status": driver.driver_status,
            "last_location_updated": driver.last_location_updated.isoformat() if driver.last_location_updated else None,
        })

