from decimal import Decimal
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    class Roles(models.TextChoices):
        CUSTOMER = "CUSTOMER", "Customer"
        DELIVERY_PARTNER = "DRIVER", "Delivery Partner"
        ADMIN = "ADMIN", "Administrator"

    role = models.CharField(max_length=20, choices=Roles.choices, default=Roles.CUSTOMER)
    phone = models.CharField(max_length=20, unique=True)
    address = models.TextField(blank=True, default="")
    city = models.CharField(max_length=100, default="Hyderabad")
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("500.00"))
    delivery_instructions = models.CharField(max_length=255, blank=True, default="Ring bell and leave at door")
    delivery_slot_preference = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    latitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("17.43190000"))
    longitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("78.40730000"))

    def __str__(self):
        return f"{self.first_name or self.username} ({self.role}) - ₹{self.wallet_balance}"


class WalletTransaction(models.Model):
    class Types(models.TextChoices):
        CREDIT = "CREDIT", "Credit / Top-Up"
        DEBIT = "DEBIT", "Daily Delivery Debit"

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="wallet_transactions")
    amount = models.DecimalField(max_digits=8, decimal_places=2)
    transaction_type = models.CharField(max_length=10, choices=Types.choices)
    description = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user.username} - {self.transaction_type} ₹{self.amount} ({self.description})"


class Notification(models.Model):
    class Types(models.TextChoices):
        DELIVERY = "DELIVERY", "Delivery Update"
        WALLET = "WALLET", "Wallet Transaction"
        VACATION = "VACATION", "Vacation / Schedule"
        OFFER = "OFFER", "Promotional Offer"

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    title = models.CharField(max_length=150)
    message = models.TextField()
    notification_type = models.CharField(max_length=20, choices=Types.choices, default=Types.DELIVERY)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Notification for {self.user.username}: {self.title}"
