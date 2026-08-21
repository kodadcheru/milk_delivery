import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/category_products_screen.dart';

class HomeCategoryShowcase extends StatelessWidget {
  final AppState state;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  const HomeCategoryShowcase({
    super.key,
    required this.state,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  // 6-color cyclic tint palette (matching service-mobile reference)
  static const List<Map<String, dynamic>> categoriesData = [
    {
      'key': 'MILK',
      'title': 'Fresh Milk',
      'icon': '🥛',
      'bg': Color(0xFFE6F5F0),
      'fg': Color(0xFF0D7C66),
    },
    {
      'key': 'MEAT',
      'title': 'Meat & Poultry',
      'icon': '🥩',
      'bg': Color(0xFFFDE8E8),
      'fg': Color(0xFFDC2626),
    },
    {
      'key': 'EGGS',
      'title': 'Farm Eggs',
      'icon': '🥚',
      'bg': Color(0xFFFFF3E6),
      'fg': Color(0xFFE67E22),
    },
    {
      'key': 'WATER_CAN',
      'title': 'Water Cans',
      'icon': '💧',
      'bg': Color(0xFFE8F2FE),
      'fg': Color(0xFF2563EB),
    },
    {
      'key': 'PANEER',
      'title': 'Paneer & Curd',
      'icon': '🧀',
      'bg': Color(0xFFF0EAFC),
      'fg': Color(0xFF7C3AED),
    },
    {
      'key': 'GHEE',
      'title': 'Desi Ghee',
      'icon': '🫙',
      'bg': Color(0xFFFEF3C7),
      'fg': Color(0xFFD97706),
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Only show categories that have products OR are core (first 4)
    final displayCategories = categoriesData.where((cat) {
      final key = cat['key'] as String;
      final count = state.products.where((p) => p.category == key).length;
      final coreIndex = categoriesData.indexOf(cat);
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
        children: displayCategories.map((cat) {
          return SizedBox(
            width: tileWidth,
            child: _buildCategoryTile(context, cat),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, Map<String, dynamic> cat) {
    final catKey = cat['key'] as String;
    final isSelected = selectedCategory == catKey;
    final bgColor = cat['bg'] as Color;
    final fgColor = cat['fg'] as Color;

    return GestureDetector(
      onTap: () {
        onSelectCategory(catKey);
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? fgColor
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2.5 : 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? fgColor.withValues(alpha: 0.2)
                        : const Color(0xFF0D7C66).withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  color: bgColor,
                  alignment: Alignment.center,
                  child: Text(
                    cat['icon'] as String,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Label
          Text(
            cat['title'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? fgColor : const Color(0xFF334155),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
