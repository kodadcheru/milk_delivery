import '../models/product_model.dart';

/// Pack-size options and their (cosmetic) price multipliers.
///
/// Extracted verbatim from `product_detail_sheet.dart` so the product card and
/// both the buy-once and subscription sheets agree on which pack sizes a
/// product offers and what each costs. Behaviour is unchanged from the original
/// inline getters — this is a pure de-duplication.
class PackPricing {
  PackPricing._();

  /// Pack sizes offered for [product], e.g. `['500 ml', '1 Litre', '2 Litres']`.
  static List<String> sizesFor(ProductModel product) {
    final name = product.name.toLowerCase();
    final cat = product.category.toUpperCase();

    if (cat == 'MILK' || name.contains('milk')) {
      return const ['500 ml', '1 Litre', '2 Litres'];
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
    final name = product.name.toLowerCase();
    final cat = product.category.toUpperCase();
    final uq = product.unitQuantity.toLowerCase();

    if (cat == 'MILK' || name.contains('milk')) {
      return uq.contains('500') ? '500 ml' : '1 Litre';
    } else if (cat == 'EGGS' || name.contains('egg')) {
      return '6 Eggs';
    } else if (cat == 'WATER_CAN' || name.contains('water')) {
      return '20 Litres';
    } else if (uq.contains('500')) {
      return '500g';
    } else {
      return '1 Litre';
    }
  }

  /// Per-unit price for [packSize] given the product's base [pricePerUnit].
  static double effectiveUnitPrice(double pricePerUnit, String packSize) {
    final clean = packSize.toLowerCase().trim();
    if (clean.contains('500')) {
      return (pricePerUnit * 0.5).roundToDouble();
    } else if (clean.contains('2') && (clean.contains('litre') || clean.contains('liter') || clean.contains('kg'))) {
      return (pricePerUnit * 2.0).roundToDouble();
    } else if (clean.contains('12')) {
      return (pricePerUnit * 2.0).roundToDouble();
    } else if (clean.contains('30')) {
      return (pricePerUnit * 5.0).roundToDouble();
    } else if (clean.contains('10') && (clean.contains('litre') || clean.contains('liter'))) {
      return (pricePerUnit * 0.5).roundToDouble();
    }
    return pricePerUnit;
  }
}
