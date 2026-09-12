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
  /// Reads directly from backend dynamic `product.packSizes`.
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
      if (options.isNotEmpty) return options;
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
