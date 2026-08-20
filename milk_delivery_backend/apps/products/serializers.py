from rest_framework import serializers
from apps.products.models import Category, Product


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
            "created_at",
        ]
