from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from apps.core.views import HealthCheckView
from apps.core.upload_views import FileUploadView
from apps.accounts.admin_views import (
    AdminBroadcastNotificationView,
    AdminConsoleHTMLView,
    AdminCreditWalletView,
    AdminCustomerDetailView,
    AdminCustomerListView,
    AdminCustomerTransactionsView,
    AdminFleetDetailView,
    AdminFleetListView,
    AdminHubAssignDriverView,
    AdminHubCleanupView,
    AdminHubDetailView,
    AdminHubRebalanceView,
    AdminHubsView,
    AdminProductStockToggleView,
    AdminServiceAreaManageView,
    AdminSubscriptionCreateView,
    AdminSubscriptionDetailView,
    AdminSubscriptionToggleView,
    AdminSubscriptionsListView,
    HubDriverCreateView,
    ServiceAreaCheckView,
    ServiceAreaListView,
    AdminBottleReturnsView,
    AdminPayoutsView,
    AdminDebitWalletView,
    AdminVacationPausesView,
    AdminCustomerExportView,
    AdminDeliveryReassignView,
    AdminSupportAgentListCreateView,
    AdminSupportAgentDetailView,
)
from apps.core.chat_views import (
    SupportChatSendView,
    SupportChatHistoryView,
    AdminSupportChatThreadsView,
)
from apps.accounts.address_views import (
    CustomerAddressDetailView,
    CustomerAddressListCreateView,
    CustomerAddressSetDefaultView,
)
from apps.accounts.phone_auth_views import (
    RegisterMobileUserView,
    SendOTPView,
    VerifyOTPView,
)
from apps.accounts.views import (
    DriverLocationByOrderView,
    DriverLocationUpdateView,
    NotificationListView,
    NotificationMarkReadView,
    RegisterView,
    RobustTokenObtainPairView,
    UserProfileView,
    WalletBalanceView,
    WalletTopUpView,
    WalletTransactionListView,
)
from apps.deliveries.views import (
    BottleReturnListCreateView,
    BottleReturnUpdateView,
    DailyMilkBatchListCreateView,
    DailyMilkBatchDetailView,
    DeliverySummaryView,
    DeliveryTaskCompleteView,
    DeliveryTaskListView,
    DeliveryTaskSkipView,
    GenerateTodayTasksView,
    ProviderPayoutListCreateView,
    SlotAvailabilityView,
    QualityHistoryView,
)
from apps.deliveries.order_views import (
    ExpressOrderListCreateView,
    ExpressOrderDetailView,
)
from apps.products.views import (
    CategoryDetailView,
    CategoryListCreateView,
    ProductDetailView,
    ProductListView,
    HubInventoryListUpdateView,
    StorefrontConfigView,
)
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
    path("api/admin/customers/<int:pk>/", AdminCustomerDetailView.as_view(), name="admin_customer_detail"),
    path("api/admin/customers/<int:user_id>/transactions/", AdminCustomerTransactionsView.as_view(), name="admin_customer_txs"),
    path("api/admin/credit-wallet/", AdminCreditWalletView.as_view(), name="admin_credit_wallet"),
    path("api/admin/debit-wallet/", AdminDebitWalletView.as_view(), name="admin_debit_wallet"),
    path("api/admin/vacation-pauses/", AdminVacationPausesView.as_view(), name="admin_vacation_pauses"),
    path("api/admin/customers/export/", AdminCustomerExportView.as_view(), name="admin_customer_export"),
    path("api/admin/deliveries/<int:pk>/reassign/", AdminDeliveryReassignView.as_view(), name="admin_delivery_reassign"),
    path("api/admin/deliveries/reassign/", AdminDeliveryReassignView.as_view(), name="admin_delivery_reassign_batch"),
    path("api/admin/broadcast-notification/", AdminBroadcastNotificationView.as_view(), name="admin_broadcast"),
    path("api/admin/hubs/", AdminHubsView.as_view(), name="admin_hubs"),
    path("api/admin/hubs/cleanup/", AdminHubCleanupView.as_view(), name="admin_hubs_cleanup"),
    path("api/admin/hubs/<str:pk>/", AdminHubDetailView.as_view(), name="admin_hub_detail"),
    path("api/admin/hubs/<str:pk>/assign-driver/", AdminHubAssignDriverView.as_view(), name="admin_hub_assign_driver"),
    path("api/admin/hubs/<str:hub_code>/rebalance/", AdminHubRebalanceView.as_view(), name="admin_hub_rebalance"),
    path("api/admin/subscriptions/", AdminSubscriptionsListView.as_view(), name="admin_subscriptions"),
    path("api/admin/subscriptions/create/", AdminSubscriptionCreateView.as_view(), name="admin_subscription_create"),
    path("api/admin/subscriptions/<int:pk>/", AdminSubscriptionDetailView.as_view(), name="admin_subscription_detail"),
    path("api/admin/subscriptions/<int:pk>/toggle/", AdminSubscriptionToggleView.as_view(), name="admin_subscription_toggle"),
    path("api/admin/products/<int:pk>/toggle-stock/", AdminProductStockToggleView.as_view(), name="admin_product_stock_toggle"),
    path("api/admin/fleet/", AdminFleetListView.as_view(), name="admin_fleet"),
    path("api/admin/fleet/<int:pk>/", AdminFleetDetailView.as_view(), name="admin_fleet_detail"),
    path("api/admin/fleet/create-driver/", HubDriverCreateView.as_view(), name="admin_create_driver"),
    # Support Agents Management & Live Chat Desk
    path("api/admin/support-agents/", AdminSupportAgentListCreateView.as_view(), name="admin_support_agents"),
    path("api/admin/support-agents/create/", AdminSupportAgentListCreateView.as_view(), name="admin_support_agent_create"),
    path("api/admin/support-agents/<int:pk>/", AdminSupportAgentDetailView.as_view(), name="admin_support_agent_detail"),
    path("api/admin/support/threads/", AdminSupportChatThreadsView.as_view(), name="admin_support_threads"),
    # Customer Live Support Chat endpoints (Redis-backed)
    path("api/support/chat/send/", SupportChatSendView.as_view(), name="support_chat_send"),
    path("api/support/chat/history/", SupportChatHistoryView.as_view(), name="support_chat_history"),
    # Bottle Returns & Provider Payouts
    path("api/admin/bottle-returns/", AdminBottleReturnsView.as_view(), name="admin_bottle_returns"),
    path("api/admin/payouts/", AdminPayoutsView.as_view(), name="admin_payouts"),
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
    path("api/auth/token/", RobustTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/auth/me/", UserProfileView.as_view(), name="auth_me"),
    path("api/driver/location/", DriverLocationUpdateView.as_view(), name="driver_location_update"),
    path("api/driver/location/<str:order_id>/", DriverLocationByOrderView.as_view(), name="driver_location_by_order"),
    # Customer Address Book endpoints
    path("api/accounts/addresses/", CustomerAddressListCreateView.as_view(), name="address_list"),
    path("api/accounts/addresses/<int:pk>/", CustomerAddressDetailView.as_view(), name="address_detail"),
    path("api/accounts/addresses/<int:pk>/set-default/", CustomerAddressSetDefaultView.as_view(), name="address_set_default"),
    # Notification endpoints
    path("api/notifications/", NotificationListView.as_view(), name="notification_list"),
    path("api/notifications/<int:pk>/read/", NotificationMarkReadView.as_view(), name="notification_mark_read"),
    path("api/notifications/read-all/", NotificationMarkReadView.as_view(), name="notification_read_all"),
    # Category & Product endpoints
    path("api/categories/", CategoryListCreateView.as_view(), name="category_list"),
    path("api/categories/<int:pk>/", CategoryDetailView.as_view(), name="category_detail"),
    path("api/products/", ProductListView.as_view(), name="product_list"),
    path("api/products/<int:pk>/", ProductDetailView.as_view(), name="product_detail"),
    path("api/storefront/config/", StorefrontConfigView.as_view(), name="storefront_config"),
    path("api/hub-inventory/", HubInventoryListUpdateView.as_view(), name="hub_inventory_list_update"),
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
    path("api/slots/availability/", SlotAvailabilityView.as_view(), name="slot_availability"),
    path("api/admin/generate-tasks/", GenerateTodayTasksView.as_view(), name="generate_tasks"),
    # Bottle Return & Payout Tracking endpoints
    path("api/bottles/", BottleReturnListCreateView.as_view(), name="bottle_list_create"),
    path("api/bottles/<int:pk>/", BottleReturnUpdateView.as_view(), name="bottle_update"),
    path("api/payouts/", ProviderPayoutListCreateView.as_view(), name="provider_payouts"),
    # Hub Provider Daily Milk Batch certification & quality metrics
    path("api/deliveries/daily-batches/", DailyMilkBatchListCreateView.as_view(), name="daily_milk_batches"),
    path("api/deliveries/daily-batches/<int:pk>/", DailyMilkBatchDetailView.as_view(), name="daily_milk_batch_detail"),
    path("api/deliveries/quality-history/", QualityHistoryView.as_view(), name="quality_history"),
    # Express / Live Orders endpoints
    path("api/orders/express/", ExpressOrderListCreateView.as_view(), name="express_order_list_create"),
    path("api/orders/express/<str:order_id>/", ExpressOrderDetailView.as_view(), name="express_order_detail"),
    # Image & Media Upload Service endpoint
    path("api/upload/image/", FileUploadView.as_view(), name="image_upload"),
]

# Serve media files directly in development and production (with volume mount support)
from django.urls import re_path
from django.views.static import serve

urlpatterns += [
    re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
]
