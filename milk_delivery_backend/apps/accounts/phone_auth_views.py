from decimal import Decimal
from datetime import date
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import Notification, User, WalletTransaction
from apps.accounts.serializers import UserSerializer
from apps.products.models import Product
from apps.subscriptions.models import Subscription
from apps.deliveries.models import DeliveryTask


def _get_or_create_admin_if_applicable(phone_last_10):
    if phone_last_10 == "8919548905":
        admin_user = (
            User.objects.filter(phone__endswith="8919548905").first()
            or User.objects.filter(username="admin").first()
        )
        if not admin_user:
            admin_user = User.objects.create(
                username="admin",
                phone="+91 8919548905",
                first_name="Operations",
                last_name="Administrator",
                email="admin@milkdrop.in",
                role=User.Roles.ADMIN,
                is_staff=True,
                is_superuser=True,
                wallet_balance=Decimal("10000.00"),
            )
            admin_user.set_password("admin123")
            admin_user.save()
        else:
            admin_user.phone = "+91 8919548905"
            admin_user.role = User.Roles.ADMIN
            admin_user.is_staff = True
            admin_user.is_superuser = True
            admin_user.save()
        return admin_user
    return None


class SendOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        if not phone:
            return Response({"detail": "Phone number is required."}, status=status.HTTP_400_BAD_REQUEST)

        clean_digits = "".join(filter(str.isdigit, phone))
        last_10 = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits

        _get_or_create_admin_if_applicable(last_10)

        formatted_phone = f"+91 {last_10}" if len(last_10) == 10 else phone
        is_existing = (
            User.objects.filter(phone=phone).exists()
            or User.objects.filter(phone=formatted_phone).exists()
            or User.objects.filter(phone__endswith=last_10).exists()
        )

        return Response(
            {
                "success": True,
                "message": "OTP sent successfully to phone number.",
                "phone": formatted_phone,
                "is_existing_user": is_existing,
                "test_otp": "1234",
            },
            status=status.HTTP_200_OK,
        )


class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        otp = request.data.get("otp", "").strip()

        if not phone or not otp:
            return Response({"detail": "Phone and OTP are required."}, status=status.HTTP_400_BAD_REQUEST)

        clean_digits = "".join(filter(str.isdigit, phone))
        last_10 = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits

        if otp != "1234":
            return Response({"detail": "Invalid OTP code. Use test OTP '1234'."}, status=status.HTTP_400_BAD_REQUEST)

        _get_or_create_admin_if_applicable(last_10)

        formatted_phone = f"+91 {last_10}" if len(last_10) == 10 else phone

        user = (
            User.objects.filter(phone=phone).first()
            or User.objects.filter(phone=formatted_phone).first()
            or User.objects.filter(phone__endswith=last_10).first()
        )

        if user:
            refresh = RefreshToken.for_user(user)
            return Response(
                {
                    "success": True,
                    "is_new_user": False,
                    "access": str(refresh.access_token),
                    "refresh": str(refresh),
                    "user": UserSerializer(user).data,
                },
                status=status.HTTP_200_OK,
            )
        else:
            return Response(
                {
                    "success": True,
                    "is_new_user": True,
                    "phone": formatted_phone,
                    "message": "New phone number verified. Please complete your registration.",
                },
                status=status.HTTP_200_OK,
            )


class RegisterMobileUserView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()
        email = request.data.get("email", "").strip()
        gender = request.data.get("gender", "Male").strip()
        address = request.data.get("address", "Jubilee Hills, Hyderabad").strip()
        instructions = request.data.get("delivery_instructions", "Ring bell twice and leave near doorstep box").strip()

        if not phone or not first_name:
            return Response({"detail": "Phone and Name are required."}, status=status.HTTP_400_BAD_REQUEST)

        clean_digits = "".join(filter(str.isdigit, phone))
        last_10 = clean_digits[-10:] if len(clean_digits) >= 10 else clean_digits
        formatted_phone = f"+91 {last_10}" if len(last_10) == 10 else phone

        if (
            User.objects.filter(phone=phone).exists()
            or User.objects.filter(phone=formatted_phone).exists()
            or User.objects.filter(phone__endswith=last_10).exists()
        ):
            return Response({"detail": "User with this phone number already exists."}, status=status.HTTP_400_BAD_REQUEST)

        username = f"cust_{last_10}"

        user = User.objects.create(
            username=username,
            phone=formatted_phone,
            first_name=first_name,
            last_name=last_name,
            email=email,
            address=address or "Jubilee Hills, Hyderabad",
            city="Hyderabad",
            role=User.Roles.CUSTOMER,
            wallet_balance=Decimal("500.00"),
            delivery_instructions=instructions,
        )
        user.set_password("pass123")
        user.save()

        # Initial Welcome Wallet Transaction
        WalletTransaction.objects.create(
            user=user,
            amount=Decimal("500.00"),
            transaction_type=WalletTransaction.Types.CREDIT,
            description="🎁 Welcome Bonus & Initial Top-Up",
        )

        # Welcome Notification
        Notification.objects.create(
            user=user,
            title="🥛 Welcome to MilkDrop Express!",
            message=f"Hello {first_name}! ₹500 welcome bonus credited to your prepaid wallet. Browse our farm fresh catalog to subscribe or order.",
            notification_type=Notification.Types.WALLET,
        )

        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "success": True,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
                "message": "Account created successfully with ₹500 prepaid bonus!",
            },
            status=status.HTTP_201_CREATED,
        )
