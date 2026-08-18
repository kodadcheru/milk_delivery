from decimal import Decimal
from rest_framework import serializers
from apps.accounts.models import Notification, User, WalletTransaction


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
    amount = serializers.DecimalField(max_digits=8, decimal_places=2, min_value=Decimal("1.00"))
    description = serializers.CharField(max_length=255, default="Wallet Top-Up (UPI/Card)")


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "user", "title", "message", "notification_type", "is_read", "created_at"]
        read_only_fields = ["id", "user", "created_at"]
