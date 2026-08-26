import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/category_products_screen.dart';
import '../../theme/category_catalog.dart';
import '../../theme/ui_tokens.dart';
import '../common/app_cached_image.dart';

class HomeCategoryShowcase extends StatelessWidget {
  final AppState state;

  const HomeCategoryShowcase({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    // If no categories are configured on backend, do not render placeholders
    if (state.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final backendCategories = state.categories.where((c) => c.isActive).toList();
    if (backendCategories.isEmpty) {
      return const SizedBox.shrink();
    }

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
        children: backendCategories.map((bCat) {
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
        }).toList(),
      ),
    );
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
                    // Background category photo or emoji container
                    AppCachedImage(
                      imageUrl: imageUrl ?? '',
                      fallbackIcon: icon,
                      fallbackBgColor: bgColor,
                      fit: BoxFit.cover,
                      memCacheWidth: 250,
                      memCacheHeight: 250,
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
