from decimal import Decimal
from django.db import models


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True, blank=True)
    icon = models.CharField(max_length=50, default="🥛", help_text="Emoji or Icon symbol e.g. 🥛, 🥩, 🥚, 💧, 🥬")
    image_url = models.URLField(max_length=500, blank=True, default="")
    description = models.TextField(blank=True, default="")
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["display_order", "id"]
        verbose_name_plural = "Categories"

    def __str__(self):
        return f"{self.icon} {self.name}"

    def save(self, *args, **kwargs):
        if not self.slug:
            from django.utils.text import slugify
            self.slug = slugify(self.name) or "category"
        super().save(*args, **kwargs)


class Product(models.Model):
    class Units(models.TextChoices):
        LITER = "LITER", "Liter (L)"
        MILLILITER = "ML", "Milliliter (mL)"
        PACKET = "PACKET", "Pouch / Pack"
        GRAM = "GRAM", "Gram (g)"
        KG = "KG", "Kilogram (kg)"
        PIECES = "PCS", "Pieces / Count"
        CAN = "CAN", "Water Can"

    name = models.CharField(max_length=150)
    category = models.CharField(max_length=50, default="MILK", help_text="Category name or slug")
    category_ref = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name="products")
    description = models.TextField(blank=True, default="")
    price_per_unit = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("35.00"))
    unit = models.CharField(max_length=20, choices=Units.choices, default=Units.LITER)
    unit_quantity = models.CharField(max_length=50, default="500 mL")
    image_url = models.URLField(blank=True, default="")
    badge_text = models.CharField(max_length=50, blank=True, default="Bestseller")
    nutrition_info = models.CharField(max_length=150, blank=True, default="100% Pure & Certified Quality")
    farm_origin = models.CharField(max_length=120, blank=True, default="Heritage Source, Hyderabad")
    rating = models.DecimalField(max_digits=3, decimal_places=1, default=Decimal("4.9"))
    is_available = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if self.category_ref and not self.category:
            self.category = self.category_ref.slug or self.category_ref.name.upper()
        elif self.category and not self.category_ref:
            cat = Category.objects.filter(models.Q(slug__iexact=self.category) | models.Q(name__iexact=self.category)).first()
            if cat:
                self.category_ref = cat
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.category}) - ₹{self.price_per_unit} / {self.unit_quantity}"


class HubProductInventory(models.Model):
    hub = models.ForeignKey("deliveries.LocationHub", on_delete=models.CASCADE, related_name="inventories")
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="hub_inventories")
    daily_capacity_slots = models.PositiveIntegerField(default=100, help_text="Total daily available capacity slots (e.g. 100 Litres/Units)")
    booked_slots = models.PositiveIntegerField(default=0, help_text="Currently booked slots for today")
    is_available = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("hub", "product")
        verbose_name_plural = "Hub Product Inventories"

    def __str__(self):
        return f"{self.hub.name} - {self.product.name}: {self.available_slots}/{self.daily_capacity_slots} slots left"

    @property
    def available_slots(self):
        return max(0, self.daily_capacity_slots - self.booked_slots)


class StorefrontConfig(models.Model):
    banner_image_url = models.URLField(
        max_length=500,
        blank=True,
        default="https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80",
        help_text="Direct URL or CDN/S3 URL for top banner image",
    )
    banner_image = models.ImageField(upload_to="storefront_banners/", blank=True, null=True)
    headline = models.CharField(max_length=200, default="Order by 11PM Tonight →")
    subtitle = models.CharField(
        max_length=300,
        default="❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub",
    )
    dispatch_tag = models.CharField(max_length=100, default="MORNING DROP 05:30 AM ☀️")
    promo_chip = models.CharField(max_length=100, default="🥛 FRESH TODAY")
    cta_text = models.CharField(max_length=100, default="SUBSCRIBE NOW ➔")
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Storefront Configuration"
        verbose_name_plural = "Storefront Configurations"

    def __str__(self):
        return f"Storefront Config ({self.headline})"

    @classmethod
    def get_active(cls):
        obj = cls.objects.filter(is_active=True).first()
        if not obj:
            obj = cls.objects.create()
        return obj

    @property
    def effective_banner_url(self):
        if self.banner_image:
            try:
                return self.banner_image.url
            except Exception:
                pass
        return self.banner_image_url or "https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80"

