from django.contrib import admin
from apps.deliveries.models import DeliveryTask, LocationHub, ServiceArea, LiveOrder, LiveOrderItem, BottleReturn, ProviderPayout


@admin.register(DeliveryTask)
class DeliveryTaskAdmin(admin.ModelAdmin):
    list_display = ["id", "subscription", "driver", "delivery_date", "slot_time", "status", "delivered_at"]
    list_filter = ["status", "delivery_date"]
    search_fields = ["subscription__customer__username", "subscription__customer__phone", "driver__username", "driver__phone"]


@admin.register(LocationHub)
class LocationHubAdmin(admin.ModelAdmin):
    list_display = ["hub_code", "name", "manager_name", "manager_phone", "coverage_radius_km", "created_at"]
    list_filter = ["created_at"]
    search_fields = ["hub_code", "name", "manager_name", "address"]


@admin.register(ServiceArea)
class ServiceAreaAdmin(admin.ModelAdmin):
    list_display = ["name", "hub", "city", "pincodes", "status", "active_households"]
    list_filter = ["status", "city"]
    search_fields = ["name", "pincodes", "popular_societies"]


@admin.register(LiveOrder)
class LiveOrderAdmin(admin.ModelAdmin):
    list_display = ["id", "customer", "order_type", "status", "total_amount", "delivery_date", "created_at"]
    list_filter = ["status", "order_type"]
    search_fields = ["id", "customer__username", "customer__phone"]


@admin.register(LiveOrderItem)
class LiveOrderItemAdmin(admin.ModelAdmin):
    list_display = ["id", "order", "product", "quantity", "unit_price"]
    search_fields = ["order__id", "product__name"]


@admin.register(BottleReturn)
class BottleReturnAdmin(admin.ModelAdmin):
    list_display = ["id", "customer", "driver", "hub", "product", "quantity", "deposit_amount", "status", "collected_date", "returned_date"]
    list_filter = ["status", "collected_date"]
    search_fields = ["customer__username", "customer__phone", "driver__username"]


@admin.register(ProviderPayout)
class ProviderPayoutAdmin(admin.ModelAdmin):
    list_display = ["id", "hub", "manager", "period_start", "period_end", "total_deliveries", "net_payout", "status", "paid_at"]
    list_filter = ["status", "period_end"]
    search_fields = ["hub__name", "hub__hub_code", "manager__username"]

