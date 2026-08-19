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

  static const List<Map<String, dynamic>> categoriesData = [
    {
      'key': 'MILK',
      'title': 'Fresh Milk & Dairy',
      'subtitle': 'A2 Desi Cow, Buffalo & Organic',
      'badge': '4 Varieties',
      'icon': '🥛',
      'gradient': [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
      'accent': Color(0xFF0284C7),
      'tag': 'PURE VEDIC',
    },
    {
      'key': 'MEAT',
      'title': 'Meat & Poultry',
      'subtitle': 'Tender Chicken & Mutton Cut',
      'badge': '100% Fresh',
      'icon': '🥩',
      'gradient': [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
      'accent': Color(0xFFDC2626),
      'tag': 'ANTIBIOTIC-FREE',
    },
    {
      'key': 'EGGS',
      'title': 'Farm Fresh Eggs',
      'subtitle': 'Free-Range Desi & Brown Eggs',
      'badge': 'Daily Harvest',
      'icon': '🥚',
      'gradient': [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
      'accent': Color(0xFFD97706),
      'tag': 'HIGH PROTEIN',
    },
    {
      'key': 'WATER_CAN',
      'title': 'Pure Water Cans',
      'subtitle': '20L Mineral Cans & Dispensers',
      'badge': '8-Stage RO',
      'icon': '💧',
      'gradient': [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
      'accent': Color(0xFF0D9488),
      'tag': 'MINERAL RICH',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Essential Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap any category to open full storefront catalog',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selectedCategory != 'ALL')
                InkWell(
                  onTap: () => onSelectCategory('ALL'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View All ✨',
                      style: TextStyle(
                        color: Color(0xFF0D7C66),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 2x2 Large Category Cards (Row/Expanded layout)
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildCategoryCard(context, categoriesData[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCategoryCard(context, categoriesData[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCategoryCard(context, categoriesData[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCategoryCard(context, categoriesData[3])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat) {
    final catKey = cat['key'] as String;
    final isSelected = selectedCategory == catKey;
    final gradient = cat['gradient'] as List<Color>;
    final accentColor = cat['accent'] as Color;
    final count = state.products.where((p) => p.category == catKey).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onSelectCategory(catKey);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => CategoryProductsScreen(categoryKey: catKey, state: state),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [accentColor.withValues(alpha: 0.18), accentColor.withValues(alpha: 0.06)]
                  : gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? accentColor : accentColor.withValues(alpha: 0.3),
              width: isSelected ? 2.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? accentColor.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                blurRadius: isSelected ? 10 : 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tag & Selection Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat['tag'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: accentColor, fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 10),
                    )
                  else
                    Text('$count items', style: TextStyle(fontSize: 9.5, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),

              // Center Icon Box
              Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(cat['icon'] as String, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 8),

              // Category Title
              Text(
                cat['title'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isSelected ? accentColor : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 1),

              // Subtitle
              Text(
                cat['subtitle'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),

              // Bottom Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cat['badge'] as String,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  Row(
                    children: [
                      Text(
                        isSelected ? 'Active' : 'Shop',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accentColor),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: accentColor),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
