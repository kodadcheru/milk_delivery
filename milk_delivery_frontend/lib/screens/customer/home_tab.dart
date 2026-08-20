import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/product_model.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/shimmer_loading.dart';

import '../../widgets/home/home_location_bar.dart';
import '../../widgets/home/home_morning_dispatch_capsule.dart';
import '../../widgets/home/home_story_reels.dart';
import '../../widgets/home/home_wallet_vacation_card.dart';
import '../../widgets/home/home_promo_carousel.dart';
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

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  late final PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(viewportFraction: 0.92);
    _startBannerAutoSlide();

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
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSub = widget.state.subscriptions.isNotEmpty ? widget.state.subscriptions.first : null;

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
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Location Bar with OpenStreetMap GPS ──
              HomeLocationBar(
                state: widget.state,
                onLocationTap: () => HomeLocationSheet.show(context, widget.state),
              ),

              // ── 2. Next-Gen Hero Morning Dispatch Countdown Capsule ──
              HomeMorningDispatchCapsule(state: widget.state),

              // ── 3. Interactive Farm Story Highlights / Reels ──
              const HomeStoryReels(),

              // ── 4. Prepaid Wallet Balance & Vacation Banner ──
              HomeWalletVacationCard(
                state: widget.state,
                onRechargeTap: () => HomeTopUpDialog.show(context, widget.state),
              ),

              const SizedBox(height: 14),

              if (!widget.state.isLocationCovered) ...[
                HomeServingSoonView(
                  state: widget.state,
                  onSelectZoneTap: () => HomeLocationSheet.show(context, widget.state),
                ),
              ] else ...[
                // ── 5. Promotional Carousel ──
                HomePromoCarousel(
                  state: widget.state,
                  controller: _bannerController,
                  currentIndex: _currentBannerIndex,
                  onPageChanged: (idx) => setState(() => _currentBannerIndex = idx),
                ),

                const SizedBox(height: 16),

                // ── 6. Active Subscription Snapshot (if any) ──
                if (activeSub != null) ...[
                  HomeActiveSubscriptionCard(state: widget.state, sub: activeSub),
                  const SizedBox(height: 16),
                ],

                // ── 5. PROMINENT 4 CORE CATEGORIES MEGA SHOWCASE ──
                HomeCategoryShowcase(
                  state: widget.state,
                  selectedCategory: _selectedCategory,
                  onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                ),

                const SizedBox(height: 18),

                // ── 6. Search Bar & Category Quick Chips ──
                HomeSearchFilterBar(
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

                const SizedBox(height: 16),

                // ── 7. Catalog Section Header ──
                _buildSectionHeader(
                  context,
                  _selectedCategory == 'MILK'
                      ? '🥛 Farm Fresh Milk & Dairy'
                      : _selectedCategory == 'MEAT'
                          ? '🥩 Tender Meat & Chicken'
                          : _selectedCategory == 'EGGS'
                              ? '🥚 Farm Fresh Eggs'
                              : _selectedCategory == 'WATER_CAN'
                                  ? '💧 Mineral & Purified Water Cans'
                                  : 'Daily Essentials Catalog',
                  '${filteredProducts.length} items available for doorstep morning 06:00 AM delivery',
                ),
                const SizedBox(height: 12),

                // ── 8. Dynamic Product Grid ──
                _buildProductGrid(context, filteredProducts),

                const SizedBox(height: 24),

                // ── 9. Trust & Quality Assurance Strip ──
                const HomeTrustAssuranceStrip(),
              ],

              const SizedBox(height: 20),
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

  // ── Catalog Section Header ──
  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ── Dynamic Product Grid ──
  Widget _buildProductGrid(BuildContext context, List<ProductModel> productList) {
    if (widget.state.isLoading && productList.isEmpty) {
      return const ProductGridSkeleton();
    }

    if (productList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Text('🔍', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              const Text('No products match your search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Try searching for milk, meat, eggs, or water can', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < productList.length; i += 2) {
      final p1 = productList[i];
      final p2 = (i + 1 < productList.length) ? productList[i + 1] : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: HomeProductCard(state: widget.state, item: p1)),
              const SizedBox(width: 12),
              if (p2 != null)
                Expanded(child: HomeProductCard(state: widget.state, item: p2))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: rows),
    );
  }
}
