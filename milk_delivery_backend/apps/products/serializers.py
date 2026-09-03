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
            "image_url",
            "description",
            "subtitle",
            "quality_badge_title",
            "quality_specs",
            "tracking_badges",
            "display_order",
            "is_active",
            "items_count",
            "created_at",
        ]

    def get_items_count(self, obj):
        if hasattr(obj, "items_count_annotated"):
            return obj.items_count_annotated
        return obj.products.count() if hasattr(obj, "products") else 0


class ProductSerializer(serializers.ModelSerializer):
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(), source="category_ref", required=False, allow_null=True
    )
    category_detail = CategorySerializer(source="category_ref", read_only=True)
    category_icon = serializers.CharField(read_only=True)
    available_slots = serializers.SerializerMethodField()
    daily_capacity_slots = serializers.SerializerMethodField()
    resolved_subtitle = serializers.CharField(read_only=True)
    resolved_quality_badge_title = serializers.CharField(read_only=True)
    resolved_quality_specs = serializers.JSONField(read_only=True)
    resolved_tracking_badges = serializers.JSONField(read_only=True)

    class Meta:
        model = Product
        fields = [
            "id",
            "name",
            "category",
            "category_id",
            "category_ref",
            "category_detail",
            "category_icon",
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
            "subtitle",
            "quality_badge_title",
            "quality_specs",
            "tracking_badges",
            "resolved_subtitle",
            "resolved_quality_badge_title",
            "resolved_quality_specs",
            "resolved_tracking_badges",
            "created_at",
        ]

    def _resolve_hub(self):
        request = self.context.get("request")
        hub = None
        if request and hasattr(request, "query_params"):
            from apps.deliveries.models import LocationHub
            hub_code = request.query_params.get("hub_code") or request.query_params.get("hub")
            hub_id = request.query_params.get("hub_id")
            if hub_code:
                if str(hub_code).isdigit():
                    hub = LocationHub.objects.filter(pk=int(hub_code)).first()
                if not hub:
                    hub = LocationHub.objects.filter(hub_code=hub_code).first()
            elif hub_id:
                try:
                    hub = LocationHub.objects.filter(pk=int(hub_id)).first()
                except (ValueError, TypeError):
                    pass
        user = request.user if request and hasattr(request, "user") and request.user.is_authenticated else None
        if not hub and user:
            hub = getattr(user, "assigned_hub", None)
        return hub

    def get_available_slots(self, obj):
        hub = self._resolve_hub()
        if hub:
            inv = HubProductInventory.objects.filter(hub=hub, product=obj).first()
            if inv:
                return inv.available_slots
        return 100

    def get_daily_capacity_slots(self, obj):
        hub = self._resolve_hub()
        if hub:
            inv = HubProductInventory.objects.filter(hub=hub, product=obj).first()
            if inv:
                return inv.daily_capacity_slots
        return 100


class StorefrontConfigSerializer(serializers.ModelSerializer):
    banner_image_url = serializers.SerializerMethodField()
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

    def get_banner_image_url(self, obj):
        request = self.context.get("request")
        if obj.banner_image:
            try:
                if request:
                    return request.build_absolute_uri(obj.banner_image.url)
                return obj.banner_image.url
            except Exception:
                pass
        return obj.banner_image_url or "https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80"

