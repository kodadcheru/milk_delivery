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
    return s == 'SKIPPED' || s == 'CANCELLED' || s == 'PAUSED';
  }

  bool _isActive(String status) => _isActiveOrder(status);

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

    // Filter orders based on selected chip
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

    // Remaining orders excluding the hero one
    final remainingOrders = List<LiveOrderModel>.from(filteredOrders);
    if (firstActiveOrder != null) {
      remainingOrders.removeWhere((o) => o.id == firstActiveOrder.id);
    }

    final isListEmpty = filteredOrders.isEmpty && filteredSubscriptions.isEmpty;

    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: UiTone.primary,
          strokeWidth: 2.5,
          onRefresh: () => widget.state.reloadAllData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              _buildHeaderRow(totalCount),
              const SizedBox(height: 12),
              _buildSearchBar(),
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
                            : 'Recent Orders',
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

  Widget _buildHeaderRow(int totalCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Deliveries & Orders', style: UiText.h1.copyWith(fontSize: 21)),
            const SizedBox(height: 2),
            Text('Live tracking, receipts & delivery ratings', style: UiText.caption.copyWith(color: UiTone.softText)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: UiTone.primarySoft,
            borderRadius: BorderRadius.circular(UiRadius.pill),
          ),
          child: Text(
            '$totalCount Orders',
            style: UiText.caption.copyWith(color: UiTone.primary, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: UiText.body.copyWith(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search orders, milk type, date, or partner...',
          hintStyle: UiText.caption.copyWith(color: UiTone.softText),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: UiTone.softText),
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
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(
        children: [
          Text(title, style: UiText.h2.copyWith(fontSize: 15)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: UiTone.surfaceMuted,
                borderRadius: BorderRadius.circular(UiRadius.xs),
              ),
              child: Text(
                '$count',
                style: UiText.caption.copyWith(fontWeight: FontWeight.w700, color: UiTone.softText),
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
      height: 42,
      margin: const EdgeInsets.only(top: 10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0D7C66) : UiTone.surface,
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder,
                    ),
                    boxShadow: isSelected ? UiShadow.glowPrimary : null,
                  ),
                  child: Text(
                    chips[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : UiTone.ink,
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
    String title;
    String subtitle;
    IconData icon;

    switch (filterIndex) {
      case 1:
        title = 'No Active Orders';
        subtitle = 'You don’t have any deliveries on the way right now.';
        icon = Icons.moped_rounded;
        break;
      case 2:
        title = 'No Delivered Orders';
        subtitle = 'Completed orders and morning drops will appear here.';
        icon = Icons.inventory_2_outlined;
        break;
      case 3:
        title = 'No Cancelled Orders';
        subtitle = 'You have not cancelled or skipped any scheduled drops.';
        icon = Icons.cancel_outlined;
        break;
      default:
        title = _searchQuery.isNotEmpty ? 'No Matching Results' : 'No Orders Yet';
        subtitle = _searchQuery.isNotEmpty
            ? 'Try searching with another product name or date.'
            : 'Explore fresh milk, paneer, and ghee to place your first order!';
        icon = Icons.shopping_basket_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: UiTone.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: UiTone.softText),
          ),
          const SizedBox(height: 16),
          Text(title, style: UiText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: UiText.caption.copyWith(color: UiTone.softText),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderHeroCard(LiveOrderModel order) {
    final driverName = order.driverName.isNotEmpty ? order.driverName : 'Assigned Partner';
    final driverPhone = order.driverPhone;

    return Container(
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.xl),
        border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        children: [
          // Top Pulse Banner
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: UiGradient.hero,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _animController,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.moped_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE RADAR • ON THE WAY',
                        style: UiText.caption.copyWith(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      Text(
                        'Arriving in ~${order.etaMinutes > 0 ? order.etaMinutes : 22} mins',
                        style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
                if (order.deliveryOtp.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                    ),
                    child: Text(
                      'OTP: ${order.deliveryOtp}',
                      style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.items.isNotEmpty ? order.items.first.product.name : 'Morning Fresh Order',
                            style: UiText.h2.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.items.length} items • ${order.deliveryAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UiText.caption.copyWith(color: UiTone.softText),
                          ),
                        ],
                      ),
                    ),
                    Text(UiFormat.price(order.totalAmount), style: UiText.price.copyWith(color: UiTone.primaryDark)),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: UiTone.surfaceBorder),
                const SizedBox(height: 12),

                // Driver & Action Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: UiTone.primarySoft,
                      child: const Text('👨‍🌾', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driverName, style: UiText.bodyStrong.copyWith(fontSize: 13)),
                          Text('4.9 ★ • EV Scooter', style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11)),
                        ],
                      ),
                    ),
                    // In-App Chat
                    IconButton.filledTonal(
                      onPressed: () {
                        DeliveryChatSheet.show(
                          context,
                          orderId: order.id,
                          driverName: driverName,
                          driverPhone: driverPhone,
                          customerName: widget.state.currentUser?.name ?? 'Customer',
                          customerPhone: widget.state.currentUser?.phone ?? '',
                          orderTitle: order.items.isNotEmpty ? order.items.first.product.name : 'Express Order',
                          deliveryAddress: order.deliveryAddress,
                        );
                      },
                      icon: const Icon(Icons.forum_rounded, size: 18, color: Color(0xFF0D7C66)),
                      tooltip: 'Live Chat',
                      style: IconButton.styleFrom(backgroundColor: UiTone.primarySoft),
                    ),
                    const SizedBox(width: 6),
                    // Track Radar CTA
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
                              driverName: driverName,
                              driverPhone: driverPhone,
                              deliveryOtp: order.deliveryOtp,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.moped_rounded, size: 16),
                      label: const Text('Track 🛵', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard({
    required Widget child,
    required Color accent,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(UiRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(width: 4, color: accent)),
              borderRadius: BorderRadius.circular(UiRadius.lg),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(LiveOrderModel order) {
    final statusColor = _getStatusColor(order.status);
    final isActive = _isActive(order.status);
    final isDelivered = _isDeliveredOrder(order.status);

    String itemsSummary = '';
    if (order.items.isNotEmpty) {
      if (order.items.length <= 2) {
        itemsSummary = order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ');
      } else {
        itemsSummary = '${order.items[0].quantity}x ${order.items[0].product.name}, ${order.items[1].quantity}x ${order.items[1].product.name} + ${order.items.length - 2} more';
      }
    }

    return _timelineCard(
      accent: statusColor,
      onTap: () => BookingDetailSheet.showForExpressOrder(context, widget.state, order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: UiTone.surfaceMuted,
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  order.id,
                  style: UiText.caption.copyWith(fontWeight: FontWeight.w700, color: UiTone.softText, fontFamily: 'monospace'),
                ),
              ),
              const Spacer(),
              if (order.deliveryType == 'INSTANT')
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0D7C66), Color(0xFF10A37F)]),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: const Text(
                    '⚡ INSTANT',
                    style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  order.status,
                  style: UiText.caption.copyWith(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            itemsSummary.isNotEmpty ? itemsSummary : 'Fresh Dairy Order',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: UiText.bodyStrong.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: UiTone.softText),
              const SizedBox(width: 4),
              Text(
                '${order.deliveryDate.isNotEmpty ? order.deliveryDate : "Today"} • ${order.deliverySlot}',
                style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: UiTone.surfaceBorder),
          const SizedBox(height: 10),

          // Bottom Action Row (Track / Rate / Invoice / Proof)
          Row(
            children: [
              Text(
                UiFormat.price(order.totalAmount),
                style: UiText.price.copyWith(fontSize: 14.5, color: UiTone.primaryDark),
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
                  label: const Text('Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D7C66))),
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
                  label: const Text('Invoice 🧾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D7C66))),
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
                    DeliveryRatingDialog.show(
                      context,
                      productName: order.items.isNotEmpty ? order.items.first.product.name : 'Express Order',
                      driverName: order.driverName.isNotEmpty ? order.driverName : 'Delivery Partner',
                      deliveryDate: order.deliveryDate.isNotEmpty ? order.deliveryDate : 'Today',
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
    );
  }

  Widget _buildSubscriptionCard(DeliveryTaskModel task) {
    final sub = task.subscriptionDetail;
    final product = sub?.productDetail;
    final statusColor = _getStatusColor(task.status);
    final slotStr = task.slotTime.isNotEmpty ? task.slotTime : '05:30 AM - 07:00 AM';
    final isEvening = slotStr.toUpperCase().contains('PM') || slotStr.toUpperCase().contains('17:') || slotStr.toUpperCase().contains('18:') || slotStr.toUpperCase().contains('19:');
    final isDelivered = _isDeliveredTask(task.status);
    final isActive = _isActiveTask(task.status);

    return _timelineCard(
      accent: statusColor,
      onTap: () => BookingDetailSheet.showForSubscription(context, widget.state, task),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.xs),
            child: Image.network(
              product?.imageUrl ?? 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 54,
                height: 54,
                color: UiTone.surfaceMuted,
                child: const Center(child: Text('🥛', style: TextStyle(fontSize: 24))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product?.name ?? 'Fresh A2 Cow Milk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text(
                        task.status,
                        style: UiText.caption.copyWith(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub?.quantity ?? 1}x ${sub?.packSize ?? "1 Litre"} • Recurring Morning Drop',
                  style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEvening ? const Color(0xFF7C3AED).withValues(alpha: 0.12) : const Color(0xFF0D7C66).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text(
                        '${isEvening ? "🌙" : "☀️"} 📅 ${task.deliveryDate.isNotEmpty ? task.deliveryDate : "Today"} • $slotStr',
                        style: UiText.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isEvening ? const Color(0xFF7C3AED) : const Color(0xFF0D7C66),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Actions (Track Partner / Rate / Invoice / Proof)
                Row(
                  children: [
                    const Spacer(),
                    if (isActive)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => LiveDriverTrackingScreen(
                                state: widget.state,
                                subscriptionTask: task,
                                orderTitle: product?.name ?? 'Fresh A2 Cow Milk',
                                deliveryAddress: task.deliveryAddress,
                                driverName: task.driverDetail?.fullName.isNotEmpty == true ? task.driverDetail!.fullName : 'Assigned Partner',
                                driverPhone: task.driverDetail?.phone ?? '',
                                deliveryOtp: '06AM',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.moped_rounded, size: 13),
                        label: const Text('Track Partner 🛵', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                          elevation: 0,
                        ),
                      )
                    else if (isDelivered) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          OrderInvoiceSheet.show(
                            context,
                            task: task,
                            orderId: 'SUB-DROP-#${task.id}',
                            orderDate: task.deliveryDate.isNotEmpty ? task.deliveryDate : 'Today',
                            slotTime: slotStr,
                            address: task.deliveryAddress,
                            totalAmount: (sub?.displayPrice ?? 40) * (sub?.quantity ?? 1),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFF0D7C66)),
                        label: const Text('Invoice 🧾', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0D7C66))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D7C66)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          minimumSize: const Size(0, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () {
                          DeliveryRatingDialog.show(
                            context,
                            productName: product?.name ?? 'Fresh A2 Cow Milk',
                            driverName: task.driverDetail?.fullName.isNotEmpty == true ? task.driverDetail!.fullName : 'Assigned Partner',
                            deliveryDate: task.deliveryDate.isNotEmpty ? task.deliveryDate : 'Today',
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
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'DELIVERED' || s == 'COMPLETED') return const Color(0xFF10B981);
    if (s == 'OUT_FOR_DELIVERY' || s == 'IN_TRANSIT' || s == 'ON_THE_WAY') return const Color(0xFF0D7C66);
    if (s == 'PLACED' || s == 'CONFIRMED' || s == 'PREPARING' || s == 'PACKED' || s == 'ACTIVE' || s == 'PENDING') return const Color(0xFF0284C7);
    if (s == 'CANCELLED' || s == 'REJECTED' || s == 'FAILED' || s == 'SKIPPED') return const Color(0xFFEF4444);
    if (s == 'PAUSED') return const Color(0xFFF59E0B);
    return UiTone.softText;
  }
}
