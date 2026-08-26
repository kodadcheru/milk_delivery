import os
import django

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.accounts.models import User


def seed():
    print("🌱 [Railway DB Initializer] Ensuring Super Admin account exists...")

    # 1. Permanent Super Admin Account (zero hardcoded categories, products, hubs, or banners)
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

    # NOTE: ZERO categories, products, hubs, or storefront banners are seeded automatically.
    # Everything is managed dynamically from the PostgreSQL backend via the Admin Web Console.
    print("✅ [Railway DB Initializer] Ready with 100% dynamic backend architecture.")


if __name__ == "__main__":
    seed()
