import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/category_products_screen.dart';
import '../../theme/ui_tokens.dart';

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

  /// Two flagship staples only. The category grid is the primary browse
  /// surface, so the carousel intentionally spotlights the daily essentials
  /// (fresh milk + water cans) instead of mirroring every category tile.
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
                      borderRadius: BorderRadius.circular(UiRadius.md),
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
                                  borderRadius: BorderRadius.circular(UiRadius.pill),
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
                color: isActive ? UiTone.primary : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(UiRadius.pill),
              ),
            );
          }),
        ),
      ],
    );
  }
}
