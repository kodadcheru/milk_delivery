from decimal import Decimal
from rest_framework import serializers
from apps.accounts.models import CustomerAddress, Notification, User, WalletTransaction


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "phone",
            "address",
            "city",
            "wallet_balance",
            "delivery_instructions",
            "delivery_slot_preference",
            "latitude",
            "longitude",
        ]
        read_only_fields = ["id", "wallet_balance"]


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "password",
            "first_name",
            "last_name",
            "email",
            "phone",
            "role",
            "address",
            "city",
            "delivery_instructions",
            "delivery_slot_preference",
            "latitude",
            "longitude",
        ]

    def create(self, validated_data):
        password = validated_data.pop("password")
        # Force CUSTOMER role on public registration to prevent privilege escalation
        validated_data["role"] = "CUSTOMER"
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = ["id", "user", "amount", "transaction_type", "description", "created_at"]
        read_only_fields = ["id", "user", "created_at"]


class WalletTopUpSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=8, decimal_places=2, min_value=Decimal("1.00"), max_value=Decimal("50000.00"))
    description = serializers.CharField(max_length=255, default="Wallet Top-Up (UPI/Card)")
    payment_method = serializers.ChoiceField(
        choices=["UPI", "CARD", "NETBANKING", "WALLET_TRANSFER", "ADMIN_CREDIT"],
        default="UPI",
        required=False,
    )
    payment_reference = serializers.CharField(max_length=100, required=False, default="")


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "user", "title", "message", "notification_type", "is_read", "created_at"]
        read_only_fields = ["id", "user", "created_at"]


class CustomerAddressSerializer(serializers.ModelSerializer):
    formatted_address = serializers.SerializerMethodField()
    display_type = serializers.CharField(source="get_address_type_display", read_only=True)

    class Meta:
        model = CustomerAddress
        fields = [
            "id",
            "user",
            "address_type",
            "display_type",
            "custom_tag",
            "flat_house_no",
            "floor",
            "building_name",
            "street_address",
            "landmark",
            "city",
            "pincode",
            "latitude",
            "longitude",
            "delivery_instructions",
            "is_default",
            "formatted_address",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "user", "created_at", "updated_at"]

    def get_formatted_address(self, obj):
        parts = []
        if obj.flat_house_no:
            parts.append(obj.flat_house_no)
        if obj.floor:
            parts.append(obj.floor)
        if obj.building_name:
            parts.append(obj.building_name)
        if obj.street_address:
            parts.append(obj.street_address)
        if obj.landmark:
            parts.append(f"Near {obj.landmark}")
        if obj.city:
            parts.append(f"{obj.city} - {obj.pincode}")
        return ", ".join(parts) if parts else obj.street_address

