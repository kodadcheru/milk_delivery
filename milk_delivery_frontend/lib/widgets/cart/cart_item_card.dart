import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/ui_tokens.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';

class CartItemCard extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final AppState state;
  final VoidCallback? onRemoved;

  const CartItemCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.state,
    this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final linePrice = product.pricePerUnit * quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Product Image
          Container(
            width: 56,
            height: 56,
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
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(product.icon, style: const TextStyle(fontSize: 26)),
                      ),
                    )
                  : Center(
                      child: Text(product.icon, style: const TextStyle(fontSize: 26)),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Center: Title, Unit, Price Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.localizedName(state.currentLanguage),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: UiTone.ink,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  product.unitQuantity,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: UiTone.softText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${linePrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: UiTone.ink,
                      ),
                    ),
                    if (quantity > 1) ...[
                      const SizedBox(width: 5),
                      Text(
                        '(₹${product.pricePerUnit.toStringAsFixed(0)} ea)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: UiTone.softText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Modern Pill Stepper
          Container(
            decoration: BoxDecoration(
              color: UiTone.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: UiTone.primary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (quantity == 1) {
                      state.removeFromCart(product);
                      onRemoved?.call();
                    } else {
                      state.decreaseCartQty(product);
                    }
                  },
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(
                      quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                      size: 16,
                      color: quantity == 1 ? Colors.red.shade600 : UiTone.primary,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Container(
                    key: ValueKey(quantity),
                    constraints: const BoxConstraints(minWidth: 20),
                    alignment: Alignment.center,
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: UiTone.primaryDark,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.addToCart(product);
                  },
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: UiTone.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
