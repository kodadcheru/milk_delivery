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
    final backendCategories = state.categories.where((c) => c.isActive).toList();

    // Calculate tile width for 3-column grid
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0 * 2;
    const spacing = 12.0;
    final tileWidth = (screenWidth - horizontalPadding - spacing * 2) / 3;
    final isCovered = state.isLocationCovered;

    final List<Widget> categoryTiles;
    if (backendCategories.isNotEmpty) {
      categoryTiles = backendCategories.map((bCat) {
        final catalogMeta = categoryMetaFor(bCat.slug);
        final effectiveImageUrl = bCat.imageUrl.isNotEmpty ? bCat.imageUrl : catalogMeta.image;
        final effectiveIcon = bCat.icon.isNotEmpty ? bCat.icon : catalogMeta.icon;

        return SizedBox(
          width: tileWidth,
          child: _buildCategoryTile(
            context: context,
            categoryKey: bCat.slug,
            title: bCat.name,
            icon: effectiveIcon,
            imageUrl: effectiveImageUrl,
            bgColor: catalogMeta.tileBg,
          ),
        );
      }).toList();
    } else {
      // Graceful fallback to curated catalogue so the customer storefront never looks empty
      categoryTiles = kHomeCategoryKeys.map((key) {
        final meta = categoryMetaFor(key);
        return SizedBox(
          width: tileWidth,
          child: _buildCategoryTile(
            context: context,
            categoryKey: meta.key,
            title: meta.shortTitle,
            icon: meta.icon,
            imageUrl: meta.image,
            bgColor: meta.tileBg,
          ),
        );
      }).toList();
    }

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: spacing,
        runSpacing: 16,
        children: categoryTiles,
      ),
    );

    if (!isCovered) {
      content = Opacity(
        opacity: 0.78,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildCategoryTile({
    required BuildContext context,
    required String categoryKey,
    required String title,
    required String icon,
    required String? imageUrl,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CategoryProductsScreen(categoryKey: categoryKey, state: state),
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
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: bgColor,
                          alignment: Alignment.center,
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 34),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: bgColor,
                        alignment: Alignment.center,
                        child: Text(
                          icon,
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
                          icon,
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
            state.translateCategory(title),
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
