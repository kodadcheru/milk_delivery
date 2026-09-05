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


from apps.products.serializers import ProductSerializer


class DeliveryTaskSerializer(serializers.ModelSerializer):
    subscription_detail = SubscriptionSerializer(source="subscription", read_only=True)
    driver_detail = UserSerializer(source="driver", read_only=True)
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    delivery_address = serializers.SerializerMethodField()
    delivery_instructions = serializers.SerializerMethodField()
    customer_latitude = serializers.SerializerMethodField()
    customer_longitude = serializers.SerializerMethodField()
    product_name = serializers.SerializerMethodField()
    product_image = serializers.SerializerMethodField()
    quantity = serializers.SerializerMethodField()
    pack_size = serializers.SerializerMethodField()
    price_per_unit = serializers.SerializerMethodField()
    fat_percentage = serializers.SerializerMethodField()
    snf_percentage = serializers.SerializerMethodField()
    water_percentage = serializers.SerializerMethodField()
    batch_price_per_litre = serializers.SerializerMethodField()
    batch_code = serializers.SerializerMethodField()
    temperature_celsius = serializers.SerializerMethodField()
    hub_detail = serializers.SerializerMethodField()
    drops_ahead = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryTask
        fields = [
            "id",
            "subscription",
            "subscription_detail",
            "order",
            "driver",
            "driver_detail",
            "hub",
            "hub_detail",
            "drops_ahead",
            "customer_name",
            "customer_phone",
            "delivery_address",
            "delivery_instructions",
            "customer_latitude",
            "customer_longitude",
            "product_name",
            "product_image",
            "quantity",
            "pack_size",
            "price_per_unit",
            "fat_percentage",
            "snf_percentage",
            "water_percentage",
            "batch_price_per_litre",
            "batch_code",
            "temperature_celsius",
            "delivery_date",
            "slot_time",
            "status",
            "failure_reason",
            "is_cod",
            "cash_collected",
            "cash_amount",
            "proof_image_url",
            "delivered_at",
        ]
        read_only_fields = ["id", "delivered_at"]

    def _get_cust(self, obj):
        if obj.subscription and obj.subscription.customer:
            return obj.subscription.customer
        if obj.order and obj.order.customer:
            return obj.order.customer
        return None

    def get_customer_name(self, obj):
        cust = self._get_cust(obj)
        if not cust:
            return "Customer"
        name = f"{cust.first_name} {cust.last_name}".strip()
        return name if name else cust.username

    def get_customer_phone(self, obj):
        cust = self._get_cust(obj)
        return cust.phone if cust else ""

    def get_delivery_address(self, obj):
        if obj.subscription and obj.subscription.delivery_address:
            return obj.subscription.delivery_address
        if obj.order and obj.order.delivery_address:
            return obj.order.delivery_address
        cust = self._get_cust(obj)
        return cust.address if cust else ""

    def get_delivery_instructions(self, obj):
        if obj.subscription and obj.subscription.delivery_instructions:
            return obj.subscription.delivery_instructions
        cust = self._get_cust(obj)
        return cust.delivery_instructions if cust else ""

    def get_customer_latitude(self, obj):
        if obj.subscription and obj.subscription.delivery_latitude is not None:
            try:
                val = float(obj.subscription.delivery_latitude)
                if val != 0.0:
                    return val
            except (ValueError, TypeError):
                pass
        if obj.order and obj.order.delivery_latitude is not None:
            try:
                val = float(obj.order.delivery_latitude)
                if val != 0.0:
                    return val
            except (ValueError, TypeError):
                pass
        cust = self._get_cust(obj)
        if cust and cust.latitude:
            try:
                val = float(cust.latitude)
                if val != 0.0:
                    return val
            except (ValueError, TypeError):
                pass
        return 16.9950

    def get_customer_longitude(self, obj):
        if obj.subscription and obj.subscription.delivery_longitude is not None:
            try:
                val = float(obj.subscription.delivery_longitude)
                if val != 0.0:
                    return val
            except (ValueError, TypeError):
                pass
        if obj.order and obj.order.delivery_longitude is not None:
            try:
                val = float(obj.order.delivery_longitude)
                if val != 0.0:
                    return val
            except (ValueError, TypeError):
                pass
        cust = self._get_cust(obj)
        if cust and cust.longitude:
            try:
                val = float(cust.longitude)
                if val != 0.0:
                    return val
            except (ValueError, TypeError):
                pass
        return 79.9670

    def get_product_name(self, obj):
        if obj.subscription and obj.subscription.product:
            return obj.subscription.product.name
        if obj.order:
            first_item = obj.order.items.first()
            if first_item and first_item.product:
                return first_item.product.name
        return "Farm Fresh Cow Milk"

    def get_product_image(self, obj):
        if obj.subscription and obj.subscription.product:
            return obj.subscription.product.image_url
        if obj.order:
            first_item = obj.order.items.first()
            if first_item and first_item.product:
                return first_item.product.image_url
        return "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80"

    def get_quantity(self, obj):
        if obj.subscription:
            return obj.subscription.quantity
        if obj.order:
            first_item = obj.order.items.first()
            if first_item:
                return first_item.quantity
        return 1

    def get_pack_size(self, obj):
        if obj.subscription:
            return obj.subscription.pack_size or (obj.subscription.product.unit_quantity if obj.subscription.product else "1 Litre")
        return "1 Litre"

    def get_price_per_unit(self, obj):
        if obj.subscription:
            eff = obj.subscription.effective_unit_price
            if eff is not None and float(eff) > 0:
                return str(eff)
            if obj.subscription.product:
                base = float(obj.subscription.product.price_per_unit)
                p_size = (obj.subscription.pack_size or '').lower()
                if '500' in p_size:
                    return str(round(base * 0.5, 2))
                elif '2' in p_size and ('litre' in p_size or 'liter' in p_size or 'kg' in p_size):
                    return str(round(base * 2.0, 2))
                return str(round(base, 2))
        if obj.order:
            first_item = obj.order.items.first()
            if first_item:
                return str(first_item.unit_price)
        return "0.00"

    def _get_batch(self, obj):
        from apps.deliveries.models import DailyMilkBatch
        if not hasattr(obj, "_cached_batch"):
            prod_name = self.get_product_name(obj)
            first_word = prod_name.split()[0] if prod_name else ""
            batch = DailyMilkBatch.objects.filter(
                batch_date=obj.delivery_date,
                product_name__icontains=first_word,
            ).first()
            if not batch:
                batch = DailyMilkBatch.objects.filter(batch_date=obj.delivery_date).first()
            if not batch:
                batch = DailyMilkBatch.objects.first()
            obj._cached_batch = batch
        return obj._cached_batch

    def _is_dairy(self, obj):
        prod = self.get_product_name(obj).lower()
        if any(x in prod for x in ["meat", "chicken", "mutton", "poultry", "egg", "water", "can", "fish", "prawn"]):
            return False
        return any(x in prod for x in ["milk", "dairy", "ghee", "paneer", "curd", "butter", "a2", "buffalo", "cow"])

    def get_fat_percentage(self, obj):
        if not self._is_dairy(obj):
            return 0.0
        batch = self._get_batch(obj)
        if batch:
            return float(batch.fat_percentage)
        prod = self.get_product_name(obj).lower()
        return 6.8 if "buffalo" in prod else (4.5 if "a2" in prod or "desi" in prod else 4.2)

    def get_snf_percentage(self, obj):
        if not self._is_dairy(obj):
            return 0.0
        batch = self._get_batch(obj)
        if batch:
            return float(batch.snf_percentage)
        prod = self.get_product_name(obj).lower()
        return 9.0 if "buffalo" in prod else 8.5

    def get_water_percentage(self, obj):
        if not self._is_dairy(obj):
            return 0.0
        batch = self._get_batch(obj)
        if batch:
            return float(batch.water_percentage)
        return 0.0

    def get_batch_price_per_litre(self, obj):
        batch = self._get_batch(obj)
        if batch:
            return float(batch.price_per_litre)
        try:
            return float(self.get_price_per_unit(obj))
        except (ValueError, TypeError):
            return 68.0

    def get_batch_code(self, obj):
        batch = self._get_batch(obj)
        if batch:
            return batch.batch_code
        return f"BATCH-{obj.delivery_date.strftime('%Y%m%d')}-01"

    def get_temperature_celsius(self, obj):
        batch = self._get_batch(obj)
        if batch:
            return float(batch.temperature_celsius)
        return 3.8

    def get_hub_detail(self, obj):
        hub = obj.hub
        if not hub and obj.subscription:
            hub = obj.subscription.hub
        if not hub and obj.order:
            hub = obj.order.hub
        if not hub and obj.driver and getattr(obj.driver, "assigned_hub", None):
            hub = obj.driver.assigned_hub
        if hub:
            return {
                "id": hub.id,
                "hub_code": hub.hub_code,
                "name": hub.name,
                "address": hub.address,
                "latitude": float(hub.latitude) if hub.latitude is not None else None,
                "longitude": float(hub.longitude) if hub.longitude is not None else None,
                "contact_phone": getattr(hub, "contact_phone", "") or "",
                "coverage_radius_km": float(hub.coverage_radius_km) if hub.coverage_radius_km is not None else None,
            }
        return None

    def get_drops_ahead(self, obj):
        if not obj.driver or obj.status in [DeliveryTask.Statuses.DELIVERED, DeliveryTask.Statuses.SKIPPED, DeliveryTask.Statuses.FAILED]:
            return 0
        return DeliveryTask.objects.filter(
            driver=obj.driver,
            delivery_date=obj.delivery_date,
            status__in=[DeliveryTask.Statuses.PENDING, DeliveryTask.Statuses.PICKED_UP, DeliveryTask.Statuses.ON_THE_WAY],
            id__lt=obj.id,
        ).count()


class LiveOrderItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.IntegerField(write_only=True)

    class Meta:
        from apps.deliveries.models import LiveOrderItem
        model = LiveOrderItem
        fields = ["id", "product", "product_id", "quantity", "pack_size", "unit_price"]


class LiveOrderSerializer(serializers.ModelSerializer):
    items = LiveOrderItemSerializer(many=True, read_only=True)
    customer_detail = UserSerializer(source="customer", read_only=True)
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    driver_name = serializers.SerializerMethodField()
    driver_phone = serializers.SerializerMethodField()
    driver_vehicle = serializers.SerializerMethodField()
    fat_percentage = serializers.SerializerMethodField()
    snf_percentage = serializers.SerializerMethodField()
    water_percentage = serializers.SerializerMethodField()
    batch_price_per_litre = serializers.SerializerMethodField()
    batch_code = serializers.SerializerMethodField()
    temperature_celsius = serializers.SerializerMethodField()
    delivery_latitude = serializers.FloatField(required=False, allow_null=True)
    delivery_longitude = serializers.FloatField(required=False, allow_null=True)

    class Meta:
        from apps.deliveries.models import LiveOrder
        model = LiveOrder
        fields = [
            "id",
            "customer",
            "customer_detail",
            "customer_name",
            "customer_phone",
            "hub",
            "driver",
            "driver_name",
            "driver_phone",
            "driver_vehicle",
            "order_type",
            "status",
            "total_amount",
            "delivery_date",
            "delivery_slot",
            "delivery_address",
            "delivery_latitude",
            "delivery_longitude",
            "delivery_otp",
            "payment_status",
            "payment_method",
            "is_cod",
            "cash_collected",
            "cash_amount",
            "proof_image_url",
            "delivered_at",
            "created_at",
            "updated_at",
            "items",
            "fat_percentage",
            "snf_percentage",
            "water_percentage",
            "batch_price_per_litre",
            "batch_code",
            "temperature_celsius",
            "delivery_type",
            "eta_minutes",
            "estimated_delivery_time",
        ]
        read_only_fields = ["created_at", "updated_at"]

    def get_customer_name(self, obj):
        if obj.customer:
            name = f"{obj.customer.first_name} {obj.customer.last_name}".strip()
            return name if name else obj.customer.username
        return "Customer"

    def get_customer_phone(self, obj):
        return obj.customer.phone if obj.customer else ""

    def get_driver_name(self, obj):
        if not obj.driver and (obj.hub or getattr(obj.customer, 'assigned_hub', None)):
            try:
                from apps.deliveries.order_views import auto_assign_hub_driver
                auto_assign_hub_driver(obj)
            except Exception:
                pass
        if obj.driver:
            name = f"{obj.driver.first_name} {obj.driver.last_name}".strip()
            return name if name else obj.driver.username
        if obj.hub:
            return f"{obj.hub.name} Delivery Partner"
        return "Delivery Partner"

    def get_driver_phone(self, obj):
        if not obj.driver and (obj.hub or getattr(obj.customer, 'assigned_hub', None)):
            try:
                from apps.deliveries.order_views import auto_assign_hub_driver
                auto_assign_hub_driver(obj)
            except Exception:
                pass
        return obj.driver.phone if obj.driver else ""

    def get_driver_vehicle(self, obj):
        if obj.driver and getattr(obj.driver, "vehicle_number", None) and obj.driver.vehicle_number:
            return obj.driver.vehicle_number
        return "Electric Scooter (TS 09 EB 4092)"

    def _get_batch(self, obj):
        from apps.deliveries.models import DailyMilkBatch
        if not hasattr(obj, "_cached_batch"):
            if obj.batch:
                obj._cached_batch = obj.batch
            else:
                obj._cached_batch = DailyMilkBatch.objects.filter(hub=obj.hub, batch_date=obj.delivery_date).first()
        return obj._cached_batch

    def _is_dairy_order(self, obj):
        if not hasattr(obj, "_cached_is_dairy"):
            has_dairy = False
            for it in obj.items.all():
                p_name = (it.product.name if it.product else "").lower()
                p_cat = (it.product.category if it.product else "").lower()
                if any(x in p_cat for x in ["meat", "poultry", "egg", "water"]):
                    continue
                if any(x in p_name for x in ["meat", "chicken", "mutton", "egg", "water", "can", "fish", "prawn"]):
                    continue
                if any(x in p_cat for x in ["milk", "dairy", "ghee", "paneer", "curd"]) or any(x in p_name for x in ["milk", "ghee", "paneer", "curd", "butter", "a2", "buffalo"]):
                    has_dairy = True
                    break
            obj._cached_is_dairy = has_dairy
        return obj._cached_is_dairy

    def get_fat_percentage(self, obj):
        if not self._is_dairy_order(obj):
            return 0.0
        batch = self._get_batch(obj)
        return float(batch.fat_percentage) if batch else 6.8

    def get_snf_percentage(self, obj):
        if not self._is_dairy_order(obj):
            return 0.0
        batch = self._get_batch(obj)
        return float(batch.snf_percentage) if batch else 9.0

    def get_water_percentage(self, obj):
        if not self._is_dairy_order(obj):
            return 0.0
        batch = self._get_batch(obj)
        return float(batch.water_percentage) if batch else 0.0

    def get_batch_price_per_litre(self, obj):
        batch = self._get_batch(obj)
        return float(batch.price_per_litre) if batch else float(obj.total_amount)

    def get_batch_code(self, obj):
        batch = self._get_batch(obj)
        return batch.batch_code if batch else ""

    def get_temperature_celsius(self, obj):
        batch = self._get_batch(obj)
        return float(batch.temperature_celsius) if batch else 3.8


class DeliveryRatingSerializer(serializers.ModelSerializer):
    class Meta:
        from apps.deliveries.models import DeliveryRating
        model = DeliveryRating
        fields = "__all__"

