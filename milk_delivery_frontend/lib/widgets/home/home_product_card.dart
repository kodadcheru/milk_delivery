import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_tokens.dart';
import '../buy_once_sheet.dart';
import '../product_detail_sheet.dart';
import '../common/app_cached_image.dart';

/// Product card shared by the home grid and the category products screen.
///
/// Tap the body to open the lightweight [BuyOnceSheet] (pick a pack size); the
/// trailing control adds the base pack straight to the cart and then becomes an
/// inline −/N/+ stepper so a second delivery never requires opening a sheet.
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
    final inCartQty = state.cartQtyOf(item);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        boxShadow: UiShadow.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => BuyOnceSheet.show(context, item, state),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-bleed cached image or emoji fallback
                AppCachedImage(
                  imageUrl: item.imageUrl,
                  fallbackIcon: item.icon,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  memCacheHeight: 400,
                  customErrorWidget: _buildEmojiFallback(),
                ),

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
                          Colors.black.withValues(alpha: 0.88),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
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
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      item.badgeText.isNotEmpty ? item.badgeText : item.category,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: UiTone.primary,
                      ),
                    ),
                  ),
                ),

                // 4. Top-right prominent Quick Subscribe Badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => ProductDetailSheet.show(context, item, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E784D), Color(0xFF044E32)],
                        ),
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        border: Border.all(color: const Color(0xFF34D399), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat_rounded, size: 11, color: Color(0xFF34D399)),
                          SizedBox(width: 3),
                          Text(
                            'SUBSCRIBE',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
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
                          borderRadius: BorderRadius.circular(UiRadius.xs),
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
                        // Product name (Localized)
                        Text(
                          item.localizedName(state.currentLanguage),
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

                        // Price row + cart / subscribe control
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Price
                            Flexible(
                              child: Text(
                                UiFormat.price(item.pricePerUnit),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Controls: Subscribe + ADD
                            if (!item.isOutOfStock) _buildCartControl(context, inCartQty),
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

  Widget _buildCartControl(BuildContext context, int inCartQty) {
    if (inCartQty == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clear direct Subscribe button
          GestureDetector(
            onTap: () => ProductDetailSheet.show(context, item, state),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0E784D),
                borderRadius: BorderRadius.circular(UiRadius.pill),
                border: Border.all(color: const Color(0xFF34D399), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, size: 11, color: Color(0xFF34D399)),
                  SizedBox(width: 2),
                  Text(
                    'SUB',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // ADD button for 1-time order
          GestureDetector(
            onTap: () => state.addToCart(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UiRadius.pill),
              ),
              child: const Text(
                'ADD +',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: UiTone.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: UiTone.primary,
        borderRadius: BorderRadius.circular(UiRadius.pill),
        boxShadow: UiShadow.glowPrimary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(Icons.remove_rounded, () => state.decreaseCartQty(item)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$inCartQty',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          _stepButton(Icons.add_rounded, () => state.addToCart(item)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.white),
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
