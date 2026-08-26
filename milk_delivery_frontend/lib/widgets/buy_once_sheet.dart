import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../providers/app_state.dart';
import '../services/pack_pricing.dart';
import '../theme/ui_format.dart';
import '../theme/ui_text.dart';
import '../theme/ui_tokens.dart';
import 'common/app_cached_image.dart';
import 'product_detail_sheet.dart';

/// Lightweight "buy it once" bottom sheet: pick a pack size + quantity and add
/// to the cart. Deliberately compact — a shopper who just wants one delivery
/// never has to scroll past subscription options to reach the primary action.
/// A subtle secondary row opens the full subscription sheet for those who want
/// a recurring plan instead.
class BuyOnceSheet extends StatefulWidget {
  final ProductModel product;
  final AppState state;

  const BuyOnceSheet({super.key, required this.product, required this.state});

  static void show(BuildContext context, ProductModel product, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BuyOnceSheet(product: product, state: state),
    );
  }

  @override
  State<BuyOnceSheet> createState() => _BuyOnceSheetState();
}

class _BuyOnceSheetState extends State<BuyOnceSheet> {
  late String _packSize;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _packSize = PackPricing.defaultSizeFor(widget.product);
  }

  double get _unitPrice =>
      PackPricing.effectiveUnitPrice(widget.product.pricePerUnit, _packSize);

  double get _lineTotal => _unitPrice * _qty;

  ProductModel get _variant =>
      widget.product.copyWith(pricePerUnit: _unitPrice, unitQuantity: _packSize);

  void _addToCart() {
    HapticFeedback.mediumImpact();
    final variant = _variant;
    final existing = widget.state.cartQtyOf(variant);
    widget.state.updateCartQty(variant, existing + _qty);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: UiTone.ink,
        content: Text('🛒 Added ${_qty}x ${widget.product.name} ($_packSize) to cart'),
      ),
    );
  }

  void _openSubscription() {
    final navigator = Navigator.of(context);
    navigator.pop();
    ProductDetailSheet.show(navigator.context, widget.product, widget.state);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final packs = PackPricing.sizesFor(item);
    final soldOut = item.isOutOfStock;

    return Container(
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grabber
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: UiTone.surfaceBorder,
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                      ),
                    ),
                  ),

                  // Header: thumbnail + name + unit
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _thumbnail(item),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.localizedName(widget.state.currentLanguage), style: UiText.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(widget.state.translateCategory(item.badgeText.isNotEmpty ? item.badgeText : item.category), style: UiText.label),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, color: UiTone.softText),
                      ),
                    ],
                  ),

                  if (item.category == 'MILK' || item.name.toLowerCase().contains('milk')) ...[
                    const SizedBox(height: 12),
                    _buildPurityBadge(item),
                  ],

                  const SizedBox(height: 16),

                  // Pack size
                  Text('Pack size', style: UiText.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: packs.map((p) => _packChip(p)).toList(),
                  ),

                  const SizedBox(height: 18),

                  // Quantity + price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quantity', style: UiText.label),
                          const SizedBox(height: 8),
                          _quantityStepper(),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total', style: UiText.label),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(UiFormat.price(_lineTotal), style: UiText.h1),
                              const SizedBox(width: 6),
                              Text(UiFormat.strike(_lineTotal), style: UiText.priceStrike),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Primary: add to cart
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: soldOut ? null : UiGradient.primary,
                        color: soldOut ? UiTone.surfaceMuted : null,
                        borderRadius: BorderRadius.circular(UiRadius.md),
                        boxShadow: soldOut ? null : UiShadow.glowPrimary,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(UiRadius.md),
                          onTap: soldOut ? null : _addToCart,
                          child: Center(
                            child: Text(
                              soldOut ? 'Sold out' : 'Add to cart · ${UiFormat.price(_lineTotal)}',
                              style: UiText.title.copyWith(
                                color: soldOut ? UiText.muted : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary: Prominent Subscribe & Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0E784D),
                        side: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                        backgroundColor: const Color(0xFFE6F5F0),
                        elevation: 0,
                      ),
                      onPressed: _openSubscription,
                      icon: const Icon(Icons.repeat_rounded, size: 20, color: Color(0xFF0E784D)),
                      label: const Text(
                        'SUBSCRIBE DAILY / SCHEDULED →',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: Color(0xFF0E784D),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(ProductModel item) {
    return AppCachedImage(
      imageUrl: item.imageUrl,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(UiRadius.sm),
      fallbackIcon: item.icon,
      customErrorWidget: _thumbFallback(item),
    );
  }

  Widget _thumbFallback(ProductModel item) => Container(
        color: UiTone.primarySoft,
        alignment: Alignment.center,
        child: Text(item.icon, style: const TextStyle(fontSize: 28)),
      );

  Widget _buildPurityBadge(ProductModel item) {
    final nameLower = item.name.toLowerCase();
    Map<String, dynamic>? activeBatch;
    final batches = widget.state.dailyMilkBatches;
    if (batches.isNotEmpty) {
      activeBatch = batches.firstWhere(
        (b) {
          final bName = b['product_name']?.toString().toLowerCase() ?? '';
          return bName.contains(nameLower.split(' ').first);
        },
        orElse: () => batches.first,
      );
    }

    final fatVal = activeBatch != null ? '${activeBatch['fat_percentage']}%' : (nameLower.contains('buffalo') ? '6.8%' : '4.2%');
    final waterVal = activeBatch != null ? '${activeBatch['water_percentage']}%' : '0.0%';
    final tempVal = activeBatch != null ? '${activeBatch['temperature_celsius']}°C' : '3.8°C';
    final batchCode = activeBatch != null ? (activeBatch['batch_code'] ?? 'BATCH-CERT-01') : 'BATCH-CERT-01';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: UiTone.successSoft,
        borderRadius: BorderRadius.circular(UiRadius.xs),
        border: Border.all(color: UiTone.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: UiTone.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Lab Certified ($batchCode) • $fatVal Fat • $waterVal Water • $tempVal',
              style: UiText.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: UiTone.success,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _packChip(String pack) {
    final selected = pack == _packSize;
    final price = PackPricing.effectiveUnitPrice(widget.product.pricePerUnit, pack);
    return GestureDetector(
      onTap: () => setState(() => _packSize = pack),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? UiTone.primarySoft : UiTone.surface,
          borderRadius: BorderRadius.circular(UiRadius.sm),
          border: Border.all(
            color: selected ? UiTone.primary : UiTone.surfaceBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pack,
              style: UiText.bodyStrong.copyWith(
                color: selected ? UiTone.primaryDark : UiTone.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(UiFormat.price(price), style: UiText.caption),
          ],
        ),
      ),
    );
  }

  Widget _quantityStepper() {
    return Container(
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.sm),
        border: Border.all(color: UiTone.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, _qty > 1 ? () => setState(() => _qty--) : null),
          SizedBox(
            width: 36,
            child: Text('$_qty', textAlign: TextAlign.center, style: UiText.title),
          ),
          _stepBtn(Icons.add_rounded, () => setState(() => _qty++)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UiRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Icon(icon, size: 18, color: onTap == null ? UiTone.surfaceBorder : UiTone.primary),
      ),
    );
  }
}
