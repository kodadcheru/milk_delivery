import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/delivery_chat_sheet.dart';
import '../../widgets/delivery_rating_dialog.dart';
import '../../widgets/order_invoice_sheet.dart';
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
  late TabController _tabController;
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Delivered, 3: Cancelled/Skipped
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final isTelugu = widget.state.isTelugu;
    final liveOrders = widget.state.liveOrders;
    final subTasks = widget.state.deliveries;
    final activeSubs = widget.state.subscriptions.where((s) => s.status != 'CANCELLED').toList();

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
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D7C66)),
                          tooltip: 'Refresh Orders',
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await widget.state.reloadAllData();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Dual Top Sliding Tab Selector: Express Orders & Subscriptions ──
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        onTap: (index) => HapticFeedback.selectionClick(),
                        indicator: BoxDecoration(
                          color: UiTone.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: UiTone.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
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
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(10),
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
                                const Text('🔁', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(isTelugu ? 'సభ్యత్వాలు' : 'Subscriptions'),
                                if (activeSubs.isNotEmpty || subTasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${activeSubs.isNotEmpty ? activeSubs.length : subTasks.length}',
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
                          _filterPill(0, isTelugu ? 'అన్నీ' : 'All'),
                          const SizedBox(width: 8),
                          _filterPill(1, isTelugu ? 'యాక్టివ్ / డెలివరీలో' : 'Active / In-Transit'),
                          const SizedBox(width: 8),
                          _filterPill(2, isTelugu ? 'పూర్తయినవి' : 'Delivered'),
                          const SizedBox(width: 8),
                          _filterPill(3, isTelugu ? 'రద్దు / స్కిప్ చేయబడినవి' : 'Cancelled / Skipped'),
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

  Widget _filterPill(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? UiTone.primary : Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: UiTone.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: EXPRESS ORDERS VIEW
  // ══════════════════════════════════════════════════════════════════════════
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

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      isTelugu ? 'తక్షణ ఆర్డర్లు ఏవీ లేవు' : 'No Express Orders Found',
                      style: UiText.h2.copyWith(fontSize: 16, color: UiTone.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isTelugu
                          ? 'తాజా పాలు, పెరుగు, పన్నీర్ మరియు వాటర్ క్యాన్‌లను తక్షణమే ఆర్డర్ చేయండి.'
                          : 'Order fresh milk, curd, paneer, and pure water cans with instant dispatch.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => widget.state.setTab(0),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: Text(isTelugu ? 'ఉత్పత్తులను బ్రౌజ్ చేయండి' : 'Browse Fresh Products'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...orders.map((order) => _buildExpressOrderCard(context, order, isTelugu)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpressOrderCard(BuildContext context, LiveOrderModel order, bool isTelugu) {
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

    return InkWell(
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
                        order.deliverySlot,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
                ],
              ),
            ),

            // Items Preview
            Padding(
              padding: const EdgeInsets.all(16),
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
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              BookingDetailSheet.showForLiveOrder(context, widget.state, order);
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: Text(isTelugu ? 'ఆర్డర్ షీట్ 📄' : 'Order Sheet 📄'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              BookingDetailSheet.showForLiveOrder(context, widget.state, order);
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: Text(isTelugu ? 'ఆర్డర్ షీట్ 📄' : 'Order Sheet 📄'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
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
                            label: Text(isTelugu ? 'రశీదు / ఇన్వాయిస్' : 'Invoice 📄'),
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
                            tooltip: 'View Proof',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                       ClipRRect(
                                         borderRadius: BorderRadius.circular(12),
                                         child: Image.network(order.proofImageUrl, fit: BoxFit.cover),
                                       ),
                                    ],
                                  ),
                                ),
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: SUBSCRIPTION DELIVERIES VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSubscriptionDeliveriesView(BuildContext context, bool isTelugu) {
    // 1. Filter parent recurring subscriptions
    final subs = widget.state.subscriptions.where((sub) {
      if (_searchQuery.isNotEmpty) {
        final pName = (sub.productDetail?.name ?? '').toLowerCase();
        final addr = sub.deliveryAddress.toLowerCase();
        if (!pName.contains(_searchQuery) && !addr.contains(_searchQuery)) return false;
      }
      if (_selectedFilterIndex == 1) return sub.status == 'ACTIVE';
      if (_selectedFilterIndex == 2) return sub.status == 'PAUSED';
      if (_selectedFilterIndex == 3) return sub.status == 'CANCELLED';
      return true;
    }).toList();

    // 2. Filter daily fulfillment delivery drops
    final tasks = widget.state.deliveries.where((task) {
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

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Empty state when both subscriptions and daily runs are empty
            if (subs.isEmpty && tasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Text('🥛', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      isTelugu ? 'సభ్యత్వాలు లేదా డెలివరీలు ఏవీ లేవు' : 'No Active Subscriptions Found',
                      style: UiText.h2.copyWith(fontSize: 16, color: UiTone.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isTelugu
                          ? 'తాజా పాలు ప్రతిరోజూ ఉదయం 06:00 గంటలకు మీ ఇంటి వద్ద పొందడానికి సబ్‌స్క్రయిబ్ చేసుకోండి.'
                          : 'Subscribe to farm fresh milk & dairy for guaranteed 06:00 AM morning doorstep delivery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
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
                  ],
                ),
              ),

            // ── Section 1: Active Recurring Subscriptions ──
            if (subs.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        isTelugu ? 'యాక్టివ్ సబ్‌స్క్రిప్షన్లు' : 'Active Subscriptions',
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
                          '${subs.length}',
                          style: TextStyle(color: UiTone.primary, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.state.setTab(1); // Navigate to dedicated Subscriptions tab
                    },
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: Text(isTelugu ? 'నిర్వహించండి' : 'Manage All'),
                    style: TextButton.styleFrom(
                      foregroundColor: UiTone.primary,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...subs.map((sub) => _buildActiveSubscriptionCard(context, sub, isTelugu)),
              const SizedBox(height: 16),
            ],

            // ── Section 2: Daily Delivery Drops / Route Fulfillment ──
            if (tasks.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    isTelugu ? 'డైలీ డెలివరీ రన్స్' : 'Daily Delivery Drops',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: UiTone.ink),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...tasks.map((task) => _buildSubscriptionTaskCard(context, task, isTelugu)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard(BuildContext context, SubscriptionModel sub, bool isTelugu) {
    final prod = sub.productDetail;
    final pName = prod?.name ?? 'Farm Fresh Milk';
    final isPaused = sub.status == 'PAUSED';
    final isCancelled = sub.status == 'CANCELLED';
    final unitPrice = prod?.pricePerUnit ?? 72.0;
    final dailyTotal = unitPrice * sub.quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaused ? Colors.orange.shade200 : Colors.grey.shade200,
          width: isPaused ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPaused
                      ? Colors.orange.withValues(alpha: 0.1)
                      : UiTone.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(prod?.icon ?? '🥛', style: const TextStyle(fontSize: 24)),
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
                      '${sub.packSize} • ${sub.scheduleType}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? Colors.red.withValues(alpha: 0.1)
                      : isPaused
                          ? Colors.orange.withValues(alpha: 0.12)
                          : const Color(0xFF0D7C66).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCancelled
                            ? Colors.red
                            : isPaused
                                ? Colors.orange.shade700
                                : const Color(0xFF0D7C66),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isCancelled
                          ? (isTelugu ? 'రద్దు చేయబడింది' : 'CANCELLED')
                          : isPaused
                              ? (isTelugu ? 'విరామం' : 'PAUSED')
                              : (isTelugu ? 'యాక్టివ్' : 'ACTIVE'),
                      style: TextStyle(
                        color: isCancelled
                            ? Colors.red
                            : isPaused
                                ? Colors.orange.shade800
                                : const Color(0xFF0D7C66),
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCancelled) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: isTelugu ? 'సభ్యత్వాన్ని తొలగించండి' : 'Delete Subscription',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () => _confirmDeleteSubscription(context, sub, isTelugu),
                ),
              ],
            ],
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    sub.deliverySlot,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                '${sub.quantity} Units • ${UiFormat.price(dailyTotal)} / day',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: UiTone.ink),
              ),
            ],
          ),
          if (sub.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sub.deliveryAddress.length > 36
                        ? '${sub.deliveryAddress.substring(0, 36)}...'
                        : sub.deliveryAddress,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (!isCancelled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final ok = await widget.state.toggleSubscriptionStatus(sub.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: isPaused ? const Color(0xFF0D7C66) : Colors.orange.shade800,
                            content: Text(isPaused
                                ? (isTelugu ? 'సబ్‌స్క్రిప్షన్ పునఃప్రారంభించబడింది' : 'Subscription resumed!')
                                : (isTelugu ? 'సబ్‌స్క్రిప్షన్ తాత్కాలికంగా నిలిపివేయబడింది' : 'Subscription paused')),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 16,
                      color: isPaused ? const Color(0xFF0D7C66) : Colors.orange.shade800,
                    ),
                    label: Text(
                      isPaused
                          ? (isTelugu ? 'పునఃప్రారంభించు ▶' : 'Resume ▶')
                          : (isTelugu ? 'విరామం ⏸' : 'Pause ⏸'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPaused ? const Color(0xFF0D7C66) : Colors.orange.shade800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isPaused
                            ? const Color(0xFF0D7C66).withValues(alpha: 0.4)
                            : Colors.orange.shade300,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteSubscription(context, sub, isTelugu),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                  label: Text(
                    isTelugu ? 'తొలగించు' : 'Delete',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                    backgroundColor: Colors.red.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.state.setTab(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    isTelugu ? 'సవరించు' : 'Manage',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSubscription(BuildContext context, SubscriptionModel sub, bool isTelugu) async {
    HapticFeedback.mediumImpact();
    final pName = sub.productDetail?.name ?? 'Subscription';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isTelugu ? 'సభ్యత్వాన్ని తొలగించాలా?' : 'Delete Subscription?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTelugu
                  ? '${widget.state.translateProduct(pName)} సభ్యత్వాన్ని ఖచ్చితంగా తొలగించాలనుకుంటున్నారా?'
                  : 'Are you sure you want to delete your recurring subscription for ${widget.state.translateProduct(pName)}?',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTelugu
                          ? 'రేపటి నుండి ఉదయం డెలివరీలు మరియు రోజువారీ ఛార్జీలు వెంటనే ఆగిపోతాయి.'
                          : 'Morning doorstep deliveries and daily charges will be stopped immediately.',
                      style: TextStyle(color: Colors.brown.shade800, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isTelugu ? 'ఉంచండి' : 'Keep Plan',
              style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: Text(isTelugu ? 'అవును, తొలగించు' : 'Yes, Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      final ok = await widget.state.cancelSubscription(sub.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? Colors.red.shade700 : Colors.orange.shade800,
            content: Text(ok
                ? (isTelugu ? 'సభ్యత్వం విజయవంతంగా తొలగించబడింది.' : 'Subscription deleted successfully.')
                : (isTelugu ? 'లోపం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.' : 'Failed to delete subscription.')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSubscriptionTaskCard(BuildContext context, DeliveryTaskModel task, bool isTelugu) {
    final isDelivered = _isDeliveredTask(task.status);
    final statusColor = _getStatusColor(task.status);
    final pName = task.productName.isNotEmpty ? task.productName : 'Fresh Cow Milk';

    return InkWell(
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
                          'TASK #${task.id}',
                          style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.slotTime,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
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
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              BookingDetailSheet.showForSubscriptionTask(context, widget.state, task);
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 15),
                            label: Text(isTelugu ? 'వివరాలు 📄' : 'Order Sheet 📄'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              BookingDetailSheet.showForSubscriptionTask(context, widget.state, task);
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 15),
                            label: Text(isTelugu ? 'వివరాలు 📄' : 'Order Sheet 📄'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
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
                              showDialog(
                                context: context,
                                builder: (_) => DeliveryRatingDialog(
                                  state: widget.state,
                                  productName: pName,
                                  driverName: task.driverDetail?.fullName ?? 'Delivery Hero',
                                  deliveryDate: task.deliveryDate,
                                  taskId: task.id,
                                ),
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
                          IconButton(
                            icon: const Icon(Icons.photo_camera_rounded, color: Color(0xFF0284C7)),
                            tooltip: 'Doorstep Proof',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(task.proofImageUrl, fit: BoxFit.cover),
                                  ),
                                ),
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
    );
  }
}
