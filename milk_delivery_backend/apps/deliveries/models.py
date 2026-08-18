from django.conf import settings
from django.db import models
from apps.subscriptions import models as sub_models


class DeliveryTask(models.Model):
    class Statuses(models.TextChoices):
        PENDING = "PENDING", "Scheduled (Pending)"
        DELIVERED = "DELIVERED", "Delivered at Doorstep"
        SKIPPED = "SKIPPED", "Skipped / Paused"

    subscription = models.ForeignKey(sub_models.Subscription, on_delete=models.CASCADE, related_name="deliveries")
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_deliveries")
    delivery_date = models.DateField()
    slot_time = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.PENDING)
    proof_image_url = models.URLField(blank=True, default="")
    delivered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["delivery_date", "id"]

    def __str__(self):
        return f"Delivery #{self.id} on {self.delivery_date} - {self.subscription.customer.username} ({self.status})"
