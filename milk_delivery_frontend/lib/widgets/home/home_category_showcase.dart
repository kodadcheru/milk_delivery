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

  // 8-color cyclic tint palette (matching service-mobile reference)
  static const List<Map<String, dynamic>> categoriesData = [
    {
      'key': 'MILK',
      'title': 'Fresh Milk & Dairy',
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
      'title': 'Farm Fresh Eggs',
      'icon': '🥚',
      'bg': Color(0xFFFFF3E6),
      'fg': Color(0xFFE67E22),
    },
    {
      'key': 'WATER_CAN',
      'title': 'Pure Water Cans',
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

    // Calculate tile dimensions
    const crossAxisCount = 3;
    const crossAxisSpacing = 14.0;
    const mainAxisSpacing = 18.0;
    final screenWidth = MediaQuery.of(context).size.width - 32; // 16px padding each side
    final iconSize = (screenWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: 0.72,
        ),
        itemCount: displayCategories.length,
        itemBuilder: (context, index) {
          final cat = displayCategories[index];
          return _buildCategoryTile(context, cat, iconSize);
        },
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, Map<String, dynamic> cat, double iconSize) {
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
        children: [
          // Icon Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? fgColor
                    : const Color(0xFF0D7C66).withValues(alpha: 0.22),
                width: isSelected ? 2.5 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? fgColor.withValues(alpha: 0.2)
                      : const Color(0xFF0D7C66).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
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
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Label
          SizedBox(
            height: 38,
            child: Text(
              cat['title'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? fgColor : const Color(0xFF2A313D),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
