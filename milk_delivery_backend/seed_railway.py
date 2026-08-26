import os
import django

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.accounts.models import User
from apps.products.models import StorefrontConfig


def seed():
    print("🌱 [Railway DB Initializer] Ensuring Super Admin account exists...")

    # 1. Permanent Super Admin (zero hardcoded categories, products, or hubs)
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
            "city": "Kodad",
            "address": "Operations Command Center",
            "latitude": 17.001734,
            "longitude": 79.962500,
        },
    )
    if not created:
        admin.role = User.Roles.ADMIN
        admin.is_staff = True
        admin.is_superuser = True

    admin.set_password("admin123")
    admin.save()
    print("🛡️ [Super Admin Initialized]: admin / admin123 (Phone: +91 8919548905)")

    # 2. Storefront Banner Config Default (if not present)
    StorefrontConfig.objects.get_or_create(
        id=1,
        defaults={
            "banner_image_url": "https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80",
            "headline": "Order by 11PM Tonight →",
            "subtitle": "❄️ 4°C Cold Chain • Farm to Doorstep",
            "dispatch_tag": "MORNING DROP 05:30 AM ☀️",
            "promo_chip": "🥛 FRESH TODAY",
            "cta_text": "SUBSCRIBE NOW ➔",
            "is_active": True,
        }
    )

    # NOTE: ZERO categories, products, or subscriptions are seeded.
    # All categories and products are managed dynamically via Admin Web Console.
    print("✅ [Railway DB Initializer] Ready with 0 auto-seeded categories or products.")


if __name__ == "__main__":
    seed()
