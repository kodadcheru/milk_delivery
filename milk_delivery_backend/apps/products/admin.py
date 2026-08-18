from django.contrib import admin
from apps.products.models import Product


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "category", "price_per_unit", "unit_quantity", "badge_text", "is_available", "created_at"]
    list_filter = ["category", "is_available", "created_at"]
    search_fields = ["name", "description", "farm_origin"]
