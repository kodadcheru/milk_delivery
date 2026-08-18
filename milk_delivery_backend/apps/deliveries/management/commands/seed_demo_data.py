from datetime import date
from decimal import Decimal
from django.core.management.base import BaseCommand

from apps.accounts.models import User, WalletTransaction
from apps.deliveries.models import DeliveryTask
from apps.products.models import Product
from apps.subscriptions.models import Subscription


class Command(BaseCommand):
    help = "Seed database with demo users, products, subscriptions, and delivery tasks."

    def handle(self, *args, **options):
        self.stdout.write("Seeding demo data...")

        # 1. Create Users
        customer, _ = User.objects.get_or_create(
            username="customer",
            defaults={
                "first_name": "Ramesh",
                "last_name": "Kumar",
                "email": "ramesh@example.com",
                "role": User.Roles.CUSTOMER,
                "phone": "+91 9876543210",
                "address": "Flat 402, Green Acres, Jubilee Hills",
                "city": "Hyderabad",
                "wallet_balance": Decimal("650.00"),
                "delivery_instructions": "Ring bell twice and leave near doorstep box",
            },
        )
        if not customer.check_password("pass123"):
            customer.set_password("pass123")
            customer.save()

        driver, _ = User.objects.get_or_create(
            username="driver",
            defaults={
                "first_name": "Suresh",
                "last_name": "Rao",
                "email": "driver@milkdrop.com",
                "role": User.Roles.DELIVERY_PARTNER,
                "phone": "+91 9123456789",
                "address": "Route 4 - Jubilee Hills Hub",
                "city": "Hyderabad",
                "wallet_balance": Decimal("0.00"),
            },
        )
        if not driver.check_password("pass123"):
            driver.set_password("pass123")
            driver.save()

        admin, _ = User.objects.get_or_create(
            username="admin",
            defaults={
                "first_name": "Anita",
                "last_name": "Sharma",
                "email": "admin@milkdrop.com",
                "role": User.Roles.ADMIN,
                "phone": "+91 9000000000",
                "is_staff": True,
                "is_superuser": True,
                "city": "Hyderabad",
            },
        )
        if not admin.check_password("admin123"):
            admin.set_password("admin123")
            admin.save()

        # 2. Create Products
        products_data = [
            {
                "name": "Farm Fresh A2 Cow Milk",
                "description": "Pure, unprocessed, pasteurized A2 Desi Cow Milk delivered within 4 hours of milking.",
                "price_per_unit": Decimal("72.00"),
                "unit": Product.Units.PACKET,
                "unit_quantity": "1 Liter Pouch",
                "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80",
            },
            {
                "name": "Pure Buffalo Milk (High Fat)",
                "description": "Rich 7.5% fat creamy buffalo milk ideal for tea, coffee, and homemade curd.",
                "price_per_unit": Decimal("78.00"),
                "unit": Product.Units.PACKET,
                "unit_quantity": "1 Liter Pouch",
                "image_url": "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500&q=80",
            },
            {
                "name": "Farm Fresh Set Curd (Dahi)",
                "description": "Thick, creamy natural curd made with organic milk in eco-friendly tub.",
                "price_per_unit": Decimal("45.00"),
                "unit": Product.Units.PACKET,
                "unit_quantity": "500 g Tub",
                "image_url": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=500&q=80",
            },
            {
                "name": "Traditional Bilona Desi Ghee",
                "description": "Hand-churned wooden bilona method pure cow ghee with golden texture & aroma.",
                "price_per_unit": Decimal("650.00"),
                "unit": Product.Units.MILLILITER,
                "unit_quantity": "500 mL Glass Jar",
                "image_url": "https://images.unsplash.com/photo-1589927986076-2d50a22301c2?w=500&q=80",
            },
        ]

        created_products = []
        for pdata in products_data:
            p, _ = Product.objects.get_or_create(name=pdata["name"], defaults=pdata)
            created_products.append(p)

        # 3. Create Subscriptions
        sub1, _ = Subscription.objects.get_or_create(
            customer=customer,
            product=created_products[0],
            defaults={
                "quantity": 1,
                "schedule_type": Subscription.Schedules.DAILY,
                "start_date": date.today(),
                "status": Subscription.Statuses.ACTIVE,
            },
        )

        sub2, _ = Subscription.objects.get_or_create(
            customer=customer,
            product=created_products[2],
            defaults={
                "quantity": 2,
                "schedule_type": Subscription.Schedules.ALTERNATE,
                "start_date": date.today(),
                "status": Subscription.Statuses.ACTIVE,
            },
        )

        # 4. Wallet Transactions
        WalletTransaction.objects.get_or_create(
            user=customer,
            amount=Decimal("1000.00"),
            transaction_type=WalletTransaction.Types.CREDIT,
            description="Welcome Bonus & UPI Top-Up",
        )

        WalletTransaction.objects.get_or_create(
            user=customer,
            amount=Decimal("350.00"),
            transaction_type=WalletTransaction.Types.DEBIT,
            description="Previous Week Milk Deliveries Settlement",
        )

        # 5. Create Today's Delivery Tasks
        today = date.today()
        task1, _ = DeliveryTask.objects.get_or_create(
            subscription=sub1,
            delivery_date=today,
            defaults={
                "driver": driver,
                "slot_time": "05:30 AM - 07:00 AM",
                "status": DeliveryTask.Statuses.PENDING,
            },
        )

        task2, _ = DeliveryTask.objects.get_or_create(
            subscription=sub2,
            delivery_date=today,
            defaults={
                "driver": driver,
                "slot_time": "05:30 AM - 07:00 AM",
                "status": DeliveryTask.Statuses.PENDING,
            },
        )

        self.stdout.write(
            self.style.SUCCESS(
                f"Successfully seeded database! Demo users created:\n"
                f" - Customer: customer / pass123\n"
                f" - Driver: driver / pass123\n"
                f" - Admin: admin / admin123"
            )
        )
