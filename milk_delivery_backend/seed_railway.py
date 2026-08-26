import os
import django

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.accounts.models import User
from apps.deliveries.models import LocationHub
from apps.products.models import StorefrontConfig


def seed():
    print("🌱 [Railway DB Initializer] Ensuring Super Admin and Operations Hub exist...")

    # 1. Permanent Super Admin & Operations Hub
    hub_kodad, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-KDD-01",
        defaults={
            "name": "Kodad Depot",
            "address": "2X27+M36, Kodad, Telangana 508206, India",
            "latitude": 17.001734,
            "longitude": 79.962500,
            "manager_name": "srinuvasa reddy",
            "manager_phone": "8885199878",
            "coverage_radius_km": 8.5,
            "bank_name": "State Bank of India",
            "bank_account_number": "389201948210",
            "bank_ifsc": "SBIN0004892",
            "bank_account_holder": "Srinuvasa Reddy",
            "upi_id": "8885199878@upi",
        }
    )

    admin, created = User.objects.get_or_create(
        username="admin",
        defaults={
            "phone": "+91 8919548905",
            "email": "admin@milkdrop.in",
            "first_name": "Operations",
            "last_name": "Administrator",
            "role": User.Roles.ADMIN,
            "is_staff": True,
            "is_superuser": True,
            "assigned_hub": hub_kodad,
            "city": "Kodad",
            "address": "2X27+M36, Kodad, Telangana 508206, India",
            "latitude": 17.001734,
            "longitude": 79.962500,
        },
    )
    if not created:
        admin.role = User.Roles.ADMIN
        admin.is_staff = True
        admin.is_superuser = True
        if not admin.assigned_hub:
            admin.assigned_hub = hub_kodad

    admin.set_password("admin123")
    admin.save()

    print("🛡️ [Super Admin Initialized]: admin / admin123")

    # 2. Storefront Banner Config Default (if not present)
    StorefrontConfig.objects.get_or_create(
        id=1,
        defaults={
            "banner_image_url": "https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80",
            "headline": "Order by 11PM Tonight →",
            "subtitle": "❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub",
            "dispatch_tag": "MORNING DROP 05:30 AM ☀️",
            "promo_chip": "🥛 FRESH TODAY",
            "cta_text": "SUBSCRIBE NOW ➔",
            "is_active": True,
        }
    )

    # NOTE: ZERO categories, products, or subscriptions are seeded automatically.
    # All categories and products are managed dynamically via Admin Web Console.
    print("✅ [Railway DB Initializer] Initial setup completed with 0 automatic products/categories seeded.")


if __name__ == "__main__":
    seed()
