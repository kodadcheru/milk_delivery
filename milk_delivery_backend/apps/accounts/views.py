from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

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

            user = request.user
            user.wallet_balance += amount
            user.save()

            tx = WalletTransaction.objects.create(
                user=user,
                amount=amount,
                transaction_type=WalletTransaction.Types.CREDIT,
                description=desc,
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

    def get_queryset(self):
        return WalletTransaction.objects.filter(user=self.request.user)


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


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
            Notification.filter = Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
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

        # 1. Guaranteed self-healing for demo accounts (Admin / Hub Manager / Driver / Customer)
        if username_input == "admin" and password_input == "admin123":
            user, _ = User.objects.get_or_create(
                username="admin",
                defaults={
                    "email": "admin@milkdrop.in",
                    "first_name": "Rajesh",
                    "last_name": "Varma",
                    "role": User.Roles.ADMIN,
                    "phone": "+91 98888 77777",
                    "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
                    "is_staff": True,
                    "is_superuser": True,
                    "wallet_balance": Decimal("10000.00"),
                },
            )
            user.set_password("admin123")
            user.is_staff = True
            user.is_superuser = True
            user.role = User.Roles.ADMIN
            user.is_active = True
            user.save()
        elif username_input == "hub_manager" and password_input == "pass123":
            user, _ = User.objects.get_or_create(
                username="hub_manager",
                defaults={
                    "email": "hubmanager@milkdrop.in",
                    "first_name": "Sanjay",
                    "last_name": "Rao",
                    "role": User.Roles.ADMIN,
                    "phone": "+91 97654 32100",
                    "address": "Madhapur Tech Enclave Depot #3",
                    "is_staff": True,
                    "wallet_balance": Decimal("5000.00"),
                },
            )
            user.set_password("pass123")
            user.is_staff = True
            user.role = User.Roles.ADMIN
            user.is_active = True
            user.save()
        elif username_input == "driver" and password_input == "pass123":
            user, _ = User.objects.get_or_create(
                username="driver",
                defaults={
                    "email": "driver@milkdrop.in",
                    "first_name": "Suresh",
                    "last_name": "Rao",
                    "role": User.Roles.DELIVERY_PARTNER,
                    "phone": "+91 9123456789",
                    "address": "Jubilee Hills Central Depot #1",
                    "wallet_balance": Decimal("0.00"),
                },
            )
            user.set_password("pass123")
            user.role = User.Roles.DELIVERY_PARTNER
            user.is_active = True
            user.save()
        elif username_input == "customer" and password_input == "pass123":
            user, _ = User.objects.get_or_create(
                username="customer",
                defaults={
                    "email": "customer@milkdrop.in",
                    "first_name": "Ramesh",
                    "last_name": "Kumar",
                    "role": User.Roles.CUSTOMER,
                    "phone": "+91 98765 43210",
                    "address": "Flat 402, Road No. 36, Jubilee Hills, Hyderabad",
                    "wallet_balance": Decimal("1500.00"),
                },
            )
            user.set_password("pass123")
            user.role = User.Roles.CUSTOMER
            user.is_active = True
            user.save()
        else:
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
