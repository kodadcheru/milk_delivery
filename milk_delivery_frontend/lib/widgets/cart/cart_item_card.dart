import 'package:flutter/material.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Left: Image
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: UiTone.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(child: Text(product.icon, style: const TextStyle(fontSize: 24))),
                    )
                  : Center(child: Text(product.icon, style: const TextStyle(fontSize: 24))),
            ),
          ),
          const SizedBox(width: 12),
          
          // Center: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: UiTone.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product.unitQuantity,
                  style: const TextStyle(fontSize: 12, color: UiTone.softText),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${(product.pricePerUnit * quantity).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UiTone.primary),
                ),
              ],
            ),
          ),
          
          // Right: Stepper
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: UiTone.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (quantity == 1) {
                      state.removeFromCart(product);
                      onRemoved?.call();
                    } else {
                      state.decreaseCartQty(product);
                    }
                  },
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      quantity == 1 ? Icons.delete_outline : Icons.remove,
                      size: 16,
                      color: quantity == 1 ? Colors.red.shade400 : UiTone.primary,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '$quantity',
                    key: ValueKey(quantity),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                  ),
                ),
                InkWell(
                  onTap: () {
                    state.addToCart(product);
                  },
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.add, size: 16, color: UiTone.primary),
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
