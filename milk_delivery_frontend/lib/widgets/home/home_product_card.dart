import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/product_detail_sheet.dart';

class HomeProductCard extends StatelessWidget {
  final AppState state;
  final ProductModel item;

  const HomeProductCard({
    super.key,
    required this.state,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final discountPrice = item.pricePerUnit * 1.12;
    final inCartQty = state.getCartQty(item.id);

    return Container(
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(
          color: inCartQty > 0 ? UiTone.primary : UiTone.surfaceBorder,
          width: inCartQty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: inCartQty > 0 ? UiShadow.glowPrimary : UiShadow.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(UiRadius.md),
        child: InkWell(
          onTap: () => ProductDetailSheet.show(context, item, state),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Text Strip & Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          item.badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0D7C66),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 2),
                          Text(
                            '${item.rating}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Avatar / Image Display Container
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 85,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF1F5F9),
                          const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Center(
                              child: Text(item.icon, style: const TextStyle(fontSize: 36)),
                            ),
                          )
                        : Center(
                            child: Text(item.icon, style: const TextStyle(fontSize: 36)),
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // Product Name & Quantity
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: -0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  item.unitQuantity,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),

                // Price
                Row(
                  children: [
                    Text(
                      '₹${item.pricePerUnit.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF0D7C66),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '₹${discountPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Smart Cart Stepper or Dual CTA Buttons / Out of Stock Banner
                if (item.isOutOfStock)
                  SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[700],
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'OUT OF STOCK ❌',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else if (inCartQty > 0)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => state.decreaseCartQty(item.id),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Icon(Icons.remove_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                        Text(
                          '$inCartQty in cart',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        InkWell(
                          onTap: () => state.addToCart(item),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () {
                              state.addToCart(item);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: const Color(0xFF0F172A),
                                  content: Text('🛒 Added 1x ${item.name} to Cart!'),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              '+ Cart',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => ProductDetailSheet.show(context, item, state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Subscribe',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
