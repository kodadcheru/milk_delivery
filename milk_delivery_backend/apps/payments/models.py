from decimal import Decimal
from django.conf import settings
from django.db import models


class RazorpayPayment(models.Model):
    class Purpose(models.TextChoices):
        WALLET_TOPUP = "WALLET_TOPUP", "Wallet Top-Up"
        ORDER_PAYMENT = "ORDER_PAYMENT", "Order Payment"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        SUCCESS = "SUCCESS", "Success"
        FAILED = "FAILED", "Failed"
        REFUNDED = "REFUNDED", "Refunded"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="razorpay_payments",
    )
    purpose = models.CharField(
        max_length=32,
        choices=Purpose.choices,
        default=Purpose.WALLET_TOPUP,
    )
    order = models.ForeignKey(
        "deliveries.LiveOrder",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="razorpay_payments",
    )
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=Decimal("0.00"),
    )
    currency = models.CharField(max_length=10, default="INR")
    razorpay_order_id = models.CharField(max_length=128, unique=True, db_index=True)
    razorpay_payment_id = models.CharField(
        max_length=128,
        blank=True,
        null=True,
        db_index=True,
    )
    razorpay_signature = models.CharField(
        max_length=256,
        blank=True,
        null=True,
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )
    error_description = models.TextField(blank=True, null=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Razorpay Payment"
        verbose_name_plural = "Razorpay Payments"

    def __str__(self):
        return f"Payment {self.razorpay_order_id} ({self.purpose}) - ₹{self.amount} [{self.status}]"
