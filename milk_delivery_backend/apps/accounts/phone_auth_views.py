from decimal import Decimal
from datetime import date
import re
import uuid
from django.core.validators import validate_email as django_validate_email
from django.core.exceptions import ValidationError
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import Notification, User, WalletTransaction
from apps.accounts.serializers import UserSerializer
from apps.products.models import Product
from apps.subscriptions.models import Subscription
from apps.deliveries.models import DeliveryTask


def _clean_and_validate_indian_phone(phone_raw: str):
    """
    Validates and extracts a 10-digit Indian mobile number.
    Returns (formatted_phone, last_10, error_message).
    If valid: ("+91 9876543210", "9876543210", None)
    If invalid: (None, None, "error description")
    """
    if not phone_raw or not str(phone_raw).strip():
        return None, None, "Phone number is required."

    clean_digits = "".join(filter(str.isdigit, str(phone_raw)))

    # If phone has 12 digits and starts with 91 (e.g. +91 9876543210)
    if len(clean_digits) == 12 and clean_digits.startswith("91"):
        last_10 = clean_digits[2:]
    elif len(clean_digits) == 10:
        last_10 = clean_digits
    elif len(clean_digits) > 10:
        last_10 = clean_digits[-10:]
    else:
        return None, None, "Please enter a valid 10-digit mobile number."

    if not re.match(r"^[6-9]\d{9}$", last_10):
        return None, None, "Invalid mobile number. Must be a valid 10-digit Indian number starting with 6, 7, 8, or 9."

    return f"+91 {last_10}", last_10, None


def _get_or_create_staff_user_if_applicable(phone_last_10):
    if not phone_last_10 or len(phone_last_10) < 10:
        return None

    # 1. Super Admin (8919548905)
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
                email="admin@pamba.in",
                role=User.Roles.ADMIN,
                is_staff=True,
                is_superuser=True,
                wallet_balance=Decimal("10000.00"),
            )
            admin_user.set_password(uuid.uuid4().hex)
            admin_user.save()
        else:
            admin_user.phone = "+91 8919548905"
            admin_user.role = User.Roles.ADMIN
            admin_user.is_staff = True
            admin_user.is_superuser = True
            admin_user.save()
        return admin_user

    # 2. Location Hub Owner / Manager (Matching LocationHub.manager_phone)
    from apps.deliveries.models import LocationHub
    for hub in LocationHub.objects.all():
        clean_hub_phone = "".join(filter(str.isdigit, hub.manager_phone or ""))
        if clean_hub_phone and clean_hub_phone.endswith(phone_last_10):
            hub_user = (
                User.objects.filter(phone__endswith=phone_last_10).first()
                or User.objects.filter(username=f"hub_{hub.hub_code.lower()}").first()
            )
            if not hub_user:
                hub_user = User.objects.create(
                    username=f"hub_{hub.hub_code.lower()}",
                    phone=f"+91 {phone_last_10}",
                    first_name=hub.manager_name or hub.name,
                    last_name="Hub Manager",
                    email=f"hub_{hub.hub_code.lower()}@pamba.in",
                    role=User.Roles.HUB_MANAGER,  # "PROVIDER"
                    is_staff=True,
                    assigned_hub=hub,
                    wallet_balance=Decimal("10000.00"),
                )
                hub_user.set_password(uuid.uuid4().hex)
                hub_user.save()
            else:
                hub_user.assigned_hub = hub
                hub_user.is_staff = True
                if hub_user.role not in [User.Roles.ADMIN, User.Roles.HUB_MANAGER, "PROVIDER", "HUB_MANAGER"]:
                    hub_user.role = User.Roles.HUB_MANAGER
                hub_user.save()
            return hub_user

    return None


class SendOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        formatted_phone, last_10, err = _clean_and_validate_indian_phone(phone)
        if err:
            return Response({"detail": err}, status=status.HTTP_400_BAD_REQUEST)

        _get_or_create_staff_user_if_applicable(last_10)

        is_existing = (
            User.objects.filter(phone=phone).exists()
            or User.objects.filter(phone=formatted_phone).exists()
            or User.objects.filter(phone__endswith=last_10).exists()
        )

        response_data = {
            "success": True,
            "message": "OTP sent successfully to phone number.",
            "phone": formatted_phone,
            "is_existing_user": is_existing,
        }

        from django.conf import settings
        if settings.DEBUG:
            response_data["test_otp"] = "1234"

        return Response(response_data, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        otp = request.data.get("otp", "").strip()

        if not phone or not otp:
            return Response({"detail": "Phone and OTP are required."}, status=status.HTTP_400_BAD_REQUEST)

        formatted_phone, last_10, err = _clean_and_validate_indian_phone(phone)
        if err:
            return Response({"detail": err}, status=status.HTTP_400_BAD_REQUEST)

        if otp != "1234":
            return Response({"detail": "Invalid OTP code. Use test OTP '1234'."}, status=status.HTTP_400_BAD_REQUEST)

        _get_or_create_staff_user_if_applicable(last_10)

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
        address = request.data.get("address", "").strip()
        instructions = request.data.get("delivery_instructions", "Ring bell twice and leave near doorstep box").strip()
        city = request.data.get("city", "").strip()

        if not phone or not first_name:
            return Response({"detail": "Phone and Name are required."}, status=status.HTTP_400_BAD_REQUEST)

        if len(first_name) < 2:
            return Response({"detail": "Full Name must be at least 2 characters long."}, status=status.HTTP_400_BAD_REQUEST)

        formatted_phone, last_10, err = _clean_and_validate_indian_phone(phone)
        if err:
            return Response({"detail": err}, status=status.HTTP_400_BAD_REQUEST)

        # Email validation & duplicate check
        if email:
            try:
                django_validate_email(email)
            except ValidationError:
                return Response({"detail": "Please enter a valid email address (e.g. name@example.com)."}, status=status.HTTP_400_BAD_REQUEST)

            if User.objects.filter(email__iexact=email).exists():
                return Response({"detail": "An account with this email address already exists. Please log in or use a different email."}, status=status.HTTP_400_BAD_REQUEST)

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
            gender=gender,
            address=address,
            city=city,
            role=User.Roles.CUSTOMER,
            wallet_balance=Decimal("500.00"),
            delivery_instructions=instructions,
        )
        user.set_password(uuid.uuid4().hex)
        user.save()

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
            title="🥛 Welcome to Pamba Fresh!",
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
