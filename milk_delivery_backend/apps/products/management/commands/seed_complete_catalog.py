import logging
from decimal import Decimal
from django.core.management.base import BaseCommand
from apps.products.models import Category, Product

logger = logging.getLogger(__name__)

CATEGORY_DATA = [
    {
        "name": "Fresh Milk",
        "slug": "milk",
        "name_te": "తాజా పాలు",
        "icon": "🥛",
        "image_url": "https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Pure A2 Vedic Desi Cow & Buffalo Milk",
        "subtitle_te": "స్వచ్ఛమైన వేద దేశీ ఆవు మరియు గేదె పాలు",
        "banner_en": "🥛 Pure A2 Vedic Desi Cow & Buffalo Milk",
        "banner_te": "🥛 100% సహజమైన స్వచ్ఛమైన ఆవు మరియు గేదె పాలు",
        "subtags": ["ALL", "COW MILK", "BUFFALO"],
        "tile_bg_color": "#E6F5F0",
        "tile_fg_color": "#0D7C66",
        "gradient_colors": ["#0369A1", "#0284C7"],
        "display_order": 1,
    },
    {
        "name": "Farm Eggs",
        "slug": "eggs",
        "name_te": "తాజా గుడ్లు",
        "icon": "🥚",
        "image_url": "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Free-Range & Organic Daily Harvested",
        "subtitle_te": "సహజ పద్ధతిలో సేకరించిన తాజా గుడ్లు",
        "banner_en": "🥚 Daily Dawn Harvested • Free-Range & Organic",
        "banner_te": "🥚 ప్రతిరోజూ ఉదయం సేకరించిన సేంద్రీయ గుడ్లు",
        "subtags": ["ALL", "DESI", "BROWN", "HIGH PROTEIN"],
        "tile_bg_color": "#FFF3E6",
        "tile_fg_color": "#E67E22",
        "gradient_colors": ["#B45309", "#D97706"],
        "display_order": 2,
    },
    {
        "name": "Water Cans",
        "slug": "water_can",
        "name_te": "మినరల్ వాటర్",
        "icon": "💧",
        "image_url": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=600&q=85",
        "subtitle": "8-Stage RO + UV Purified • Sealed Can",
        "subtitle_te": "8 దశల ఆర్వో ప్యూరిఫైడ్ మినరల్ వాటర్",
        "banner_en": "💧 8-Stage RO + UV Purified • Mineral Rich",
        "banner_te": "💧 పరిశుభ్రమైన తాగునీరు • రోజూ డోర్‌స్టెప్ డెలివరీ",
        "subtags": ["ALL", "20L CAN", "DISPENSER", "MINERAL"],
        "tile_bg_color": "#E8F2FE",
        "tile_fg_color": "#2563EB",
        "gradient_colors": ["#0F766E", "#0D9488"],
        "display_order": 3,
    },
    {
        "name": "Meat & Poultry",
        "slug": "meat",
        "name_te": "తాజా మాంసం",
        "icon": "🥩",
        "image_url": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Fresh Tender Meat • 100% Antibiotic-Free",
        "subtitle_te": "తాజా చికెన్ & మటన్ • యాంటీబయాటిక్ రహితం",
        "banner_en": "🥩 Fresh Tender Meat • 100% Antibiotic-Free",
        "banner_te": "🥩 పరిశుభ్రమైన తాజా మాంసం",
        "subtags": ["ALL", "CHICKEN", "MUTTON", "FRESH CUT"],
        "tile_bg_color": "#FDE8E8",
        "tile_fg_color": "#DC2626",
        "gradient_colors": ["#991B1B", "#DC2626"],
        "display_order": 4,
    },
    {
        "name": "Paneer & Curd",
        "slug": "paneer",
        "name_te": "తాజా పనీర్",
        "icon": "🧀",
        "image_url": "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Soft Malai Paneer • Crafted Fresh Daily",
        "subtitle_te": "రోజూ తాజాగా తయారుచేసిన మృదువైన పనీర్",
        "banner_en": "🧀 Soft Malai Paneer • Crafted Fresh Daily",
        "banner_te": "🧀 ప్రిజర్వేటివ్స్ లేని తాజా పనీర్",
        "subtags": ["ALL", "MALAI", "PANEER", "VACUUM PACK"],
        "tile_bg_color": "#F0EAFC",
        "tile_fg_color": "#7C3AED",
        "gradient_colors": ["#6D28D9", "#8B5CF6"],
        "display_order": 5,
    },
    {
        "name": "Desi Ghee",
        "slug": "ghee",
        "name_te": "స్వచ్ఛమైన నెయ్యి",
        "icon": "🧈",
        "image_url": "https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Traditional Bilona Vedic Cow Ghee",
        "subtitle_te": "సాంప్రదాయ బిలోనా పద్ధతిలో తయారుచేసిన దేశీ నెయ్యి",
        "banner_en": "🧈 Traditional Bilona Vedic Cow Ghee & White Butter",
        "banner_te": "🧈 సువాసన గల కమ్మని దేశీ నెయ్యి",
        "subtags": ["ALL", "BILONA GHEE", "BUTTER", "A2 VEDIC"],
        "tile_bg_color": "#FEF3C7",
        "tile_fg_color": "#D97706",
        "gradient_colors": ["#D97706", "#F59E0B"],
        "display_order": 6,
    },
    {
        "name": "Set Curd",
        "slug": "curd",
        "name_te": "తాజా పెరుగు",
        "icon": "🥣",
        "image_url": "https://images.unsplash.com/photo-1571212515416-fef01fc43637?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Probiotic-Rich Natural Set Curd",
        "subtitle_te": "చిక్కటి, కమ్మనైన సహజ పెరుగు",
        "banner_en": "🥣 Probiotic-Rich Natural Set Curd in Eco Tubs",
        "banner_te": "🥣 ఆరోగ్యకరమైన ప్రోబయోటిక్ పెరుగు",
        "subtags": ["ALL", "MATKA DAHI", "SET CURD", "ORGANIC"],
        "tile_bg_color": "#E6F5F0",
        "tile_fg_color": "#0D7C66",
        "gradient_colors": ["#0D9488", "#14B8A6"],
        "display_order": 7,
    },
    {
        "name": "Bakery",
        "slug": "bakery",
        "name_te": "బేకరీ ఉత్పత్తులు",
        "icon": "🍞",
        "image_url": "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=85",
        "subtitle": "Fresh Morning Breads & Bakes",
        "subtitle_te": "రోజూ ఉదయం బేక్ చేసిన తాజా బ్రెడ్స్",
        "banner_en": "🍞 Fresh Morning Multi-Grain & Sourdough Breads",
        "banner_te": "🍞 తాజా బ్రెడ్స్ మరియు బేకరీ ఐటమ్స్",
        "subtags": ["ALL", "MULTI-GRAIN", "SOURDOUGH", "WHOLE WHEAT"],
        "tile_bg_color": "#FEF3C7",
        "tile_fg_color": "#B45309",
        "gradient_colors": ["#B45309", "#D97706"],
        "display_order": 8,
    },
]

