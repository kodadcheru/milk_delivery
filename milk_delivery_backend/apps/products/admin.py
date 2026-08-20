from django.contrib import admin
from apps.products.models import Product, Category


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "category", "price_per_unit", "unit_quantity", "badge_text", "is_available", "created_at"]
    list_filter = ["category", "is_available", "created_at"]
    search_fields = ["name", "description", "farm_origin"]


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "slug", "icon", "display_order", "is_active", "created_at"]
    list_filter = ["is_active"]
    search_fields = ["name", "slug", "description"]
    prepopulated_fields = {"slug": ("name",)}
