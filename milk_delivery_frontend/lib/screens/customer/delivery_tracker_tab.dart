import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';
import '../../providers/app_state.dart';
import '../../models/live_order_model.dart';
import '../../models/delivery_task_model.dart';
import '../../widgets/booking_detail_sheet.dart';
import '../../widgets/delivery_rating_dialog.dart';
import '../../widgets/delivery_chat_sheet.dart';
import '../../widgets/order_invoice_sheet.dart';
import 'live_driver_tracking_screen.dart';

class DeliveryTrackerTab extends StatefulWidget {
  final AppState state;

  const DeliveryTrackerTab({super.key, required this.state});

  @override
  State<DeliveryTrackerTab> createState() => _DeliveryTrackerTabState();
}

typedef BookingsTab = DeliveryTrackerTab;

class _DeliveryTrackerTabState extends State<DeliveryTrackerTab> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Delivered, 3: Cancelled
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
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
    return s == 'PENDING' || s == 'OUT_FOR_DELIVERY' || s == 'ACTIVE';
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
    final liveOrders = widget.state.liveOrders;
    final subscriptions = widget.state.deliveries;

    final activeOrdersCount = liveOrders.where((o) => _isActiveOrder(o.status)).length +
        subscriptions.where((t) => _isActiveTask(t.status)).length;
    final deliveredOrdersCount = liveOrders.where((o) => _isDeliveredOrder(o.status)).length +
        subscriptions.where((t) => _isDeliveredTask(t.status)).length;
    final cancelledOrdersCount = liveOrders.where((o) => _isCancelledOrder(o.status)).length +
        subscriptions.where((t) => _isCancelledTask(t.status)).length;
    final totalCount = liveOrders.length + subscriptions.length;

    List<LiveOrderModel> filteredOrders;
    List<DeliveryTaskModel> filteredSubscriptions;

    if (_selectedFilterIndex == 1) {
      filteredOrders = liveOrders.where((o) => _isActiveOrder(o.status)).toList();
      filteredSubscriptions = subscriptions.where((t) => _isActiveTask(t.status)).toList();
    } else if (_selectedFilterIndex == 2) {
      filteredOrders = liveOrders.where((o) => _isDeliveredOrder(o.status)).toList();
      filteredSubscriptions = subscriptions.where((t) => _isDeliveredTask(t.status)).toList();
    } else if (_selectedFilterIndex == 3) {
      filteredOrders = liveOrders.where((o) => _isCancelledOrder(o.status)).toList();
      filteredSubscriptions = subscriptions.where((t) => _isCancelledTask(t.status)).toList();
    } else {
      filteredOrders = List.from(liveOrders);
      filteredSubscriptions = List.from(subscriptions);
    }

    // Apply real-time search query
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filteredOrders = filteredOrders.where((o) =>
        o.id.toLowerCase().contains(q) ||
        o.deliveryAddress.toLowerCase().contains(q) ||
        o.driverName.toLowerCase().contains(q) ||
        o.deliveryDate.toLowerCase().contains(q) ||
        o.items.any((i) => i.product.name.toLowerCase().contains(q))
      ).toList();

      filteredSubscriptions = filteredSubscriptions.where((t) =>
        t.deliveryAddress.toLowerCase().contains(q) ||
        t.deliveryDate.toLowerCase().contains(q) ||
        (t.driverDetail?.fullName.toLowerCase().contains(q) ?? false) ||
        (t.subscriptionDetail?.productDetail?.name.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    final activeOrders = filteredOrders.where((o) => _isActiveOrder(o.status)).toList();
    final firstActiveOrder = (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) && activeOrders.isNotEmpty && q.isEmpty
        ? activeOrders.first
        : null;

    final remainingOrders = List<LiveOrderModel>.from(filteredOrders);
    if (firstActiveOrder != null) {
      remainingOrders.removeWhere((o) => o.id == firstActiveOrder.id);
    }

    final isListEmpty = filteredOrders.isEmpty && filteredSubscriptions.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0D7C66),
          strokeWidth: 2.5,
          onRefresh: () => widget.state.reloadAllData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              _buildTopHeaderRow(totalCount),
              const SizedBox(height: 14),

              // KPI Stats Row
              _buildStatsBar(activeOrdersCount, deliveredOrdersCount, totalCount),
              const SizedBox(height: 14),

              // Search Bar
              _buildSearchBar(),
              const SizedBox(height: 10),

              // Filter Chips Carousel
              _buildFilterChips(
                totalCount: totalCount,
                activeCount: activeOrdersCount,
                deliveredCount: deliveredOrdersCount,
                cancelledCount: cancelledOrdersCount,
              ),

              if (isListEmpty)
                _buildFilteredEmptyState(_selectedFilterIndex)
              else ...[
                if (firstActiveOrder != null) ...[
                  const SizedBox(height: 16),
                  _buildActiveOrderHeroCard(firstActiveOrder),
                ],
                if (remainingOrders.isNotEmpty) ...[
                  _buildSectionHeader(
                    _selectedFilterIndex == 2
                        ? 'Delivered Orders'
                        : _selectedFilterIndex == 3
                            ? 'Cancelled Orders'
                            : 'Express Orders',
                    count: remainingOrders.length,
                  ),
                  ...remainingOrders.map((o) => _buildOrderCard(o)),
                ],
                if (filteredSubscriptions.isNotEmpty) ...[
                  _buildSectionHeader(
                    _selectedFilterIndex == 2
                        ? 'Delivered Morning Milk'
                        : _selectedFilterIndex == 3
                            ? 'Skipped / Paused Deliveries'
                            : 'Morning Subscriptions',
                    count: filteredSubscriptions.length,
                  ),
                  ...filteredSubscriptions.map((task) => _buildSubscriptionCard(task)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderRow(int totalCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('My Bookings & Orders', style: UiText.h1.copyWith(fontSize: 21)),
                const SizedBox(width: 6),
                const Text('🥛', style: TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 2),
            Text('Live tracking, receipts & delivery ratings', style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 12)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(UiRadius.pill),
            border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF0D7C66), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(
                '$totalCount Total',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF0D7C66)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(int active, int delivered, int total) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem('⚡ Live Active', '$active Drops', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem('✅ Delivered', '$delivered Completed', const Color(0xFF0D7C66), const Color(0xFFF0FDF4)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem('🥛 Pure Milk', '100% Quality', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: UiText.body.copyWith(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by Order ID, Product, Driver or Date...',
          hintStyle: UiText.caption.copyWith(color: const Color(0xFF94A3B8), fontSize: 12.5),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0D7C66)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: UiTone.softText),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {int? count}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Text(title, style: UiText.h2.copyWith(fontSize: 15)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(UiRadius.xs),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required int totalCount,
    required int activeCount,
    required int deliveredCount,
    required int cancelledCount,
  }) {
    final chips = [
      'All ($totalCount)',
      '⚡ Active ($activeCount)',
      '✅ Delivered ($deliveredCount)',
      '❌ Cancelled ($cancelledCount)',
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(chips.length, (index) {
            final isSelected = _selectedFilterIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => setState(() => _selectedFilterIndex = index),
                borderRadius: BorderRadius.circular(UiRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0D7C66) : Colors.white,
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFF0D7C66).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Text(
                    chips[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(int filterIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.shopping_basket_outlined, size: 40, color: Color(0xFF0D7C66)),
          ),
          const SizedBox(height: 16),
          Text(_searchQuery.isNotEmpty ? 'No Matching Deliveries' : 'No Orders Found', style: UiText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching with another product name or date.'
                : 'Explore farm fresh milk, paneer, and ghee to place your first order!',
            textAlign: TextAlign.center,
            style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── HERO ACTIVE ORDER CARD ──
  Widget _buildActiveOrderHeroCard(LiveOrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => BookingDetailSheet.showForExpressOrder(context, widget.state, order),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          const Text('LIVE RADAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.id,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'OTP: ${order.deliveryOtp}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  order.items.isNotEmpty
                      ? order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ')
                      : 'Express Milk Drop',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivering to: ${order.deliveryAddress}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Driver Partner', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
                          Text(
                            order.driverName.isNotEmpty ? order.driverName : 'Assigned Partner',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => LiveDriverTrackingScreen(
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
                      icon: const Icon(Icons.moped_rounded, size: 15, color: Colors.white),
                      label: const Text('Live Track 🛵', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ORDER CARD ──
  Widget _buildOrderCard(LiveOrderModel order) {
    final statusColor = _getStatusColor(order.status);
    final isActive = _isActiveOrder(order.status);
    final isDelivered = _isDeliveredOrder(order.status);

    String itemsSummary = '';
    if (order.items.isNotEmpty) {
      if (order.items.length <= 2) {
        itemsSummary = order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ');
      } else {
        itemsSummary = '${order.items[0].quantity}x ${order.items[0].product.name}, ${order.items[1].quantity}x ${order.items[1].product.name} + ${order.items.length - 2} more';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => BookingDetailSheet.showForExpressOrder(context, widget.state, order),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace', fontSize: 10.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.deliveryType == 'INSTANT')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0D7C66), Color(0xFF10A37F)]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('⚡ INSTANT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Items summary
                Text(
                  itemsSummary.isNotEmpty ? itemsSummary : 'Fresh Farm Milk & Essentials',
                  style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Date & Slot
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${order.deliveryDate.isNotEmpty ? order.deliveryDate : "Today"} • ${order.deliverySlot}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // Action Row
                Row(
                  children: [
                    Text(
                      UiFormat.price(order.totalAmount),
                      style: UiText.price.copyWith(fontSize: 15, color: const Color(0xFF0D7C66)),
                    ),
                    const Spacer(),
                    if (isActive) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          DeliveryChatSheet.show(
                            context,
                            orderId: order.id,
                            driverName: order.driverName.isNotEmpty ? order.driverName : 'Assigned Partner',
                            driverPhone: order.driverPhone,
                            customerName: widget.state.currentUser?.name ?? 'Customer',
                            customerPhone: widget.state.currentUser?.phone ?? '',
                            orderTitle: order.items.isNotEmpty ? order.items.first.product.name : 'Express Order',
                            deliveryAddress: order.deliveryAddress,
                          );
                        },
                        icon: const Icon(Icons.forum_rounded, size: 13, color: Color(0xFF0D7C66)),
                        label: const Text('Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D7C66)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => LiveDriverTrackingScreen(
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
                        icon: const Icon(Icons.moped_rounded, size: 13),
                        label: const Text('Track 🛵', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                          elevation: 0,
                        ),
                      ),
                    ] else if (isDelivered) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          OrderInvoiceSheet.show(
                            context,
                            order: order,
                            orderId: order.id,
                            orderDate: order.deliveryDate.isNotEmpty ? order.deliveryDate : 'Today',
                            slotTime: order.deliverySlot,
                            address: order.deliveryAddress,
                            totalAmount: order.totalAmount,
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFF0D7C66)),
                        label: const Text('Invoice 🧾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D7C66)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.state.isOrderRated(order.id))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                            border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Rated ${widget.state.getOrderRating(order.id)}★ ✓',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66)),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            DeliveryRatingDialog.show(
                              context,
                              state: widget.state,
                              orderId: order.id,
                              productName: order.items.isNotEmpty ? order.items.first.product.name : 'Express Order',
                              driverName: order.driverName.isNotEmpty ? order.driverName : 'Delivery Partner',
                              deliveryDate: order.deliveryDate.isNotEmpty ? order.deliveryDate : 'Today',
                              onRated: (_) => setState(() {}),
                            );
                          },
                          icon: const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          label: const Text('Rate ⭐', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SUBSCRIPTION CARD ──
  Widget _buildSubscriptionCard(DeliveryTaskModel task) {
    final statusColor = _getStatusColor(task.status);
    final isDelivered = _isDeliveredTask(task.status);
    final total = (task.pricePerUnit > 0 ? task.pricePerUnit : 40.0) * (task.quantity > 0 ? task.quantity : 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => BookingDetailSheet.showForSubscription(context, widget.state, task),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DROP #${task.id}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace', fontSize: 10.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('🥛 DAILY DROP', style: TextStyle(color: Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  task.productName.isNotEmpty ? task.productName : 'Farm Fresh A2 Cow Milk',
                  style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      '${task.deliveryDate.isNotEmpty ? task.deliveryDate : "Today"} • ${task.slotTime}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      UiFormat.price(total),
                      style: UiText.price.copyWith(fontSize: 15, color: const Color(0xFF0D7C66)),
                    ),
                    const Spacer(),
                    if (isDelivered) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          OrderInvoiceSheet.show(
                            context,
                            task: task,
                            orderId: 'SUB-DROP-#${task.id}',
                            orderDate: task.deliveryDate.isNotEmpty ? task.deliveryDate : 'Today',
                            slotTime: task.slotTime,
                            address: task.deliveryAddress,
                            totalAmount: total,
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFF0D7C66)),
                        label: const Text('Invoice 🧾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D7C66)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.state.isTaskRated(task.id))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                            border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Rated ${widget.state.getTaskRating(task.id)}★ ✓',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66)),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            DeliveryRatingDialog.show(
                              context,
                              state: widget.state,
                              taskId: task.id,
                              productName: task.productName,
                              driverName: task.driverDetail?.fullName.isNotEmpty == true ? task.driverDetail!.fullName : 'Assigned Partner',
                              deliveryDate: task.deliveryDate.isNotEmpty ? task.deliveryDate : 'Today',
                              onRated: (_) => setState(() {}),
                            );
                          },
                          icon: const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                          label: const Text('Rate ⭐', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            minimumSize: const Size(0, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
