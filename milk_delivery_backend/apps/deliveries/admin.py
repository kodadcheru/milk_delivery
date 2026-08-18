from django.contrib import admin
from apps.deliveries.models import DeliveryTask


@admin.register(DeliveryTask)
class DeliveryTaskAdmin(admin.ModelAdmin):
    list_display = ["id", "subscription", "driver", "delivery_date", "slot_time", "status", "delivered_at"]
    list_filter = ["status", "delivery_date"]
    search_fields = ["subscription__customer__username", "subscription__customer__phone", "driver__username", "driver__phone"]
