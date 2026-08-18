from rest_framework import serializers
from apps.products.models import Product


class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = [
            "id",
            "name",
            "category",
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
