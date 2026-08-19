import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/product_model.dart';
import '../../models/subscription_model.dart';
import '../../services/location_service.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/product_detail_sheet.dart';
import '../../widgets/service_area_sheet.dart';
import '../../widgets/shimmer_loading.dart';
import 'address_book_screen.dart';
import 'category_products_screen.dart';
import 'map_location_picker_screen.dart';

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
              _buildLocationBar(context),

              // ── 2. Prepaid Wallet Balance & Vacation Banner ──
              _buildWalletAndVacationBanner(context),

              const SizedBox(height: 16),

              if (!widget.state.isLocationCovered) ...[
                _buildServingSoonView(context),
              ] else ...[
                // ── 3. Promotional Carousel ──
                _buildHeroPromoCarousel(context),

                const SizedBox(height: 18),

                // ── 4. Active Subscription Snapshot (if any) ──
                if (activeSub != null) ...[
                  _buildActiveSubscriptionCard(context, activeSub),
                  const SizedBox(height: 18),
                ],

                // ── 5. PROMINENT 4 CORE CATEGORIES MEGA SHOWCASE ──
                _buildMegaCategoriesShowcase(context),

                const SizedBox(height: 18),

                // ── 6. Search Bar & Category Quick Chips ──
                _buildSearchAndFilterBar(context),

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
                _buildTrustAssuranceStrip(context),
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

  // ── 1. Location Bar with Address Book & Live GPS ──
  Widget _buildLocationBar(BuildContext context) {
    final activeAddr = widget.state.activeAddress;
    final address = activeAddr?.summaryAddress ?? widget.state.currentDeliveryAddress;
    final iconText = activeAddr?.icon ?? '📍';
    final titleText = activeAddr != null ? '${activeAddr.title} • ' : '';
    final isDetecting = widget.state.isDetectingLocation;

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showLocationSelectorSheet(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(iconText, style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                activeAddr != null ? 'DELIVERING TO (${activeAddr.displayType.toUpperCase()})' : 'DELIVERING TO (LIVE GPS)',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                              ),
                              if (isDetecting)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: SizedBox(width: 8, height: 8, child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 1.5)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$titleText$address',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => AddressBookScreen(state: widget.state),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 4),
                  Text('Book', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Wallet & Vacation Banner ──
  Widget _buildWalletAndVacationBanner(BuildContext context) {
    final bal = widget.state.currentUser?.walletBalance ?? 500.00;
    int estDays = (bal / 72.0).floor();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('PREPAID MILK WALLET', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                            child: const Text('AUTO-DEBIT 🟢', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${bal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        estDays > 0 ? '✨ Covers approx. $estDays days of morning deliveries' : '⚠️ Low balance! Recharge for uninterrupted milk',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _showTopUpDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Color(0xFF0D7C66)),
                        SizedBox(width: 4),
                        Text(
                          'Recharge',
                          style: TextStyle(color: Color(0xFF0D7C66), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subscription Status Strip
          if (widget.state.subscriptions.any((s) => s.status == 'ACTIVE')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.state.isVacationMode ? Icons.beach_access_rounded : Icons.schedule_rounded,
                    color: widget.state.isVacationMode ? Colors.amber : const Color(0xFF10B981),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.state.isVacationMode
                          ? '⏸ Vacation Pause Active (Deliveries on hold)'
                          : '🟢 Morning Deliveries Active: Tomorrow 06:00 AM',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.state.toggleVacationMode(!widget.state.isVacationMode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: !widget.state.isVacationMode ? Colors.amber[900] : const Color(0xFF0D7C66),
                          content: Text(!widget.state.isVacationMode ? '⏸ Vacation Mode turned ON.' : '▶️ Vacation Mode turned OFF.'),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      widget.state.isVacationMode ? 'Resume' : 'Pause',
                      style: TextStyle(
                        color: widget.state.isVacationMode ? Colors.amber : const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.explore_outlined, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🌱 No Active Subscriptions • Subscribe below for 6 AM milk',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Promotional Carousel with Smooth Auto-Slide ──
  Widget _buildHeroPromoCarousel(BuildContext context) {
    final promos = [
      {
        'title': 'Pure A2 Vedic Desi Cow Milk',
        'subtitle': 'Zero preservatives, direct farm dispatch by 6 AM',
        'tag': '100% ORGANIC',
        'colors': [const Color(0xFF0D7C66), const Color(0xFF042F2E)],
        'btn': 'Subscribe Milk 🥛',
        'cat': 'MILK',
      },
      {
        'title': 'Mineral Pure 20L Water Cans',
        'subtitle': 'Strict 8-stage RO+UV quality certified pure water',
        'tag': 'ESSENTIAL',
        'colors': [const Color(0xFF0369A1), const Color(0xFF075985)],
        'btn': 'Order Water 💧',
        'cat': 'WATER_CAN',
      },
      {
        'title': 'Farm Free-Range Country Eggs',
        'subtitle': 'Rich in protein & vitamins, fresh each dawn',
        'tag': 'HEALTH FIRST',
        'colors': [const Color(0xFFB45309), const Color(0xFF78350F)],
        'btn': 'Get Eggs 🥚',
        'cat': 'EGGS',
      },
      {
        'title': 'Antibiotic-Free Fresh Cuts & Meat',
        'subtitle': 'Hygienically vacuum-sealed, tender premium cuts',
        'tag': 'FRESH CUT',
        'colors': [const Color(0xFF991B1B), const Color(0xFF7F1D1D)],
        'btn': 'Fresh Meat 🍗',
        'cat': 'MEAT',
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: promos.length,
            onPageChanged: (idx) {
              setState(() => _currentBannerIndex = idx);
            },
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
                        builder: (ctx) => CategoryProductsScreen(categoryKey: p['cat'] as String, state: widget.state),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                              child: Text(p['tag'] as String, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 15),
                                SizedBox(width: 3),
                                Text('Quality Assured', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5)),
                            const SizedBox(height: 2),
                            Text(p['subtitle'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.electric_bolt_rounded, color: Colors.amber, size: 14),
                                SizedBox(width: 2),
                                Text('Guaranteed 06:00 AM Delivery', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                                ],
                              ),
                              child: Text(p['btn'] as String, style: TextStyle(color: colors.first, fontWeight: FontWeight.bold, fontSize: 10.5)),
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
            final isActive = _currentBannerIndex == idx;
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

  // ── 4. Active Subscription Snapshot ──
  Widget _buildActiveSubscriptionCard(BuildContext context, SubscriptionModel sub) {
    final pName = sub.productDetail?.name ?? 'Daily Farm Fresh Milk';
    final pPrice = sub.productDetail?.pricePerUnit ?? 72.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.autorenew_rounded, color: Color(0xFF0D7C66), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Active Morning Subscription',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Next: Tomorrow 6:00 AM', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(sub.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 1),
                        Text(
                          '${sub.quantity} Unit(s) • ₹${(pPrice * sub.quantity).toStringAsFixed(0)} / day • ${sub.scheduleType}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => widget.state.setTab(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. PROMINENT 4 CORE CATEGORIES MEGA SHOWCASE (LARGE CARDS LIKE ITEMS) ──
  Widget _buildMegaCategoriesShowcase(BuildContext context) {
    final categoriesData = [
      {
        'key': 'MILK',
        'title': 'Fresh Milk & Dairy',
        'subtitle': 'A2 Desi Cow, Buffalo & Organic',
        'badge': '4 Varieties',
        'icon': '🥛',
        'gradient': [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
        'accent': const Color(0xFF0284C7),
        'tag': 'PURE VEDIC',
      },
      {
        'key': 'MEAT',
        'title': 'Meat & Poultry',
        'subtitle': 'Tender Chicken & Mutton Cut',
        'badge': '100% Fresh',
        'icon': '🥩',
        'gradient': [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)],
        'accent': const Color(0xFFDC2626),
        'tag': 'ANTIBIOTIC-FREE',
      },
      {
        'key': 'EGGS',
        'title': 'Farm Fresh Eggs',
        'subtitle': 'Free-Range Desi & Brown Eggs',
        'badge': 'Daily Harvest',
        'icon': '🥚',
        'gradient': [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        'accent': const Color(0xFFD97706),
        'tag': 'HIGH PROTEIN',
      },
      {
        'key': 'WATER_CAN',
        'title': 'Pure Water Cans',
        'subtitle': '20L Mineral Cans & Dispensers',
        'badge': '8-Stage RO',
        'icon': '💧',
        'gradient': [const Color(0xFFF0FDFA), const Color(0xFFCCFBF1)],
        'accent': const Color(0xFF0D9488),
        'tag': 'MINERAL RICH',
      },
    ];

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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
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
              if (_selectedCategory != 'ALL')
                InkWell(
                  onTap: () => setState(() => _selectedCategory = 'ALL'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View All ✨', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 2x2 Large Category Cards (Row/Expanded robust layout)
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
    final isSelected = _selectedCategory == catKey;
    final gradient = cat['gradient'] as List<Color>;
    final accentColor = cat['accent'] as Color;
    final count = widget.state.products.where((p) => p.category == catKey).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = catKey;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => CategoryProductsScreen(categoryKey: catKey, state: widget.state),
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

              // Center Icon Box (Large)
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

  // ── 6. Search Bar & Category Quick Chips ──
  Widget _buildSearchAndFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search milk, chicken, mutton, eggs, water can...',
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
          const SizedBox(height: 10),

          // Horizontal Category Quick Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('ALL', 'All Items ✨'),
                const SizedBox(width: 8),
                _buildCategoryPill('MILK', '🥛 Milk'),
                const SizedBox(width: 8),
                _buildCategoryPill('MEAT', '🥩 Meat'),
                const SizedBox(width: 8),
                _buildCategoryPill('EGGS', '🥚 Eggs'),
                const SizedBox(width: 8),
                _buildCategoryPill('WATER_CAN', '💧 Water Can'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String catKey, String label) {
    final isSelected = _selectedCategory == catKey;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = catKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── 7. Catalog Section Header ──
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

  // ── 8. Dynamic Product Grid ──
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
              Expanded(child: _buildProductCard(context, p1)),
              const SizedBox(width: 12),
              if (p2 != null)
                Expanded(child: _buildProductCard(context, p2))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel item) {
    final discountPrice = item.pricePerUnit * 1.12;
    final inCartQty = widget.state.cartItems[item.id] ?? 0;

    return Card(
      child: InkWell(
        onTap: () => ProductDetailSheet.show(context, item, widget.state),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Text Strip & Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF0D7C66), fontSize: 8.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                      Text('${item.rating}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Avatar / Icon Box
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 80,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Center(
                            child: Text(item.icon, style: const TextStyle(fontSize: 32)),
                          ),
                        )
                      : Center(
                          child: Text(item.icon, style: const TextStyle(fontSize: 32)),
                        ),
                ),
              ),
              const SizedBox(height: 8),

              // Product Name
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              const SizedBox(height: 1),
              Text(
                item.unitQuantity,
                style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
              ),
              const SizedBox(height: 4),

              // Price
              Row(
                children: [
                  Text(
                    '₹${item.pricePerUnit.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0D7C66)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '₹${discountPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Smart Cart Stepper or Dual CTAs
              if (inCartQty > 0)
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7C66),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => widget.state.decreaseCartQty(item.id),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(Icons.remove, size: 14, color: Colors.white),
                        ),
                      ),
                      Text('$inCartQty in cart', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5)),
                      InkWell(
                        onTap: () => widget.state.addToCart(item),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton(
                          onPressed: () {
                            widget.state.addToCart(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF0F172A),
                                content: Text('🛒 Added 1x ${item.name} to Cart!'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('+ Cart', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => ProductDetailSheet.show(context, item, widget.state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Subscribe', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
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
  }

  // ── 9. Trust & Quality Assurance Strip ──
  Widget _buildTrustAssuranceStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTrustBadge('🌿 100% Vedic Pure', 'Zero Adulteration'),
            Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
            _buildTrustBadge('❄️ Chilled < 4°C', 'Direct Cold Chain'),
            Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
            _buildTrustBadge('⚡ 06:00 AM Slot', 'Doorstep Guaranteed'),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge(String title, String subtitle) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A))),
        const SizedBox(height: 1),
        Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }

  // ── 10. Location Selector Sheet ──
  void _showLocationSelectorSheet(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Delivery Location 📍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),

              // ── Saved Addresses Section ──
              if (widget.state.savedAddresses.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SAVED ADDRESSES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => AddressBookScreen(state: widget.state)),
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF10B981)),
                      label: const Text('Manage Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.state.savedAddresses.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final addr = widget.state.savedAddresses[i];
                      final isSelected = widget.state.activeAddress?.id == addr.id;

                      return InkWell(
                        onTap: () {
                          widget.state.selectActiveAddress(addr);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("🚀 Delivering to '${addr.title}'"),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(addr.icon, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          addr.title,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                        ),
                                        if (addr.isDefault) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('PRIMARY', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      addr.summaryAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                              else
                                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
              ],

              // ── 1. Real-Time Google Maps Search Bar ──
              TextField(
                controller: searchCtrl,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search society, building, or street on Google Maps...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981)),
                  suffixIcon: isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
                        )
                      : (searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(() => searchResults = []);
                              },
                            )
                          : null),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (query) async {
                  if (query.trim().isEmpty) {
                    setModalState(() {
                      searchResults = [];
                      isSearching = false;
                    });
                    return;
                  }
                  setModalState(() => isSearching = true);
                  final results = await LocationService.searchPlaces(query);
                  setModalState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                },
                onSubmitted: (query) async {
                  if (query.trim().isEmpty) return;
                  setModalState(() => isSearching = true);
                  final results = await LocationService.searchPlaces(query);
                  setModalState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                },
              ),
              const SizedBox(height: 10),

              // Search Results List Dropdown
              if (searchResults.isNotEmpty) ...[
                const Text('Google Maps Results:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    separatorBuilder: (ctx, sepIdx) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = searchResults[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                          child: const Icon(Icons.place_rounded, color: Color(0xFF10B981), size: 16),
                        ),
                        title: Text(item['short_title'] ?? item['display_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(item['display_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        onTap: () {
                          final lat = (item['lat'] as num?)?.toDouble() ?? 17.4319;
                          final lon = (item['lon'] as num?)?.toDouble() ?? 78.4073;
                          final chosenAddr = item['display_name'] ?? item['short_title'] ?? 'Custom Address';
                          widget.state.updateDeliveryLocation(chosenAddr, lat, lon);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              content: Text('📍 Delivery address updated to: $chosenAddr'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 16),
              ],

              // ── 2. Quick Location Action Tiles ──
              // Use GPS Location Button
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.my_location_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: const Text('Use Current Device GPS Location 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Auto-detect and reverse-geocode doorstep address', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📍 Detecting current location via GPS...')),
                  );
                  bool ok = await widget.state.requestDeviceGPS();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(ok ? '📍 Location auto-filled to: ${widget.state.currentDeliveryAddress}' : 'Location permission needed.'),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 10),

              // Pick on Google Map Button
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.map_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                title: const Text('Pick on Google Map / Pin Doorstep 🗺️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Interactive map with live draggable pin & search', style: TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0284C7)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => MapLocationPickerScreen(state: widget.state),
                    ),
                  );
                },
              ),
              const Divider(height: 10),

              // Geofenced Service Areas Modal Trigger
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.location_city_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                title: const Text('Browse Hyderabad Service Zones 🏙️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Current Zone: ${widget.state.selectedServiceArea.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6366F1)),
                onTap: () {
                  Navigator.pop(ctx);
                  ServiceAreaSheet.show(context, widget.state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 11. Top Up Dialog ──
  void _showTopUpDialog(BuildContext context) {
    final amtController = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚡', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Quick Wallet Top-Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter amount to recharge for daily deliveries:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Amount (INR)',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('+ ₹300', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => amtController.text = '300',
                ),
                ActionChip(
                  label: const Text('+ ₹500', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => amtController.text = '500',
                ),
                ActionChip(
                  label: const Text('+ ₹1000', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => amtController.text = '1000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amtController.text.trim()) ?? 500.0;
              widget.state.topUpWallet(amt, 'UPI Express Top-Up');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0D7C66),
                  content: Text('⚡ Successfully recharged ₹${amt.toStringAsFixed(0)} to your Milk Wallet!'),
                ),
              );
            },
            child: const Text('Pay & Top-Up ⚡'),
          ),
        ],
      ),
    );
  }

  Widget _buildServingSoonView(BuildContext context) {
    final areaName = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Text('🚚', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          const Text(
            'We are Serving Soon in Your Area!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We haven\'t expanded doorstep 06:00 AM delivery to "$areaName" yet. Our active hubs currently serve a 5.0 km radius.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 20),

          // Operational Hub Badges
          // Operational Hub Badges
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📍 Active Operational Delivery Hubs:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                if (widget.state.locationHubs.isNotEmpty)
                  ...widget.state.locationHubs.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${h['name']} (${(h['coverage_radius_km'] as num?)?.toDouble() ?? 5.0} km Radius)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text('Central Operations Hub (5.0 km Radius)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showLocationSelectorSheet(context),
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: const Text('📍 Select Active Service Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF0D7C66),
                    content: Text('🔔 Thanks! We recorded your pincode interest and will notify you when MilkDrop launches here.'),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF0D7C66)),
              label: const Text('🔔 Notify Me When MilkDrop Launches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0D7C66)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
