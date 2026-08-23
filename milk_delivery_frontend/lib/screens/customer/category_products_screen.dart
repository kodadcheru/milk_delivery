import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/category_catalog.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/floating_cart_bar.dart';
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
    final meta = categoryMetaFor(widget.categoryKey);
    final accent = meta.accent;
    final gradient = meta.gradient;
    final subtags = meta.subtags;

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
        backgroundColor: UiTone.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(meta.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  meta.longTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Text(
              '${categoryProducts.length} Products • Tomorrow 06:00 AM Delivery',
              style: const TextStyle(color: UiTone.success, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🔗 Sharing link to ${meta.longTitle} catalog!')),
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
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Text(meta.icon, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(UiRadius.xs)),
                              child: const Text('100% QUALITY ASSURED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta.banner,
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
                  style: UiText.body,
                  decoration: InputDecoration(
                    hintText: 'Search ${meta.longTitle}...',
                    hintStyle: const TextStyle(color: UiText.muted, fontSize: 13, fontWeight: FontWeight.w500),
                    prefixIcon: const Icon(Icons.search_rounded, color: UiTone.primary, size: 20),
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
                    fillColor: UiTone.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm), borderSide: BorderSide.none),
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
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? accent : UiTone.surfaceMuted,
                              borderRadius: BorderRadius.circular(UiRadius.sm),
                              border: Border.all(color: isSelected ? accent : UiTone.surfaceBorder),
                            ),
                            child: Text(
                              tag == 'ALL' ? 'All Varieties' : tag,
                              style: TextStyle(
                                color: isSelected ? Colors.white : UiTone.ink,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: UiTone.success),
                        SizedBox(width: 4),
                        Text('FSSAI Lab Certified', style: TextStyle(color: UiTone.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category Products Grid
                if (categoryProducts.isEmpty)
                  _buildEmptyState()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryProducts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.76,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 18,
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

  Widget _buildEmptyState() {
    // Distinguish "nothing matches the active search/filter" from an empty category.
    final isFiltered = _searchQuery.isNotEmpty || _filterTag != 'ALL';
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UiTone.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                size: 40,
                color: UiTone.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isFiltered ? 'No matches' : 'No products yet',
              textAlign: TextAlign.center,
              style: UiText.title,
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Try clearing the search or filter tags'
                  : 'Fresh stock is on its way — check back soon',
              textAlign: TextAlign.center,
              style: UiText.label,
            ),
          ],
        ),
      ),
    );
  }
}
