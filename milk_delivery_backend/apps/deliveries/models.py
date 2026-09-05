from decimal import Decimal
from django.conf import settings
from django.db import models
from datetime import date
import random
from apps.subscriptions import models as sub_models


class LocationHub(models.Model):
    hub_code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=150)
    address = models.TextField()
    latitude = models.FloatField(default=17.001734)
    longitude = models.FloatField(default=79.962500)
    manager_name = models.CharField(max_length=100)
    manager_phone = models.CharField(max_length=20)
    fssai_license = models.CharField(max_length=50, default="13621014000342")
    coverage_radius_km = models.FloatField(default=8.5)
    bank_name = models.CharField(max_length=150, blank=True, default="")
    bank_account_number = models.CharField(max_length=50, blank=True, default="")
    bank_ifsc = models.CharField(max_length=20, blank=True, default="")
    bank_account_holder = models.CharField(max_length=150, blank=True, default="")
    upi_id = models.CharField(max_length=100, blank=True, default="")
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


class CoverageExpansionRequest(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="coverage_expansion_requests",
    )
    phone = models.CharField(max_length=20, blank=True, default="")
    city = models.CharField(max_length=100, default="Kodad")
    area_name = models.CharField(max_length=255, blank=True, default="")
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Expansion Request: {self.area_name or self.city} ({self.phone or 'Guest'})"


class DeliverySlot(models.Model):
    hub = models.ForeignKey('LocationHub', on_delete=models.CASCADE, related_name='delivery_slots')
    name = models.CharField(max_length=50)  # '05:30 AM - 07:00 AM'
    label = models.CharField(max_length=50, default='Morning')  # 'Peak Morning'
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_orders = models.PositiveIntegerField(default=50)
    is_active = models.BooleanField(default=True)
    cutoff_minutes_before = models.IntegerField(default=30)

    class Meta:
        unique_together = ['hub', 'name']
        ordering = ['start_time']

    def __str__(self):
        return f"{self.name} ({self.hub.name}) - {self.max_orders} max"

    def booked_count(self, date):
        """Count how many delivery tasks are booked for this slot on a given date."""
        return DeliveryTask.objects.filter(
            hub=self.hub,
            slot_time=self.name,
            delivery_date=date,
            status__in=['PENDING', 'PICKED_UP', 'ON_THE_WAY', 'DELIVERED']
        ).count()

    def is_full(self, date):
        return self.booked_count(date) >= self.max_orders

    def is_cutoff_passed(self, delivery_date=None):
        from django.utils import timezone
        import datetime
        now = timezone.localtime()
        if delivery_date:
            if isinstance(delivery_date, str):
                try:
                    delivery_date = datetime.datetime.strptime(delivery_date, '%Y-%m-%d').date()
                except ValueError:
                    delivery_date = now.date()
            if delivery_date > now.date():
                return False
        cutoff = datetime.datetime.combine(now.date(), self.start_time) - datetime.timedelta(minutes=self.cutoff_minutes_before)
        cutoff = timezone.make_aware(cutoff) if timezone.is_naive(cutoff) else cutoff
        return now >= cutoff


