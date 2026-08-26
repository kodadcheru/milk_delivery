import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/category_products_screen.dart';
import '../../theme/category_catalog.dart';
import '../../theme/ui_tokens.dart';

class HomeCategoryShowcase extends StatelessWidget {
  final AppState state;

  const HomeCategoryShowcase({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    // Only show categories that have products OR are core (first 4)
    final displayKeys = kHomeCategoryKeys.where((key) {
      final count = state.products.where((p) => p.category == key).length;
      final coreIndex = kHomeCategoryKeys.indexOf(key);
      return coreIndex < 4 || count > 0;
    }).toList();

    // Calculate tile width for 3-column grid
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0 * 2;
    const spacing = 12.0;
    final tileWidth = (screenWidth - horizontalPadding - spacing * 2) / 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: spacing,
        runSpacing: 16,
        children: displayKeys.map((key) {
          return SizedBox(
            width: tileWidth,
            child: _buildCategoryTile(context, categoryMetaFor(key)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, CategoryMeta cat) {
    final catKey = cat.key;
    final bgColor = cat.tileBg;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CategoryProductsScreen(categoryKey: catKey, state: state),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Container — square aspect ratio
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UiRadius.lg),
                border: Border.all(
                  color: UiTone.surfaceBorder,
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: UiTone.primary.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cat.image != null)
                      Image.network(
                        cat.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: bgColor,
                          alignment: Alignment.center,
                          child: Text(
                            cat.icon,
                            style: const TextStyle(fontSize: 34),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: bgColor,
                        alignment: Alignment.center,
                        child: Text(
                          cat.icon,
                          style: const TextStyle(fontSize: 34),
                        ),
                      ),

                    // Subtle bottom gradient for depth
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Right mini icon badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          cat.icon,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Label (Localized)
          Text(
            state.translateCategory(cat.shortTitle),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
