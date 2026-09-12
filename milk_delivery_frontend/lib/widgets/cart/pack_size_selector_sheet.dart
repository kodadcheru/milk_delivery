import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../services/pack_pricing.dart';
import '../../theme/ui_tokens.dart';

/// Modal bottom sheet presented to customer when tapping "ADD +" on a product
/// with multiple pack size variants (e.g. 500 ml vs 1 Litre).
class PackSizeSelectorSheet extends StatelessWidget {
  final ProductModel product;
  final AppState state;

  const PackSizeSelectorSheet({
    super.key,
    required this.product,
    required this.state,
  });

  static Future<void> show(BuildContext context, {required ProductModel product, required AppState state}) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PackSizeSelectorSheet(product: product, state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = PackPricing.packOptionsFor(product);
    final isTe = state.isTelugu;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Thumbnail + Title + Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: product.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(product.icon, style: const TextStyle(fontSize: 24)),
                              ),
                            )
                          : Center(
                              child: Text(product.icon, style: const TextStyle(fontSize: 24)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.localizedName(state.currentLanguage),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: UiTone.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTe ? 'పరిమాణాన్ని ఎంచుకోండి (ధర చూడండి)' : 'Select Pack Size & Quantity',
                          style: const TextStyle(
                            fontSize: 12,
                            color: UiTone.softText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Pack Options List
              ...options.map((opt) {
                final variant = product.copyWith(
                  unitQuantity: opt.size,
                  pricePerUnit: opt.price,
                );
                final inCartQty = state.cartQtyOf(variant);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: inCartQty > 0 ? UiTone.primarySoft.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: inCartQty > 0 ? UiTone.primary.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                      width: inCartQty > 0 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pack Size Badge & Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.size,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: UiTone.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '₹${opt.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: UiTone.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action: Add button or Stepper
                      inCartQty == 0
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: UiTone.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                state.addToCart(variant);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    isTe ? 'చేర్చండి' : 'ADD',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: UiTone.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 18),
                                    onPressed: () => state.decreaseCartQty(variant),
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text(
                                    '$inCartQty',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                    onPressed: () => state.addToCart(variant),
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Done Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isTe ? 'పూర్తయింది' : 'Done',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