class DeliveryTask(models.Model):
    class Statuses(models.TextChoices):
        PENDING = "PENDING", "Scheduled (Pending)"
        PICKED_UP = "PICKED_UP", "Picked Up from Hub"
        ON_THE_WAY = "ON_THE_WAY", "Out for Delivery / On the Way"
        DELIVERED = "DELIVERED", "Delivered at Doorstep"
        SKIPPED = "SKIPPED", "Skipped / Paused"
        FAILED = "FAILED", "FAILED"

    subscription = models.ForeignKey(sub_models.Subscription, on_delete=models.SET_NULL, related_name="deliveries", null=True, blank=True)
    order = models.ForeignKey("LiveOrder", on_delete=models.SET_NULL, related_name="deliveries", null=True, blank=True)
    batch = models.ForeignKey('DailyMilkBatch', null=True, blank=True, on_delete=models.SET_NULL, related_name='delivery_tasks')
    hub = models.ForeignKey(LocationHub, on_delete=models.CASCADE, related_name="tasks", null=True, blank=True)
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_deliveries")
    address = models.ForeignKey("accounts.CustomerAddress", on_delete=models.SET_NULL, null=True, blank=True, related_name="delivery_tasks")
    delivery_date = models.DateField()
    slot_time = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.PENDING)
    failure_reason = models.CharField(max_length=255, blank=True, default='')
    is_cod = models.BooleanField(default=False)
    cash_collected = models.BooleanField(default=False)
    cash_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    proof_image_url = models.URLField(blank=True, default="")
    delivered_at = models.DateTimeField(null=True, blank=True)
    payout = models.ForeignKey('ProviderPayout', on_delete=models.SET_NULL, null=True, blank=True, related_name='delivery_tasks')

    class Meta:
        ordering = ["delivery_date", "id"]
        indexes = [
            models.Index(fields=["delivery_date", "status"], name="deliv_date_status_idx"),
            models.Index(fields=["driver", "delivery_date"], name="deliv_driver_date_idx"),
        ]

    @property
    def target_customer(self):
        if self.subscription:
            return self.subscription.customer
        if self.order:
            return self.order.customer
        return None

    @property
    def customer_code(self):
        c = self.target_customer
        return getattr(c, 'customer_code', f"CUST-{1000 + c.id}") if c else ""

    @property
    def driver_code(self):
        return getattr(self.driver, 'driver_code', f"DRV-{2000 + self.driver.id}") if self.driver else "UNASSIGNED"

    @property
    def hub_code(self):
        return getattr(self.hub, 'hub_code', 'HUB-KDD-01') if self.hub else 'HUB-KDD-01'

    @property
    def formatted_delivery_address(self):
        if self.address:
            return self.address.formatted_address
        if self.subscription and self.subscription.address:
            return self.subscription.address.formatted_address
        if self.order and self.order.address:
            return self.order.address.formatted_address
        return self.subscription.delivery_address if self.subscription else (self.order.delivery_address if self.order else "")

    def __str__(self):
        cust_name = self.target_customer.username if self.target_customer else "Unknown"
        return f"Delivery #{self.id} [{self.customer_code}] on {self.delivery_date} - {cust_name} ({self.status})"


class LiveOrder(models.Model):
    class DeliveryTypes(models.TextChoices):
        INSTANT = 'INSTANT', 'Instant Delivery'
        SCHEDULED = 'SCHEDULED', 'Scheduled Delivery'

    class OrderTypes(models.TextChoices):
        ONE_TIME = "ONE_TIME", "One-Time Order"
        EXPRESS = "EXPRESS", "Express Delivery"
        SUBSCRIPTION_ORDER = "SUBSCRIPTION_ORDER", "Subscription Batch Order"

    class Statuses(models.TextChoices):
        PLACED = "PLACED", "Order Placed"
        PREPARING = "PREPARING", "Preparing / Packing"
        PICKED_UP = "PICKED_UP", "Order Picked Up"
        OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY", "Out for Delivery / On the Way"
        DELIVERED = "DELIVERED", "Delivered"
        CANCELLED = "CANCELLED", "Cancelled"

    id = models.CharField(max_length=50, primary_key=True)  # e.g., MD-8042
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="live_orders")
    hub = models.ForeignKey(LocationHub, on_delete=models.SET_NULL, null=True, blank=True, related_name="live_orders")
    batch = models.ForeignKey('DailyMilkBatch', null=True, blank=True, on_delete=models.SET_NULL, related_name='live_orders')
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_orders")
    address = models.ForeignKey("accounts.CustomerAddress", on_delete=models.SET_NULL, null=True, blank=True, related_name="live_orders")
    delivery_type = models.CharField(
        max_length=20,
        choices=DeliveryTypes.choices,
        default=DeliveryTypes.SCHEDULED,
    )
    eta_minutes = models.IntegerField(default=0, help_text='Estimated delivery time in minutes')
    estimated_delivery_time = models.DateTimeField(null=True, blank=True)
    order_type = models.CharField(max_length=30, choices=OrderTypes.choices, default=OrderTypes.ONE_TIME)
    status = models.CharField(max_length=30, choices=Statuses.choices, default=Statuses.PREPARING)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    delivery_date = models.DateField(default=date.today)
    delivery_slot = models.CharField(max_length=50, default="05:30 AM - 07:00 AM")
    delivery_address = models.TextField(default="")
    delivery_latitude = models.DecimalField(max_digits=15, decimal_places=8, null=True, blank=True)
    delivery_longitude = models.DecimalField(max_digits=15, decimal_places=8, null=True, blank=True)
    delivery_otp = models.CharField(max_length=10, default="")
    payment_status = models.CharField(max_length=50, default="PENDING")
    payment_method = models.CharField(max_length=20, default="WALLET", choices=[("WALLET", "Wallet Auto-Debit"), ("UPI", "Instant UPI / Pay"), ("COD", "Cash on Delivery")])
    is_cod = models.BooleanField(default=False)
    cash_collected = models.BooleanField(default=False)
    cash_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
    proof_image_url = models.URLField(blank=True, default="")
    delivered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["customer", "-created_at"], name="order_cust_created_idx"),
            models.Index(fields=["status", "-created_at"], name="order_status_created_idx"),
        ]

    @property
    def customer_code(self):
        return getattr(self.customer, 'customer_code', f"CUST-{1000 + self.customer_id}")

    @property
    def driver_code(self):
        return getattr(self.driver, 'driver_code', f"DRV-{2000 + self.driver_id}") if self.driver else "UNASSIGNED"

    @property
    def hub_code(self):
        return getattr(self.hub, 'hub_code', 'HUB-KDD-01') if self.hub else 'HUB-KDD-01'

    @property
    def formatted_delivery_address(self):
        if self.address:
            return self.address.formatted_address
        return self.delivery_address or (self.customer.address if hasattr(self.customer, 'address') else '')

    def __str__(self):
        return f"{self.id} [{self.customer_code}] - {self.customer.username} ({self.status}) - ₹{self.total_amount}"


