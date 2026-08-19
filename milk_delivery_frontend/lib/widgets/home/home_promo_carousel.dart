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
      'title': 'Pure A2 Vedic Desi Cow Milk',
      'subtitle': 'Zero preservatives, direct farm dispatch by 6 AM',
      'tag': '100% ORGANIC',
      'colors': [Color(0xFF0D7C66), Color(0xFF042F2E)],
      'btn': 'Subscribe Milk 🥛',
      'cat': 'MILK',
    },
    {
      'title': 'Mineral Pure 20L Water Cans',
      'subtitle': 'Strict 8-stage RO+UV quality certified pure water',
      'tag': 'ESSENTIAL',
      'colors': [Color(0xFF0369A1), Color(0xFF075985)],
      'btn': 'Order Water 💧',
      'cat': 'WATER_CAN',
    },
    {
      'title': 'Farm Free-Range Country Eggs',
      'subtitle': 'Rich in protein & vitamins, fresh each dawn',
      'tag': 'HEALTH FIRST',
      'colors': [Color(0xFFB45309), Color(0xFF78350F)],
      'btn': 'Get Eggs 🥚',
      'cat': 'EGGS',
    },
    {
      'title': 'Antibiotic-Free Fresh Cuts & Meat',
      'subtitle': 'Hygienically vacuum-sealed, tender premium cuts',
      'tag': 'FRESH CUT',
      'colors': [Color(0xFF991B1B), Color(0xFF7F1D1D)],
      'btn': 'Fresh Meat 🍗',
      'cat': 'MEAT',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: controller,
            itemCount: promos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) {
              final p = promos[i];
              final colors = p['colors'] as List<Color>;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: InkWell(
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
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['tag'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 15),
                                SizedBox(width: 3),
                                Text(
                                  'Quality Assured',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p['subtitle'] as String,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.electric_bolt_rounded, color: Colors.amber, size: 14),
                                SizedBox(width: 2),
                                Text(
                                  'Guaranteed 06:00 AM Delivery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                p['btn'] as String,
                                style: TextStyle(
                                  color: colors.first,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Animated Dot Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promos.length, (idx) {
            final isActive = currentIndex == idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }
}
