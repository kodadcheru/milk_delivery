from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from apps.accounts.models import User, WalletTransaction, Notification, CustomerAddress


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ["username", "phone", "first_name", "last_name", "role", "wallet_balance", "is_staff"]
    list_filter = ["role", "is_staff", "is_superuser"]
    fieldsets = BaseUserAdmin.fieldsets + (
        ("Milk Delivery Profile", {
            "fields": ("role", "phone", "address", "city", "wallet_balance", "delivery_instructions", "delivery_slot_preference")
        }),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ("Milk Delivery Profile", {
            "fields": ("role", "phone", "address", "city", "wallet_balance", "delivery_instructions", "delivery_slot_preference")
        }),
    )


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ["id", "user", "amount", "transaction_type", "description", "created_at"]
    list_filter = ["transaction_type", "created_at"]
    search_fields = ["user__username", "user__phone", "description"]


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ["id", "user", "title", "notification_type", "is_read", "created_at"]
    list_filter = ["notification_type", "is_read", "created_at"]
    search_fields = ["user__username", "title", "message"]


@admin.register(CustomerAddress)
class CustomerAddressAdmin(admin.ModelAdmin):
    list_display = ["id", "user", "address_type", "street_address", "city", "pincode", "is_default", "created_at"]
    list_filter = ["address_type", "is_default", "city"]
    search_fields = ["user__username", "user__phone", "street_address", "pincode"]