class LiveOrderItem(models.Model):
    order = models.ForeignKey(LiveOrder, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey("products.Product", on_delete=models.CASCADE, related_name="order_items")
    quantity = models.PositiveIntegerField(default=1)
    pack_size = models.CharField(max_length=50, default="1 Litre", blank=True)
    unit_price = models.DecimalField(max_digits=8, decimal_places=2)

    def __str__(self):
        return f"{self.order.id}: {self.quantity}x {self.product.name} ({self.pack_size}) @ ₹{self.unit_price}"


class BottleReturn(models.Model):
    """Tracks glass bottle deposits and returns for water cans, milk bottles, etc."""
    class Statuses(models.TextChoices):
        DEPOSITED = "DEPOSITED", "Deposit Collected"
        RETURNED = "RETURNED", "Bottle Returned"
        LOST = "LOST", "Bottle Lost / Not Returned"

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="bottle_returns")
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="bottle_collections")
    hub = models.ForeignKey(LocationHub, on_delete=models.SET_NULL, null=True, blank=True, related_name="bottle_returns")
    product = models.ForeignKey("products.Product", on_delete=models.SET_NULL, null=True, blank=True)
    quantity = models.PositiveIntegerField(default=1)
    deposit_amount = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.DEPOSITED)
    collected_date = models.DateField(auto_now_add=True)
    returned_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Bottle #{self.id}: {self.customer.username} - {self.quantity}x ({self.status})"


class ProviderPayout(models.Model):
    """Tracks hub-level payout settlements for providers/hub managers."""
    class Statuses(models.TextChoices):
        PENDING = "PENDING", "Pending Settlement"
        PROCESSING = "PROCESSING", "Processing"
        COMPLETED = "COMPLETED", "Paid / Settled"
        FAILED = "FAILED", "Failed"

    hub = models.ForeignKey(LocationHub, on_delete=models.CASCADE, related_name="payouts")
    manager = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="payouts")
    period_start = models.DateField()
    period_end = models.DateField()
    total_deliveries = models.PositiveIntegerField(default=0)
    total_revenue = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    cash_collected = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"), help_text="Cash collected in hand at doorstep (COD)")
    prepaid_revenue = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"), help_text="Online / Wallet prepaid revenue")
    driver_salaries = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    platform_commission = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    net_payout = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.PENDING)
    payment_reference = models.CharField(max_length=100, blank=True, default="")
    bank_name = models.CharField(max_length=150, blank=True, default="")
    bank_account_number = models.CharField(max_length=50, blank=True, default="")
    bank_ifsc = models.CharField(max_length=20, blank=True, default="")
    upi_id = models.CharField(max_length=100, blank=True, default="")
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-period_end"]

    def __str__(self):
        return f"Payout #{self.id}: {self.hub.name} ({self.period_start} to {self.period_end}) - ₹{self.net_payout} ({self.status})"


