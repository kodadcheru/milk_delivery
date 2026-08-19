from django.conf import settings
from django.db import models
from apps.subscriptions import models as sub_models


class LocationHub(models.Model):
    hub_code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=150)
    address = models.TextField()
    latitude = models.FloatField(default=17.4320)
    longitude = models.FloatField(default=78.4070)
    manager_name = models.CharField(max_length=100)
    manager_phone = models.CharField(max_length=20)
    fssai_license = models.CharField(max_length=50, default="13621014000342")
    coverage_radius_km = models.FloatField(default=5.0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.hub_code})"


class ServiceArea(models.Model):
    class Statuses(models.TextChoices):
        ACTIVE = "ACTIVE", "Active & Delivering"
        EXPANDING = "EXPANDING", "Expanding Soon"
        WAITLIST = "WAITLIST", "Waitlist Only"

    hub = models.ForeignKey(LocationHub, on_delete=models.CASCADE, related_name="service_areas", null=True, blank=True)
    name = models.CharField(max_length=100)  # e.g., Jubilee Hills, Film Nagar, Madhapur
    city = models.CharField(max_length=100, default="Hyderabad")
    pincodes = models.CharField(max_length=255, help_text="Comma-separated pincodes, e.g., 500033, 500096")
    radius_km = models.FloatField(default=5.0)
    latitude = models.FloatField(default=17.4320)
    longitude = models.FloatField(default=78.4070)
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.ACTIVE)
    active_households = models.PositiveIntegerField(default=128)
    popular_societies = models.TextField(default="My Home Bhooja, Rainbow Vistas, Aparna Sarovar, Lodha Bellezza")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.city}) - Pincodes: {self.pincodes}"


class DeliveryTask(models.Model):
    class Statuses(models.TextChoices):
        PENDING = "PENDING", "Scheduled (Pending)"
        DELIVERED = "DELIVERED", "Delivered at Doorstep"
        SKIPPED = "SKIPPED", "Skipped / Paused"

    subscription = models.ForeignKey(sub_models.Subscription, on_delete=models.CASCADE, related_name="deliveries", null=True, blank=True)
    order = models.ForeignKey("LiveOrder", on_delete=models.CASCADE, related_name="deliveries", null=True, blank=True)
    hub = models.ForeignKey(LocationHub, on_delete=models.CASCADE, related_name="tasks", null=True, blank=True)
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_deliveries")
    delivery_date = models.DateField()
    slot_time = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.PENDING)
    proof_image_url = models.URLField(blank=True, default="")
    delivered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["delivery_date", "id"]

    def __str__(self):
        cust_name = self.subscription.customer.username if self.subscription else (self.order.customer.username if self.order else "Unknown")
        return f"Delivery #{self.id} on {self.delivery_date} - {cust_name} ({self.status})"


class LiveOrder(models.Model):
    class OrderTypes(models.TextChoices):
        ONE_TIME = "ONE_TIME", "One-Time Order"
        EXPRESS = "EXPRESS", "Express Delivery"
        SUBSCRIPTION_ORDER = "SUBSCRIPTION_ORDER", "Subscription Batch Order"

    class Statuses(models.TextChoices):
        PLACED = "PLACED", "Order Placed"
        PREPARING = "PREPARING", "Preparing / Packing"
        OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY", "Out for Delivery"
        DELIVERED = "DELIVERED", "Delivered"
        CANCELLED = "CANCELLED", "Cancelled"

    id = models.CharField(max_length=50, primary_key=True)  # e.g., MD-8042
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="live_orders")
    hub = models.ForeignKey(LocationHub, on_delete=models.SET_NULL, null=True, blank=True, related_name="live_orders")
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_orders")
    order_type = models.CharField(max_length=30, choices=OrderTypes.choices, default=OrderTypes.ONE_TIME)
    status = models.CharField(max_length=30, choices=Statuses.choices, default=Statuses.PREPARING)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    delivery_date = models.CharField(max_length=50, default="Tomorrow")
    delivery_slot = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    delivery_address = models.TextField(default="Doorstep Delivery Location")
    delivery_latitude = models.DecimalField(max_digits=11, decimal_places=8, default=17.4319)
    delivery_longitude = models.DecimalField(max_digits=11, decimal_places=8, default=78.4073)
    delivery_otp = models.CharField(max_length=10, default="4892")
    payment_status = models.CharField(max_length=50, default="PAID (Prepaid Wallet)")
    proof_image_url = models.URLField(blank=True, default="")
    delivered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.id} - {self.customer.username} ({self.status}) - ₹{self.total_amount}"


class LiveOrderItem(models.Model):
    order = models.ForeignKey(LiveOrder, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey("products.Product", on_delete=models.CASCADE, related_name="order_items")
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=8, decimal_places=2)

    def __str__(self):
        return f"{self.order.id}: {self.quantity}x {self.product.name} @ ₹{self.unit_price}"
