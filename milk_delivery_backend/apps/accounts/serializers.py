from decimal import Decimal
from rest_framework import serializers
from apps.accounts.models import CustomerAddress, Notification, User, WalletTransaction


class UserSerializer(serializers.ModelSerializer):
    customer_code = serializers.CharField(read_only=True)
    driver_code = serializers.CharField(read_only=True)
    assigned_hub_name = serializers.CharField(source="assigned_hub.name", read_only=True, default="")
    assigned_hub_code = serializers.CharField(source="assigned_hub.hub_code", read_only=True, default="")

    class Meta:
        model = User
        fields = [
            "id",
            "customer_code",
            "driver_code",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "gender",
            "phone",
            "address",
            "city",
            "wallet_balance",
            "delivery_instructions",
            "delivery_slot_preference",
            "latitude",
            "longitude",
            "monthly_salary",
            "driver_status",
            "assigned_hub",
            "assigned_hub_name",
            "assigned_hub_code",
            "last_location_updated",
        ]
        read_only_fields = [
            "id",
            "customer_code",
            "driver_code",
            "phone",
            "wallet_balance",
            "assigned_hub_name",
            "assigned_hub_code",
            "role",
            "assigned_hub",
            "monthly_salary",
            "driver_status",
        ]


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
        fields = [
            "id",
            "user",
            "title",
            "message",
            "notification_type",
            "target_screen",
            "target_param",
            "is_read",
            "created_at",
        ]
        read_only_fields = ["id", "user", "created_at"]


class CustomerAddressSerializer(serializers.ModelSerializer):
    formatted_address = serializers.SerializerMethodField()
    display_type = serializers.CharField(source="get_address_type_display", read_only=True)
    customer_code = serializers.CharField(source="customer.customer_code", read_only=True)
    customer_id = serializers.IntegerField(source="customer.id", read_only=True)
    user = serializers.PrimaryKeyRelatedField(source="customer", read_only=True)
    street_address = serializers.CharField(required=False, allow_blank=True, default="Main Road, Kodad")
    latitude = serializers.FloatField(required=False, default=17.001734)
    longitude = serializers.FloatField(required=False, default=79.9625)

    def validate_latitude(self, value):
        if value is not None:
            try:
                return Decimal(f"{float(value):.8f}")
            except Exception:
                return Decimal("17.00173400")
        return Decimal("17.00173400")

    def validate_longitude(self, value):
        if value is not None:
            try:
                return Decimal(f"{float(value):.8f}")
            except Exception:
                return Decimal("79.96250000")
        return Decimal("79.96250000")

    class Meta:
        model = CustomerAddress
        fields = [
            "id",
            "customer",
            "customer_id",
            "user",
            "customer_code",
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
        read_only_fields = ["id", "customer", "customer_id", "user", "customer_code", "created_at", "updated_at"]

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

