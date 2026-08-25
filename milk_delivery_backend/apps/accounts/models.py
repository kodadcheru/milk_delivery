from decimal import Decimal
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class User(AbstractUser):
    class Roles(models.TextChoices):
        CUSTOMER = "CUSTOMER", "Customer"
        DELIVERY_PARTNER = "DRIVER", "Delivery Partner"
        HUB_MANAGER = "PROVIDER", "Location Hub Owner / Provider"
        SUPPORT_AGENT = "SUPPORT", "Support Executive / Agent"
        ADMIN = "ADMIN", "Administrator"

    # Convenient aliases
    Roles.DRIVER = Roles.DELIVERY_PARTNER
    Roles.PROVIDER = Roles.HUB_MANAGER
    Roles.SUPPORT = Roles.SUPPORT_AGENT

    class Genders(models.TextChoices):
        MALE = "Male", "Male 👨"
        FEMALE = "Female", "Female 👩"
        OTHER = "Other", "Other 👤"

    role = models.CharField(max_length=20, choices=Roles.choices, default=Roles.CUSTOMER)
    gender = models.CharField(max_length=10, choices=Genders.choices, default=Genders.MALE)
    phone = models.CharField(max_length=20, unique=True)
    address = models.TextField(blank=True, default="")
    city = models.CharField(max_length=100, default="Kodad")
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    delivery_instructions = models.CharField(max_length=255, blank=True, default="Ring bell and leave at door")
    delivery_slot_preference = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    latitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("17.00173400"))
    longitude = models.DecimalField(max_digits=11, decimal_places=8, default=Decimal("79.96250000"))

    # Hub Affiliation & Salaried Employment Fields
    assigned_hub = models.ForeignKey("deliveries.LocationHub", on_delete=models.SET_NULL, null=True, blank=True, related_name="delivery_partners")
    monthly_salary = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("15000.00"))
    driver_status = models.CharField(max_length=20, default="ACTIVE")
    last_location_updated = models.DateTimeField(null=True, blank=True)
    vehicle_number = models.CharField(max_length=20, blank=True, default='')
    driving_license = models.CharField(max_length=50, blank=True, default='')

    @property
    def customer_code(self):
        return f"CUST-{1000 + self.id}"

    @property
    def driver_code(self):
        return f"DRV-{2000 + self.id}"

    def __str__(self):
        hub_info = f" • {self.assigned_hub.name}" if self.assigned_hub else ""
        code = self.driver_code if self.role == self.Roles.DRIVER else self.customer_code
        return f"{self.first_name or self.username} [{code}] ({self.role}{hub_info}) - ₹{self.wallet_balance}"

    class Meta:
        constraints = [
            models.CheckConstraint(
                check=models.Q(wallet_balance__gte=Decimal("0.00")),
                name="user_wallet_balance_non_negative",
            )
        ]


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
        indexes = [
            models.Index(fields=["user", "-created_at"], name="wallet_user_created_idx"),
            models.Index(fields=["user", "transaction_type"], name="wallet_user_type_idx"),
        ]

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
    target_screen = models.CharField(max_length=50, blank=True, default="", help_text="Target screen code: DELIVERIES, WALLET, SUBSCRIPTIONS, CATEGORY, OFFERS, SUPPORT")
    target_param = models.CharField(max_length=100, blank=True, default="", help_text="Target parameter like category key or ID")
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_read", "-created_at"], name="notif_user_read_idx"),
        ]

    def __str__(self):
        return f"Notification for {self.user.username}: {self.title}"


class CustomerAddress(models.Model):
    class AddressTypes(models.TextChoices):
        HOME = "HOME", "Home 🏠"
        WORK = "WORK", "Work / Office 💼"
        OTHER = "OTHER", "Other Location 📍"

    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name="saved_addresses", db_column="customer_id")
    address_type = models.CharField(max_length=20, choices=AddressTypes.choices, default=AddressTypes.HOME)
    custom_tag = models.CharField(max_length=100, blank=True, default="", help_text="e.g. Parents Villa, Vacation House")
    flat_house_no = models.CharField(max_length=100, blank=True, default="")
    floor = models.CharField(max_length=50, blank=True, default="")
    building_name = models.CharField(max_length=150, blank=True, default="")
    street_address = models.CharField(max_length=255, blank=True, default="Main Road, Kodad")
    landmark = models.CharField(max_length=150, blank=True, default="")
    city = models.CharField(max_length=100, default="Kodad")
    pincode = models.CharField(max_length=20, default="508206")
    latitude = models.DecimalField(max_digits=18, decimal_places=10, default=Decimal("17.00173400"))
    longitude = models.DecimalField(max_digits=18, decimal_places=10, default=Decimal("79.96250000"))
    delivery_instructions = models.CharField(max_length=255, blank=True, default="Leave in doorstep milk basket, ring bell")
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-is_default", "-created_at"]
        verbose_name_plural = "Customer Addresses"

    @property
    def user(self):
        return self.customer

    @user.setter
    def user(self, value):
        self.customer = value

    def __str__(self):
        type_str = self.custom_tag if self.address_type == self.AddressTypes.OTHER and self.custom_tag else self.get_address_type_display()
        cust_name = self.customer.username if self.customer else "Unknown"
        return f"{type_str} - {self.flat_house_no}, {self.building_name}, {self.street_address} ({cust_name})"

    @property
    def address_code(self):
        return f"ADDR-{3000 + self.id}"

    @property
    def formatted_address(self):
        parts = []
        if self.flat_house_no:
            parts.append(self.flat_house_no)
        if self.floor:
            parts.append(self.floor)
        if self.building_name:
            parts.append(self.building_name)
        if self.street_address:
            parts.append(self.street_address)
        if self.landmark:
            parts.append(f"Near {self.landmark}")
        if self.city:
            parts.append(f"{self.city} - {self.pincode}")
        return ", ".join(parts) if parts else self.street_address

    def save(self, *args, **kwargs):
        if self.is_default:
            # Unset is_default on any other address for this customer
            CustomerAddress.objects.filter(customer=self.customer, is_default=True).exclude(pk=self.pk).update(is_default=False)
        super().save(*args, **kwargs)
        if self.customer and (self.is_default or not self.customer.address):
            User.objects.filter(pk=self.customer.pk).update(
                address=self.formatted_address or self.street_address,
                city=self.city or "Kodad",
                latitude=self.latitude,
                longitude=self.longitude,
                delivery_instructions=self.delivery_instructions or self.customer.delivery_instructions
            )


class SupportMessage(models.Model):
    class SenderTypes(models.TextChoices):
        USER = "user", "Customer"
        AGENT = "agent", "Support Agent"
        SYSTEM = "system", "System"

    phone = models.CharField(max_length=20, db_index=True)
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="support_messages")
    sender_type = models.CharField(max_length=10, choices=SenderTypes.choices, default=SenderTypes.USER)
    sender_name = models.CharField(max_length=100, default="Customer")
    text = models.TextField()
    order_id = models.CharField(max_length=50, blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["phone", "created_at"], name="supp_phone_created_idx"),
        ]

    def __str__(self):
        return f"[{self.sender_type}] {self.sender_name} ({self.phone}): {self.text[:30]}"


