import '../models/product_model.dart';

/// Pack-size options and their (cosmetic) price multipliers.
///
/// Extracted verbatim from `product_detail_sheet.dart` so the product card and
/// both the buy-once and subscription sheets agree on which pack sizes a
/// product offers and what each costs. Behaviour is unchanged from the original
/// inline getters — this is a pure de-duplication.
class PackPricing {
  PackPricing._();

  /// Pack sizes offered for [product], e.g. `['500 ml', '1 Litre']`.
  /// Reads directly from backend dynamic `product.packSizes` if available.
  static List<String> sizesFor(ProductModel product) {
    if (product.packSizes.isNotEmpty) {
      final sizes = <String>[];
      for (final item in product.packSizes) {
        if (item is Map && item['size'] != null) {
          final s = item['size'].toString().trim();
          if (s.isNotEmpty) sizes.add(s);
        } else if (item is String && item.trim().isNotEmpty) {
          sizes.add(item.trim());
        }
      }
      if (sizes.isNotEmpty) return sizes;
    }

    final name = product.name.toLowerCase();
    final cat = product.category.toUpperCase();

    if (cat == 'MILK' || name.contains('milk')) {
      return const ['500 ml', '1 Litre'];
    } else if (cat == 'EGGS' || name.contains('egg')) {
      return const ['6 Eggs', '12 Eggs', '30 Tray'];
    } else if (cat == 'WATER_CAN' || name.contains('water')) {
      return const ['10 Litres', '20 Litres'];
    } else if (cat == 'MEAT' ||
        name.contains('chicken') ||
        name.contains('curd') ||
        name.contains('dahi')) {
      return const ['500g', '1 kg'];
    } else {
      return const ['500 ml', '1 Litre'];
    }
  }

  /// The pack size selected by default when a product is first opened.
  static String defaultSizeFor(ProductModel product) {
    final available = sizesFor(product);
    if (available.isEmpty) return '1 Litre';

    final uq = product.unitQuantity.toLowerCase();
    for (final s in available) {
      if (uq.contains(s.toLowerCase()) || s.toLowerCase().contains(uq)) {
        return s;
      }
    }

    final name = product.name.toLowerCase();
    final cat = product.category.toUpperCase();

    if (cat == 'MILK' || name.contains('milk')) {
      return uq.contains('500') ? '500 ml' : '1 Litre';
    } else if (cat == 'EGGS' || name.contains('egg')) {
      return available.contains('6 Eggs') ? '6 Eggs' : available.first;
    } else if (cat == 'WATER_CAN' || name.contains('water')) {
      return available.contains('20 Litres') ? '20 Litres' : available.first;
    } else if (uq.contains('500')) {
      return available.contains('500g') ? '500g' : available.first;
    } else {
      return available.first;
    }
  }

  /// Per-unit price for [packSize] given the product.
  /// Prioritizes backend-configured price in [product.packSizes].
  static double effectivePriceForProduct(ProductModel product, String packSize) {
    if (product.packSizes.isNotEmpty) {
      final clean = packSize.toLowerCase().trim();
      for (final item in product.packSizes) {
        if (item is Map && item['size'] != null && item['price'] != null) {
          if (item['size'].toString().toLowerCase().trim() == clean) {
            final p = double.tryParse(item['price'].toString());
            if (p != null) return p;
          }
        }
      }
    }
    return effectiveUnitPrice(product.pricePerUnit, packSize);
  }

  /// Per-unit price for [packSize] given the product's base [pricePerUnit].
  static double effectiveUnitPrice(double pricePerUnit, String packSize) {
    final clean = packSize.toLowerCase().trim();

    // 20L Water Can is the base product (₹80)
    if (clean.contains('20')) {
      return pricePerUnit;
    }
    // 10L Water Can is half-can (₹40)
    if (clean.contains('10') && (clean.contains('litre') || clean.contains('liter') || clean.contains('l'))) {
      return (pricePerUnit * 0.5).roundToDouble();
    }
    // 500ml / 500g is half size
    if (clean.contains('500')) {
      return (pricePerUnit * 0.5).roundToDouble();
    }
    // Eggs
    if (clean.contains('12')) {
      return (pricePerUnit * 2.0).roundToDouble();
    }
    if (clean.contains('30')) {
      return (pricePerUnit * 5.0).roundToDouble();
    }
    // 2 kg (e.g. meat/curd, using word boundary so '20' is never matched)
    if (RegExp(r'\b2(\.0)?\s*(kg|kilo)\b').hasMatch(clean)) {
      return (pricePerUnit * 2.0).roundToDouble();
    }
    return pricePerUnit;
  }
}
