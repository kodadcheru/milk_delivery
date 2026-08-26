import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

import '../../providers/app_state.dart';
import '../../models/product_model.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/shimmer_loading.dart';

import '../../widgets/home/home_location_bar.dart';
import '../../widgets/home/home_active_subscription_card.dart';
import '../../widgets/home/home_category_showcase.dart';
import '../../widgets/home/home_product_card.dart';
import '../../widgets/home/home_trust_assurance_strip.dart';
import '../../widgets/home/home_serving_soon_view.dart';
import '../../widgets/home/home_location_sheet.dart';

class CustomerHomeTab extends StatefulWidget {
  final AppState state;

  const CustomerHomeTab({super.key, required this.state});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

typedef HomeTab = CustomerHomeTab;

class _CustomerHomeTabState extends State<CustomerHomeTab>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Staggered entry animation
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _searchController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSub = widget.state.subscriptions
        .where((s) => s.status == 'ACTIVE')
        .firstOrNull;

    // Show ALL products by default, filtered only by search query
    final filteredProducts = widget.state.products.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.badgeText.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Stack(
      children: [
        RefreshIndicator(
          color: UiTone.primary,
          onRefresh: () async {
            await widget.state.reloadAllData();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── 1. Hero Green Gradient Banner with Integrated Search Bar ──
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

              if (!widget.state.isLocationCovered) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: HomeServingSoonView(
                    state: widget.state,
                    onSelectZoneTap: () => HomeLocationSheet.show(context, widget.state),
                  ),
                ),
              ] else ...[
                // ── Active Subscription Snapshot ──
                if (activeSub != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: HomeActiveSubscriptionCard(state: widget.state, sub: activeSub),
                    ),
                  ),
                ],

                // ── Category Grid ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: HomeCategoryShowcase(
                      state: widget.state,
                    ),
                  ),
                ),

                // ── 6. Section Title: Popular Products ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.state.isTelugu ? 'ప్రజాదరణ పొందిన ఉత్పత్తులు' : 'Popular Products',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: UiTone.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.state.isTelugu
                              ? '${filteredProducts.length} ఉత్పత్తులు ఉదయం డెలివరీకి సిద్ధంగా ఉన్నాయి'
                              : '${filteredProducts.length} items available for doorstep delivery',
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

                // ── 7. Product Grid (ALL products) ──
                _buildProductGrid(filteredProducts),

                // ── 8. Trust Assurance Strip ──
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
      final error = widget.state.errorMessage;
      if (error != null) {
        // (a) Something failed to load — offer a retry.
        return SliverToBoxAdapter(
          child: _emptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load products",
            subtitle: error,
            onRetry: () => widget.state.reloadAllData(),
          ),
        );
      }
      if (_searchQuery.isNotEmpty) {
        // (b) The catalog has items, just none matching this query.
        return SliverToBoxAdapter(
          child: _emptyState(
            icon: Icons.search_off_rounded,
            title: 'No results for "$_searchQuery"',
            subtitle: 'Try milk, meat, eggs, or water can',
          ),
        );
      }
      // (c) Genuinely empty catalog.
      return SliverToBoxAdapter(
        child: _emptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No products yet',
          subtitle: 'Fresh stock is on its way — check back soon',
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

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
  }) {
    return Padding(
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
              child: Icon(icon, size: 40, color: UiTone.primary),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: UiText.title),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: UiText.label),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UiTone.primary,
                  side: const BorderSide(color: UiTone.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
