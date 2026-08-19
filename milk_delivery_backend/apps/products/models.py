from decimal import Decimal
from django.db import models


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True, blank=True)
    icon = models.CharField(max_length=50, default="🥛", help_text="Emoji or Icon symbol e.g. 🥛, 🥩, 🥚, 💧, 🥬")
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

    def __str__(self):
        return f"{self.name} ({self.category}) - ₹{self.price_per_unit} / {self.unit_quantity}"
