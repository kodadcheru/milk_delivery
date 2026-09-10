from django.contrib import admin
from .models import SiteConfig

@admin.register(SiteConfig)
class SiteConfigAdmin(admin.ModelAdmin):
    fieldsets = (
        ('Financial Settings', {
            'fields': ('platform_commission_rate', 'default_milk_price_per_litre',
                       'max_wallet_topup', 'welcome_bonus_amount',
                       'customer_platform_fee', 'tax_percentage', 
                       'delivery_fee', 'free_delivery_threshold'),
        }),
        ('Delivery Timing', {
            'fields': ('morning_cutoff_hour', 'morning_cutoff_minute',
                       'afternoon_cutoff_hour', 'default_delivery_slot'),
        }),
        ('Hub & Geography', {
            'fields': ('max_hub_distance_km',),
        }),
        ('Support & Contact', {
            'fields': ('support_phone', 'support_whatsapp', 'support_email',
                       'default_city'),
        }),
        ('API Keys & Integrations', {
            'fields': ('google_maps_api_key',),
        }),
        ('SMS Gateway (NinzaSMS)', {
            'fields': ('ninzasms_enabled', 'ninzasms_api_key', 'ninzasms_sender_id'),
        }),
    )
    
    def has_add_permission(self, request):
        # Singleton: only allow add if none exists
        return not SiteConfig.objects.exists()
    
    def has_delete_permission(self, request, obj=None):
        return False