PRODUCT_TRANSLATIONS = {
    "cow milk": {
        "name_te": "స్వచ్ఛమైన ఆవు పాలు",
        "desc_te": "రోజువారీ ఉదయం మీ ఇంటి ముంగిటకు వచ్చే 100% సహజమైన, స్వచ్ఛమైన ఆవు పాలు. ఎటువంటి రసాయనాలు కలపని సహజ పోషకాలు.",
        "badge_te": "రైతు ఉత్పత్తి",
    },
    "buffalo milk": {
        "name_te": "చిక్కటి గేదె పాలు",
        "desc_te": "అధిక వెన్న శాతం మరియు చిక్కదనం కలిగిన సహజ సిద్ధమైన గేదె పాలు. టీ, కాఫీ మరియు పెరుగు తయారీకి అత్యుత్తమం.",
        "badge_te": "అధిక వెన్న శాతం",
    },
    "milk": {
        "name_te": "ఫారం తాజా పాలు",
        "desc_te": "ప్రతిరోజూ ఉదయం ఫారం నుండి నేరుగా మీ ఇంటికి వచ్చే స్వచ్ఛమైన పాలు.",
        "badge_te": "తాజా పాలు",
    },
    "curd": {
        "name_te": "స్వచ్ఛమైన పెరుగు",
        "desc_te": "సహజ పాలతో తోడుపెట్టిన చిక్కటి, కమ్మనైన పెరుగు. రోగనిరోధక శక్తిని మరియు జీర్ణక్రియను మెరుగుపరుస్తుంది.",
        "badge_te": "సహజ పెరుగు",
    },
    "dahi": {
        "name_te": "తాజా పెరుగు",
        "desc_te": "సహజ పాలతో తోడుపెట్టిన చిక్కటి, కమ్మనైన పెరుగు.",
        "badge_te": "తాజా పెరుగు",
    },
    "ghee": {
        "name_te": "స్వచ్ఛమైన దేశీ నెయ్యి",
        "desc_te": "సాంప్రదాయ బిలోనా పద్ధతిలో కవ్వంతో చిలికి స్వచ్ఛమైన ఆవు వెన్న నుండి తయారుచేసిన కమ్మని సువాసన గల దేశీ నెయ్యి.",
        "badge_te": "బిలోనా పద్ధతి",
    },
    "butter": {
        "name_te": "స్వచ్ఛమైన వెన్న",
        "desc_te": "తాజా పాల నుండి చిలికి తయారుచేసిన స్వచ్ఛమైన తెల్ల వెన్న.",
        "badge_te": "సహజ వెన్న",
    },
    "paneer": {
        "name_te": "తాజా పనీర్",
        "desc_te": "ఎటువంటి ప్రిజర్వేటివ్స్ లేకుండా రోజూ తాజాగా తయారుచేయబడిన మృదువైన, పోషక విలువలు నిండిన పనీర్.",
        "badge_te": "మలై పనీర్",
    },
    "egg": {
        "name_te": "తాజా ఫారం గుడ్లు",
        "desc_te": "సహజ వాతావరణంలో పెరిగిన నాటు కోళ్ల నుండి సేకరించిన పోషక సమృద్ధమైన ప్రోటీన్ గుడ్లు.",
        "badge_te": "హై ప్రోటీన్",
    },
    "water": {
        "name_te": "మినరల్ వాటర్ క్యాన్ 20L",
        "desc_te": "కఠినమైన 8-దశల ఆర్వో ప్యూరిఫికేషన్ ప్రక్రియతో శుద్ధి చేయబడిన పరిశుభ్రమైన తాగునీరు.",
        "badge_te": "8-దశల ఆర్వో",
    },
    "bread": {
        "name_te": "తాజా హోల్ వీట్ బ్రెడ్",
        "desc_te": "మైదా లేకుండా సంపూర్ణ గోధుమలతో కాల్చిన ఆరోగ్యకరమైన తాజా బ్రెడ్.",
        "badge_te": "బేకరీ ఫ్రెష్",
    },
}

