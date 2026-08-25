from django.conf import settings
from django.db import models
from apps.products.models import Product


class Subscription(models.Model):
    class Schedules(models.TextChoices):
        DAILY = "DAILY", "Everyday (Daily)"
        ALTERNATE = "ALTERNATE", "Alternate Days"
        CUSTOM = "CUSTOM", "Custom Days"
        ONCE = "ONCE", "One Time Order"
        WEEKDAYS = 'WEEKDAYS', 'Weekdays Only'

    class Statuses(models.TextChoices):
        ACTIVE = "ACTIVE", "Active"
        PAUSED = "PAUSED", "Vacation / Paused"
        CANCELLED = "CANCELLED", "Cancelled"

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subscriptions")
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="subscriptions")
    hub = models.ForeignKey("deliveries.LocationHub", on_delete=models.SET_NULL, null=True, blank=True, related_name="subscriptions")
    address = models.ForeignKey("accounts.CustomerAddress", on_delete=models.SET_NULL, null=True, blank=True, related_name="subscriptions")
    quantity = models.PositiveIntegerField(default=1)
    schedule_type = models.CharField(max_length=20, choices=Schedules.choices, default=Schedules.DAILY)
    start_date = models.DateField()
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.ACTIVE)
    delivery_address = models.TextField(blank=True, default="")
    delivery_slot = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    delivery_latitude = models.DecimalField(max_digits=15, decimal_places=8, null=True, blank=True)
    delivery_longitude = models.DecimalField(max_digits=15, decimal_places=8, null=True, blank=True)
    delivery_instructions = models.CharField(max_length=255, blank=True, default="")
    pack_size = models.CharField(max_length=50, blank=True, default="1 Litre")
    effective_unit_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def formatted_delivery_address(self):
        if self.address:
            return self.address.formatted_address
        return self.delivery_address or (self.customer.address if hasattr(self.customer, 'address') else '')

    @property
    def customer_code(self):
        return getattr(self.customer, 'customer_code', f"CUST-{1000 + self.customer_id}")

    @property
    def hub_code(self):
        return getattr(self.hub, 'hub_code', 'HUB-KDD-01') if self.hub else 'HUB-KDD-01'

    def __str__(self):
        return f"{self.customer.username} [{self.customer_code}] - {self.quantity}x {self.product.name} ({self.schedule_type})"


class VacationPause(models.Model):
    subscription = models.ForeignKey(Subscription, on_delete=models.CASCADE, related_name="vacation_pauses")
    start_date = models.DateField()
    end_date = models.DateField()
    reason = models.CharField(max_length=150, blank=True, default="Out of town")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Pause {self.subscription.id}: {self.start_date} to {self.end_date}"
