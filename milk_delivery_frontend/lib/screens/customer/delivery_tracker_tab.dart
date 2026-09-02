import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
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
                                if (subTasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(10),
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
                        if (order.driverPhone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, color: Color(0xFF0D7C66)),
                            onPressed: () => launchUrl(Uri.parse('tel:${order.driverPhone}')),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                            ),
                          ),
                        ],
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
            if (tasks.isEmpty)
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
                      isTelugu ? 'సభ్యత్వ డెలివరీలు ఏవీ లేవు' : 'No Subscription Deliveries Found',
                      style: UiText.h2.copyWith(fontSize: 16, color: UiTone.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isTelugu
                          ? 'తాజా పాలు ప్రతిరోజూ ఉదయం 06:00 గంటలకు మీ ఇంటి వద్ద పొందండి.'
                          : 'Daily farm fresh milk drops will appear here during morning delivery routes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...tasks.map((task) => _buildSubscriptionTaskCard(context, task, isTelugu)),
          ],
        ),
      ),
    );
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
