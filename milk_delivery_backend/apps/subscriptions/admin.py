from django.contrib import admin
from apps.subscriptions.models import Subscription, VacationPause


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ["id", "customer", "product", "quantity", "schedule_type", "status", "start_date", "created_at"]
    list_filter = ["status", "schedule_type", "created_at"]
    search_fields = ["customer__username", "customer__phone", "product__name"]


@admin.register(VacationPause)
class VacationPauseAdmin(admin.ModelAdmin):
    list_display = ["id", "subscription", "start_date", "end_date", "reason", "created_at"]
    list_filter = ["start_date", "end_date", "created_at"]
