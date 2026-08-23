from rest_framework import serializers
from apps.products.serializers import ProductSerializer
from apps.subscriptions.models import Subscription, VacationPause
from apps.deliveries.models import LocationHub


class HubSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationHub
        fields = ["id", "hub_code", "name", "address", "latitude", "longitude", "manager_name", "manager_phone", "coverage_radius_km"]


class VacationPauseSerializer(serializers.ModelSerializer):
    class Meta:
        model = VacationPause
        fields = ["id", "subscription", "start_date", "end_date", "reason", "created_at"]
        read_only_fields = ["id", "created_at"]


from datetime import date

class SubscriptionSerializer(serializers.ModelSerializer):
    product_detail = ProductSerializer(source="product", read_only=True)
    hub_detail = HubSimpleSerializer(source="hub", read_only=True)
    vacation_pauses = VacationPauseSerializer(many=True, read_only=True)
    start_date = serializers.DateField(required=False, default=date.today)
    delivery_latitude = serializers.FloatField(required=False, allow_null=True)
    delivery_longitude = serializers.FloatField(required=False, allow_null=True)

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
            "delivery_address",
            "delivery_slot",
            "delivery_latitude",
            "delivery_longitude",
            "delivery_instructions",
            "pack_size",
            "effective_unit_price",
            "vacation_pauses",
            "created_at",
        ]
        read_only_fields = ["id", "customer", "created_at", "effective_unit_price"]