class Command(BaseCommand):
    help = "Seeds categories and products with 100% backend-driven dynamic metadata, Telugu translations, and pack sizes."

    def handle(self, *args, **options):
        self.stdout.write("Seeding categories with complete dynamic metadata...")
        cat_map = {}

        for c_data in CATEGORY_DATA:
            cat, created = Category.objects.update_or_create(
                slug=c_data["slug"],
                defaults={
                    "name": c_data["name"],
                    "name_te": c_data["name_te"],
                    "icon": c_data["icon"],
                    "image_url": c_data["image_url"],
                    "subtitle": c_data["subtitle"],
                    "subtitle_te": c_data["subtitle_te"],
                    "banner_en": c_data["banner_en"],
                    "banner_te": c_data["banner_te"],
                    "subtags": c_data["subtags"],
                    "tile_bg_color": c_data["tile_bg_color"],
                    "tile_fg_color": c_data["tile_fg_color"],
                    "gradient_colors": c_data["gradient_colors"],
                    "display_order": c_data["display_order"],
                    "is_active": True,
                },
            )
            cat_map[c_data["slug"]] = cat
            action = "Created" if created else "Updated"
            self.stdout.write(f"  {action} Category: {cat.name} ({cat.name_te})")

        self.stdout.write("\nUpdating products with Telugu translations and pack sizes...")
        for p in Product.objects.all():
            name_lower = p.name.lower()
            base_p = float(p.price_per_unit)

            # Match translation
            matched_te = None
            for key, t_data in PRODUCT_TRANSLATIONS.items():
                if key in name_lower:
                    matched_te = t_data
                    break

            if matched_te:
                p.name_te = matched_te["name_te"]
                p.description_te = matched_te["desc_te"]
                p.badge_text_te = matched_te["badge_te"]
            else:
                p.name_te = p.name
                p.description_te = p.description or ""
                p.badge_text_te = p.badge_text or ""

            # Assign pack sizes
            cat_str = (p.category or "").upper()
            if "WATER" in cat_str or "water" in name_lower or "can" in name_lower:
                p.pack_sizes = [
                    {"size": "10 Litres", "price": round(base_p * 0.5, 2)},
                    {"size": "20 Litres", "price": round(base_p, 2)},
                ]
            elif "EGG" in cat_str or "egg" in name_lower:
                p.pack_sizes = [
                    {"size": "6 Eggs", "price": round(base_p, 2)},
                    {"size": "12 Eggs", "price": round(base_p * 2.0, 2)},
                    {"size": "30 Tray", "price": round(base_p * 5.0, 2)},
                ]
            elif "MILK" in cat_str or "milk" in name_lower:
                # User specifically requested: NO 2 Litres for milk!
                p.pack_sizes = [
                    {"size": "500 ml", "price": round(base_p * 0.5, 2)},
                    {"size": "1 Litre", "price": round(base_p, 2)},
                ]
            elif "CURD" in cat_str or "curd" in name_lower or "paneer" in name_lower or "meat" in name_lower:
                p.pack_sizes = [
                    {"size": "500g", "price": round(base_p, 2)},
                    {"size": "1 kg", "price": round(base_p * 2.0, 2)},
                ]
            else:
                p.pack_sizes = [
                    {"size": p.unit_quantity or "1 Unit", "price": round(base_p, 2)}
                ]

            # Default subscriptions to enabled
            p.is_subscription_enabled = True

            # Link category_ref if missing
            if not p.category_ref:
                for c_slug, cat_obj in cat_map.items():
                    if c_slug in name_lower or c_slug in cat_str.lower():
                        p.category_ref = cat_obj
                        p.category = cat_obj.name
                        break

            p.save()
            self.stdout.write(f"  Updated Product #{p.id}: {p.name} -> {p.name_te} | Pack Sizes: {len(p.pack_sizes)} options | Sub Enabled: {p.is_subscription_enabled}")

        self.stdout.write(self.style.SUCCESS("\nAll categories and products successfully seeded with complete dynamic backend metadata!"))
