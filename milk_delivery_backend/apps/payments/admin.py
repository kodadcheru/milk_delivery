from django.contrib import admin
from .models import RazorpayPayment


@admin.register(RazorpayPayment)
class RazorpayPaymentAdmin(admin.ModelAdmin):
    list_display = [
        "razorpay_order_id",
        "user",
        "purpose",
        "amount",
        "status",
        "razorpay_payment_id",
        "created_at",
    ]
    list_filter = ["status", "purpose", "created_at"]
    search_fields = [
        "razorpay_order_id",
        "razorpay_payment_id",
        "user__username",
        "user__phone",
    ]
    readonly_fields = [
        "created_at",
        "updated_at",
        "razorpay_signature",
        "metadata",
    ]
