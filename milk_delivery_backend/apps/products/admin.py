from django.contrib import admin
from apps.products.models import Product, Category


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "name_te", "category", "price_per_unit", "unit_quantity", "is_available", "is_subscription_enabled", "created_at"]
    list_filter = ["category", "is_available", "is_subscription_enabled", "created_at"]
    list_editable = ["is_available", "is_subscription_enabled"]
    search_fields = ["name", "name_te", "description", "farm_origin"]
    fieldsets = [
        ("Basic Information", {
            "fields": ["name", "name_te", "category_ref", "category", "description", "description_te", "image_url", "is_available", "is_subscription_enabled"]
        }),
        ("Pricing & Packaging", {
            "fields": ["price_per_unit", "unit", "unit_quantity", "pack_sizes", "badge_text", "badge_text_te", "farm_origin", "rating"]
        }),
        ("Quality & Purity Attributes (Shown on App)", {
            "description": "Overrides category defaults if specified. Leave blank to inherit from category.",
            "fields": ["subtitle", "subtitle_te", "quality_badge_title", "quality_specs", "tracking_badges"],
            "classes": ["collapse"],
        }),
    ]


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "name_te", "slug", "icon", "subtitle", "display_order", "is_active", "created_at"]
    list_filter = ["is_active"]
    search_fields = ["name", "name_te", "slug", "description", "subtitle"]
    prepopulated_fields = {"slug": ("name",)}
    fieldsets = [
        ("General Details", {
            "fields": ["name", "name_te", "slug", "icon", "image_url", "description", "display_order", "is_active"]
        }),
        ("Display & Theme Styling", {
            "fields": ["banner_en", "banner_te", "subtags", "tile_bg_color", "tile_fg_color", "gradient_colors"]
        }),
        ("Quality & Purity Attributes (Default for Products in Category)", {
            "description": "Configures trust badges, subtitles, expandable lab specs, and tracking tags for all products in this category.",
            "fields": ["subtitle", "subtitle_te", "quality_badge_title", "quality_specs", "tracking_badges"],
        }),
    ]


from apps.products.models import StorefrontConfig

@admin.register(StorefrontConfig)
class StorefrontConfigAdmin(admin.ModelAdmin):
    list_display = ["id", "headline", "is_cod_enabled", "is_wallet_enabled", "is_active", "updated_at"]
    list_editable = ["is_cod_enabled", "is_wallet_enabled", "is_active"]
    fieldsets = [
        ("General Details", {
            "fields": [
                "is_cod_enabled",
                "is_wallet_enabled",
                "is_active",
                "headline",
                "subtitle",
                "dispatch_tag",
                "promo_chip",
                "cta_text",
                "banner_image_url",
                "banner_image",
            ]
        }),
        ("Fees & Taxes Settings", {
            "fields": [
                "platform_fee",
                "tax_percentage",
                "delivery_fee",
                "free_delivery_threshold",
            ]
        }),
    ]
