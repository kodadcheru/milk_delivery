from rest_framework import serializers
from apps.accounts.serializers import UserSerializer
from apps.deliveries.models import DeliveryTask, LocationHub, ServiceArea
from apps.subscriptions.serializers import SubscriptionSerializer


class LocationHubSerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationHub
        fields = "__all__"


class ServiceAreaSerializer(serializers.ModelSerializer):
    hub_detail = LocationHubSerializer(source="hub", read_only=True)

    class Meta:
        model = ServiceArea
        fields = "__all__"


class DeliveryTaskSerializer(serializers.ModelSerializer):
    subscription_detail = SubscriptionSerializer(source="subscription", read_only=True)
    driver_detail = UserSerializer(source="driver", read_only=True)
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    delivery_address = serializers.SerializerMethodField()
    delivery_instructions = serializers.SerializerMethodField()
    customer_latitude = serializers.SerializerMethodField()
    customer_longitude = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryTask
        fields = [
            "id",
            "subscription",
            "subscription_detail",
            "driver",
            "driver_detail",
            "customer_name",
            "customer_phone",
            "delivery_address",
            "delivery_instructions",
            "customer_latitude",
            "customer_longitude",
            "delivery_date",
            "slot_time",
            "status",
            "proof_image_url",
            "delivered_at",
        ]
        read_only_fields = ["id", "delivered_at"]

    def get_customer_name(self, obj):
        cust = obj.subscription.customer
        name = f"{cust.first_name} {cust.last_name}".strip()
        return name if name else cust.username

    def get_customer_phone(self, obj):
        return obj.subscription.customer.phone

    def get_delivery_address(self, obj):
        return obj.subscription.customer.address

    def get_delivery_instructions(self, obj):
        return obj.subscription.customer.delivery_instructions

    def get_customer_latitude(self, obj):
        return float(obj.subscription.customer.latitude) if obj.subscription.customer.latitude else 17.4319

    def get_customer_longitude(self, obj):
        return float(obj.subscription.customer.longitude) if obj.subscription.customer.longitude else 78.4073
