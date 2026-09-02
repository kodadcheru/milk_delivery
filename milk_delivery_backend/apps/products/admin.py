from django.contrib import admin
from apps.products.models import Product, Category


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "category", "price_per_unit", "unit_quantity", "badge_text", "is_available", "created_at"]
    list_filter = ["category", "is_available", "created_at"]
    search_fields = ["name", "description", "farm_origin"]
    fieldsets = [
        ("Basic Information", {
            "fields": ["name", "category_ref", "category", "description", "image_url", "is_available"]
        }),
        ("Pricing & Packaging", {
            "fields": ["price_per_unit", "unit", "unit_quantity", "badge_text", "farm_origin", "rating"]
        }),
        ("Quality & Purity Attributes (Shown on App)", {
            "description": "Overrides category defaults if specified. Leave blank to inherit from category.",
            "fields": ["subtitle", "quality_badge_title", "quality_specs", "tracking_badges"],
            "classes": ["collapse"],
        }),
    ]


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "slug", "icon", "subtitle", "quality_badge_title", "display_order", "is_active", "created_at"]
    list_filter = ["is_active"]
    search_fields = ["name", "slug", "description", "subtitle"]
    prepopulated_fields = {"slug": ("name",)}
    fieldsets = [
        ("General Details", {
            "fields": ["name", "slug", "icon", "image_url", "description", "display_order", "is_active"]
        }),
        ("Quality & Purity Attributes (Default for Products in Category)", {
            "description": "Configures trust badges, subtitles, expandable lab specs, and tracking tags for all products in this category.",
            "fields": ["subtitle", "quality_badge_title", "quality_specs", "tracking_badges"],
        }),
    ]
