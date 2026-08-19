import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
django.setup()

from django.contrib.auth.hashers import make_password
from apps.accounts.models import User, WalletTransaction, Notification
from apps.products.models import Product, Category
from apps.subscriptions.models import Subscription
from apps.deliveries.models import LocationHub, ServiceArea, DeliveryTask
from datetime import date
from decimal import Decimal


def seed():
    print("🌱 [Railway DB Seeder] Initializing database & permanent Super Admin...")

    # 1. Configure the Permanent Super Admin (Protected across all Railway deployments)
    admin = User.objects.filter(username="admin").first()
    if not admin:
        admin = User.objects.filter(phone__endswith="8919548905").first()

    if not admin:
        admin = User.objects.create(
            username="admin",
            phone="+91 8919548905",
            email="admin@milkdrop.in",
            first_name="Operations",
            last_name="Administrator",
            role=User.Roles.ADMIN,
            is_staff=True,
            is_superuser=True,
            wallet_balance=Decimal("10000.00"),
        )
    else:
        admin.username = "admin"
        admin.phone = "+91 8919548905"
        admin.email = "admin@milkdrop.in"
        admin.first_name = "Operations"
        admin.last_name = "Administrator"
        admin.role = User.Roles.ADMIN
        admin.is_staff = True
        admin.is_superuser = True

    admin.set_password("admin123")
    admin.save()

    print("🛡️ [Permanent Super Admin Verified]:")
    print("   • Username: admin / admin123")
    print("   • Phone OTP: +91 8919548905 (OTP: 1234)")
    print("   • Role: ADMIN (is_staff=True, is_superuser=True)")

    # 2. Standard Categories (Storefront Structure)
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

    # 3. Core Products
    p1, _ = Product.objects.get_or_create(
        name="A2 Vedic Desi Cow Milk",
        defaults={
            "description": "100% Raw, Unprocessed, Pure Vedic Gir Cow Milk in Glass Bottle",
            "category": "Milk & Dairy",
            "category_ref": cat_milk,
            "price_per_unit": Decimal("90.00"),
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
            "price_per_unit": Decimal("75.00"),
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
            "price_per_unit": Decimal("90.00"),
            "unit_quantity": "20L Can",
            "is_available": True,
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=500&q=80",
        },
    )

    print("🎉 [Railway DB Seeder] Database safe & persistent! All registered users, subscriptions & tasks preserved across deployments.")


if __name__ == "__main__":
    seed()
