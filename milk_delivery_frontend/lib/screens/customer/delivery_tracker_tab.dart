import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/delivery_chat_sheet.dart';
import '../../widgets/delivery_rating_dialog.dart';
import '../../widgets/order_invoice_sheet.dart';
import '../../widgets/booking_detail_sheet.dart';
import '../../widgets/order_status_tracker.dart';
import '../../widgets/bookings/active_booking_live_map_card.dart';
import '../../widgets/ui_kit/ui_empty_state.dart';
import 'live_driver_tracking_screen.dart';
import '../../widgets/ui_kit/pamba_refresh_indicator.dart';
import '../../config/app_config.dart';

class DeliveryTrackerTab extends StatefulWidget {
  final AppState state;

  const DeliveryTrackerTab({super.key, required this.state});

  @override
  State<DeliveryTrackerTab> createState() => _DeliveryTrackerTabState();
}

typedef BookingsTab = DeliveryTrackerTab;

class _DeliveryTrackerTabState extends State<DeliveryTrackerTab> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Delivered, 3: Cancelled/Skipped
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _pulseController;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    final initialTab = (widget.state.liveOrders.isEmpty && widget.state.deliveries.isNotEmpty) ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialTab);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _pulseController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  bool _isActiveOrder(String status) {
    final s = status.toUpperCase();
    return s == 'PLACED' ||
        s == 'PENDING' ||
        s == 'CONFIRMED' ||
        s == 'PREPARING' ||
        s == 'PACKED' ||
        s == 'OUT_FOR_DELIVERY' ||
        s == 'PROCESSING' ||
        s == 'IN_TRANSIT';
  }

  bool _isDeliveredOrder(String status) {
    final s = status.toUpperCase();
    return s == 'DELIVERED' || s == 'COMPLETED';
  }

  bool _isCancelledOrder(String status) {
    final s = status.toUpperCase();
    return s == 'CANCELLED' || s == 'REJECTED' || s == 'FAILED';
  }

  bool _isActiveTask(String status) {
    final s = status.toUpperCase();
    return s == 'PENDING' ||
        s == 'OUT_FOR_DELIVERY' ||
        s == 'ON_THE_WAY' ||
        s == 'PICKED_UP' ||
        s == 'ACTIVE' ||
        s == 'CONFIRMED' ||
        s == 'PROCESSING';
  }

  bool _isDeliveredTask(String status) {
    final s = status.toUpperCase();
    return s == 'DELIVERED' || s == 'COMPLETED';
  }

  bool _isCancelledTask(String status) {
    final s = status.toUpperCase();
    return s == 'SKIPPED' || s == 'PAUSED' || s == 'FAILED';
  }

  Color _getStatusColor(String status) {
    if (_isDeliveredOrder(status) || _isDeliveredTask(status)) return const Color(0xFF0D7C66);
    if (_isCancelledOrder(status) || _isCancelledTask(status)) return const Color(0xFFDC2626);
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final isTelugu = widget.state.isTelugu;
    final liveOrders = widget.state.liveOrders;
    final subTasks = widget.state.subscriptionDeliveries;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Row ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTelugu ? 'నా ఆర్డర్లు' : 'My Orders',
                              style: UiText.h1.copyWith(fontSize: 22, color: UiTone.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isTelugu ? 'తక్షణ ఆర్డర్లు మరియు డైలీ సబ్‌స్క్రిప్షన్ డెలివరీలు' : 'Track express instant orders & daily subscriptions',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Next-Gen Bookings Live Tracking Banner ──
                    _buildNextGenBookingsHero(context, isTelugu, liveOrders, subTasks),
                    const SizedBox(height: 10),

                    // ── Dual Top Sliding Tab Selector: Express Orders & Subscriptions ──
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            
                          )
                        ]
                      ),
                      child: TabBar(
                        controller: _tabController,
                        onTap: (index) => HapticFeedback.selectionClick(),
                        indicator: BoxDecoration(
                          color: UiTone.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: UiTone.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey.shade700,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(isTelugu ? 'తక్షణ ఆర్డర్లు' : 'Express Orders'),
                                if (liveOrders.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      '${liveOrders.length}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🥛', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(isTelugu ? 'డైలీ ఆర్డర్లు' : 'Daily Orders'),
                                if (subTasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      '${subTasks.length}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Search & Quick Filter Pills Bar ──
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                                    decoration: InputDecoration(
                                      hintText: isTelugu ? 'ఆర్డర్ / ఉత్పత్తిని శోధించండి...' : 'Search orders or items...',
                                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips: All, Active, Delivered, Cancelled
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Builder(builder: (context) {
                            final allCount = liveOrders.length + subTasks.length;
                            final activeCount = liveOrders.where((o) => _isActiveOrder(o.status)).length + subTasks.where((t) => _isActiveTask(t.status)).length;
                            final deliveredCount = liveOrders.where((o) => _isDeliveredOrder(o.status)).length + subTasks.where((t) => _isDeliveredTask(t.status)).length;
                            final cancelledCount = liveOrders.where((o) => _isCancelledOrder(o.status)).length + subTasks.where((t) => _isCancelledTask(t.status)).length;
                            return Row(
                              children: [
                                _filterPill(0, isTelugu ? 'అన్నీ' : 'All', allCount),
                                const SizedBox(width: 8),
                                _filterPill(1, isTelugu ? 'యాక్టివ్ / డెలివరీలో' : 'Active / In-Transit', activeCount),
                                const SizedBox(width: 8),
                                _filterPill(2, isTelugu ? 'పూర్తయినవి' : 'Delivered', deliveredCount),
                                const SizedBox(width: 8),
                                _filterPill(3, isTelugu ? 'రద్దు / స్కిప్ చేయబడినవి' : 'Cancelled / Skipped', cancelledCount),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // ── TAB 1: EXPRESS ON-DEMAND ORDERS ──
              _buildExpressOrdersView(context, isTelugu),

              // ── TAB 2: SUBSCRIPTION RECURRING DELIVERIES ──
              _buildSubscriptionDeliveriesView(context, isTelugu),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextGenBookingsHero(
    BuildContext context,
    bool isTelugu,
    List<LiveOrderModel> liveOrders,
    List<DeliveryTaskModel> subTasks,
  ) {
    LiveOrderModel? inTransitOrder;
    for (final o in liveOrders) {
      final s = o.status.toUpperCase();
      if (s == 'OUT_FOR_DELIVERY' || s == 'IN_TRANSIT' || s == 'ON_THE_WAY') {
        inTransitOrder = o;
        break;
      }
    }

    DeliveryTaskModel? inTransitTask;
    for (final t in subTasks) {
      final s = t.status.toUpperCase();
      if (s == 'OUT_FOR_DELIVERY' || s == 'IN_TRANSIT' || s == 'ON_THE_WAY' || s == 'PICKED_UP') {
        inTransitTask = t;
        break;
      }
    }

    final activeOrdersCount = liveOrders.where((o) => _isActiveOrder(o.status)).length;
    final activeTasksCount = subTasks.where((t) => _isActiveTask(t.status)).length;
    final totalActive = activeOrdersCount + activeTasksCount;
    final deliveredOrders = liveOrders.where((o) => _isDeliveredOrder(o.status)).length;
    final deliveredTasks = subTasks.where((t) => _isDeliveredTask(t.status)).length;
    final totalDelivered = deliveredOrders + deliveredTasks;

    // ── 1. If an express order or morning daily drop is actively out for delivery, show Service-Mobile Live Map Hero ──
    if (inTransitOrder != null || inTransitTask != null) {
      return ActiveBookingLiveMapCard(
        state: widget.state,
        liveOrder: inTransitOrder,
        subscriptionTask: inTransitTask,
        isTelugu: isTelugu,
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: UiTone.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Text('✨', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTelugu ? 'మీ తదుపరి డెలివరీలు ట్రాక్ చేయండి' : 'Track your deliveries',
                      style: TextStyle(
                        color: UiTone.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isTelugu
                          ? 'మీ యాక్టివ్ ఆర్డర్లు మరియు సబ్‌స్క్రిప్షన్‌లను ఇక్కడ చూడండి.'
                          : 'View your active orders and upcoming subscriptions here.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                icon: '📦',
                count: totalActive.toString(),
                label: isTelugu ? 'యాక్టివ్' : 'Active',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                icon: '✅',
                count: totalDelivered.toString(),
                label: isTelugu ? 'పూర్తయినవి' : 'Delivered',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                icon: '⏱️',
                count: '06:00 AM',
                label: isTelugu ? 'తదుపరి డ్రాప్' : 'Next Drop',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({required String icon, required String count, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            count,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(int index, String label, int count) {
    final isSelected = _selectedFilterIndex == index;
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilterIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [Color(0xFF0D7C66), Color(0xFF14B8A6)])
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpressOrdersView(BuildContext context, bool isTelugu) {
    final orders = widget.state.liveOrders.where((order) {
      if (_searchQuery.isNotEmpty) {
        final matchesId = order.id.toLowerCase().contains(_searchQuery);
        final matchesItem = order.items.any((i) => i.product.name.toLowerCase().contains(_searchQuery));
        if (!matchesId && !matchesItem) return false;
      }
      if (_selectedFilterIndex == 1) return _isActiveOrder(order.status);
      if (_selectedFilterIndex == 2) return _isDeliveredOrder(order.status);
      if (_selectedFilterIndex == 3) return _isCancelledOrder(order.status);
      return true;
    }).toList();

    return PambaRefreshIndicator(
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (orders.isEmpty)
              UiEmptyState(
                emoji: '📦',
                title: 'No Deliveries Yet',
                message: 'Your daily milk & grocery deliveries will appear here once you subscribe.',
                action: ElevatedButton.icon(
                  onPressed: () => widget.state.setTab(0),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: Text(isTelugu ? 'ఉత్పత్తులను బ్రౌజ్ చేయండి' : 'Browse Fresh Products'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              ...orders.map((order) => _buildExpressOrderCard(context, order, isTelugu)),
          ],
        ),
      ),
    );
  }

    Widget _buildFeatureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66)),
      ),
    );
  }
  Widget _buildExpressOrderCard(BuildContext context, LiveOrderModel order, bool isTelugu, {int index = 0}) {
    final isDelivered = _isDeliveredOrder(order.status);
    final isOutForDelivery = order.status == 'OUT_FOR_DELIVERY';
    final isPlaced = _isActiveOrder(order.status) && !isOutForDelivery;
    final statusColor = _getStatusColor(order.status);

    String statusText = 'ORDER PLACED';
    if (isDelivered) {
      statusText = isTelugu ? 'డెలివరీ పూర్తయింది' : 'DELIVERED';
    } else if (isOutForDelivery) {
      statusText = isTelugu ? 'డెలివరీ భాగస్వామి దారిలో ఉన్నారు' : 'OUT FOR DELIVERY';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        BookingDetailSheet.showForLiveOrder(context, widget.state, order);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: UiTone.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${order.id}',
                          style: TextStyle(color: UiTone.primary, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(order.createdAt),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            // ── Live Order Status Tracker ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: OrderStatusTracker(
                status: order.status,
                isTelugu: isTelugu,
                deliveredAt: order.deliveredAt != null ? UiFormat.time(order.deliveredAt!) : null,
              ),
            ),
            const Divider(height: 12),

            // Items Preview
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(item.product.icon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${widget.state.translateProduct(item.product.name)} x ${item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Text(
                            UiFormat.price(item.totalPrice),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),

                  // Total & Address
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            order.deliveryAddress.length > 25
                                ? '${order.deliveryAddress.substring(0, 25)}...'
                                : order.deliveryAddress,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            isTelugu ? 'మొత్తం: ' : 'Total: ',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          Text(
                            UiFormat.price(order.totalAmount),
                            style: TextStyle(color: UiTone.primary, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Assigned Delivery Partner Snippet
                  if (order.driverName.isNotEmpty && order.driverName != 'Assigning Partner...') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.delivery_dining_rounded, size: 16, color: Color(0xFF0D7C66)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${order.driverName} • ${order.driverPhone.isNotEmpty ? order.driverPhone : "Hub Partner"}',
                              style: const TextStyle(color: Color(0xFF0D7C66), fontSize: 11.5, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            order.driverVehicle.isNotEmpty ? order.driverVehicle.split(' ').first : 'Scooter',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      if (isOutForDelivery || isPlaced) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveDriverTrackingScreen(
                                    state: widget.state,
                                    liveOrder: order,
                                    orderTitle: order.items.isNotEmpty ? order.items.first.product.name : 'Express Order',
                                    deliveryAddress: order.deliveryAddress,
                                    driverName: order.driverName,
                                    driverPhone: order.driverPhone,
                                    deliveryOtp: order.deliveryOtp,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.directions_bike_rounded, size: 16),
                            label: Text(isTelugu ? 'లైవ్ ట్రాకింగ్ 🛵' : 'Live Map Track 🛵'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UiTone.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, color: Color(0xFF0D7C66), size: 18),
                          tooltip: 'Call Delivery Partner',
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final clean = order.driverPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                            if (clean.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.orange,
                                  content: Text('Delivery partner phone number is not available yet.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            final uri = Uri.parse('tel:$clean');
                            try {
                              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!ok) await launchUrl(uri);
                            } catch (_) {}
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.forum_rounded, color: Color(0xFF0F172A), size: 18),
                          tooltip: 'Live Chat',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            DeliveryChatSheet.show(
                              context,
                              orderId: order.id,
                              driverName: order.driverName.isNotEmpty ? order.driverName : 'Delivery Partner',
                              driverPhone: order.driverPhone,
                              customerName: widget.state.currentUser?.name ?? 'Customer',
                              customerPhone: widget.state.currentUser?.phone ?? '',
                              orderTitle: 'Express Order ${order.id}',
                              deliveryAddress: order.deliveryAddress,
                            );
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                          tooltip: 'WhatsApp Delivery Partner',
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            String clean = order.driverPhone.replaceAll(RegExp(r'\D'), '');
                            if (clean.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.orange,
                                  content: Text('Delivery partner WhatsApp number is not available yet.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            if (clean.length == 10) {
                              clean = '91$clean';
                            } else if (clean.startsWith('0') && clean.length == 11) {
                              clean = '91${clean.substring(1)}';
                            }

                            final dName = order.driverName.isNotEmpty ? order.driverName : 'Delivery Partner';
                            final msg = 'Hi $dName, I am tracking my Pamba Express Order #${order.id}. Please deliver to: ${order.deliveryAddress}. Thank you!';
                            final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
                            try {
                              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!ok) {
                                await launchUrl(Uri.parse('https://api.whatsapp.com/send?phone=$clean&text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
                              }
                            } catch (_) {}
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                          ),
                        ),
                      ] else if (isDelivered) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.state.setTab(0);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(isTelugu ? 'మళ్లీ ఆర్డర్ చేయండి' : 'Reorder 🔄'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UiTone.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => OrderInvoiceSheet(
                                  order: order,
                                  orderId: order.id,
                                  orderDate: order.deliveryDate,
                                  slotTime: order.deliverySlot,
                                  address: order.deliveryAddress,
                                  totalAmount: order.totalAmount,
                                  customerName: order.customerName,
                                ),
                              );
                            },
                            icon: const Icon(Icons.receipt_rounded, size: 16),
                            label: Text(isTelugu ? 'రశీదు / ఇన్వాయిస్ 📄' : 'Bill Invoice 📄'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: UiTone.primary,
                              side: BorderSide(color: UiTone.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (order.proofImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.photo_camera_rounded, color: Color(0xFF0284C7)),
                            tooltip: 'View Doorstep Proof',
                            onPressed: () {
                              _showDoorstepProofLightbox(
                                context,
                                AppConfig.normalizeImageUrl(order.proofImageUrl),
                                'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                                'Verified Doorstep Photo Proof',
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: SUBSCRIPTION DELIVERIES VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSubscriptionDeliveriesView(BuildContext context, bool isTelugu) {
    // Filter daily fulfillment delivery drops (daily orders)
    final tasks = widget.state.subscriptionDeliveries.where((task) {
      if (_searchQuery.isNotEmpty) {
        final matchesName = task.productName.toLowerCase().contains(_searchQuery);
        final matchesAddr = task.deliveryAddress.toLowerCase().contains(_searchQuery);
        if (!matchesName && !matchesAddr) return false;
      }
      if (_selectedFilterIndex == 1) return _isActiveTask(task.status);
      if (_selectedFilterIndex == 2) return _isDeliveredTask(task.status);
      if (_selectedFilterIndex == 3) return _isCancelledTask(task.status);
      return true;
    }).toList();

    final hasActiveSubs = widget.state.subscriptions.any((s) => s.status == 'ACTIVE');

    return PambaRefreshIndicator(
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tasks.isEmpty && !hasActiveSubs)
              UiEmptyState(
                emoji: '📦',
                title: 'No Deliveries Yet',
                message: 'Your daily milk & grocery deliveries will appear here once you subscribe.',
                action: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.state.setTab(0);
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(isTelugu ? 'సబ్‌స్క్రిప్షన్‌ను ప్రారంభించండి' : 'Start a Subscription'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              )
            else if (tasks.isEmpty && hasActiveSubs)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: const Text('🥛', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isTelugu ? 'డైలీ ఆర్డర్లు షెడ్యూల్ చేయబడ్డాయి' : 'Daily Drops Scheduled',
                      style: UiText.h2.copyWith(fontSize: 16, color: UiTone.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isTelugu
                          ? 'మీ యాక్టివ్ సబ్‌స్క్రిప్షన్ కోసం రేపటి ఉదయం డెలివరీ 06:00 AM కి డోర్‌స్టెప్ వద్ద చేరుతుంది.'
                          : 'Your active subscription is scheduled for guaranteed 06:00 AM morning doorstep delivery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFeatureChip('🌅 06:00 AM'),
                        const SizedBox(width: 8),
                        _buildFeatureChip('🚛 Daily'),
                        const SizedBox(width: 8),
                        _buildFeatureChip('🧪 Lab Tested'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.state.setTab(1); // Go to Subscriptions tab
                      },
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: Text(isTelugu ? 'సభ్యత్వాలను నిర్వహించండి' : 'View / Manage Subscriptions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UiTone.primary,
                        side: BorderSide(color: UiTone.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    isTelugu ? 'డైలీ సబ్‌స్క్రిప్షన్ ఆర్డర్లు' : 'Daily Subscription Orders',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: UiTone.ink),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: UiTone.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(color: UiTone.primary, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tasks.asMap().entries.map((e) => _buildSubscriptionTaskCard(context, e.value, isTelugu, index: e.key)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionTaskCard(BuildContext context, DeliveryTaskModel task, bool isTelugu, {int index = 0}) {
    final isDelivered = _isDeliveredTask(task.status);
    final statusColor = _getStatusColor(task.status);
    final pName = task.productName.isNotEmpty ? task.productName : 'Fresh Cow Milk';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        BookingDetailSheet.showForSubscriptionTask(context, widget.state, task);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DAILY ORDER #${task.id}',
                          style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatCalendarDate(task.deliveryDate),
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          isDelivered ? (isTelugu ? 'పూర్తయింది' : 'DELIVERED') : task.status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            // ── Live Order Status Tracker ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: OrderStatusTracker(
                status: task.status,
                isTelugu: isTelugu,
                deliveredAt: task.deliveredAt != null ? UiFormat.time(task.deliveredAt!) : null,
              ),
            ),
            const Divider(height: 12),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: UiTone.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🥛', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.state.translateProduct(pName),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${task.packSize.isNotEmpty ? task.packSize : "1 Litre"} • ${task.quantity} Packs',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        UiFormat.price(task.pricePerUnit * task.quantity),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                  if (task.fatPercentage > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🥛 Fat: ${task.fatPercentage}% | SNF: ${task.snfPercentage}% | 🌡️ ${task.temperatureCelsius}°C',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                      ),
                    ),
                  const Divider(height: 20),

                  // Address & Route
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            task.deliveryAddress.length > 25
                                ? '${task.deliveryAddress.substring(0, 25)}...'
                                : task.deliveryAddress,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      if (task.driverDetail != null)
                        Text(
                          '🛵 ${task.driverDetail!.fullName}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      if (!isDelivered) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveDriverTrackingScreen(
                                    state: widget.state,
                                    subscriptionTask: task,
                                    orderTitle: pName,
                                    deliveryAddress: task.deliveryAddress,
                                    driverName: task.driverDetail?.fullName ?? 'Assigned Hero',
                                    driverPhone: task.driverDetail?.phone ?? '',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.directions_bike_rounded, size: 16),
                            label: Text(isTelugu ? 'లైవ్ ట్రాకింగ్ 🛵' : 'Live Map Track 🛵'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UiTone.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if ((task.driverDetail?.phone ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, color: Color(0xFF0D7C66), size: 18),
                            tooltip: 'Call Delivery Partner',
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              final clean = (task.driverDetail?.phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
                              if (clean.isNotEmpty) {
                                final uri = Uri.parse('tel:$clean');
                                try { await launchUrl(uri); } catch (_) {}
                              }
                            },
                          ),
                        ],
                      ] else ...[
                        if (widget.state.isTaskRated(task.id))
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Rated ${widget.state.getTaskRating(task.id)}★ ✓',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                DeliveryRatingDialog.show(
                                  context,
                                  state: widget.state,
                                  productName: pName,
                                  driverName: task.driverDetail?.fullName ?? 'Delivery Hero',
                                  deliveryDate: task.deliveryDate,
                                  taskId: task.id,
                                  onRated: (_) => setState(() {}),
                                );
                              },
                              icon: const Icon(Icons.star_outline_rounded, size: 16),
                              label: Text(isTelugu ? 'రేటింగ్ ఇవ్వండి' : 'Rate Delivery ⭐'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: UiTone.primary,
                                side: BorderSide(color: UiTone.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        if (task.proofImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _showDoorstepProofLightbox(
                                context,
                                AppConfig.normalizeImageUrl(task.proofImageUrl),
                                'Daily Drop #${task.id}',
                                '${task.productName} • ${task.deliveryDate}',
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                AppConfig.normalizeImageUrl(task.proofImageUrl),
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  width: 36,
                                  height: 36,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showDoorstepProofLightbox(BuildContext context, String imageUrl, String title, String subtitle) {
    showDialog(
      context: context,
      barrierColor: const Color(0xE0000000),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xBFFFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pinch-to-zoom interactive viewer
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    AppConfig.normalizeImageUrl(imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(32),
                      color: const Color(0xFF1E293B),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Could not load photo proof', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x3310B981),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x8010B981)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Pinch to zoom • Verified Doorstep Photo Drop',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return createdAt.split('T').first;
    } catch (_) {
      return createdAt;
    }
  }

  String _formatCalendarDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }
}
