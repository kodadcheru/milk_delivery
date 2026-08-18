import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
django.setup()

from django.contrib.auth.hashers import make_password
from apps.accounts.models import User, WalletTransaction, Notification
from apps.products.models import Product
from apps.subscriptions.models import Subscription
from apps.deliveries.models import LocationHub, ServiceArea, DeliveryTask
from datetime import date


def seed():
    print("🌱 [Railway DB Seeder] Checking database records...")

    # 1. Admin & Users
    admin, created = User.objects.get_or_create(
        username="admin",
        defaults={
            "password": make_password("admin123"),
            "email": "admin@milkdrop.in",
            "first_name": "Rajesh",
            "last_name": "Varma",
            "role": "ADMIN",
            "phone": "+91 98888 77777",
            "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
            "is_staff": True,
            "is_superuser": True,
            "wallet_balance": 10000.0,
        },
    )
    admin.set_password("admin123")
    admin.is_staff = True
    admin.is_superuser = True
    admin.role = "ADMIN"
    admin.save()
    print("✅ Super Admin verified: admin / admin123")

    hub_mgr, _ = User.objects.get_or_create(
        username="hub_manager",
        defaults={
            "password": make_password("pass123"),
            "email": "hubmanager@milkdrop.in",
            "first_name": "Sanjay",
            "last_name": "Rao",
            "role": "ADMIN",
            "phone": "+91 97654 32100",
            "address": "Madhapur Tech Enclave Depot #3",
            "is_staff": True,
            "wallet_balance": 5000.0,
        },
    )
    hub_mgr.set_password("pass123")
    hub_mgr.is_staff = True
    hub_mgr.save()
    print("✅ Hub Manager verified: hub_manager / pass123")

    driver, _ = User.objects.get_or_create(
        username="driver",
        defaults={
            "password": make_password("pass123"),
            "email": "driver@milkdrop.in",
            "first_name": "Suresh",
            "last_name": "Rao",
            "role": "DRIVER",
            "phone": "+91 9123456789",
            "address": "Jubilee Hills Central Depot #1",
            "wallet_balance": 0.0,
        },
    )
    driver.set_password("pass123")
    driver.save()

    cust, _ = User.objects.get_or_create(
        username="customer",
        defaults={
            "password": make_password("pass123"),
            "email": "customer@milkdrop.in",
            "first_name": "Ramesh",
            "last_name": "Kumar",
            "role": "CUSTOMER",
            "phone": "+91 98765 43210",
            "address": "Flat 402, Road No. 36, Jubilee Hills, Hyderabad",
            "wallet_balance": 1500.0,
        },
    )
    cust.set_password("pass123")
    cust.save()

    # 2. Products
    p1, _ = Product.objects.get_or_create(
        name="A2 Vedic Desi Cow Milk",
        defaults={
            "description": "100% Raw, Unprocessed, Pure Vedic Gir Cow Milk in Glass Bottle",
            "category": "MILK",
            "price_per_unit": 90.00,
            "unit_quantity": "1 Litre Glass Bottle",
            "is_available": True,
            "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80",
        },
    )
    p2, _ = Product.objects.get_or_create(
        name="Buffalo Gold Cream Milk",
        defaults={
            "description": "Rich 8.5% fat traditional farm fresh buffalo milk",
            "category": "MILK",
            "price_per_unit": 85.00,
            "unit_quantity": "1 Litre Pouch",
            "is_available": True,
            "image_url": "https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=500&q=80",
        },
    )

    # 3. Subscriptions & Deliveries
    sub, _ = Subscription.objects.get_or_create(
        customer=cust,
        product=p1,
        defaults={
            "quantity": 2,
            "schedule_type": "DAILY",
            "status": "ACTIVE",
            "start_date": date.today(),
        },
    )

    DeliveryTask.objects.get_or_create(
        subscription=sub,
        delivery_date=date.today(),
        defaults={
            "driver": driver,
            "slot_time": "05:30 AM - 07:00 AM",
            "status": "PENDING",
            "proof_image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80",
        },
    )

    print("🎉 [Railway DB Seeder] Database seeded and verified successfully!")


if __name__ == "__main__":
    seed()
