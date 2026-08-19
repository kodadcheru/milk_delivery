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


def safe_upsert_user(uname, defaults):
    user = User.objects.filter(username=uname).first()
    if not user:
        ph = defaults.get("phone")
        if ph:
            user = User.objects.filter(phone=ph).first()

    if not user:
        user = User.objects.create(username=uname, **defaults)
    else:
        for k, v in defaults.items():
            setattr(user, k, v)
        user.save()
    return user


def seed():
    print("🌱 [Railway DB Seeder] Checking database records...")

    # 1. Ensure Hubs exist
    hub1, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-HYD-01",
        defaults={
            "name": "Jubilee Hills Central Depot #1",
            "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
            "latitude": 17.4320,
            "longitude": 78.4070,
            "manager_name": "Rajesh Varma",
            "manager_phone": "+91 98888 77777",
            "fssai_license": "13621014000342",
        }
    )

    hub2, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-HYD-02",
        defaults={
            "name": "Banjara Hills Micro-Depot #2",
            "address": "Road #12, Banjara Hills, Hyderabad",
            "latitude": 17.4156,
            "longitude": 78.4350,
            "manager_name": "Kavitha Reddy",
            "manager_phone": "+91 98765 43211",
            "fssai_license": "13621014000889",
        }
    )

    hub3, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-HYD-03",
        defaults={
            "name": "Madhapur Tech Enclave Depot #3",
            "address": "Hitec City Main Road, Madhapur, Hyderabad",
            "latitude": 17.4483,
            "longitude": 78.3915,
            "manager_name": "Sanjay Rao",
            "manager_phone": "+91 97654 32100",
            "fssai_license": "13621014000912",
        }
    )

    # 2. Admin & Staff Users
    admin = safe_upsert_user("admin", {
        "password": make_password("admin123"),
        "email": "admin@milkdrop.in",
        "first_name": "Rajesh",
        "last_name": "Varma",
        "role": User.Roles.ADMIN,
        "phone": "+91 98888 77777",
        "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
        "assigned_hub": hub1,
        "is_staff": True,
        "is_superuser": True,
        "wallet_balance": 10000.0,
    })
    print("✅ Super Admin verified: admin / admin123")

    hub_mgr = safe_upsert_user("hub_manager", {
        "password": make_password("pass123"),
        "email": "hubmanager@milkdrop.in",
        "first_name": "Sanjay",
        "last_name": "Rao",
        "role": User.Roles.ADMIN,
        "phone": "+91 97654 32100",
        "address": "Madhapur Tech Enclave Depot #3",
        "assigned_hub": hub3,
        "is_staff": True,
        "wallet_balance": 5000.0,
    })
    print("✅ Hub Manager verified: hub_manager / pass123")

    # 3. Delivery Boys Assigned to Specific Hubs
    hub_drivers = [
        ("driver", "Suresh", "Rao", "+91 9123456789", hub1),
        ("suresh_driver", "Suresh", "Rao", "+91 9123456788", hub1),
        ("vikram_driver", "Vikram", "Sharma", "+91 9876501234", hub1),
        ("raju_driver", "Raju", "Patel", "+91 9654321098", hub2),
        ("anil_driver", "Anil", "Kumar", "+91 9765432109", hub3),
    ]

    for uname, fn, ln, ph, hub in hub_drivers:
        safe_upsert_user(uname, {
            "password": make_password("pass123"),
            "email": f"{uname}@milkdrop.in",
            "first_name": fn,
            "last_name": ln,
            "role": User.Roles.DELIVERY_PARTNER,
            "phone": ph,
            "address": hub.address,
            "assigned_hub": hub,
            "monthly_salary": 15000.0,
            "driver_status": "ACTIVE",
            "wallet_balance": 0.0,
        })
    print(f"✅ {len(hub_drivers)} Delivery Boys assigned to Hubs (#1, #2, #3)")

    # 4. Customer
    cust = safe_upsert_user("customer", {
        "password": make_password("pass123"),
        "email": "customer@milkdrop.in",
        "first_name": "Ramesh",
        "last_name": "Kumar",
        "role": User.Roles.CUSTOMER,
        "phone": "+91 98765 43210",
        "address": "",
        "assigned_hub": hub1,
        "wallet_balance": 500.0,
    })

    # 5. Categories & Products
    from apps.products.models import Category

    cat_milk, _ = Category.objects.get_or_create(
        slug="milk",
        defaults={"name": "Milk & Dairy", "icon": "🥛", "display_order": 1, "description": "Farm Fresh A2, Buffalo, and Whole Cow Milk"}
    )
    cat_meat, _ = Category.objects.get_or_create(
        slug="meat",
        defaults={"name": "Meat & Poultry", "icon": "🥩", "display_order": 2, "description": "Fresh Country Chicken & Mutton cuts"}
    )
    cat_eggs, _ = Category.objects.get_or_create(
        slug="eggs",
        defaults={"name": "Country Eggs", "icon": "🥚", "display_order": 3, "description": "Organic Free-Range Brown & White Eggs"}
    )
    cat_water, _ = Category.objects.get_or_create(
        slug="water-can",
        defaults={"name": "Water Cans", "icon": "💧", "display_order": 4, "description": "20L RO Purified Mineral Water Can Drops"}
    )

    p1, _ = Product.objects.get_or_create(
        name="A2 Vedic Desi Cow Milk",
        defaults={
            "description": "100% Raw, Unprocessed, Pure Vedic Gir Cow Milk in Glass Bottle",
            "category": "Milk & Dairy",
            "category_ref": cat_milk,
            "price_per_unit": 90.00,
            "unit_quantity": "1 Litre Glass Bottle",
            "is_available": True,
            "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80",
        },
    )
    if not p1.category_ref:
        p1.category_ref = cat_milk
        p1.save()

    p2, _ = Product.objects.get_or_create(
        name="Organic Country Eggs (Pack of 6)",
        defaults={
            "description": "Antibiotic-free Free-Range Country Eggs",
            "category": "Country Eggs",
            "category_ref": cat_eggs,
            "price_per_unit": 75.00,
            "unit_quantity": "6 Eggs Pack",
            "is_available": True,
            "image_url": "https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=500&q=80",
        },
    )

    p3, _ = Product.objects.get_or_create(
        name="Bisleri 20L Mineral Water Can",
        defaults={
            "description": "Purified 20 Litre Mineral Drinking Water Can Doorstep Drop",
            "category": "Water Cans",
            "category_ref": cat_water,
            "price_per_unit": 90.00,
            "unit_quantity": "20L Can",
            "is_available": True,
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=500&q=80",
        },
    )

    # 6. Purge any stale dummy customer subscriptions and pending mock tasks
    from apps.subscriptions.models import Subscription
    from apps.deliveries.models import DeliveryTask
    deleted_subs = Subscription.objects.all().delete()
    deleted_tasks = DeliveryTask.objects.filter(subscription__isnull=True).delete()
    print(f"🧹 Cleaned {deleted_subs} old subscriptions for pristine customer experience.")

    print("🎉 [Railway DB Seeder] All Categories, Hubs, and Drivers verified successfully with clean customer slate!")


if __name__ == "__main__":
    seed()
