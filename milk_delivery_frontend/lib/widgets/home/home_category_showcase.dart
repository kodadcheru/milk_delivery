import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/category_products_screen.dart';
import '../../theme/category_catalog.dart';
import '../../theme/ui_tokens.dart';

class HomeCategoryShowcase extends StatefulWidget {
  final AppState state;

  const HomeCategoryShowcase({
    super.key,
    required this.state,
  });

  @override
  State<HomeCategoryShowcase> createState() => _HomeCategoryShowcaseState();
}

class _HomeCategoryShowcaseState extends State<HomeCategoryShowcase> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final backendCategories = widget.state.categories.where((c) => c.isActive).toList();

    // Calculate responsive tile width for category grid
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0 * 2;
    const spacing = 12.0;
    final columns = screenWidth > 900 ? 6 : (screenWidth > 600 ? 4 : 3);
    final tileWidth = (screenWidth - horizontalPadding - spacing * (columns - 1)) / columns;
    final isCovered = widget.state.isLocationCovered;

    final List<Widget> categoryTiles;
    if (backendCategories.isNotEmpty) {
      categoryTiles = backendCategories.asMap().entries.map((entry) {
        final idx = entry.key;
        final bCat = entry.value;
        final catalogMeta = categoryMetaFor(bCat.slug);
        final effectiveImageUrl = bCat.imageUrl.isNotEmpty ? bCat.imageUrl : catalogMeta.image;
        final effectiveIcon = bCat.icon.isNotEmpty ? bCat.icon : catalogMeta.icon;
        final isHighlighted = _selectedCategoryIndex == 0 || _selectedCategoryIndex == idx + 1;

        return SizedBox(
          width: tileWidth,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isHighlighted ? 1.0 : 0.3,
            child: _buildCategoryTile(
              context: context,
              category: bCat,
              categoryKey: bCat.slug,
              title: bCat.name,
              icon: effectiveIcon,
              imageUrl: effectiveImageUrl,
              bgColor: catalogMeta.tileBg,
            ),
          ),
        );
      }).toList();
    } else {
      // Graceful fallback to curated catalogue so the customer storefront never looks empty
      categoryTiles = kHomeCategoryKeys.asMap().entries.map((entry) {
        final idx = entry.key;
        final key = entry.value;
        final meta = categoryMetaFor(key);
        final isHighlighted = _selectedCategoryIndex == 0 || _selectedCategoryIndex == idx + 1;

        return SizedBox(
          width: tileWidth,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isHighlighted ? 1.0 : 0.3,
            child: _buildCategoryTile(
              context: context,
              categoryKey: meta.key,
              title: meta.shortTitle,
              icon: meta.icon,
              imageUrl: meta.image,
              bgColor: meta.tileBg,
            ),
          ),
        );
      }).toList();
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: (backendCategories.isNotEmpty ? backendCategories.length : kHomeCategoryKeys.length) + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = index == _selectedCategoryIndex;
              String label;
              
              if (index == 0) {
                label = 'All';
              } else {
                if (backendCategories.isNotEmpty) {
                  label = backendCategories[index - 1].name;
                } else {
                  final meta = categoryMetaFor(kHomeCategoryKeys[index - 1]);
                  label = meta.shortTitle;
                }
              }
              
              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? UiTone.primary : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(
                      color: isSelected ? UiTone.primary : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: UiTone.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: spacing,
            runSpacing: 16,
            children: categoryTiles,
          ),
        ),
      ],
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
    CategoryModel? category,
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
            builder: (ctx) => CategoryProductsScreen(
              category: category,
              categoryKey: categoryKey,
              state: widget.state,
            ),
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
                          child: Icon(
                            Icons.category_rounded,
                            size: 32,
                            color: UiTone.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: bgColor,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.category_rounded,
                          size: 32,
                          color: UiTone.primary.withValues(alpha: 0.4),
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
            widget.state.translateCategory(title),
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
