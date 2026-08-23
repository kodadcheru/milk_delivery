import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';
import '../../providers/app_state.dart';
import '../../models/live_order_model.dart';
import '../../models/delivery_task_model.dart';
import '../../widgets/booking_detail_sheet.dart';
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
    super.dispose();
  }

  void _callDriver(String phone) async {
    final cleanPhone = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dialing partner: $phone')),
        );
      }
    }
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

    final activeOrders = filteredOrders.where((o) => _isActiveOrder(o.status)).toList();
    final firstActiveOrder = (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) && activeOrders.isNotEmpty
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
            Text('My Orders', style: UiText.h1),
            const SizedBox(height: 2),
            Text('Track & manage your orders', style: UiText.label),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: UiTone.primarySoft,
            borderRadius: BorderRadius.circular(UiRadius.sm),
          ),
          child: Text(
            '$totalCount',
            style: UiText.bodyStrong.copyWith(color: UiTone.primary, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {int? count}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 14),
      child: Row(
        children: [
          Text(title, style: UiText.h2.copyWith(fontSize: 16)),
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
      height: 48,
      margin: const EdgeInsets.only(top: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(
                      color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
                    ),
                  ),
                  child: Text(
                    chips[index],
                    style: UiText.label.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : UiTone.softText,
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
        subtitle = 'You do not have any orders or morning deliveries currently in transit.';
        icon = Icons.bolt_rounded;
        break;
      case 2:
        title = 'No Delivered Orders';
        subtitle = 'Delivered express items and past morning milk deliveries will appear here.';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 3:
        title = 'No Cancelled Orders';
        subtitle = 'You have not cancelled or skipped any orders or deliveries.';
        icon = Icons.cancel_outlined;
        break;
      default:
        title = 'No Orders Yet';
        subtitle = 'Your express orders and morning subscriptions will appear here.';
        icon = Icons.receipt_long_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 48.0, bottom: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: UiTone.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: UiTone.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: UiText.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                style: UiText.label.copyWith(height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),
            if (filterIndex > 0)
              OutlinedButton(
                onPressed: () => setState(() => _selectedFilterIndex = 0),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: UiTone.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('View All Orders',
                    style: UiText.bodyStrong.copyWith(color: UiTone.primary)),
              )
            else
              ElevatedButton(
                onPressed: () => widget.state.setTab(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Start Shopping 🛒',
                    style: UiText.bodyStrong.copyWith(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Live-order hero card — on-brand teal gradient focal card ──
  Widget _buildActiveOrderHeroCard(LiveOrderModel order) {
    return Container(
      decoration: BoxDecoration(
        gradient: UiGradient.hero,
        borderRadius: BorderRadius.circular(UiRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        boxShadow: UiShadow.glowPrimary,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('LIVE ORDER',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                order.id,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Arriving soon',
            style: UiText.h2.copyWith(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 6,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.24),
            ),
          ),
          const SizedBox(height: 14),
          _buildHeroStepper(order.status),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Text('Start OTP', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Text(
                  order.deliveryOtp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.driverName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'Delivery Partner',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _callDriver(order.driverPhone),
                icon: const Icon(Icons.phone, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: UiTone.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                elevation: 0,
              ),
              child: Text('Track Live Driver 🛰️',
                  style: UiText.bodyStrong.copyWith(color: UiTone.primaryDark, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStepper(String status) {
    int currentStep = 1;
    if (status == 'PREPARING' || status == 'PACKED') currentStep = 2;
    if (status == 'OUT_FOR_DELIVERY') currentStep = 3;
    if (status == 'DELIVERED') currentStep = 4;

    return Row(
      children: [
        _buildHeroStepNode('Placed', 1, currentStep),
        _buildHeroConnector(1, currentStep),
        _buildHeroStepNode('Packed', 2, currentStep),
        _buildHeroConnector(2, currentStep),
        _buildHeroStepNode('On Way', 3, currentStep),
        _buildHeroConnector(3, currentStep),
        _buildHeroStepNode('Doorstep', 4, currentStep),
      ],
    );
  }

  Widget _buildHeroStepNode(String label, int stepNumber, int activeStep) {
    final isDone = activeStep > stepNumber;
    final isCurrent = activeStep == stepNumber;
    final isFuture = activeStep < stepNumber;

    final Color bgColor =
        isFuture ? Colors.white.withValues(alpha: 0.30) : Colors.white;

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: isDone
              ? const Icon(Icons.check, color: UiTone.primary, size: 12)
              : (isCurrent
                  ? AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: UiTone.primary.withValues(alpha: 0.4 + 0.6 * _animController.value),
                              width: 3,
                            ),
                          ),
                        );
                      },
                    )
                  : const SizedBox()),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isFuture ? Colors.white70 : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroConnector(int stepNumber, int activeStep) {
    final isDone = activeStep > stepNumber;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 14),
        color: isDone ? Colors.white : Colors.white.withValues(alpha: 0.28),
      ),
    );
  }

  /// Tokenized status → accent color, exhaustive over known order/task statuses.
  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'DELIVERED' || s == 'COMPLETED') return UiTone.accentBlue;
    if (s == 'CANCELLED' || s == 'REJECTED' || s == 'FAILED' || s == 'SKIPPED') return UiTone.error;
    if (s == 'PAUSED') return UiTone.warning;
    if (s == 'OUT_FOR_DELIVERY' || s == 'PACKED' || s == 'IN_TRANSIT' || s == 'ACTIVE') return UiTone.success;
    if (s == 'PLACED' || s == 'PENDING' || s == 'CONFIRMED' || s == 'PREPARING' || s == 'PROCESSING') {
      return UiTone.warning;
    }
    return UiTone.primary;
  }

  /// Shared timeline-dot + connector + white card chrome for both express
  /// orders and morning subscriptions. The connector fills the card height via
  /// `IntrinsicHeight`, so it tracks content instead of a fragile fixed height.
  Widget _timelineCard({
    required Color accent,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 24),
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              Expanded(
                child: Container(width: 2, color: UiTone.surfaceBorder),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.lg),
                border: Border.all(color: UiTone.surfaceMuted),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(LiveOrderModel order) {
    final statusColor = _getStatusColor(order.status);
    final isActive = _isActive(order.status);

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  order.status,
                  style: UiText.caption.copyWith(color: statusColor, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            itemsSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: UiText.bodyStrong.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: UiText.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${order.deliveryDate} • ${order.deliverySlot}',
                  style: UiText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                UiFormat.price(order.totalAmount),
                style: UiText.price,
              ),
              const Spacer(),
              if (isActive)
                InkWell(
                  onTap: () {
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
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: UiTone.primarySoft,
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                    ),
                    child: Text('Track',
                        style: UiText.caption.copyWith(color: UiTone.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
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

    return _timelineCard(
      accent: statusColor,
      onTap: () => BookingDetailSheet.showForSubscription(context, widget.state, task),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.xs),
            child: Image.network(
              product?.imageUrl ?? 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 50,
                height: 50,
                color: UiTone.surfaceMuted,
                child: const Center(child: Text('🥛', style: TextStyle(fontSize: 22))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Fresh A2 Cow Milk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UiText.bodyStrong.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sub?.quantity ?? 1}x ${sub?.packSize ?? "Unit"} • ${task.deliveryDate}',
                  style: UiText.caption,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ),
        ],
      ),
    );
  }
}
