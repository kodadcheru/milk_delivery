import os
import django

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.accounts.models import User


def auto_heal_schema():
    print("🛠️ [Railway DB Initializer] Ensuring schema consistency...")
    from django.db import connection
    vendor = connection.vendor
    with connection.cursor() as cursor:
        try:
            if vendor == 'postgresql':
                cursor.execute("""
                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS is_cod BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS cash_collected BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS cash_amount NUMERIC(10, 2) DEFAULT 0.00;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS is_cod BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS cash_collected BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS cash_amount NUMERIC(10, 2) DEFAULT 0.00;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) DEFAULT 'WALLET';
                """)
            elif vendor == 'sqlite':
                columns = [c.name for c in connection.introspection.get_table_description(cursor, 'deliveries_deliverytask')]
                if 'is_cod' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN is_cod BOOLEAN DEFAULT FALSE;")
                if 'cash_collected' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN cash_collected BOOLEAN DEFAULT FALSE;")
                if 'cash_amount' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN cash_amount NUMERIC(10, 2) DEFAULT 0.00;")
                order_cols = [c.name for c in connection.introspection.get_table_description(cursor, 'deliveries_liveorder')]
                if 'is_cod' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN is_cod BOOLEAN DEFAULT FALSE;")
                if 'cash_collected' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN cash_collected BOOLEAN DEFAULT FALSE;")
                if 'cash_amount' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN cash_amount NUMERIC(10, 2) DEFAULT 0.00;")
                if 'payment_method' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN payment_method VARCHAR(20) DEFAULT 'WALLET';")
            print("✅ [Railway DB Initializer] Database columns verified.")
        except Exception as e:
            print("Schema auto-heal notice:", e)


def seed():
    auto_heal_schema()
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

    # 2. Ensure initial active categories exist if empty
    try:
        from apps.products.models import Category
        if Category.objects.count() == 0:
            default_categories = [
                {"name": "Fresh Milk", "slug": "milk", "icon": "🥛", "subtitle": "Pure 4°C Raw Cow & Buffalo Milk", "quality_badge_title": "100% Antibiotic & Preservative-Free", "display_order": 1},
                {"name": "Country Eggs", "slug": "eggs", "icon": "🥚", "subtitle": "Free-Range Organic Desi Eggs", "quality_badge_title": "Direct from Native Farms", "display_order": 2},
                {"name": "Tender Meat", "slug": "meat", "icon": "🥩", "subtitle": "Fresh Cut Certified Hygienic", "quality_badge_title": "FSSAI Inspected • Zero Frozen", "display_order": 3},
                {"name": "Water Cans", "slug": "water_can", "icon": "💧", "subtitle": "20L RO UV Purified Mineral Cans", "quality_badge_title": "Daily Sanitized Food-Grade Cans", "display_order": 4},
                {"name": "Fresh Paneer", "slug": "paneer", "icon": "🧀", "subtitle": "Soft Malai Paneer Made Daily", "quality_badge_title": "100% Pure Buffalo Milk", "display_order": 5},
                {"name": "Desi Ghee", "slug": "ghee", "icon": "🧈", "subtitle": "Bilona Churned Golden Ghee", "quality_badge_title": "A2 Traditional Vedic Churning", "display_order": 6},
                {"name": "Fresh Curd", "slug": "curd", "icon": "🥣", "subtitle": "Thick Traditional Clay-Pot Dahi", "quality_badge_title": "Active Live Cultures", "display_order": 7},
                {"name": "Bakery & Breads", "slug": "bakery", "icon": "🍞", "subtitle": "Fresh Sourdough & Brown Breads", "quality_badge_title": "Zero Palm Oil • Artisanal", "display_order": 8},
            ]
            for cat_data in default_categories:
                Category.objects.create(**cat_data)
            print(f"📦 [Railway DB Initializer] Seeded {len(default_categories)} default core categories.")
    except Exception as e:
        print("Category seeding notice:", e)

    print("✅ [Railway DB Initializer] Ready with dynamic backend architecture.")


if __name__ == "__main__":
    seed()
