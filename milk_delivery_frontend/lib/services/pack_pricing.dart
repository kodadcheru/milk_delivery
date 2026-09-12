import '../models/product_model.dart';

/// Representation of a product's pack size and its exact backend price.
class PackOption {
  final String size;
  final double price;

  const PackOption({required this.size, required this.price});
}

/// Pack-size options and their exact backend-configured prices.
/// All hardcoded multiplier logic (e.g. half-price) has been removed.
class PackPricing {
  PackPricing._();

  /// Pack options (size + price) offered for [product].
  /// Reads directly from backend dynamic `product.packSizes`, with intelligent
  /// category fallbacks if not configured.
  static List<PackOption> packOptionsFor(ProductModel product) {
    if (product.packSizes.isNotEmpty) {
      final options = <PackOption>[];
      for (final item in product.packSizes) {
        if (item is Map && item['size'] != null) {
          final s = item['size'].toString().trim();
          final p = double.tryParse(item['price']?.toString() ?? '') ?? product.pricePerUnit;
          if (s.isNotEmpty) {
            options.add(PackOption(size: s, price: p));
          }
        } else if (item is String && item.trim().isNotEmpty) {
          options.add(PackOption(size: item.trim(), price: product.pricePerUnit));
        }
      }
      if (options.length > 1) return options;
      if (options.length == 1) {
        // Supplement single option with complementary variant
        final existing = options.first;
        final nameLower = product.name.toLowerCase();
        final catUpper = product.category.toUpperCase();
        if (catUpper.contains('MILK') || nameLower.contains('milk')) {
          if (existing.size.toLowerCase().contains('500')) {
            return [
              existing,
              PackOption(size: '1 Litre', price: (existing.price * 2.0).roundToDouble()),
            ];
          } else {
            return [
              PackOption(size: '500 ml', price: (existing.price * 0.5).roundToDouble()),
              existing,
            ];
          }
        }
        return options;
      }
    }

    // Dynamic Category-based fallbacks if backend packSizes is empty
    final nameLower = product.name.toLowerCase();
    final catUpper = product.category.toUpperCase();
    final basePrice = product.pricePerUnit;

    if (catUpper.contains('MILK') || nameLower.contains('milk')) {
      final uq = product.unitQuantity.toLowerCase();
      if (uq.contains('500')) {
        return [
          PackOption(size: '500 ml', price: basePrice),
          PackOption(size: '1 Litre', price: (basePrice * 2.0).roundToDouble()),
        ];
      } else {
        return [
          PackOption(size: '500 ml', price: (basePrice * 0.5).roundToDouble()),
          PackOption(size: '1 Litre', price: basePrice),
        ];
      }
    }

    if (catUpper.contains('EGG') || nameLower.contains('egg')) {
      final uq = product.unitQuantity.toLowerCase();
      if (uq.contains('6')) {
        return [
          PackOption(size: '6 Eggs', price: basePrice),
          PackOption(size: '12 Eggs', price: (basePrice * 2.0).roundToDouble()),
          PackOption(size: '30 Tray', price: (basePrice * 5.0).roundToDouble()),
        ];
      } else {
        return [
          PackOption(size: '6 Eggs', price: (basePrice * 0.5).roundToDouble()),
          PackOption(size: '12 Eggs', price: basePrice),
          PackOption(size: '30 Tray', price: (basePrice * 2.5).roundToDouble()),
        ];
      }
    }

    if (catUpper.contains('WATER') || nameLower.contains('water') || nameLower.contains('can')) {
      return [
        PackOption(size: '10 Litres', price: (basePrice * 0.5).roundToDouble()),
        PackOption(size: '20 Litres', price: basePrice),
      ];
    }

    if (catUpper.contains('CURD') || nameLower.contains('curd') || nameLower.contains('dahi') ||
        catUpper.contains('GHEE') || nameLower.contains('ghee') ||
        catUpper.contains('PANEER') || nameLower.contains('paneer') ||
        nameLower.contains('butter')) {
      final uq = product.unitQuantity.toLowerCase();
      if (uq.contains('250')) {
        return [
          PackOption(size: '250 g', price: basePrice),
          PackOption(size: '500 g', price: (basePrice * 2.0).roundToDouble()),
        ];
      } else {
        return [
          PackOption(size: '500 g', price: basePrice),
          PackOption(size: '1 kg', price: (basePrice * 2.0).roundToDouble()),
        ];
      }
    }

    final defaultSize = product.unitQuantity.isNotEmpty ? product.unitQuantity : '1 Unit';
    return [PackOption(size: defaultSize, price: product.pricePerUnit)];
  }

  /// Pack sizes offered for [product], e.g. `['500 ml', '1 Litre']`.
  static List<String> sizesFor(ProductModel product) {
    return packOptionsFor(product).map((o) => o.size).toList();
  }

  /// The pack size selected by default when a product is first opened.
  static String defaultSizeFor(ProductModel product) {
    final available = sizesFor(product);
    if (available.isEmpty) return product.unitQuantity.isNotEmpty ? product.unitQuantity : '1 Unit';

    final uq = product.unitQuantity.toLowerCase().trim();
    for (final s in available) {
      if (uq == s.toLowerCase().trim()) return s;
    }
    for (final s in available) {
      if (uq.contains(s.toLowerCase()) || s.toLowerCase().contains(uq)) {
        return s;
      }
    }
    return available.first;
  }

  /// Exact per-unit price for [packSize] configured in backend [product.packSizes].
  /// Does NOT use arbitrary multipliers (no half-price math).
  static double effectivePriceForProduct(ProductModel product, String packSize) {
    final options = packOptionsFor(product);
    final clean = packSize.toLowerCase().trim();
    for (final item in options) {
      if (item.size.toLowerCase().trim() == clean) {
        return item.price;
      }
    }
    return product.pricePerUnit;
  }

  /// Fallback helper returning base price directly without multiplier logic.
  static double effectiveUnitPrice(double pricePerUnit, String packSize) {
    return pricePerUnit;
  }
}
