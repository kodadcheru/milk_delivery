from django.db import migrations


def create_initial_data(apps, schema_editor):
    Product = apps.get_model('products', 'Product')

    # Initial Product Catalog across 4 Core Categories
    initial_products = [
        {
            'name': 'Farm Fresh A2 Desi Cow Milk',
            'description': '100% pure raw unadulterated Vedic A2 cow milk, pasteurized & chilled under 4°C within 1 hour of morning milking.',
            'category': 'MILK',
            'price_per_unit': 85.00,
            'unit': 'LITER',
            'unit_quantity': '1 Litre Glass Bottle',
            'badge_text': 'Bestseller ⭐',
            'rating': 4.9,
            'farm_origin': 'Gir Cow Vedic Farm, Shamirpet',
            'nutrition_info': '4.5% Natural Fat • Protein Rich',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
        },
        {
            'name': 'Rich Cream Pure Buffalo Milk',
            'description': 'Thick high-fat creamy buffalo milk ideal for morning tea, coffee, and homemade paneer & rich curd.',
            'category': 'MILK',
            'price_per_unit': 78.00,
            'unit': 'LITER',
            'unit_quantity': '1 Litre Packet',
            'badge_text': 'High Protein 💪',
            'rating': 4.8,
            'farm_origin': 'Murrah Buffalo Dairy, Medchal',
            'nutrition_info': '6.8% Rich Cream • High Calcium',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500&q=80',
        },
        {
            'name': 'Natural Traditional Clay Pot Curd (Dahi)',
            'description': 'Slow-fermented probiotic rich thick natural curd prepared traditionally in hygienic earthen pots.',
            'category': 'MILK',
            'price_per_unit': 60.00,
            'unit': 'PACKET',
            'unit_quantity': '500g Clay Pot',
            'badge_text': 'Probiotic 🥣',
            'rating': 4.9,
            'farm_origin': 'Fresh Dairy Kitchen, Kondapur',
            'nutrition_info': 'Active Probiotic Cultures',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1588710929895-6ef7bf47e06a?w=500&q=80',
        },
        {
            'name': 'Antibiotic-Free Tender Chicken Curry Cut',
            'description': 'Freshly processed healthy broiler chicken curry cuts (with bone), 100% antibiotic and hormone free, vacuum-sealed.',
            'category': 'MEAT',
            'price_per_unit': 160.00,
            'unit': 'KG',
            'unit_quantity': '500g Vacuum Pack',
            'badge_text': 'Fresh Cut 🍗',
            'rating': 4.9,
            'farm_origin': 'Bio-Secure Poultry Farms, Vikarabad',
            'nutrition_info': 'Lean Muscle Protein',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=500&q=80',
        },
        {
            'name': 'Boneless Tender Chicken Breast',
            'description': 'Premium lean boneless chicken breast fillets, perfectly trimmed and hygienic for fitness & keto meals.',
            'category': 'MEAT',
            'price_per_unit': 210.00,
            'unit': 'KG',
            'unit_quantity': '500g Fillet Pack',
            'badge_text': 'Gym Diet 💪',
            'rating': 4.8,
            'farm_origin': 'Bio-Secure Poultry Farms, Vikarabad',
            'nutrition_info': '31g Protein / 100g',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=500&q=80',
        },
        {
            'name': 'Farm Fresh Country Desi Brown Eggs',
            'description': 'Free-range pasture-raised Desi hen brown eggs, rich in natural omega-3 and bright golden yolks.',
            'category': 'EGGS',
            'price_per_unit': 85.00,
            'unit': 'PACKET',
            'unit_quantity': '6 Eggs Bio-Carton',
            'badge_text': 'Omega-3 🥚',
            'rating': 4.9,
            'farm_origin': 'Grassland Free-Range Farms, Sangareddy',
            'nutrition_info': 'Natural Omega-3 & Lutein',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=500&q=80',
        },
        {
            'name': 'Classic Farm White Table Eggs',
            'description': 'Clean, sanitized high-protein white eggs harvested daily at dawn for your breakfast needs.',
            'category': 'EGGS',
            'price_per_unit': 120.00,
            'unit': 'PACKET',
            'unit_quantity': '12 Eggs Pack',
            'badge_text': 'Value Pack 📦',
            'rating': 4.7,
            'farm_origin': 'Sunrise Layer Farms, Medak',
            'nutrition_info': 'High Protein Breakfast',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=500&q=80',
        },
        {
            'name': '8-Stage Purified 20L Mineral Water Can',
            'description': 'BIS certified 20 Litre mineral water jar with tamper-proof security seal and 8-stage RO+UV filtration.',
            'category': 'WATER_CAN',
            'price_per_unit': 60.00,
            'unit': 'CAN',
            'unit_quantity': '20 Litre Can',
            'badge_text': 'Doorstep Drop 💧',
            'rating': 4.9,
            'farm_origin': 'AquaDrop Purification Plant, Miyapur',
            'nutrition_info': 'TDS 120 (Optimal Balance)',
            'is_available': True,
            'image_url': 'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=500&q=80',
        },
    ]

    for p in initial_products:
        Product.objects.get_or_create(name=p['name'], defaults=p)

def remove_initial_data(apps, schema_editor):
    pass

class Migration(migrations.Migration):

    dependencies = [
        ('products', '0003_alter_product_category_alter_product_farm_origin_and_more'),
        ('accounts', '0003_user_latitude_user_longitude'),
    ]

    operations = [
        migrations.RunPython(create_initial_data, remove_initial_data),
    ]
