import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/ui_tokens.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0D7C66),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 14),
                    child: Text(
                      _selectedFilterIndex == 2
                          ? 'Delivered Orders'
                          : _selectedFilterIndex == 3
                              ? 'Cancelled Orders'
                              : 'Recent Orders',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ),
                  ...remainingOrders.map((o) => _buildOrderCard(o)),
                ],
                if (filteredSubscriptions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 14),
                    child: Row(
                      children: [
                        Text(
                          _selectedFilterIndex == 2
                              ? 'Delivered Morning Milk'
                              : _selectedFilterIndex == 3
                                  ? 'Skipped / Paused Deliveries'
                                  : 'Morning Subscriptions',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(UiRadius.xs)),
                          child: Text('${filteredSubscriptions.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Orders',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            SizedBox(height: 2),
            Text(
              'Track & manage your orders',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFE6F5F0), borderRadius: BorderRadius.circular(10)),
          child: Text(
            '$totalCount',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66)),
          ),
        ),
      ],
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    chips[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
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
      padding: const EdgeInsets.only(top: 40.0, bottom: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            if (filterIndex > 0)
              OutlinedButton(
                onPressed: () => setState(() => _selectedFilterIndex = 0),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0D7C66)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('View All Orders', style: TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton(
                onPressed: () => widget.state.setTab(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7C66),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Start Shopping 🛒', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderHeroCard(LiveOrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF10B766).withValues(alpha: 0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x5510B766), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B766),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('LIVE ORDER', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                order.id,
                style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Arriving soon',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B766)),
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 14),
          _buildHeroStepper(order.status),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.key, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 6),
                const Text('Start OTP', style: TextStyle(color: Colors.white60, fontSize: 12)),
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
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF10B766),
                child: Icon(Icons.person, color: Colors.white, size: 20),
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
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _callDriver(order.driverPhone),
                icon: const Icon(Icons.phone, color: Color(0xFF10B766)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
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
                backgroundColor: const Color(0xFF0D7C66),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Track Live Driver 🛰️', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
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

    Color bgColor = isDone ? const Color(0xFF059669) : (isCurrent ? const Color(0xFF10B766) : Colors.white12);
    
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
              ? const Icon(Icons.check, color: Colors.white, size: 12)
              : (isCurrent
                  ? AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5 + 0.5 * _animController.value),
                              width: 2,
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
            color: isFuture ? Colors.white38 : Colors.white,
            fontSize: 10,
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
        color: isDone ? const Color(0xFF059669) : Colors.white12,
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'PLACED' || status == 'PENDING') return const Color(0xFFD97706);
    if (status == 'PACKED' || status == 'OUT_FOR_DELIVERY') return const Color(0xFF059669);
    if (status == 'DELIVERED') return const Color(0xFF2563EB);
    if (status == 'CANCELLED') return const Color(0xFFDC2626);
    return const Color(0xFFD97706); // fallback
  }

  Widget _buildOrderCard(LiveOrderModel order) {
    final statusColor = _getStatusColor(order.status);
    final isActive = _isActive(order.status);
    final isDelivered = order.status == 'DELIVERED';
    
    String itemsSummary = '';
    if (order.items.isNotEmpty) {
      if (order.items.length <= 2) {
        itemsSummary = order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ');
      } else {
        itemsSummary = '${order.items[0].quantity}x ${order.items[0].product.name}, ${order.items[1].quantity}x ${order.items[1].product.name} + ${order.items.length - 2} more';
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left timeline
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 24),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 130, // Approx height, will fill nicely
              color: const Color(0xFFE2E8F0),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Expanded Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => BookingDetailSheet.showForExpressOrder(context, widget.state, order),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(width: 4, color: statusColor)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.id,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontFamily: 'monospace'),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        itemsSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${order.deliveryDate} • ${order.deliverySlot}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4F1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Track', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            )
                          else if (isDelivered)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Reorder', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(DeliveryTaskModel task) {
    final sub = task.subscriptionDetail;
    final product = sub?.productDetail;
    final isDelivered = task.status == 'DELIVERED';
    final statusColor = isDelivered ? const Color(0xFF2563EB) : const Color(0xFF059669);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 24),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 120, // Approx height
              color: const Color(0xFFE2E8F0),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => BookingDetailSheet.showForSubscription(context, widget.state, task),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(width: 4, color: statusColor)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product?.imageUrl ?? 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 50,
                            height: 50,
                            color: const Color(0xFFF1F5F9),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sub?.quantity ?? 1}x Unit • ${task.deliveryDate}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                task.status,
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
