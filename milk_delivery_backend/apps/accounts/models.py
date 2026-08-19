from decimal import Decimal
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    class Roles(models.TextChoices):
        CUSTOMER = "CUSTOMER", "Customer"
        DELIVERY_PARTNER = "DRIVER", "Delivery Partner"
        HUB_MANAGER = "PROVIDER", "Location Hub Owner / Provider"
        ADMIN = "ADMIN", "Administrator"

    # Convenient aliases
    Roles.DRIVER = Roles.DELIVERY_PARTNER
    Roles.PROVIDER = Roles.HUB_MANAGER

    role = models.CharField(max_length=20, choices=Roles.choices, default=Roles.CUSTOMER)
    phone = models.CharField(max_length=20, unique=True)
    address = models.TextField(blank=True, default="")
    city = models.CharField(max_length=100, default="Hyderabad")
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("500.00"))
    delivery_instructions = models.CharField(max_length=255, blank=True, default="Ring bell and leave at door")
    delivery_slot_preference = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    latitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("17.43190000"))
    longitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("78.40730000"))

    # Hub Affiliation & Salaried Employment Fields
    assigned_hub = models.ForeignKey("deliveries.LocationHub", on_delete=models.SET_NULL, null=True, blank=True, related_name="delivery_partners")
    monthly_salary = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("15000.00"))
    driver_status = models.CharField(max_length=20, default="ACTIVE")

    def __str__(self):
        hub_info = f" • {self.assigned_hub.name}" if self.assigned_hub else ""
        return f"{self.first_name or self.username} ({self.role}{hub_info}) - ₹{self.wallet_balance}"


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


class CustomerAddress(models.Model):
    class AddressTypes(models.TextChoices):
        HOME = "HOME", "Home 🏠"
        WORK = "WORK", "Work / Office 💼"
        OTHER = "OTHER", "Other Location 📍"

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="saved_addresses")
    address_type = models.CharField(max_length=20, choices=AddressTypes.choices, default=AddressTypes.HOME)
    custom_tag = models.CharField(max_length=100, blank=True, default="", help_text="e.g. Parents Villa, Vacation House")
    flat_house_no = models.CharField(max_length=100, blank=True, default="")
    floor = models.CharField(max_length=50, blank=True, default="")
    building_name = models.CharField(max_length=150, blank=True, default="")
    street_address = models.CharField(max_length=255, default="Road No. 36, Jubilee Hills")
    landmark = models.CharField(max_length=150, blank=True, default="")
    city = models.CharField(max_length=100, default="Hyderabad")
    pincode = models.CharField(max_length=20, default="500033")
    latitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("17.43190000"))
    longitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("78.40730000"))
    delivery_instructions = models.CharField(max_length=255, blank=True, default="Leave in doorstep milk basket, ring bell")
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-is_default", "-created_at"]
        verbose_name_plural = "Customer Addresses"

    def __str__(self):
        type_str = self.custom_tag if self.address_type == self.AddressTypes.OTHER and self.custom_tag else self.get_address_type_display()
        return f"{type_str} - {self.flat_house_no}, {self.building_name}, {self.street_address} ({self.user.username})"

    def save(self, *args, **kwargs):
        if self.is_default:
            # Unset is_default on any other address for this user
            CustomerAddress.objects.filter(user=self.user, is_default=True).exclude(pk=self.pk).update(is_default=False)
        super().save(*args, **kwargs)

