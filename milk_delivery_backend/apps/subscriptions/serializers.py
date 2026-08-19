from rest_framework import serializers
from apps.products.serializers import ProductSerializer
from apps.deliveries.serializers import LocationHubSerializer
from apps.subscriptions.models import Subscription, VacationPause


class VacationPauseSerializer(serializers.ModelSerializer):
    class Meta:
        model = VacationPause
        fields = ["id", "subscription", "start_date", "end_date", "reason", "created_at"]
        read_only_fields = ["id", "created_at"]


class SubscriptionSerializer(serializers.ModelSerializer):
    product_detail = ProductSerializer(source="product", read_only=True)
    hub_detail = LocationHubSerializer(source="hub", read_only=True)
    vacation_pauses = VacationPauseSerializer(many=True, read_only=True)

    class Meta:
        model = Subscription
        fields = [
            "id",
            "customer",
            "product",
            "product_detail",
            "hub",
            "hub_detail",
            "quantity",
            "schedule_type",
            "start_date",
            "status",
            "vacation_pauses",
            "created_at",
        ]
        read_only_fields = ["id", "customer", "created_at"]
