import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/ui_tokens.dart';
import '../../providers/app_state.dart';
import '../../models/live_order_model.dart';
import '../../models/delivery_task_model.dart';
import '../../widgets/booking_detail_sheet.dart';
import 'help_support_screen.dart';
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
  int _selectedFilterIndex = 0; // 0: All, 1: Live Express, 2: Daily Subscriptions

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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

  @override
  Widget build(BuildContext context) {
    final liveOrders = widget.state.liveOrders;
    final subscriptions = widget.state.deliveries;

    final totalCount = liveOrders.length + subscriptions.length;
    final expressCount = liveOrders.length;
    final subsCount = subscriptions.length;

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Live Header Bar ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Bookings & Orders 📦',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: UiTone.ink),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Live orders & subscriptions tracking',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => HelpSupportScreen(state: widget.state, initialTopic: 'I need help tracking my live order'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: UiTone.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(UiRadius.sm),
                        border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headset_mic_rounded, color: UiTone.primary, size: 13),
                          SizedBox(width: 3),
                          Text('Support', style: TextStyle(color: UiTone.primary, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      color: UiTone.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                      border: Border.all(color: UiTone.secondary),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: UiTone.secondary, size: 6),
                        SizedBox(width: 3),
                        Text('LIVE', style: TextStyle(color: UiTone.primary, fontSize: 9, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 2. Segmented Filter Bar (All / Live Express / Subscriptions) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'All Bookings ($totalCount)'),
                const SizedBox(width: 8),
                _buildFilterChip(1, '⚡ Live Express Orders ($expressCount)'),
                const SizedBox(width: 8),
                _buildFilterChip(2, '🥛 Daily Subscriptions ($subsCount)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Content Display based on Filter ──
          if (totalCount == 0 && _selectedFilterIndex == 0) ...[
            _buildEmptyState(
              'No Active Bookings Yet',
              'You have not placed any live express orders or subscriptions yet. Explore our store for fresh farm milk, meats, eggs & water cans!',
              Icons.receipt_long_rounded,
              actionLabel: 'Explore Store 🥛',
              onAction: () => widget.state.setTab(0),
            ),
          ] else ...[
            if (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) ...[
              if (liveOrders.isNotEmpty) ...[
                _buildSectionHeader('⚡ Live Express & Instant Orders', '${liveOrders.length} active'),
                const SizedBox(height: 10),
                ...liveOrders.map((order) => _buildLiveOrderCard(order)),
                const SizedBox(height: 14),
              ] else if (_selectedFilterIndex == 1) ...[
                _buildEmptyState(
                  'No Live Express Orders',
                  'You have no active instant orders right now. Add items from store for 30-min express delivery!',
                  Icons.electric_bolt_rounded,
                  actionLabel: 'Order Express Items ⚡',
                  onAction: () => widget.state.setTab(0),
                ),
              ],
            ],

            if (_selectedFilterIndex == 0 || _selectedFilterIndex == 2) ...[
              if (subscriptions.isNotEmpty) ...[
                _buildSectionHeader('🥛 Morning Subscriptions (6 AM)', '${subscriptions.length} deliveries'),
                const SizedBox(height: 10),
                ...subscriptions.map((task) => _buildSubscriptionDeliveryCard(task)),
              ] else if (_selectedFilterIndex == 2) ...[
                _buildEmptyState(
                  'No Active Subscriptions',
                  'Subscribe to fresh milk, eggs, or water cans for daily morning 06:00 AM doorstep delivery!',
                  Icons.autorenew_rounded,
                  actionLabel: 'Subscribe to Products 🥛',
                  onAction: () => widget.state.setTab(0),
                ),
              ],
            ],
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(UiRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
          borderRadius: BorderRadius.circular(UiRadius.sm),
          border: Border.all(
            color: isSelected ? UiTone.primary : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String badge) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(color: UiTone.surfaceBorder, borderRadius: BorderRadius.circular(UiRadius.xs)),
          child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: UiTone.softText)),
        ),
      ],
    );
  }

  // ── 4. Live Express Order Card (Direct Cart / Instant Orders) ──
  Widget _buildLiveOrderCard(LiveOrderModel order) {
    final isDelivered = order.status == 'DELIVERED';
    final isOut = order.status == 'OUT_FOR_DELIVERY';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
      child: InkWell(
        onTap: () => BookingDetailSheet.showForExpressOrder(context, widget.state, order),
        borderRadius: BorderRadius.circular(UiRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Order Top Bar: Order ID, Type Badge, Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: UiTone.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                        ),
                        child: Text(
                          order.id,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: UiTone.accentBlue),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: UiTone.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on_rounded, color: UiTone.error, size: 11),
                            Text('EXPRESS', style: TextStyle(color: UiTone.error, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: (isDelivered ? UiTone.secondary : UiTone.warning).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    isDelivered ? 'DELIVERED ✅' : (isOut ? 'OUT FOR DELIVERY 🛵' : 'PREPARING 👨‍🍳'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDelivered ? UiTone.primary : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Scheduled Date & Time Slot Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: UiTone.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(UiRadius.xs),
                border: Border.all(color: UiTone.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 14, color: UiTone.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '📅 Scheduled: ${order.deliveryDate} • ⏰ ${order.deliverySlot}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Live Stepper Bar
            _buildLiveProgressStepper(order.status),
            const SizedBox(height: 12),

            // Items Breakdown List
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UiTone.shellBackground,
                borderRadius: BorderRadius.circular(UiRadius.sm),
                border: Border.all(color: UiTone.surfaceBorder),
              ),
              child: Column(
                children: [
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: UiTone.surface, borderRadius: BorderRadius.circular(UiRadius.xs)),
                            child: Text(
                              _getCategoryEmoji(item.product.category),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.product.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Text(
                            '₹${item.totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: UiTone.ink),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Paid • ${order.paymentStatus}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: UiTone.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // OTP & Delivery Address Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: UiTone.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                    border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_rounded, color: UiTone.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'OTP: ${order.deliveryOtp}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📍 ${order.deliveryAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Driver Card with Call Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: UiTone.surfaceMuted,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: UiTone.primary,
                    child: Icon(Icons.person, color: UiTone.surface, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        Text('Assigned Delivery Partner', style: TextStyle(fontSize: 9.5, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: UiTone.primary, size: 20),
                    onPressed: () => _callDriver(order.driverPhone),
                    tooltip: 'Call Driver',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Live GPS Moving Driver Map CTA Button
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
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
                icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                label: const Text('Track Live Driver on Map 🛰️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ── 5. Subscription Daily Delivery Card ──
  Widget _buildSubscriptionDeliveryCard(DeliveryTaskModel task) {
    final sub = task.subscriptionDetail;
    final product = sub?.productDetail;
    final isDelivered = task.status == 'DELIVERED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
      child: InkWell(
        onTap: () => BookingDetailSheet.showForSubscription(context, widget.state, task),
        borderRadius: BorderRadius.circular(UiRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(UiRadius.sm),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sub?.quantity ?? 1}x Unit • ${sub?.scheduleType ?? 'DAILY'} • ${task.slotTime}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${task.deliveryDate}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: UiTone.primary, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: (isDelivered ? UiTone.secondary : Colors.orange).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      isDelivered ? 'DELIVERED ✅' : 'SCHEDULED ⏰',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDelivered ? UiTone.primary : Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),

              if (isDelivered && task.proofImageUrl.isNotEmpty) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.camera_alt_rounded, size: 14, color: UiTone.secondary),
                    const SizedBox(width: 4),
                    const Text('Doorstep Photo Proof Uploaded', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
                    const Spacer(),
                    Text(task.deliveredAt ?? '06:14 AM', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => LiveDriverTrackingScreen(
                            state: widget.state,
                            orderTitle: product?.name ?? 'Morning Milk Subscription',
                            deliveryAddress: task.deliveryAddress,
                            driverName: task.driverDetail?.fullName.isNotEmpty == true
                                ? task.driverDetail!.fullName
                                : 'Assigned Hub Driver',
                            driverPhone: task.driverDetail?.phone.isNotEmpty == true
                                ? task.driverDetail!.phone
                                : '+91 8919548905',
                            deliveryOtp: '06AM',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_searching_rounded, size: 16, color: UiTone.primary),
                    label: const Text('Track Morning Delivery Van 🛰️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: UiTone.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: UiTone.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveProgressStepper(String status) {
    int currentStep = 1;
    if (status == 'PREPARING') currentStep = 2;
    if (status == 'OUT_FOR_DELIVERY') currentStep = 3;
    if (status == 'DELIVERED') currentStep = 4;

    return Row(
      children: [
        _buildStepNode('Placed', 1, currentStep),
        _buildStepConnector(1, currentStep),
        _buildStepNode('Packed', 2, currentStep),
        _buildStepConnector(2, currentStep),
        _buildStepNode('On Way', 3, currentStep),
        _buildStepConnector(3, currentStep),
        _buildStepNode('Doorstep', 4, currentStep),
      ],
    );
  }

  Widget _buildStepNode(String label, int stepNumber, int activeStep) {
    final isDone = activeStep >= stepNumber;
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: isDone ? UiTone.primary : const Color(0xFFCBD5E1),
            child: isDone
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : Text('$stepNumber', style: const TextStyle(fontSize: 8.5, color: UiTone.surface, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              color: isDone ? UiTone.ink : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int stepNumber, int activeStep) {
    final isDone = activeStep > stepNumber;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 12),
        color: isDone ? UiTone.primary : UiTone.surfaceBorder,
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, {String? actionLabel, VoidCallback? onAction}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: UiTone.shellBackground,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  String _getCategoryEmoji(String cat) {
    switch (cat.toUpperCase()) {
      case 'MEAT':
        return '🍗';
      case 'EGGS':
        return '🥚';
      case 'WATER_CAN':
        return '💧';
      case 'MILK':
      default:
        return '🥛';
    }
  }
}
