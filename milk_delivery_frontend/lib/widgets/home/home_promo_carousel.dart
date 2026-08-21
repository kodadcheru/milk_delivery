import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/category_products_screen.dart';

class HomePromoCarousel extends StatelessWidget {
  final AppState state;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const HomePromoCarousel({
    super.key,
    required this.state,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  static const List<Map<String, dynamic>> promos = [
    {
      'title': 'A2 Desi Cow Milk',
      'subtitle': 'Farm-fresh daily starting ₹72/litre',
      'badge': '100% ORGANIC',
      'colors': [Color(0xFF059669), Color(0xFF047857)],
      'icon': Icons.local_drink_rounded,
      'cat': 'MILK',
    },
    {
      'title': '20L Pure Water Cans',
      'subtitle': 'RO purified doorstep delivery',
      'badge': 'MINERAL RICH',
      'colors': [Color(0xFF0284C7), Color(0xFF0369A1)],
      'icon': Icons.water_drop_rounded,
      'cat': 'WATER_CAN',
    },
    {
      'title': 'Farm Fresh Desi Eggs',
      'subtitle': 'High protein brown & white eggs',
      'badge': 'FREE RANGE',
      'colors': [Color(0xFFD97706), Color(0xFFB45309)],
      'icon': Icons.egg_rounded,
      'cat': 'EGGS',
    },
    {
      'title': 'Fresh Cut Chicken & Mutton',
      'subtitle': 'Halal certified tender cuts',
      'badge': 'ANTIBIOTIC FREE',
      'colors': [Color(0xFFDC2626), Color(0xFF991B1B)],
      'icon': Icons.restaurant_rounded,
      'cat': 'MEAT',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: controller,
            itemCount: promos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) {
              final p = promos[i];
              final colors = p['colors'] as List<Color>;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => CategoryProductsScreen(
                          categoryKey: p['cat'] as String,
                          state: state,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  p['badge'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p['subtitle'] as String,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            p['icon'] as IconData,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promos.length, (idx) {
            final isActive = currentIndex == idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: isActive ? 16 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}
