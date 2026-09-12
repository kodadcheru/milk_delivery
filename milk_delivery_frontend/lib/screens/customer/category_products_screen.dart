import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../theme/category_catalog.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/cart/floating_cart_bar.dart' as cart;
import '../customer/cart_page.dart';
import '../../widgets/home/home_product_card.dart';
import '../../widgets/shimmer_loading.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String? categoryKey;
  final CategoryModel? category;
  final AppState state;

  const CategoryProductsScreen({
    super.key,
    this.categoryKey,
    this.category,
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

  /// Resolve the active category completely from backend data.
  CategoryModel get activeCategory {
    if (widget.category != null) return widget.category!;
    final raw = (widget.categoryKey ?? '').trim();
    if (raw.isEmpty) {
      return widget.state.categories.isNotEmpty
          ? widget.state.categories.first
          : const CategoryModel(id: 0, name: 'Products', slug: 'products', icon: '🥛');
    }

    final key = raw.toLowerCase();
    final normKey = key.replaceAll('-', '_');

    return widget.state.categories.firstWhere(
      (c) {
        final cSlug = c.slug.toLowerCase();
        final cName = c.name.toLowerCase();
        final cNorm = cSlug.replaceAll('-', '_');
        return cSlug == key ||
            cName == key ||
            cNorm == normKey ||
            c.id.toString() == key;
      },
      orElse: () {
        final meta = categoryMetaFor(raw);
        return CategoryModel(
          id: 0,
          name: meta.longTitle,
          slug: raw,
          icon: meta.icon,
          description: meta.banner,
          qualityBadgeTitle: '100% QUALITY ASSURED',
        );
      },
    );
  }

  /// Match product to category accurately using backend ID, name, or slug.
  bool _matchesCategory(ProductModel p, CategoryModel cat) {
    if (cat.id > 0 && p.categoryId == cat.id) return true;

    final pCat = p.category.trim().toLowerCase();
    final catName = cat.name.trim().toLowerCase();
    final catSlug = cat.slug.trim().toLowerCase();

    if (pCat == catName || pCat == catSlug) return true;

    final normP = pCat.replaceAll('&', 'and').replaceAll('-', '_');
    final normSlug = catSlug.replaceAll('&', 'and').replaceAll('-', '_');
    final normName = catName.replaceAll('&', 'and').replaceAll('-', '_');

    if (normP == normSlug || normP == normName) return true;

    // Semantic fallbacks if backend category mapping is loosely labeled
    if (normSlug.contains('water') && (normP.contains('water') || p.name.toLowerCase().contains('water'))) return true;
    if (normSlug.contains('egg') && (normP.contains('egg') || p.name.toLowerCase().contains('egg'))) return true;
    if (normSlug.contains('dairy') && (normP.contains('dairy') || normP.contains('ghee') || normP.contains('butter') || normP.contains('makkhan'))) return true;
    if (normSlug.contains('milk') && !normSlug.contains('dairy') && normP.contains('milk') && !normP.contains('butter') && !normP.contains('ghee')) return true;
    if (normSlug.contains('meat') && (normP.contains('meat') || normP.contains('chicken') || normP.contains('mutton'))) return true;
    if (normSlug.contains('paneer') && normP.contains('paneer')) return true;
    if (normSlug.contains('ghee') && (normP.contains('ghee') || normP.contains('butter'))) return true;
    if (normSlug.contains('curd') && (normP.contains('curd') || normP.contains('dahi'))) return true;
    if (normSlug.contains('bakery') && (normP.contains('bread') || normP.contains('bakery'))) return true;

    return false;
  }

  /// Dynamically derive subtag filter chips from the actual products in this category.
  List<String> _deriveSubtags(List<ProductModel> products) {
    final tags = <String>{'ALL'};
    for (final p in products) {
      if (p.badgeText.isNotEmpty && p.badgeText != 'Bestseller' && p.badgeText.length <= 16) {
        final clean = p.badgeText.replaceAll(RegExp(r'[^\w\s]'), '').trim().toUpperCase();
        if (clean.isNotEmpty && clean.length > 2) tags.add(clean);
      }
      if (p.unitQuantity.isNotEmpty) {
        tags.add(p.unitQuantity.toUpperCase());
      }
    }

    // Contextual keywords present in product names
    for (final p in products) {
      final nameUpper = p.name.toUpperCase();
      for (final kw in [
        'COW MILK',
        'BUFFALO',
        'A2 VEDIC',
        'TONED',
        '20L CAN',
        'DISPENSER',
        'MINERAL',
        'COUNTRY',
        'ORGANIC',
        'BROWN',
        'WHITE',
        'PACK OF 12',
        'PACK OF 6',
        'BUTTER',
        'BILONA GHEE',
        'PANEER',
        'CURD'
      ]) {
        if (nameUpper.contains(kw)) {
          tags.add(kw);
        }
      }
    }
    return tags.take(7).toList();
  }

  /// Select a harmonious visual palette based on category theme.
  (Color accent, List<Color> gradient) _resolveTheme(CategoryModel cat) {
    if (cat.parsedGradientColors.length >= 2) {
      final accent = cat.parsedTileFgColor ?? cat.parsedGradientColors.first;
      return (accent, cat.parsedGradientColors);
    }
    final slug = cat.slug.toLowerCase().replaceAll('-', '_');
    if (slug.contains('water')) {
      return (const Color(0xFF0D9488), [const Color(0xFF0F766E), const Color(0xFF0D9488)]);
    } else if (slug.contains('egg')) {
      return (const Color(0xFFD97706), [const Color(0xFFB45309), const Color(0xFFD97706)]);
    } else if (slug.contains('meat')) {
      return (const Color(0xFFDC2626), [const Color(0xFF991B1B), const Color(0xFFDC2626)]);
    } else if (slug.contains('dairy') || slug.contains('ghee') || slug.contains('butter')) {
      return (const Color(0xFFD97706), [const Color(0xFFD97706), const Color(0xFFF59E0B)]);
    } else if (slug.contains('paneer')) {
      return (const Color(0xFF7C3AED), [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)]);
    } else if (slug.contains('curd')) {
      return (const Color(0xFF0D7C66), [const Color(0xFF0D9488), const Color(0xFF14B8A6)]);
    } else if (slug.contains('bakery')) {
      return (const Color(0xFFB45309), [const Color(0xFFB45309), const Color(0xFFD97706)]);
    }
    return (const Color(0xFF0284C7), [const Color(0xFF0369A1), const Color(0xFF0284C7)]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final cat = activeCategory;
    final (accent, gradient) = _resolveTheme(cat);

    // All products matching this category
    final matchingProducts = widget.state.products.where((p) => _matchesCategory(p, cat)).toList();

    // Dynamically derived subtags from actual product data or backend Category definition
    final subtags = cat.subtags.isNotEmpty ? cat.subtags : _deriveSubtags(matchingProducts);

    // Filter products dynamically for this category + search + subtag
    final categoryProducts = matchingProducts.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesTag = _filterTag == 'ALL' ||
          p.name.toUpperCase().contains(_filterTag) ||
          p.badgeText.toUpperCase().contains(_filterTag) ||
          p.unitQuantity.toUpperCase().contains(_filterTag) ||
          p.description.toUpperCase().contains(_filterTag);

      return matchesQuery && matchesTag;
    }).toList();

    final categoryName = cat.localizedName(widget.state.currentLanguage);
    final bannerHeadline = cat.localizedBanner(widget.state.currentLanguage).isNotEmpty
        ? cat.localizedBanner(widget.state.currentLanguage)
        : (cat.description.isNotEmpty ? cat.description : cat.name);
    final bannerSubtitle = cat.localizedSubtitle(widget.state.currentLanguage).isNotEmpty
        ? cat.localizedSubtitle(widget.state.currentLanguage)
        : (widget.state.isTelugu
            ? '⚡ నాణ్యమైన ఉత్పత్తులు • ఉదయం 6 గంటలకు డెలివరీ'
            : '⚡ Milked/Harvested Fresh • Delivered by 6 AM');
    final qualityBadge = cat.qualityBadgeTitle.isNotEmpty
        ? cat.qualityBadgeTitle
        : (widget.state.isTelugu ? '100% నాణ్యతా హామీ' : '100% QUALITY ASSURED');

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
            Text(
              categoryName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              widget.state.isTelugu
                  ? '${categoryProducts.length} వస్తువులు • రేపు 06:00 AM డెలివరీ'
                  : '${categoryProducts.length} Products • Tomorrow 06:00 AM Delivery',
              style: const TextStyle(color: UiTone.success, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.state.isTelugu
                        ? '🔗 $categoryName కేటలాగ్ లింక్ షేర్ చేయండి!'
                        : '🔗 Sharing link to $categoryName catalog!',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // Extra bottom padding (140) ensures bottom cards are NEVER covered by the floating cart bar
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Hero Banner (100% sourced from backend Category model)
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
                      if (cat.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(UiRadius.md),
                          child: Image.network(
                            cat.imageUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(UiRadius.md),
                              ),
                              child: const Icon(Icons.category_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(UiRadius.md),
                          ),
                          child: const Icon(Icons.category_rounded, color: Colors.white, size: 28),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(UiRadius.xs)),
                              child: Text(
                                qualityBadge,
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bannerHeadline,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bannerSubtitle,
                              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
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
                    hintText: widget.state.isTelugu ? '$categoryName వెతకండి...' : 'Search $categoryName...',
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

                // Dynamic Subtag Quick Filters (from actual products)
                if (subtags.length > 1)
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
                                tag == 'ALL' ? (widget.state.isTelugu ? 'అన్నీ' : 'All Varieties') : tag,
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
                      widget.state.isTelugu
                          ? '${categoryProducts.length} వస్తువులు ప్రదర్శించబడుతున్నాయి'
                          : 'Showing ${categoryProducts.length} Items',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 14, color: UiTone.success),
                        const SizedBox(width: 4),
                        Text(
                          widget.state.isTelugu ? 'FSSAI ల్యాబ్ ధృవీకరించబడింది' : 'FSSAI Lab Certified',
                          style: const TextStyle(color: UiTone.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category Products Grid
                if (widget.state.isLoading && categoryProducts.isEmpty)
                  const ProductGridSkeleton()
                else if (categoryProducts.isEmpty)
                  _buildEmptyState()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryProducts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.71,
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
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: AnimatedSlide(
              offset: widget.state.totalCartItemCount > 0 ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: widget.state.totalCartItemCount > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: widget.state.totalCartItemCount == 0,
                  child: cart.FloatingCartBar(
                    state: widget.state,
                    onViewCart: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CartPage(state: widget.state),
                      ));
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildEmptyState() {
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
              isFiltered
                  ? (widget.state.isTelugu ? 'ఫలితాలు లేవు' : 'No matches')
                  : (widget.state.isTelugu ? 'వస్తువులు ఇంకా లేవు' : 'No products yet'),
              textAlign: TextAlign.center,
              style: UiText.title,
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? (widget.state.isTelugu ? 'శోధన పదాన్ని మార్చి ప్రయత్నించండి' : 'Try clearing the search or filter tags')
                  : (widget.state.isTelugu ? 'తాజా సరుకు త్వరలోనే అందుబాటులోకి వస్తుంది' : 'Fresh stock is on its way — check back soon'),
              textAlign: TextAlign.center,
              style: UiText.label,
            ),
          ],
        ),
      ),
    );
  }
}
