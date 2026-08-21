from rest_framework import serializers
from apps.products.models import Category, Product, HubProductInventory


class HubProductInventorySerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    hub_name = serializers.CharField(source="hub.name", read_only=True)
    available_slots = serializers.IntegerField(read_only=True)

    class Meta:
        model = HubProductInventory
        fields = [
            "id",
            "hub",
            "hub_name",
            "product",
            "product_name",
            "daily_capacity_slots",
            "booked_slots",
            "available_slots",
            "is_available",
            "updated_at",
        ]


class CategorySerializer(serializers.ModelSerializer):
    items_count = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = [
            "id",
            "name",
            "slug",
            "icon",
            "description",
            "display_order",
            "is_active",
            "items_count",
            "created_at",
        ]

    def get_items_count(self, obj):
        if hasattr(obj, "items_count_annotated"):
            return obj.items_count_annotated
        from django.db.models import Q
        return Product.objects.filter(Q(category_ref=obj) | Q(category__iexact=obj.slug) | Q(category__iexact=obj.name)).count()


class ProductSerializer(serializers.ModelSerializer):
    category_detail = CategorySerializer(source="category_ref", read_only=True)
    available_slots = serializers.SerializerMethodField()
    daily_capacity_slots = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = [
            "id",
            "name",
            "category",
            "category_ref",
            "category_detail",
            "description",
            "price_per_unit",
            "unit",
            "unit_quantity",
            "image_url",
            "badge_text",
            "nutrition_info",
            "farm_origin",
            "rating",
            "is_available",
            "available_slots",
            "daily_capacity_slots",
            "created_at",
        ]

    def get_available_slots(self, obj):
        request = self.context.get("request")
        user = request.user if request and hasattr(request, "user") and request.user.is_authenticated else None
        hub = getattr(user, "assigned_hub", None) if user else None
        if hub:
            inv = HubProductInventory.objects.filter(hub=hub, product=obj).first()
            if inv:
                return inv.available_slots
        return 100

    def get_daily_capacity_slots(self, obj):
        request = self.context.get("request")
        user = request.user if request and hasattr(request, "user") and request.user.is_authenticated else None
        hub = getattr(user, "assigned_hub", None) if user else None
        if hub:
            inv = HubProductInventory.objects.filter(hub=hub, product=obj).first()
            if inv:
                return inv.daily_capacity_slots
        return 100


class StorefrontConfigSerializer(serializers.ModelSerializer):
    banner_image_url = serializers.CharField(source="effective_banner_url", read_only=True)
    raw_banner_image_url = serializers.CharField(source="banner_image_url", required=False, allow_blank=True)

    class Meta:
        from apps.products.models import StorefrontConfig
        model = StorefrontConfig
        fields = [
            "id",
            "banner_image_url",
            "raw_banner_image_url",
            "banner_image",
            "headline",
            "subtitle",
            "dispatch_tag",
            "promo_chip",
            "cta_text",
            "is_active",
            "updated_at",
        ]

