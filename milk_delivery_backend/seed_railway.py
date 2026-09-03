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
                    CREATE TABLE IF NOT EXISTS deliveries_providerpayout (
                        id BIGSERIAL PRIMARY KEY,
                        period_start DATE NOT NULL DEFAULT CURRENT_DATE,
                        period_end DATE NOT NULL DEFAULT CURRENT_DATE,
                        total_deliveries INTEGER NOT NULL DEFAULT 0,
                        total_revenue NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
                        driver_salaries NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
                        platform_commission NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
                        net_payout NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
                        status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
                        payment_reference VARCHAR(100) NOT NULL DEFAULT '',
                        notes TEXT NOT NULL DEFAULT '',
                        bank_account_number VARCHAR(50) NOT NULL DEFAULT '',
                        bank_ifsc VARCHAR(20) NOT NULL DEFAULT '',
                        bank_name VARCHAR(150) NOT NULL DEFAULT '',
                        cash_collected NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
                        prepaid_revenue NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
                        upi_id VARCHAR(100) NOT NULL DEFAULT '',
                        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                        paid_at TIMESTAMP WITH TIME ZONE,
                        hub_id BIGINT REFERENCES deliveries_locationhub(id) ON DELETE CASCADE,
                        manager_id BIGINT REFERENCES accounts_user(id) ON DELETE SET NULL
                    );
                    CREATE TABLE IF NOT EXISTS deliveries_bottlereturn (
                        id BIGSERIAL PRIMARY KEY,
                        quantity INTEGER NOT NULL DEFAULT 1,
                        deposit_amount NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
                        status VARCHAR(20) NOT NULL DEFAULT 'DEPOSITED',
                        collected_date DATE NOT NULL DEFAULT CURRENT_DATE,
                        returned_date DATE,
                        notes TEXT NOT NULL DEFAULT '',
                        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                        customer_id BIGINT REFERENCES accounts_user(id) ON DELETE CASCADE,
                        driver_id BIGINT REFERENCES accounts_user(id) ON DELETE SET NULL,
                        hub_id BIGINT REFERENCES deliveries_locationhub(id) ON DELETE SET NULL,
                        product_id BIGINT REFERENCES products_product(id) ON DELETE SET NULL
                    );
                    CREATE TABLE IF NOT EXISTS deliveries_deliveryrating (
                        id BIGSERIAL PRIMARY KEY,
                        rating SMALLINT NOT NULL DEFAULT 5,
                        feedback TEXT NOT NULL DEFAULT '',
                        tags JSONB DEFAULT '[]'::jsonb,
                        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                        driver_id BIGINT REFERENCES accounts_user(id) ON DELETE SET NULL,
                        order_id VARCHAR(50) REFERENCES deliveries_liveorder(id) ON DELETE SET NULL,
                        task_id BIGINT REFERENCES deliveries_deliverytask(id) ON DELETE SET NULL,
                        user_id BIGINT REFERENCES accounts_user(id) ON DELETE SET NULL
                    );
                    CREATE INDEX IF NOT EXISTS deliv_rate_driver_idx ON deliveries_deliveryrating(driver_id, created_at DESC);
                    CREATE INDEX IF NOT EXISTS deliv_rate_order_idx ON deliveries_deliveryrating(order_id, created_at DESC);

                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS is_cod BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS cash_collected BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS cash_amount NUMERIC(10, 2) DEFAULT 0.00;
                    ALTER TABLE deliveries_deliverytask ADD COLUMN IF NOT EXISTS payout_id BIGINT;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS is_cod BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS cash_collected BOOLEAN DEFAULT FALSE;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS cash_amount NUMERIC(10, 2) DEFAULT 0.00;
                    ALTER TABLE deliveries_liveorder ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) DEFAULT 'WALLET';
                    ALTER TABLE deliveries_providerpayout ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50) DEFAULT '';
                    ALTER TABLE deliveries_providerpayout ADD COLUMN IF NOT EXISTS bank_ifsc VARCHAR(20) DEFAULT '';
                    ALTER TABLE deliveries_providerpayout ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150) DEFAULT '';
                    ALTER TABLE deliveries_providerpayout ADD COLUMN IF NOT EXISTS cash_collected NUMERIC(12, 2) DEFAULT 0.00;
                    ALTER TABLE deliveries_providerpayout ADD COLUMN IF NOT EXISTS prepaid_revenue NUMERIC(12, 2) DEFAULT 0.00;
                    ALTER TABLE deliveries_providerpayout ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100) DEFAULT '';
                    ALTER TABLE deliveries_locationhub ADD COLUMN IF NOT EXISTS bank_account_holder VARCHAR(150) DEFAULT '';
                    ALTER TABLE deliveries_locationhub ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50) DEFAULT '';
                    ALTER TABLE deliveries_locationhub ADD COLUMN IF NOT EXISTS bank_ifsc VARCHAR(20) DEFAULT '';
                    ALTER TABLE deliveries_locationhub ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150) DEFAULT '';
                    ALTER TABLE deliveries_locationhub ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100) DEFAULT '';
                """)
            elif vendor == 'sqlite':
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS deliveries_deliveryrating (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        rating INTEGER NOT NULL DEFAULT 5,
                        feedback TEXT NOT NULL DEFAULT '',
                        tags TEXT DEFAULT '[]',
                        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        driver_id INTEGER REFERENCES accounts_user(id) ON DELETE SET NULL,
                        order_id VARCHAR(50) REFERENCES deliveries_liveorder(id) ON DELETE SET NULL,
                        task_id INTEGER REFERENCES deliveries_deliverytask(id) ON DELETE SET NULL,
                        user_id INTEGER REFERENCES accounts_user(id) ON DELETE SET NULL
                    );
                """)
                columns = [c.name for c in connection.introspection.get_table_description(cursor, 'deliveries_deliverytask')]
                if 'is_cod' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN is_cod BOOLEAN DEFAULT FALSE;")
                if 'cash_collected' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN cash_collected BOOLEAN DEFAULT FALSE;")
                if 'cash_amount' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN cash_amount NUMERIC(10, 2) DEFAULT 0.00;")
                if 'payout_id' not in columns:
                    cursor.execute("ALTER TABLE deliveries_deliverytask ADD COLUMN payout_id BIGINT;")
                order_cols = [c.name for c in connection.introspection.get_table_description(cursor, 'deliveries_liveorder')]
                if 'is_cod' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN is_cod BOOLEAN DEFAULT FALSE;")
                if 'cash_collected' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN cash_collected BOOLEAN DEFAULT FALSE;")
                if 'cash_amount' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN cash_amount NUMERIC(10, 2) DEFAULT 0.00;")
                if 'payment_method' not in order_cols:
                    cursor.execute("ALTER TABLE deliveries_liveorder ADD COLUMN payment_method VARCHAR(20) DEFAULT 'WALLET';")
            print("✅ [Railway DB Initializer] Database tables and columns verified.")
        except Exception as e:
            print("Schema auto-heal notice:", e)

    try:
        from django.core.management import call_command
        call_command('migrate', interactive=False)
        print("✅ [Railway DB Initializer] Migrations caught up successfully.")
    except Exception as mig_err:
        print("⚠️ [Railway DB Initializer] Migration catch-up notice:", mig_err)


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

    # 3. Ensure Hub Coverage & Service Areas
    try:
        from apps.deliveries.models import LocationHub, ServiceArea
        from apps.products.models import Product, HubProductInventory
        from django.db.models import Q

        # Update Mella Chervu Depot radius to 15.0 km
        mlc_hub = LocationHub.objects.filter(Q(hub_code="HUB-MLC-01") | Q(name__icontains="Mella Chervu")).first()
        if mlc_hub:
            mlc_hub.coverage_radius_km = 15.0
            mlc_hub.latitude = 16.817715
            mlc_hub.longitude = 79.933978
            mlc_hub.save()
            print("📍 [Railway DB Initializer] Mella Chervu Depot coverage radius expanded to 15.0 km.")

        kdd_hub = LocationHub.objects.filter(Q(hub_code="HUB-KDD-01") | Q(name__icontains="Kodad")).first()
        if kdd_hub and kdd_hub.coverage_radius_km < 15.0:
            kdd_hub.coverage_radius_km = 15.0
            kdd_hub.save()

        # Seed Service Areas
        if mlc_hub:
            ServiceArea.objects.get_or_create(
                name="Mellacheruvu",
                defaults={
                    "pincodes": "508246",
                    "hub": mlc_hub,
                    "radius_km": 15.0,
                    "status": ServiceArea.Statuses.ACTIVE,
                    "popular_societies": "Mellacheruvu Town, Main Road, Temple Road",
                },
            )

        if kdd_hub:
            ServiceArea.objects.get_or_create(
                name="Kodad",
                defaults={
                    "pincodes": "508206",
                    "hub": kdd_hub,
                    "radius_km": 15.0,
                    "status": ServiceArea.Statuses.ACTIVE,
                    "popular_societies": "RTC Bus Depot Colony, Main Road, Gandhi Nagar",
                },
            )

        # Ensure Hub Inventory for all active hubs
        all_products = list(Product.objects.all())
        for hub in LocationHub.objects.all():
            for p in all_products:
                HubProductInventory.objects.get_or_create(
                    hub=hub,
                    product=p,
                    defaults={
                        "daily_capacity_slots": 100,
                        "booked_slots": 0,
                        "is_available": True,
                    },
                )
        print("🛒 [Railway DB Initializer] Hub product inventories ensured across all hubs.")
    except Exception as e:
        print("Hub and inventory initialization notice:", e)

    print("✅ [Railway DB Initializer] Ready with dynamic backend architecture.")


if __name__ == "__main__":
    seed()
