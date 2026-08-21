import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D7C66).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ProductDetailSheet.show(context, item, state),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-bleed image or emoji fallback
                item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(),
                      )
                    : _buildEmojiFallback(),

                // 2. Bottom gradient overlay — covers lower 55%
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Top-left category badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badgeText.isNotEmpty ? item.badgeText : item.category,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D7C66),
                      ),
                    ),
                  ),
                ),

                // 4. Top-right rating badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 10, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '${item.rating}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Out of stock overlay
                if (item.isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. Bottom content — aligned to bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Product name
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Unit
                        Row(
                          children: [
                            Icon(Icons.scale, size: 10, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(
                              item.unitQuantity,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Price row + ADD button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Price
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '₹${item.pricePerUnit.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (discountPrice > item.pricePerUnit) ...[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '₹${discountPrice.toStringAsFixed(0)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ADD button
                            if (!item.isOutOfStock)
                              GestureDetector(
                                onTap: () {
                                  if (inCartQty == 0) {
                                    state.addToCart(item);
                                  } else {
                                    ProductDetailSheet.show(context, item, state);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: inCartQty == 0 ? Colors.white : const Color(0xFF0D7C66),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      if (inCartQty > 0)
                                        BoxShadow(
                                          color: const Color(0xFF0D7C66).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Text(
                                    inCartQty == 0 ? 'ADD' : '✓ ${inCartQty}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: inCartQty == 0 ? const Color(0xFF0D7C66) : Colors.white,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiFallback() {
    // Category-based pastel background
    Color bgStart;
    Color bgEnd;
    switch (item.category) {
      case 'MILK':
        bgStart = const Color(0xFFE6F5F0);
        bgEnd = const Color(0xFFD1FAE5);
        break;
      case 'MEAT':
        bgStart = const Color(0xFFFDE8E8);
        bgEnd = const Color(0xFFFFE4E6);
        break;
      case 'EGGS':
        bgStart = const Color(0xFFFFF3E6);
        bgEnd = const Color(0xFFFEF3C7);
        break;
      case 'WATER_CAN':
        bgStart = const Color(0xFFE8F2FE);
        bgEnd = const Color(0xFFDBEAFE);
        break;
      default:
        bgStart = const Color(0xFFF8FAFC);
        bgEnd = const Color(0xFFE2E8F0);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
      ),
      child: Center(
        child: Text(
          item.icon,
          style: const TextStyle(fontSize: 44),
        ),
      ),
    );
  }
}
