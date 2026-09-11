from django.db import models
from django.core.cache import cache
from decimal import Decimal

class SiteConfig(models.Model):
    """Singleton model for admin-configurable business settings."""
    
    class Meta:
        verbose_name = "Site Configuration"
        verbose_name_plural = "Site Configuration"
    
    # Financial
    platform_commission_rate = models.DecimalField(
        max_digits=5, decimal_places=4, default=Decimal("0.0500"),
        help_text="Platform commission rate (e.g. 0.05 = 5%)")
    default_milk_price_per_litre = models.DecimalField(
        max_digits=8, decimal_places=2, default=Decimal("68.00"),
        help_text="Fallback milk price per litre when product price unavailable")
    max_wallet_topup = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal("10000.00"),
        help_text="Maximum wallet top-up amount per transaction")
    welcome_bonus_amount = models.DecimalField(
        max_digits=8, decimal_places=2, default=Decimal("0.00"),
        help_text="Welcome bonus credited to new user wallets (0 = disabled)")
    customer_platform_fee = models.DecimalField(
        max_digits=6, decimal_places=2, default=Decimal("0.00"),
        help_text="Customer platform fee in Rupees per order (0.00 for none/free)"
    )
    tax_percentage = models.DecimalField(
        max_digits=5, decimal_places=2, default=Decimal("0.00"),
        help_text="Tax / GST percentage applied to checkout orders"
    )
    delivery_fee = models.DecimalField(
        max_digits=6, decimal_places=2, default=Decimal("0.00"),
        help_text="Standard delivery partner fee in Rupees (0.00 for free delivery)"
    )
    free_delivery_threshold = models.DecimalField(
        max_digits=8, decimal_places=2, default=Decimal("0.00"),
        help_text="Minimum order subtotal for free delivery"
    )
    
    # Delivery Timing
    morning_cutoff_hour = models.IntegerField(default=5,
        help_text="Hour (0-23) after which morning tasks are generated")
    morning_cutoff_minute = models.IntegerField(default=0,
        help_text="Minute (0-59) for morning cutoff")
    afternoon_cutoff_hour = models.IntegerField(default=12,
        help_text="Hour (0-23) after which tasks are for next day")
    default_delivery_slot = models.CharField(max_length=50,
        default="05:30 AM - 07:00 AM",
        help_text="Default delivery slot label")
    
    # Hub & Geography
    max_hub_distance_km = models.FloatField(default=10.0,
        help_text="Maximum distance in km for hub assignment")
    
    # Support Contact
    support_phone = models.CharField(max_length=20, default="+91 8919548905")
    support_whatsapp = models.CharField(max_length=20, default="918919548905")
    support_email = models.EmailField(default="support@pamba.in")
    default_city = models.CharField(max_length=50, default="Kodad")
    
    # Google Maps
    google_maps_api_key = models.CharField(max_length=100, blank=True, default="",
        help_text="Google Maps API key")

    # SMS Gateway (NinzaSMS)
    ninzasms_enabled = models.BooleanField(
        default=True,
        help_text="Enable real SMS OTP delivery via NinzaSMS"
    )
    ninzasms_api_key = models.CharField(
        max_length=150,
        default="",
        help_text="NinzaSMS Authorization Key"
    )
    ninzasms_sender_id = models.CharField(
        max_length=50,
        default="",
        help_text="NinzaSMS Approved Sender ID"
    )
    
    def save(self, *args, **kwargs):
        """Ensure singleton — always use pk=1."""
        self.pk = 1
        super().save(*args, **kwargs)
        # Bust the cache
        cache.delete('site_config')
    
    def delete(self, *args, **kwargs):
        """Prevent deletion."""
        pass
    
    def __str__(self):
        return "Site Configuration"
    
    @classmethod
    def get(cls):
        """Get the cached singleton instance, creating it if necessary."""
        config = cache.get('site_config')
        if config is None:
            config, _ = cls.objects.get_or_create(pk=1)
            cache.set('site_config', config, timeout=300)
        return config


class MediaAsset(models.Model):
    """Persistent storage for uploaded images and delivery proofs, surviving ephemeral container rebuilds."""
    file_path = models.CharField(max_length=500, unique=True, db_index=True)
    content_type = models.CharField(max_length=100, default="image/jpeg")
    data = models.BinaryField()
    size_bytes = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Media Asset"
        verbose_name_plural = "Media Assets"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.file_path} ({self.size_bytes} bytes)"

