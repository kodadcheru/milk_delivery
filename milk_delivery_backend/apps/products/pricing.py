import re
from decimal import Decimal, ROUND_HALF_UP

def parse_unit_quantity_factor(unit_quantity_str: str):
    """
    Parses a unit quantity string and returns (base_type, factor_num).
    base_type: 'VOLUME_ML', 'WEIGHT_G', 'COUNT_EGGS', 'UNKNOWN'
    factor_num: float value in base units (mL, g, count)
    """
    if not unit_quantity_str:
        return 'UNKNOWN', 1.0

    s = unit_quantity_str.lower().strip()

    # 1. Volume (mL vs Litre) - check mL first to prevent '500 ml' matching 'l'
    if 'ml' in s:
        match = re.search(r'([\d.]+)', s)
        return 'VOLUME_ML', float(match.group(1)) if match else 500.0

    if 'liter' in s or 'litre' in s or ' l' in s or re.search(r'\b\d+l\b', s) or s.endswith(' l') or s == '1l':
        match = re.search(r'([\d.]+)', s)
        litres = float(match.group(1)) if match else 1.0
        return 'VOLUME_ML', litres * 1000.0

    # 2. Weight (g vs kg) - check g / kg
    if ' g' in s or s.endswith('g') or 'gram' in s:
        if 'kg' in s or 'kilo' in s:
            match = re.search(r'([\d.]+)', s)
            kgs = float(match.group(1)) if match else 1.0
            return 'WEIGHT_G', kgs * 1000.0
        match = re.search(r'([\d.]+)', s)
        return 'WEIGHT_G', float(match.group(1)) if match else 500.0

    if 'kg' in s or 'kilo' in s:
        match = re.search(r'([\d.]+)', s)
        kgs = float(match.group(1)) if match else 1.0
        return 'WEIGHT_G', kgs * 1000.0

    # 3. Eggs / Pieces Count
    if 'egg' in s or 'pc' in s or 'piece' in s or 'pack' in s or 'tray' in s or 'carton' in s:
        match = re.search(r'([\d.]+)', s)
        if match:
            return 'COUNT_EGGS', float(match.group(1))
        if 'dozen' in s:
            return 'COUNT_EGGS', 12.0
        return 'COUNT_EGGS', 1.0

    return 'UNKNOWN', 1.0


def calculate_proportional_price(source_price, source_unit_qty: str, target_unit_qty: str) -> Decimal:
    """
    Given a source price for a source_unit_qty (e.g. ₹80 for 1 Litre),
    calculates proportional price for target_unit_qty (e.g. 500 mL -> ₹40.00).
    """
    try:
        src_dec = Decimal(str(source_price))
    except Exception:
        return Decimal('0.00')

    src_type, src_factor = parse_unit_quantity_factor(source_unit_qty)
    tgt_type, tgt_factor = parse_unit_quantity_factor(target_unit_qty)

    if src_type != tgt_type or src_factor <= 0 or tgt_factor <= 0:
        return src_dec

    ratio = Decimal(str(tgt_factor)) / Decimal(str(src_factor))
    calc_price = src_dec * ratio
    return calc_price.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def update_sibling_product_prices(updated_product):
    """
    Finds sibling products in the same category sharing a similar name stem
    and updates their prices proportionally relative to updated_product.
    """
    from apps.products.models import Product

    if not updated_product or not updated_product.price_per_unit:
        return

    # Extract name stem (e.g., 'Farm Fresh A2 Desi Cow Milk' -> 'Farm Fresh A2 Desi Cow Milk')
    base_name = re.sub(r'(?i)\b(\d+[\s]*(liter|litre|l|ml|kg|g|pack|eggs|pcs))\b', '', updated_product.name).strip()
    if len(base_name) < 3:
        base_name = updated_product.name.split()[0]

    siblings = Product.objects.filter(
        category=updated_product.category
    ).exclude(pk=updated_product.pk)

    for sib in siblings:
        # Check if sibling belongs to the same product line
        if base_name.lower() in sib.name.lower() or sib.name.lower() in base_name.lower():
            new_price = calculate_proportional_price(
                updated_product.price_per_unit,
                updated_product.unit_quantity,
                sib.unit_quantity
            )
            if new_price != sib.price_per_unit:
                sib.price_per_unit = new_price
                sib.save(update_fields=['price_per_unit'])
