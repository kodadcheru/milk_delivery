import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/product_detail_sheet.dart';
import '../../widgets/home/home_product_card.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryKey;
  final AppState state;

  const CategoryProductsScreen({
    super.key,
    required this.categoryKey,
    required this.state,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  String _searchQuery = '';
  String _filterTag = 'ALL';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getCategoryMetadata(String catKey) {
    switch (catKey) {
      case 'MEAT':
        return {
          'title': 'Meat & Poultry',
          'icon': '🥩',
          'gradient': [const Color(0xFF991B1B), const Color(0xFFDC2626)],
          'accent': const Color(0xFFDC2626),
          'banner': '🥩 Fresh Tender Meat • 100% Antibiotic-Free',
          'subtags': ['ALL', 'CHICKEN', 'MUTTON', 'FRESH CUT'],
        };
      case 'EGGS':
        return {
          'title': 'Farm Fresh Eggs',
          'icon': '🥚',
          'gradient': [const Color(0xFFB45309), const Color(0xFFD97706)],
          'accent': const Color(0xFFD97706),
          'banner': '🥚 Daily Dawn Harvested • Free-Range & Organic',
          'subtags': ['ALL', 'DESI', 'BROWN', 'HIGH PROTEIN'],
        };
      case 'WATER_CAN':
        return {
          'title': 'Pure Water Cans',
          'icon': '💧',
          'gradient': [const Color(0xFF0F766E), const Color(0xFF0D9488)],
          'accent': const Color(0xFF0D9488),
          'banner': '💧 8-Stage RO + UV Purified • Mineral Rich',
          'subtags': ['ALL', '20L CAN', 'DISPENSER', 'MINERAL'],
        };
      case 'PANEER':
        return {
          'title': 'Farm Fresh Paneer',
          'icon': '🧀',
          'gradient': [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
          'accent': const Color(0xFF7C3AED),
          'banner': '🧀 Soft Malai Paneer • Crafted Fresh Daily',
          'subtags': ['ALL', 'MALAI', 'PANEER', 'VACUUM PACK'],
        };
      case 'GHEE':
        return {
          'title': 'Pure Desi Ghee & Butter',
          'icon': '🧈',
          'gradient': [const Color(0xFFD97706), const Color(0xFFF59E0B)],
          'accent': const Color(0xFFD97706),
          'banner': '🧈 Traditional Bilona Vedic Cow Ghee & White Butter',
          'subtags': ['ALL', 'BILONA GHEE', 'BUTTER', 'A2 VEDIC'],
        };
      case 'CURD':
        return {
          'title': 'Natural Set Curd (Dahi)',
          'icon': '🥣',
          'gradient': [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
          'accent': const Color(0xFF0D7C66),
          'banner': '🥣 Probiotic-Rich Natural Set Curd in Eco Tubs',
          'subtags': ['ALL', 'MATKA DAHI', 'SET CURD', 'ORGANIC'],
        };
      case 'BAKERY':
        return {
          'title': 'Artisanal Breads & Bakery',
          'icon': '🍞',
          'gradient': [const Color(0xFFB45309), const Color(0xFFD97706)],
          'accent': const Color(0xFFB45309),
          'banner': '🍞 Fresh Morning Multi-Grain & Sourdough Breads',
          'subtags': ['ALL', 'MULTI-GRAIN', 'SOURDOUGH', 'WHOLE WHEAT'],
        };
      case 'MILK':
      default:
        return {
          'title': 'Fresh Milk & Dairy',
          'icon': '🥛',
          'gradient': [const Color(0xFF0369A1), const Color(0xFF0284C7)],
          'accent': const Color(0xFF0284C7),
          'banner': '🥛 Pure A2 Vedic Desi Cow & Buffalo Milk',
          'subtags': ['ALL', 'COW MILK', 'BUFFALO', 'CURD / DAHI'],
        };
    }
  }

  bool _matchesCategory(String pCat, String catKey) {
    final c = pCat.toUpperCase().replaceAll('&', 'AND').replaceAll('-', '_');
    final k = catKey.toUpperCase().replaceAll('-', '_');
    if (c == k) return true;
    if (k == 'MILK' && (c.contains('MILK') || c.contains('DAIRY'))) return true;
    if (k == 'EGGS' && (c.contains('EGG') || c.contains('COUNTRY'))) return true;
    if (k == 'MEAT' && (c.contains('MEAT') || c.contains('CHICKEN') || c.contains('MUTTON') || c.contains('POULTRY'))) return true;
    if (k == 'WATER_CAN' && (c.contains('WATER') || c.contains('CAN') || c.contains('MINERAL'))) return true;
    if (k == 'PANEER' && c.contains('PANEER')) return true;
    if (k == 'GHEE' && (c.contains('GHEE') || c.contains('BUTTER'))) return true;
    if (k == 'CURD' && (c.contains('CURD') || c.contains('DAHI') || c.contains('YOGURT'))) return true;
    if (k == 'BAKERY' && (c.contains('BREAD') || c.contains('BAKERY'))) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final meta = _getCategoryMetadata(widget.categoryKey);
    final accent = meta['accent'] as Color;
    final gradient = meta['gradient'] as List<Color>;
    final subtags = meta['subtags'] as List<String>;

    // Filter products dynamically for this category + search + subtag
    final categoryProducts = widget.state.products.where((p) {
      if (!_matchesCategory(p.category, widget.categoryKey)) return false;

      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesTag = _filterTag == 'ALL' ||
          p.name.toUpperCase().contains(_filterTag) ||
          p.description.toUpperCase().contains(_filterTag);

      return matchesQuery && matchesTag;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(meta['icon'] as String, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  meta['title'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Text(
              '${categoryProducts.length} Products • Tomorrow 06:00 AM Delivery',
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🔗 Sharing link to ${meta['title']} catalog!')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Text(meta['icon'] as String, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                              child: const Text('100% QUALITY ASSURED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta['banner'] as String,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '⚡ Milked/Packed at 3 AM • Delivered by 6 AM',
                              style: TextStyle(color: Colors.white70, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search ${meta['title']}...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0D7C66), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Subtag Quick Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: subtags.map((tag) {
                      final isSelected = _filterTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _filterTag = tag),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? accent : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? accent : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              tag == 'ALL' ? 'All Varieties' : tag,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Products Count Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${categoryProducts.length} Items',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text('FSSAI Lab Certified', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category Products Grid
                if (categoryProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          const Text('No products match your search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Try clearing the search or filter tags', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryProducts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                    ),
                    itemBuilder: (context, index) {
                      final item = categoryProducts[index];
                      return HomeProductCard(state: widget.state, item: item);
                    },
                  ),
              ],
            ),
          ),

          // Floating Cart Bar
          if (widget.state.totalCartItemCount > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FloatingCartBar(state: widget.state),
            ),
        ],
      ),
    );
  }
}