class DailyMilkBatch(models.Model):
    """
    Daily milk batch entered and certified by the Hub Provider/Depot Manager.
    Includes lab test metrics (FAT %, SNF %, Water %) and the dynamic per-litre price.
    """
    class Statuses(models.TextChoices):
        TESTED = "TESTED", "Lab Tested & Verified"
        DISPATCHED = "DISPATCHED", "Dispatched to Drivers"
        COMPLETED = "COMPLETED", "Fully Delivered"

    hub = models.ForeignKey(LocationHub, on_delete=models.CASCADE, related_name="daily_batches", null=True, blank=True)
    batch_code = models.CharField(max_length=50, unique=True)
    product_name = models.CharField(max_length=150, default="Pure Buffalo Milk")
    batch_date = models.DateField(default=date.today)
    fat_percentage = models.DecimalField(max_digits=4, decimal_places=2, default=6.80)
    snf_percentage = models.DecimalField(max_digits=4, decimal_places=2, default=9.00)
    water_percentage = models.DecimalField(max_digits=4, decimal_places=2, default=0.00)
    price_per_litre = models.DecimalField(max_digits=8, decimal_places=2, default=68.00)
    total_litres = models.DecimalField(max_digits=8, decimal_places=2, default=450.00)
    temperature_celsius = models.DecimalField(max_digits=4, decimal_places=1, default=3.8)
    dispatched_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="dispatched_batches")
    status = models.CharField(max_length=20, choices=Statuses.choices, default=Statuses.DISPATCHED)
    quality_certificate_note = models.CharField(max_length=255, blank=True, default="FSSAI Certified • Passed 24 Purity Checks")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-batch_date", "-created_at"]
        indexes = [
            models.Index(fields=["batch_date", "product_name"], name="batch_date_prod_idx"),
        ]

    def __str__(self):
        return f"{self.batch_code} ({self.product_name}) - {self.fat_percentage}% FAT, {self.snf_percentage}% SNF @ ₹{self.price_per_litre}/L"


class DeliveryChatMessage(models.Model):
    """
    Real-time in-app chat message between Driver and Customer for a delivery task or order.
    """
    class SenderRoles(models.TextChoices):
        DRIVER = "DRIVER", "Delivery Driver"
        CUSTOMER = "CUSTOMER", "Customer"
        SYSTEM = "SYSTEM", "System Update"

    channel_key = models.CharField(max_length=100, db_index=True)
    task = models.ForeignKey(DeliveryTask, on_delete=models.SET_NULL, null=True, blank=True, related_name="chat_messages")
    order = models.ForeignKey(LiveOrder, on_delete=models.SET_NULL, null=True, blank=True, related_name="chat_messages")
    sender_role = models.CharField(max_length=20, choices=SenderRoles.choices, default=SenderRoles.DRIVER)
    sender_name = models.CharField(max_length=150, default="")
    sender_phone = models.CharField(max_length=30, blank=True, default="")
    text = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["channel_key", "created_at"], name="deliv_chat_chan_idx"),
        ]

    def __str__(self):
        return f"[{self.channel_key}] {self.sender_role} ({self.sender_name}): {self.text[:30]}"


class DeliveryRating(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="delivery_ratings")
    order = models.ForeignKey(LiveOrder, on_delete=models.SET_NULL, null=True, blank=True, related_name="ratings")
    task = models.ForeignKey(DeliveryTask, on_delete=models.SET_NULL, null=True, blank=True, related_name="ratings")
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="driver_ratings")
    rating = models.PositiveSmallIntegerField(default=5)
    feedback = models.TextField(blank=True, default="")
    tags = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["driver", "-created_at"], name="deliv_rate_driver_idx"),
            models.Index(fields=["order", "-created_at"], name="deliv_rate_order_idx"),
        ]

    def __str__(self):
        return f"Rating {self.rating}★ for {self.driver or self.order or self.task} by {self.user}"


