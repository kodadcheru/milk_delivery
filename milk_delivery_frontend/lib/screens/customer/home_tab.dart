import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

import '../../providers/app_state.dart';
import '../../models/product_model.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/shimmer_loading.dart';

import '../../widgets/home/home_location_bar.dart';
import '../../widgets/home/home_pinned_search_bar.dart';
import '../../widgets/home/home_story_reels.dart';
import '../../widgets/home/home_wallet_vacation_card.dart';
import '../../widgets/home/home_promo_carousel.dart';
import '../../widgets/home/home_quick_chips.dart';
import '../../widgets/home/home_active_subscription_card.dart';
import '../../widgets/home/home_category_showcase.dart';
import '../../widgets/home/home_search_filter_bar.dart';
import '../../widgets/home/home_product_card.dart';
import '../../widgets/home/home_trust_assurance_strip.dart';
import '../../widgets/home/home_serving_soon_view.dart';
import '../../widgets/home/home_location_sheet.dart';
import '../../widgets/home/home_topup_dialog.dart';

class CustomerHomeTab extends StatefulWidget {
  final AppState state;

  const CustomerHomeTab({super.key, required this.state});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

typedef HomeTab = CustomerHomeTab;

class _CustomerHomeTabState extends State<CustomerHomeTab>
    with TickerProviderStateMixin {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  late final PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  // Staggered entry animation
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(viewportFraction: 0.92);
    _startBannerAutoSlide();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    _entryController.forward();

    // Automatically detect customer location & sync address book on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.initDevicePermissionsAndLocation();
    });
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_bannerController.hasClients) return;
      final nextIndex = (_currentBannerIndex + 1) % 4;
      _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSub = widget.state.subscriptions.isNotEmpty
        ? widget.state.subscriptions.first
        : null;

    // Filter products dynamically across the 4 core categories
    final filteredProducts = widget.state.products.where((p) {
      final matchesCategory = _selectedCategory == 'ALL' ||
          (_selectedCategory == 'MILK' && p.category == 'MILK') ||
          (_selectedCategory == 'MEAT' && p.category == 'MEAT') ||
          (_selectedCategory == 'EGGS' && p.category == 'EGGS') ||
          (_selectedCategory == 'WATER_CAN' && p.category == 'WATER_CAN');

      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.badgeText.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesQuery;
    }).toList();

    return Stack(
      children: [
        RefreshIndicator(
          color: UiTone.primary,
          onRefresh: () async {
            await widget.state.initDevicePermissionsAndLocation();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── 1. Hero Green Gradient Banner (full-bleed) ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _entryFade,
                  child: SlideTransition(
                    position: _entrySlide,
                    child: HomeLocationBar(
                      state: widget.state,
                      onLocationTap: () => HomeLocationSheet.show(context, widget.state),
                      searchController: _searchController,
                      onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                      onClearSearch: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  ),
                ),
              ),

              // ── 2. Pinned Frosted Glass Search Bar ──
              HomePinnedSearchBar(
                controller: _searchController,
                onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),

              // ── 3. Story Reels ──
              const SliverToBoxAdapter(
                child: HomeStoryReels(),
              ),

              // ── 4. Wallet & Vacation Card ──
              SliverToBoxAdapter(
                child: HomeWalletVacationCard(
                  state: widget.state,
                  onRechargeTap: () => HomeTopUpDialog.show(context, widget.state),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              if (!widget.state.isLocationCovered) ...[
                SliverToBoxAdapter(
                  child: HomeServingSoonView(
                    state: widget.state,
                    onSelectZoneTap: () => HomeLocationSheet.show(context, widget.state),
                  ),
                ),
              ] else ...[
                // ── 5. Promo Carousel ──
                SliverToBoxAdapter(
                  child: HomePromoCarousel(
                    state: widget.state,
                    controller: _bannerController,
                    currentIndex: _currentBannerIndex,
                    onPageChanged: (idx) => setState(() => _currentBannerIndex = idx),
                  ),
                ),

                // ── 6. Quick Action Gradient Chips ──
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: HomeQuickChips(),
                  ),
                ),

                // ── Active Subscription Snapshot ──
                if (activeSub != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: HomeActiveSubscriptionCard(state: widget.state, sub: activeSub),
                    ),
                  ),
                ],

                // ── 7. Section Title: Explore Categories ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Explore Essential Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: UiTone.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Professional quality at your doorstep',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 8. Category Filter Scrollbar (horizontal pills) ──
                SliverToBoxAdapter(
                  child: HomeSearchFilterBar(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                    onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),

                // ── 9. 3-Column Category Grid ──
                SliverToBoxAdapter(
                  child: HomeCategoryShowcase(
                    state: widget.state,
                    selectedCategory: _selectedCategory,
                    onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                  ),
                ),

                // ── 10. Section Title: Products ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCategory == 'MILK'
                              ? '🥛 Farm Fresh Milk & Dairy'
                              : _selectedCategory == 'MEAT'
                                  ? '🥩 Tender Meat & Chicken'
                                  : _selectedCategory == 'EGGS'
                                      ? '🥚 Farm Fresh Eggs'
                                      : _selectedCategory == 'WATER_CAN'
                                          ? '💧 Mineral & Purified Water'
                                          : 'Popular Products',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: UiTone.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filteredProducts.length} items available for doorstep delivery',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── 11. Product Grid (2-column SliverGrid) ──
                _buildProductGrid(filteredProducts),

                // ── 12. Trust Assurance Strip ──
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: HomeTrustAssuranceStrip(),
                  ),
                ),
              ],

              // Bottom spacer
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),

        // ── Persistent Floating Smart Cart ──
        if (widget.state.totalCartItemCount > 0 && widget.state.isLocationCovered)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FloatingCartBar(state: widget.state),
          ),
      ],
    );
  }

  // ── Product Grid as Sliver ──
  Widget _buildProductGrid(List<ProductModel> productList) {
    if (widget.state.isLoading && productList.isEmpty) {
      return const SliverToBoxAdapter(child: ProductGridSkeleton());
    }

    if (productList.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: UiTone.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_off_rounded, size: 40, color: UiTone.primary),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No products match your search',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try searching for milk, meat, eggs, or water can',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.76,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return HomeProductCard(
              state: widget.state,
              item: productList[index],
            );
          },
          childCount: productList.length,
        ),
      ),
    );
  }
}
