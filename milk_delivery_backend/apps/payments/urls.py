from django.urls import path
from .views import (
    RazorpayConfigView,
    RazorpayCreateOrderView,
    RazorpayVerifyPaymentView,
)

app_name = "payments"

urlpatterns = [
    path("razorpay/config/", RazorpayConfigView.as_view(), name="razorpay_config"),
    path("razorpay/create-order/", RazorpayCreateOrderView.as_view(), name="razorpay_create_order"),
    path("razorpay/verify/", RazorpayVerifyPaymentView.as_view(), name="razorpay_verify"),
]
