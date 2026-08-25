import os
import django
from decimal import Decimal

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.accounts.models import User
from apps.products.models import Category, Product, StorefrontConfig
from apps.deliveries.models import LocationHub


def seed():
    print("🌱 [Railway DB Seeder] Initializing database & permanent Super Admin...")

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
        admin.phone = "+91 8919548905"
        admin.email = "admin@milkdrop.in"
        admin.first_name = "Operations"
        admin.last_name = "Administrator"
        admin.role = User.Roles.ADMIN
        admin.is_staff = True
        admin.is_superuser = True
        if not admin.assigned_hub:
            admin.assigned_hub = hub_kodad

    admin.set_password("admin123")
    admin.save()

    print("🛡️ [Permanent Super Admin Verified]: admin / admin123")

    # 2. Storefront Top Banner Config
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

    # 3. Real-World Categories
    categories_data = [
        {
            "slug": "milk",
            "name": "Milk & Farm Dairy",
            "icon": "🥛",
            "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80",
            "display_order": 1,
            "description": "Farm Fresh A2, Buffalo, and Pasteurized Whole Cow Milk in glass bottles and pouches",
        },
        {
            "slug": "curd",
            "name": "Curd & Yogurt",
            "icon": "🥣",
            "image_url": "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=600&q=80",
            "display_order": 2,
            "description": "Thick, probiotic-rich natural set dahi made from pure farm milk",
        },
        {
            "slug": "ghee",
            "name": "Pure Ghee & Butter",
            "icon": "🧈",
            "image_url": "https://images.unsplash.com/photo-1589927986076-2d50a22301c2?auto=format&fit=crop&w=600&q=80",
            "display_order": 3,
            "description": "Aromatic Vedic Bilona Cow Ghee and fresh churned country white butter",
        },
        {
            "slug": "paneer",
            "name": "Farm Fresh Paneer",
            "icon": "🧀",
            "image_url": "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80",
            "display_order": 4,
            "description": "Super soft, melt-in-mouth malai paneer crafted daily",
        },
        {
            "slug": "eggs",
            "name": "Country & Organic Eggs",
            "icon": "🥚",
            "image_url": "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=600&q=80",
            "display_order": 5,
            "description": "Antibiotic-free Free-Range Country Brown & White Farm Eggs",
        },
        {
            "slug": "water-can",
            "name": "Mineral Water Cans",
            "icon": "💧",
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=600&q=80",
            "display_order": 6,
            "description": "20L RO Purified & UV Treated Mineral Drinking Water Can Doorstep Delivery",
        },
        {
            "slug": "bakery",
            "name": "Artisanal Breads",
            "icon": "🍞",
            "image_url": "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80",
            "display_order": 7,
            "description": "Freshly baked morning sourdough and multi-grain artisan bread loaves",
        },
        {
            "slug": "meat",
            "name": "Meat & Poultry",
            "icon": "🥩",
            "image_url": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=600&q=80",
            "display_order": 8,
            "description": "Hygienically dressed fresh country chicken and tender cuts",
        },
    ]

    cat_map = {}
    for cdata in categories_data:
        cat, _ = Category.objects.get_or_create(slug=cdata["slug"], defaults=cdata)
        cat.name = cdata["name"]
        cat.icon = cdata["icon"]
        cat.image_url = cdata["image_url"]
        cat.display_order = cdata["display_order"]
        cat.description = cdata["description"]
        cat.save()
        cat_map[cdata["slug"]] = cat

    # 4. Real-World Curated Products
    products_data = [
        {
            "name": "A2 Vedic Desi Cow Milk",
            "category": "Milk & Farm Dairy",
            "category_ref": cat_map["milk"],
            "description": "100% Raw, Unprocessed, Pure Vedic Gir Cow Milk in Glass Bottle. Rich in A2 beta-casein.",
            "price_per_unit": Decimal("88.00"),
            "unit": Product.Units.LITER,
            "unit_quantity": "1 Litre Glass Bottle",
            "badge_text": "Bestseller",
            "farm_origin": "Kodad Heritage Gaushala",
            "nutrition_info": "A2 Protein • 4.2% Fat • Pure Unadulterated",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Pure Buffalo Whole Milk (High Fat)",
            "category": "Milk & Farm Dairy",
            "category_ref": cat_map["milk"],
            "description": "Rich 7.5% fat creamy buffalo milk ideal for tea, rich coffee, and thick homemade curd.",
            "price_per_unit": Decimal("78.00"),
            "unit": Product.Units.PACKET,
            "unit_quantity": "1 Liter Pouch",
            "badge_text": "High Fat",
            "farm_origin": "Nalgonda Dairy Farms",
            "nutrition_info": "7.5% Fat • 9.0% SNF • High Calcium",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Pasteurized Toned Cow Milk",
            "category": "Milk & Farm Dairy",
            "category_ref": cat_map["milk"],
            "description": "Daily light and nutritious toned milk homogenized for wholesome family digestion.",
            "price_per_unit": Decimal("38.00"),
            "unit": Product.Units.PACKET,
            "unit_quantity": "500 mL Pouch",
            "badge_text": "Daily Essential",
            "farm_origin": "Kodad Dairy Co-op",
            "nutrition_info": "3.0% Fat • 8.5% SNF • Vitamin Enriched",
            "rating": Decimal("4.7"),
            "image_url": "https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Natural Set Farm Curd (Dahi)",
            "category": "Curd & Yogurt",
            "category_ref": cat_map["curd"],
            "description": "Thick, creamy natural curd made with organic milk in an eco-friendly clay matka tub.",
            "price_per_unit": Decimal("45.00"),
            "unit": Product.Units.PACKET,
            "unit_quantity": "500 g Tub",
            "badge_text": "Probiotic",
            "farm_origin": "Kodad Organic Hub",
            "nutrition_info": "Live Probiotics • Zero Preservatives • Thick Texture",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Traditional Bilona Desi Cow Ghee",
            "category": "Pure Ghee & Butter",
            "category_ref": cat_map["ghee"],
            "description": "Hand-churned wooden bilona method pure cow ghee with golden granular texture & authentic aroma.",
            "price_per_unit": Decimal("650.00"),
            "unit": Product.Units.MILLILITER,
            "unit_quantity": "500 mL Glass Jar",
            "badge_text": "A2 Vedic Ghee",
            "farm_origin": "Kodad Gaushala Heritage",
            "nutrition_info": "100% Pure Grass-Fed • Rich Butyric Acid • Granular",
            "rating": Decimal("5.0"),
            "image_url": "https://images.unsplash.com/photo-1589927986076-2d50a22301c2?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Fresh Malai Soft Paneer",
            "category": "Farm Fresh Paneer",
            "category_ref": cat_map["paneer"],
            "description": "Artisanal, non-rubbery, ultra-soft paneer crafted from fresh morning whole milk.",
            "price_per_unit": Decimal("95.00"),
            "unit": Product.Units.GRAM,
            "unit_quantity": "200 g Vacuum Pack",
            "badge_text": "Farm Fresh",
            "farm_origin": "Kodad Processing Center",
            "nutrition_info": "18g Protein / 100g • Zero Starch • Melt-in-Mouth",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Free-Range Country Brown Eggs (Pack of 6)",
            "category": "Country & Organic Eggs",
            "category_ref": cat_map["eggs"],
            "description": "Antibiotic-free Free-Range Country Brown Eggs laid by naturally fed free-roaming hens.",
            "price_per_unit": Decimal("75.00"),
            "unit": Product.Units.PIECES,
            "unit_quantity": "6 Eggs Pack",
            "badge_text": "Organic Free-Range",
            "farm_origin": "Nalgonda Free-Range Farms",
            "nutrition_info": "6g Protein / Egg • Rich Omega-3 • Golden Yolk",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Farm Fresh White Eggs (Pack of 12)",
            "category": "Country & Organic Eggs",
            "category_ref": cat_map["eggs"],
            "description": "Nutrient-dense clean graded fresh table eggs, packed securely in eco-friendly molded pulp carton.",
            "price_per_unit": Decimal("110.00"),
            "unit": Product.Units.PIECES,
            "unit_quantity": "12 Eggs Carton",
            "badge_text": "Family Pack",
            "farm_origin": "Sunrise Poultry Hub",
            "nutrition_info": "High Protein • UV Sanitized • Farm Graded",
            "rating": Decimal("4.7"),
            "image_url": "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Bisleri 20L Mineral Water Can",
            "category": "Mineral Water Cans",
            "category_ref": cat_map["water-can"],
            "description": "Purified 20 Litre Mineral Drinking Water Can with Ozoned Seal delivered to your doorstep floor.",
            "price_per_unit": Decimal("90.00"),
            "unit": Product.Units.CAN,
            "unit_quantity": "20L Can",
            "badge_text": "Doorstep Can Drop",
            "farm_origin": "Bisleri Authorized Depot",
            "nutrition_info": "Added Minerals • 10-Stage RO Purified • TDS 120",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Artisanal Multi-Grain Morning Bread",
            "category": "Artisanal Breads",
            "category_ref": cat_map["bakery"],
            "description": "Freshly baked artisan multi-grain sourdough loaf made with whole wheat, flaxseeds, and oats.",
            "price_per_unit": Decimal("55.00"),
            "unit": Product.Units.PACKET,
            "unit_quantity": "400 g Loaf",
            "badge_text": "Zero Maida",
            "farm_origin": "Kodad Artisan Bakery",
            "nutrition_info": "100% Whole Grain • Zero Palm Oil • Rich Dietary Fiber",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Fresh Country Butter (White Makkhan)",
            "category": "Pure Ghee & Butter",
            "category_ref": cat_map["ghee"],
            "description": "Unsalted pure white village butter freshly churned from organic cultured cream.",
            "price_per_unit": Decimal("140.00"),
            "unit": Product.Units.GRAM,
            "unit_quantity": "250 g Tub",
            "badge_text": "Unsalted Pure",
            "farm_origin": "Kodad Dairy Co-op",
            "nutrition_info": "100% Cultured Cream • No Preservatives • Zero Salt",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
    ]

    for pdata in products_data:
        p, _ = Product.objects.get_or_create(name=pdata["name"], defaults=pdata)
        p.category = pdata["category"]
        p.category_ref = pdata["category_ref"]
        p.description = pdata["description"]
        p.price_per_unit = pdata["price_per_unit"]
        p.unit = pdata["unit"]
        p.unit_quantity = pdata["unit_quantity"]
        p.badge_text = pdata["badge_text"]
        p.farm_origin = pdata["farm_origin"]
        p.nutrition_info = pdata["nutrition_info"]
        p.rating = pdata["rating"]
        p.image_url = pdata["image_url"]
        p.is_available = pdata["is_available"]
        p.save()

    # 5. Hub Product Inventory & Daily Capacity Slots
    from apps.products.models import HubProductInventory
    from apps.subscriptions.models import Subscription
    from apps.deliveries.models import DeliveryTask
    from datetime import date

    all_products = Product.objects.all()
    for prod in all_products:
        inv, _ = HubProductInventory.objects.get_or_create(
            hub=hub_kodad,
            product=prod,
            defaults={
                "daily_capacity_slots": 150,
                "booked_slots": 0,
                "is_available": True,
            }
        )
        inv.daily_capacity_slots = 150
        inv.is_available = True
        inv.save()

    print(f"📦 [Hub Capacity Slots Configured]: {all_products.count()} products assigned 150 slots each at {hub_kodad.name}")

    # Recalculate booked capacity slots per product based on active real subscriptions
    for inv in HubProductInventory.objects.filter(hub=hub_kodad):
        booked = Subscription.objects.filter(
            hub=hub_kodad,
            product=inv.product,
            status=Subscription.Statuses.ACTIVE,
        ).count()
        inv.booked_slots = booked
        inv.save()

    print("🎉 [Railway DB Seeder] Clean production seeding completed (zero demo data)!")


if __name__ == "__main__":
    seed()


