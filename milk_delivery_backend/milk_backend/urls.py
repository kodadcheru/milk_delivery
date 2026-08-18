from django.contrib import admin
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from apps.core.views import HealthCheckView
from apps.accounts.admin_views import (
    AdminBroadcastNotificationView,
    AdminConsoleHTMLView,
    AdminCreditWalletView,
    AdminCustomerListView,
    AdminFleetListView,
    AdminHubsView,
    AdminServiceAreaManageView,
    AdminSubscriptionToggleView,
    AdminSubscriptionsListView,
    ServiceAreaCheckView,
    ServiceAreaListView,
)
from apps.accounts.phone_auth_views import (
    RegisterMobileUserView,
    SendOTPView,
    VerifyOTPView,
)
from apps.accounts.views import (
    NotificationListView,
    NotificationMarkReadView,
    RegisterView,
    UserProfileView,
    WalletBalanceView,
    WalletTopUpView,
    WalletTransactionListView,
)
from apps.deliveries.views import (
    DeliverySummaryView,
    DeliveryTaskCompleteView,
    DeliveryTaskListView,
    DeliveryTaskSkipView,
)
from apps.products.views import ProductDetailView, ProductListView
from apps.subscriptions.views import (
    SubscriptionDetailView,
    SubscriptionListCreateView,
    SubscriptionPauseView,
    SubscriptionResumeView,
)

urlpatterns = [
    path("admin/", admin.site.urls),
    # Production Health & Diagnostics Endpoint
    path("api/health/", HealthCheckView.as_view(), name="health_check"),
    # Dedicated Admin Web Console
    path("admin-console/", AdminConsoleHTMLView.as_view(), name="admin_console"),
    path("api/admin/customers/", AdminCustomerListView.as_view(), name="admin_customers"),
    path("api/admin/credit-wallet/", AdminCreditWalletView.as_view(), name="admin_credit_wallet"),
    path("api/admin/broadcast-notification/", AdminBroadcastNotificationView.as_view(), name="admin_broadcast"),
    path("api/admin/hubs/", AdminHubsView.as_view(), name="admin_hubs"),
    path("api/admin/subscriptions/", AdminSubscriptionsListView.as_view(), name="admin_subscriptions"),
    path("api/admin/subscriptions/<int:pk>/toggle/", AdminSubscriptionToggleView.as_view(), name="admin_subscription_toggle"),
    path("api/admin/fleet/", AdminFleetListView.as_view(), name="admin_fleet"),
    # Service Area endpoints
    path("api/service-areas/", ServiceAreaListView.as_view(), name="service_areas_list"),
    path("api/service-areas/check/", ServiceAreaCheckView.as_view(), name="service_areas_check"),
    path("api/admin/service-areas/", AdminServiceAreaManageView.as_view(), name="admin_service_areas_manage"),
    # Phone OTP & Mobile Auth endpoints
    path("api/auth/send-otp/", SendOTPView.as_view(), name="auth_send_otp"),
    path("api/auth/verify-otp/", VerifyOTPView.as_view(), name="auth_verify_otp"),
    path("api/auth/register-mobile/", RegisterMobileUserView.as_view(), name="auth_register_mobile"),
    # Auth & Profile endpoints
    path("api/auth/register/", RegisterView.as_view(), name="auth_register"),
    path("api/auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/auth/me/", UserProfileView.as_view(), name="auth_me"),
    # Notification endpoints
    path("api/notifications/", NotificationListView.as_view(), name="notification_list"),
    path("api/notifications/<int:pk>/read/", NotificationMarkReadView.as_view(), name="notification_mark_read"),
    path("api/notifications/read-all/", NotificationMarkReadView.as_view(), name="notification_read_all"),
    # Product endpoints
    path("api/products/", ProductListView.as_view(), name="product_list"),
    path("api/products/<int:pk>/", ProductDetailView.as_view(), name="product_detail"),
    # Subscription endpoints
    path("api/subscriptions/", SubscriptionListCreateView.as_view(), name="subscription_list"),
    path("api/subscriptions/<int:pk>/", SubscriptionDetailView.as_view(), name="subscription_detail"),
    path("api/subscriptions/<int:pk>/pause/", SubscriptionPauseView.as_view(), name="subscription_pause"),
    path("api/subscriptions/<int:pk>/resume/", SubscriptionResumeView.as_view(), name="subscription_resume"),
    # Wallet endpoints
    path("api/wallet/balance/", WalletBalanceView.as_view(), name="wallet_balance"),
    path("api/wallet/topup/", WalletTopUpView.as_view(), name="wallet_topup"),
    path("api/wallet/transactions/", WalletTransactionListView.as_view(), name="wallet_transactions"),
    # Delivery endpoints
    path("api/deliveries/", DeliveryTaskListView.as_view(), name="delivery_list"),
    path("api/deliveries/<int:pk>/complete/", DeliveryTaskCompleteView.as_view(), name="delivery_complete"),
    path("api/deliveries/<int:pk>/skip/", DeliveryTaskSkipView.as_view(), name="delivery_skip"),
    path("api/deliveries/summary/", DeliverySummaryView.as_view(), name="delivery_summary"),
]
