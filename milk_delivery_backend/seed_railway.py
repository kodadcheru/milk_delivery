import os
import django
from decimal import Decimal

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "milk_backend.settings")
    django.setup()

from apps.accounts.models import User
from apps.products.models import Category, Product, StorefrontConfig


def seed():
    print("🌱 [Railway DB Initializer] Initializing Super Admin, 4 Core Categories & Products...")

    # 1. Permanent Super Admin Account
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

    # 2. Storefront Banner Config Default
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

    # 3. Exactly 4 Core Categories: Milk, Meat, Eggs, Water Can
    categories_data = [
        {
            "slug": "milk",
            "name": "Milk & Dairy",
            "icon": "🥛",
            "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80",
            "display_order": 1,
            "description": "Farm Fresh A2 Desi Cow and Buffalo Milk in glass bottles and pouches",
        },
        {
            "slug": "meat",
            "name": "Fresh Meat & Poultry",
            "icon": "🥩",
            "image_url": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=600&q=80",
            "display_order": 2,
            "description": "Hygienically dressed antibiotic-free country chicken and tender cuts",
        },
        {
            "slug": "eggs",
            "name": "Country & Farm Eggs",
            "icon": "🥚",
            "image_url": "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=600&q=80",
            "display_order": 3,
            "description": "Free-Range Country Brown and Farm Graded table eggs",
        },
        {
            "slug": "water-can",
            "name": "Mineral Water Cans",
            "icon": "💧",
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=600&q=80",
            "display_order": 4,
            "description": "20L RO Purified & UV Treated Mineral Drinking Water Cans",
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
        cat.is_active = True
        cat.save()
        cat_map[cdata["slug"]] = cat

    # 4. Exactly 2 Products Each under the 4 Categories (8 Products total)
    products_data = [
        # ── Milk & Dairy (2 Products) ──
        {
            "name": "Farm Fresh A2 Desi Cow Milk",
            "category": "Milk & Dairy",
            "category_ref": cat_map["milk"],
            "description": "100% pure raw unadulterated Vedic A2 cow milk in a glass bottle, chilled under 4°C within 1 hour of milking.",
            "price_per_unit": Decimal("88.00"),
            "unit": Product.Units.LITER,
            "unit_quantity": "1 Litre Glass Bottle",
            "badge_text": "Bestseller ⭐",
            "farm_origin": "Kodad Heritage Gaushala",
            "nutrition_info": "A2 Protein • 4.2% Fat • Pure Unadulterated",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Pure Buffalo Whole Milk (High Fat)",
            "category": "Milk & Dairy",
            "category_ref": cat_map["milk"],
            "description": "Rich 7.5% fat creamy buffalo milk ideal for morning tea, coffee, and thick homemade curd.",
            "price_per_unit": Decimal("78.00"),
            "unit": Product.Units.PACKET,
            "unit_quantity": "1 Litre Pouch",
            "badge_text": "High Fat 🥛",
            "farm_origin": "Nalgonda Dairy Farms",
            "nutrition_info": "7.5% Fat • 9.0% SNF • High Calcium",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },

        # ── Fresh Meat & Poultry (2 Products) ──
        {
            "name": "Country Chicken Curry Cut (Antibiotic-Free)",
            "category": "Fresh Meat & Poultry",
            "category_ref": cat_map["meat"],
            "description": "Freshly dressed tender country chicken curry cuts with bone, 100% antibiotic and hormone free, hygienically vacuum packed.",
            "price_per_unit": Decimal("175.00"),
            "unit": Product.Units.GRAM,
            "unit_quantity": "500g Vacuum Pack",
            "badge_text": "Fresh Cut 🍗",
            "farm_origin": "Bio-Secure Poultry Farms",
            "nutrition_info": "High Protein • 100% Antibiotic Free • Fresh Cut",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Tender Goat Mutton Curry Cut",
            "category": "Fresh Meat & Poultry",
            "category_ref": cat_map["meat"],
            "description": "Premium pasture-raised tender goat mutton curry pieces, cleaned, trimmed, and delivered cold-chain fresh.",
            "price_per_unit": Decimal("450.00"),
            "unit": Product.Units.GRAM,
            "unit_quantity": "500g Fresh Pack",
            "badge_text": "Tender Meat 🥩",
            "farm_origin": "Kodad Meat Depot",
            "nutrition_info": "Rich Iron & Protein • Grass-Fed Goat",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },

        # ── Country & Farm Eggs (2 Products) ──
        {
            "name": "Free-Range Country Brown Eggs (Pack of 6)",
            "category": "Country & Farm Eggs",
            "category_ref": cat_map["eggs"],
            "description": "Antibiotic-free Free-Range Country Brown Eggs laid by naturally fed free-roaming village hens.",
            "price_per_unit": Decimal("75.00"),
            "unit": Product.Units.PIECES,
            "unit_quantity": "6 Eggs Pack",
            "badge_text": "Organic Free-Range 🥚",
            "farm_origin": "Nalgonda Free-Range Farms",
            "nutrition_info": "6g Protein / Egg • Rich Omega-3 • Golden Yolk",
            "rating": Decimal("4.9"),
            "image_url": "https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Farm Fresh White Table Eggs (Pack of 12)",
            "category": "Country & Farm Eggs",
            "category_ref": cat_map["eggs"],
            "description": "Clean, graded, UV-sanitized fresh table eggs packed securely in an eco-friendly molded carton.",
            "price_per_unit": Decimal("110.00"),
            "unit": Product.Units.PIECES,
            "unit_quantity": "12 Eggs Carton",
            "badge_text": "Family Pack 🍳",
            "farm_origin": "Sunrise Poultry Hub",
            "nutrition_info": "High Protein • UV Sanitized • Farm Graded",
            "rating": Decimal("4.7"),
            "image_url": "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },

        # ── Mineral Water Cans (2 Products) ──
        {
            "name": "Bisleri 20L Mineral Water Can",
            "category": "Mineral Water Cans",
            "category_ref": cat_map["water-can"],
            "description": "Purified 20 Litre Mineral Drinking Water Can with Ozoned Tamper-Proof Seal delivered directly to your doorstep floor.",
            "price_per_unit": Decimal("90.00"),
            "unit": Product.Units.CAN,
            "unit_quantity": "20L Can",
            "badge_text": "Doorstep Can Drop 💧",
            "farm_origin": "Bisleri Authorized Depot",
            "nutrition_info": "Added Minerals • 10-Stage RO Purified • TDS 120",
            "rating": Decimal("4.8"),
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=800&q=80",
            "is_available": True,
        },
        {
            "name": "Kinley 20L Purified Water Can",
            "category": "Mineral Water Cans",
            "category_ref": cat_map["water-can"],
            "description": "Clean RO & UV treated 20L drinking water can with safety seal, ideal for homes and offices.",
            "price_per_unit": Decimal("85.00"),
            "unit": Product.Units.CAN,
            "unit_quantity": "20L Can",
            "badge_text": "RO Purified 💧",
            "farm_origin": "Coca-Cola Kinley Plant",
            "nutrition_info": "Reverse Osmosis • UV Disinfected • Zero Impurity",
            "rating": Decimal("4.7"),
            "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=800&q=80",
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
        p.is_available = True
        p.save()

    print("🎉 [Railway DB Initializer] Successfully seeded 4 categories and 8 curated products (2 per category)!")


if __name__ == "__main__":
    seed()
