from decimal import Decimal
from rest_framework import serializers
from .models import RazorpayPayment


class CreateRazorpayOrderSerializer(serializers.Serializer):
    amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=Decimal("1.00"),
    )
    purpose = serializers.ChoiceField(
        choices=RazorpayPayment.Purpose.choices,
        default=RazorpayPayment.Purpose.WALLET_TOPUP,
    )
    order_id = serializers.IntegerField(required=False, allow_null=True)
    notes = serializers.DictField(required=False, default=dict)


class VerifyRazorpayPaymentSerializer(serializers.Serializer):
    razorpay_order_id = serializers.CharField(max_length=128)
    razorpay_payment_id = serializers.CharField(max_length=128)
    razorpay_signature = serializers.CharField(max_length=256)


class RazorpayPaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = RazorpayPayment
        fields = [
            "id",
            "purpose",
            "order",
            "amount",
            "currency",
            "razorpay_order_id",
            "razorpay_payment_id",
            "status",
            "error_description",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields
