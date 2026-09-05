import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_config.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';
import '../../widgets/ui_kit/ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/customer_address_model.dart';
import '../../models/live_order_model.dart';
import '../../models/subscription_model.dart';
import '../../models/bottle_return_model.dart';
import '../../models/provider_payout_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/hub_realtime_service.dart';
import 'provider_fleet_map_screen.dart';
import 'provider_earnings_screen.dart';
import '../driver/morning_batch_screen.dart';
import '../common/day_wise_orders_screen.dart';
import '../../widgets/booking_detail_sheet.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final AppState state;

  const ProviderDashboardScreen({super.key, required this.state});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _hubCommandTab = 0; // 0: Live Tasks, 1: Fleet & Balancer, 2: Batch & Bottles
  String _taskStatusFilter = 'ALL'; // ALL, PENDING, DELIVERED, EXPRESS
  int _selectedFilter = 0; // 0: All, 1: Active Subs, 2: Express, 3: Fleet, 4: Capacity, 5: Broadcasts, 6: Payouts, 7: Paused, 8: Bottles
  String _selectedShift = DateTime.now().hour >= 12 ? 'EVENING' : 'MORNING'; // Auto-selects EVENING after 12 PM, MORNING after 12 AM
  String _searchQuery = '';
  int _activeDriverCount = 0; // Synced with associated drivers for this hub
  List<Map<String, dynamic>> _hubInventory = [];
  List<Map<String, dynamic>> _liveFleet = [];
  Timer? _hubRealtimeTimer;

  final List<Map<String, dynamic>> _broadcastAlerts = [];
  List<ProviderPayoutModel> _payoutHistory = [];
  List<BottleReturnModel> _bottleReturns = [];

  String get _activeHubName {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    return activeHub != null ? (activeHub['name'] ?? AppConfig.defaultHubName) : AppConfig.defaultHubName;
  }

  @override
  void initState() {
    super.initState();
    _loadAllHubData();
    // Streamlined 20-second heartbeat to avoid database query churn
    _hubRealtimeTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (_hubCommandTab == 1) {
        _loadLiveFleet();
      } else if (_hubCommandTab == 2) {
        _loadBottleReturns();
      } else {
        _loadHubInventory();
      }
    });
  }

  @override
  void dispose() {
    _hubRealtimeTimer?.cancel();
    super.dispose();
  }

  void _loadAllHubData() {
    _loadLiveFleet();
    _loadHubInventory();
    _loadPayouts();
    _loadBottleReturns();
  }

  void _loadLiveFleet() async {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubId = activeHub?['id'] as int?;
    final fleet = await ApiService.fetchFleet(hubId: hubId);
    if (mounted) {
      setState(() {
        _liveFleet = fleet;
        final totalAssociated = fleet.length;
        if (totalAssociated == 0) {
          _activeDriverCount = 0;
        } else if (_activeDriverCount > totalAssociated || _activeDriverCount == 0) {
          _activeDriverCount = totalAssociated;
        }
      });
    }
  }

  void _loadHubInventory() async {
    final inventory = await ApiService.fetchHubInventory();
    if (mounted) {
      setState(() => _hubInventory = inventory);
    }
  }

  void _loadPayouts() async {
    final payouts = await ApiService.fetchProviderPayouts();
    if (mounted) {
      setState(() => _payoutHistory = payouts);
    }
  }

  void _loadBottleReturns() async {
    final bottles = await ApiService.fetchBottleReturns();
    if (mounted) {
      setState(() => _bottleReturns = bottles);
    }
  }

  void _callPhone(BuildContext context, String phone) async {
    final clean = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📞 Dialing $phone...')),
        );
      }
    }
  }

  void _sendWhatsAppMessage(BuildContext context, String name, String phone, String msg) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMsg = Uri.encodeComponent(msg);
    final whatsappUrl = Uri.parse('https://wa.me/91$clean?text=$encodedMsg');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📱 WhatsApp message queued for $name ($phone)')),
        );
      }
    }
  }

  void _showBroadcastDialog(BuildContext context) {
    final controller = TextEditingController();
    final presets = [
      '🌧️ Morning Dispatch Alert: Rain in sector; deliveries completing by 06:45 AM.',
      '🥛 Fresh Batch Arrived: A2 Vedic Cow Milk cold storage dispatched!',
      '⚡ Express 15-Min Delivery active in your hub zone today.',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Text('📢', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('Hub Broadcast Alert', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send instant push & SMS notification to all active subscribers in Hub zone:', style: UiText.body.copyWith(fontSize: 11.5, color: UiTone.ink)),
              const SizedBox(height: 10),
              Text('Quick Presets:', style: UiText.label.copyWith(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary)),
              const SizedBox(height: 4),
              ...presets.map((p) => InkWell(
                    onTap: () => controller.text = p,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: UiTone.surfaceMuted, borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: Text(p, style: UiText.body.copyWith(fontSize: 11)),
                    ),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 3,
                style: UiText.body.copyWith(fontSize: 12, color: UiTone.ink),
                decoration: InputDecoration(
                  hintText: 'Or type custom message to broadcast...',
                  filled: true,
                  fillColor: UiTone.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.xs), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final msg = controller.text.trim();
              Navigator.pop(ctx);
              HubRealtimeService.sendBroadcast(msg);
              await ApiService.sendBroadcastAlert('Hub Alert', msg);
              setState(() {
                _broadcastAlerts.insert(0, {
                  'title': msg,
                  'time': 'Just Now',
                  'recipients': '${widget.state.deliveries.length} Subscribers',
                  'status': 'BROADCAST SENT (REDIS) ⚡',
                });
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: UiTone.primary,
                  content: Text('📢 Broadcast Sent via Redis to ${widget.state.deliveries.length} Subscribers in Hub Zone!'),
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 15),
            label: Text('Send Broadcast', style: UiText.label.copyWith(fontWeight: FontWeight.bold, color: UiTone.surface)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTone.primary,
              foregroundColor: UiTone.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
            ),
          ),
        ],
      ),
    );
  }

  void _withdrawEarnings(BuildContext context, double amount) {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Instant Bank Payout', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Provider Balance: ${UiFormat.price(amount)}', style: UiText.bodyStrong.copyWith(fontSize: 16, fontWeight: FontWeight.w900, color: UiTone.primary)),
            const SizedBox(height: 8),
            Text('Destination Settlement Account:', style: UiText.bodyStrong.copyWith(fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: UiTone.surfaceMuted, borderRadius: BorderRadius.circular(UiRadius.xs)),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, size: 20, color: UiTone.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeHub != null && (activeHub['bank_name'] != null || activeHub['bank_account_number'] != null)
                          ? '${activeHub['bank_name'] ?? 'Primary Bank Account'} (A/C •••• ${(activeHub['bank_account_number']?.toString() ?? '••••').replaceAll(RegExp(r'.*(?=.{4}$)'), '')})\nIFSC: ${activeHub['bank_ifsc'] ?? 'Verified'} • Instant IMPS'
                          : 'Settlement Bank Account\nDaily Auto-Payout • Instant Transfer',
                      style: UiText.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: UiTone.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final newPayout = await ApiService.requestInstantPayout(amount: amount);
              if (newPayout != null) {
                _loadPayouts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: UiTone.primary,
                      content: Text('💸 Instant Payout of ${UiFormat.price(newPayout.amount)} transferred to Bank! Ref: ${newPayout.id}'),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: UiTone.error,
                      content: Text('❌ Transfer failed. Please try again.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.flash_on_rounded, size: 15),
            label: Text('Confirm Transfer', style: UiText.label.copyWith(fontWeight: FontWeight.bold, color: UiTone.surface)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTone.primary,
              foregroundColor: UiTone.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, double>> _getRevenueData() {
    final Map<String, double> revenueByDay = {};
    
    for (final task in widget.state.deliveries) {
      if (task.status == 'DELIVERED' || task.status == 'COMPLETED') {
        final price = task.subscriptionDetail?.productDetail?.pricePerUnit ?? 65.0;
        final qty = task.subscriptionDetail?.quantity ?? 1;
        final date = task.deliveryDate.isNotEmpty ? task.deliveryDate : 'Today';
        revenueByDay[date] = (revenueByDay[date] ?? 0) + (price * qty);
      }
    }
    
    final List<MapEntry<String, double>> data = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dayStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
      
      double val = 0;
      if (revenueByDay.containsKey(dayStr)) {
        val = revenueByDay[dayStr]!;
      } else if (i == 0 && revenueByDay.containsKey('Today')) {
        val = revenueByDay['Today']!;
      } else {
        val = 0.0;
      }
      data.add(MapEntry(dayName, val));
    }
    
    return data;
  }

  List<Map<String, dynamic>> _getMergedHubInventory() {
    final products = widget.state.products;
    final subscriptions = widget.state.subscriptions;
    final deliveries = widget.state.deliveries;
    final stateInventory = widget.state.hubInventory.isNotEmpty ? widget.state.hubInventory : _hubInventory;

    final list = products.map((prod) {
      final existing = stateInventory.firstWhere(
        (inv) => (inv['product'] == prod.id || inv['product_id'] == prod.id || inv['product_name'] == prod.name),
        orElse: () => <String, dynamic>{},
      );

      final subBooked = subscriptions
          .where((s) => (s.productId == prod.id || s.productDetail?.id == prod.id) && s.status == 'ACTIVE')
          .fold<int>(0, (sum, s) => sum + s.quantity);

      final deliveryBooked = deliveries
          .where((d) => d.subscriptionDetail?.productId == prod.id || d.subscriptionDetail?.productDetail?.id == prod.id)
          .fold<int>(0, (sum, d) => sum + (d.subscriptionDetail?.quantity ?? 1));

      final booked = subBooked > 0 ? subBooked : (deliveryBooked > 0 ? deliveryBooked : (existing['booked_slots'] ?? 0));
      final defaultCapacity = prod.dailyCapacitySlots > 0 ? prod.dailyCapacitySlots : (booked > 80 ? (booked + 50) : 150);
      final capacity = (existing['daily_capacity_slots'] as int?) ?? defaultCapacity;
      final isAvailable = (existing['is_available'] as bool?) ?? prod.isAvailable;
      final available = (capacity - booked).clamp(0, 9999);

      return {
        'product': prod.id,
        'product_id': prod.id,
        'product_name': prod.name,
        'icon': prod.icon,
        'category': prod.category,
        'unit': prod.unit,
        'price': prod.pricePerUnit,
        'daily_capacity_slots': capacity,
        'booked_slots': booked,
        'available_slots': available,
        'is_available': isAvailable,
      };
    }).toList();

    list.sort((a, b) {
      final bSlots = (b['booked_slots'] as int? ?? 0);
      final aSlots = (a['booked_slots'] as int? ?? 0);
      if (bSlots != aSlots) return bSlots.compareTo(aSlots);
      return (a['product_name'] as String).compareTo(b['product_name'] as String);
    });

    return list;
  }

  void _openManageCapacitySlotsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final inventoryList = _getMergedHubInventory();
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
            ),
            child: Column(
              children: [
                // Top drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: UiTone.surfaceBorder, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: UiTone.primarySoft,
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                        ),
                        child: const Text('📦', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hub Daily Slots & Inventory',
                              style: UiText.h2.copyWith(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Live product capacity limits, booked crates & availability',
                              style: UiText.body.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: UiTone.softText),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: UiTone.surfaceBorder),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: inventoryList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final item = inventoryList[idx];
                      return _buildHubInventoryCard(item, onUpdated: () => setModalState(() {}));
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.state.deliveries;
    final liveOrders = widget.state.liveOrders;
    final allSubs = widget.state.subscriptions;
    final activeSubs = allSubs.where((s) => s.status == 'ACTIVE').toList();
    final pausedSubs = allSubs.where((s) => s.status == 'PAUSED').toList();
    final totalRevenue = widget.state.totalDailyRevenue;
    final netEarnings = totalRevenue; // 100% money goes to Hub Owner
    final totalLitres = widget.state.totalDailyMilkVolume;

    // Filter tasks & orders by shift and search query
    List<DeliveryTaskModel> filteredTasks = tasks.where((t) {
      final sub = t.subscriptionDetail;
      final isSubPaused = sub != null && sub.status == 'PAUSED';
      if (_selectedFilter == 0 && (t.status == 'DELIVERED' || t.status == 'COMPLETED' || t.status == 'SKIPPED' || isSubPaused)) {
        return false;
      }

      final slotStr = t.slotTime.toUpperCase();
      final isEvening = slotStr.contains('PM') || slotStr.contains('17:') || slotStr.contains('18:') || slotStr.contains('19:') || slotStr.contains('EVENING');
      if (_selectedShift == 'MORNING' && isEvening) return false;
      if (_selectedShift == 'EVENING' && !isEvening) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.customerName.toLowerCase().contains(q) || t.deliveryAddress.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    List<LiveOrderModel> filteredExpress = liveOrders.where((ord) {
      if (_selectedFilter == 0 && ord.status == 'DELIVERED') return false;
      final slotStr = ord.deliverySlot.toUpperCase();
      final isEvening = slotStr.contains('PM') || slotStr.contains('17:') || slotStr.contains('18:') || slotStr.contains('19:') || slotStr.contains('EVENING');
      if (_selectedShift == 'MORNING' && isEvening) return false;
      if (_selectedShift == 'EVENING' && !isEvening) return false;
      return true;
    }).toList();

    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Central Dairy Depot') : 'Central Dairy Depot';
    final hubCode = activeHub != null ? (activeHub['hub_code'] ?? 'HUB-01') : 'HUB-01';

    final activeFleetCount = _liveFleet.length;
    final shiftTotal = filteredTasks.length + filteredExpress.length;
    final shiftDelivered = filteredTasks.where((t) => t.status == 'DELIVERED' || t.status == 'COMPLETED').length +
        filteredExpress.where((o) => o.status == 'DELIVERED').length;
    final progressVal = shiftTotal > 0 ? (shiftDelivered / shiftTotal).clamp(0.0, 1.0) : 0.0;
    final pendingCount = shiftTotal - shiftDelivered;

    // Filter tasks based on _taskStatusFilter
    final displayedTasks = filteredTasks.where((t) {
      final isDelivered = t.status == 'DELIVERED' || t.status == 'COMPLETED';
      if (_taskStatusFilter == 'PENDING') return !isDelivered;
      if (_taskStatusFilter == 'DELIVERED') return isDelivered;
      if (_taskStatusFilter == 'EXPRESS') return false;
      return true;
    }).toList();

    final displayedExpress = filteredExpress.where((ord) {
      final isDelivered = ord.status == 'DELIVERED';
      if (_taskStatusFilter == 'PENDING') return !isDelivered;
      if (_taskStatusFilter == 'DELIVERED') return isDelivered;
      return true;
    }).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Shift Selector Bar (Morning vs Evening) ──
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(UiRadius.pill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedShift = 'MORNING'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedShift == 'MORNING' ? const Color(0xFF0D7C66) : Colors.transparent,
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        boxShadow: _selectedShift == 'MORNING'
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0D7C66).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('☀️ ', style: TextStyle(fontSize: 13)),
                          Text(
                            'Morning Drop (5:30 AM)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _selectedShift == 'MORNING' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedShift = 'EVENING'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedShift == 'EVENING' ? const Color(0xFF7C3AED) : Colors.transparent,
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        boxShadow: _selectedShift == 'EVENING'
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🌙 ', style: TextStyle(fontSize: 13)),
                          Text(
                            'Evening Drop (5:00 PM)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _selectedShift == 'EVENING' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 2. Operational Shift Cockpit Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hub ID & Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('🏬', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hubName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Depot Zone • ID #$hubCode',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE HUB',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Shift Progress Bar & Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shift Dispatch Progress',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    Text(
                      '$shiftDelivered of $shiftTotal Delivered (${(progressVal * 100).toInt()}%)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF34D399)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 14),

                // Telemetry 3-Stat Pill Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VOLUME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.5))),
                            const SizedBox(height: 2),
                            Text('${totalLitres.toStringAsFixed(0)} Litres', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FLEET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.5))),
                            const SizedBox(height: 2),
                            Text('$activeFleetCount Drivers', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BALANCE ⚖️', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.5))),
                            const SizedBox(height: 2),
                            Text('${(shiftTotal / (_activeDriverCount > 0 ? _activeDriverCount : 1)).ceil()} drops', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Primary Action Button: Generate Tasks & Dispatch
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _showBatchLabQualityDialog(context, isGeneratingDeliveries: true),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Generate Shift Tasks & Dispatch 🚀',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 3. Hub Command 3-Tab Segmented Switcher ──
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _hubCommandTabButton(0, '📋 Live Tasks', '$shiftTotal'),
                _hubCommandTabButton(1, '🛵 Fleet & Dispatch', '$activeFleetCount'),
                _hubCommandTabButton(2, '🥛 Batch & Inventory', 'Quality'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 4. Active Tab Content Section ──
          if (_hubCommandTab == 0) ...[
            // Tab 0: Live Tasks & Orders
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, color: UiTone.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        hintText: 'Search customer, phone, or address...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Sub-Filter Pills (All, Pending, Delivered, Express, Active Subs, Paused)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _taskFilterPill('ALL', 'All ($shiftTotal)'),
                  const SizedBox(width: 6),
                  _taskFilterPill('PENDING', 'Pending ($pendingCount)'),
                  const SizedBox(width: 6),
                  _taskFilterPill('DELIVERED', 'Delivered ($shiftDelivered)'),
                  const SizedBox(width: 6),
                  _taskFilterPill('EXPRESS', 'Express ⚡ (${filteredExpress.length})'),
                  const SizedBox(width: 6),
                  _taskFilterPill('ACTIVE_SUBS', 'Active Subs (${activeSubs.length})'),
                  const SizedBox(width: 6),
                  _taskFilterPill('PAUSED_SUBS', 'Paused (${pausedSubs.length})'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Order Cards List
            if (_taskStatusFilter == 'ACTIVE_SUBS')
              _buildSubscriptionListSection('✅ Active Subscriptions', activeSubs, 'ACTIVE')
            else if (_taskStatusFilter == 'PAUSED_SUBS')
              _buildSubscriptionListSection('⏸️ Paused Subscriptions', pausedSubs, 'PAUSED')
            else if (_taskStatusFilter == 'EXPRESS')
              _buildExpressOnlySection(displayedExpress)
            else
              _buildOrdersRosterSection(displayedTasks, displayedExpress),
          ] else if (_hubCommandTab == 1) ...[
            // Tab 1: Fleet & Dispatch
            // Equal Load Balancer Stepper Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Text('⚖️ ', style: TextStyle(fontSize: 16)),
                          Text('Equal Load Balancer', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _handleAutoBalanceFleet(),
                        icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                        label: const Text('Auto-Balance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Boys Today:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          const SizedBox(height: 2),
                          Text(
                            _liveFleet.isEmpty
                                ? 'No drivers associated yet'
                                : 'Max: ${_liveFleet.length} associated with hub',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _liveFleet.isEmpty ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16, color: Color(0xFF475569)),
                              onPressed: _activeDriverCount > 1 ? () => setState(() => _activeDriverCount--) : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('$_activeDriverCount Boys', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                size: 16,
                                color: _activeDriverCount < _liveFleet.length ? const Color(0xFF0D7C66) : const Color(0xFF94A3B8),
                              ),
                              onPressed: _activeDriverCount < _liveFleet.length
                                  ? () => setState(() => _activeDriverCount++)
                                  : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF0F172A),
                                          content: Text(
                                            _liveFleet.isEmpty
                                                ? '⚠️ No delivery partners are associated with this hub yet. Onboard drivers first.'
                                                : '⚠️ Cannot increase beyond ${_liveFleet.length} drivers. Only ${_liveFleet.length} delivery partners are associated with this hub.',
                                          ),
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Fleet Radar Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ProviderFleetMapScreen(
                        state: widget.state,
                        fleetDrivers: _liveFleet,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.radar_rounded, size: 16),
                label: const Text(
                  'Open Live Fleet Radar & Route Map 🗺️',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Driver Roster
            _buildFleetDriversSection(),
          ] else ...[
            // Tab 2: Batch Quality & Inventory
            _buildDailyBatchLabCard(context),
            const SizedBox(height: 14),

            // Quick Hub Admin Actions Grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickCommand(
                    icon: Icons.inventory_2_rounded,
                    accent: const Color(0xFF0D7C66),
                    title: 'Batch Packing',
                    subtitle: 'Crate manifest',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MorningBatchScreen(state: widget.state)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _quickCommand(
                    icon: Icons.calendar_month_rounded,
                    accent: const Color(0xFF3B82F6),
                    title: 'Day Calendar',
                    subtitle: 'AM/PM orders',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DayWiseOrdersScreen(state: widget.state, role: 'PROVIDER')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _quickCommand(
                    icon: Icons.tune_rounded,
                    accent: UiTone.primary,
                    title: 'Daily Slots',
                    subtitle: 'Limits & stock',
                    onTap: () => _openManageCapacitySlotsDialog(context),
                  ),
                  const SizedBox(width: 8),
                  _quickCommand(
                    icon: Icons.campaign_rounded,
                    accent: UiTone.warning,
                    title: 'Broadcast',
                    subtitle: 'Push alerts',
                    onTap: () => _showBroadcastDialog(context),
                  ),
                  const SizedBox(width: 8),
                  _quickCommand(
                    icon: Icons.account_balance_wallet_rounded,
                    accent: const Color(0xFF10B981),
                    title: 'Settlement',
                    subtitle: 'Bank payout',
                    onTap: () => _withdrawEarnings(context, netEarnings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildInventoryCratesSection(),
            const SizedBox(height: 14),

            _buildBottleReturnsSection(),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _hubCommandTabButton(int tabIdx, String label, String badge) {
    final selected = _hubCommandTab == tabIdx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _hubCommandTab = tabIdx);
          if (tabIdx == 1) _loadLiveFleet();
          if (tabIdx == 2) { _loadBottleReturns(); _loadPayouts(); }
          if (tabIdx == 0) _loadHubInventory();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
              if (badge.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : const Color(0xFF64748B),
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

  Widget _taskFilterPill(String filterKey, String label) {
    final selected = _taskStatusFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _taskStatusFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D7C66) : Colors.white,
          borderRadius: BorderRadius.circular(UiRadius.pill),
          border: Border.all(
            color: selected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WHO ORDERED ROSTER SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOrdersRosterSection(List<DeliveryTaskModel> subscriptions, List<LiveOrderModel> express) {
    final unassignedCount = subscriptions.where((t) => t.driverId == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Customer Orders in Hub Zone:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  Text(
                    '${subscriptions.length + express.length} Orders (${_selectedShift == "ALL" ? "All Shifts" : (_selectedShift == "EVENING" ? "🌙 Evening" : "☀️ Morning")}) • $unassignedCount Unassigned',
                    style: UiText.label.copyWith(fontSize: 10.5, color: unassignedCount > 0 ? UiTone.warning : UiTone.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _handleAutoBalanceFleet(),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
              label: Text('⚡ Auto-Balance', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.accentBlue,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Express Orders
        if (_taskStatusFilter != 'DELIVERED')
          ...express.map((ord) => _buildExpressOrderCard(ord)),

        // Daily Subscriptions
        ...subscriptions.map((task) => _buildSubscriptionCustomerCard(task)),

        if (subscriptions.isEmpty && express.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No orders in this filter',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _handleAutoBalanceFleet() async {
    if (_activeDriverCount == 0 || _liveFleet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F172A),
          content: Text('⚠️ No delivery drivers associated with this hub yet. Onboard drivers first.'),
        ),
      );
      return;
    }

    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubCode = activeHub != null ? (activeHub['hub_code'] ?? 'HUB-KDD-01') : 'HUB-KDD-01';

    final res = await widget.state.autoBalanceHubDeliveries(hubCode, _activeDriverCount);
    if (mounted) {
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.accentBlue,
            content: Text(res['message'] ?? '⚡ Fleet automatically balanced across $_activeDriverCount active delivery boys!'),
          ),
        );
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.warning,
            content: Text(ApiService.lastError ?? 'Could not balance fleet'),
          ),
        );
      }
    }
  }

  void _showAssignDriverModal(DeliveryTaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final drivers = _liveFleet.isNotEmpty ? _liveFleet : widget.state.hubDrivers;
        return Container(
          decoration: const BoxDecoration(
            color: UiTone.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.lg)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: UiTone.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assign Delivery Boy',
                    style: UiText.h2.copyWith(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: UiTone.infoSoft,
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      'Stop #${task.id}',
                      style: UiText.caption.copyWith(color: UiTone.accentBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Customer: ${task.customerName} • ${task.deliveryAddress}',
                style: UiText.body.copyWith(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 24),
              Text(
                'Select Delivery Partner for this stop:',
                style: UiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (drivers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No delivery boys linked to this hub yet.'),
                  ),
                )
              else
                ...drivers.map((drv) {
                  final drvId = drv['id'] as int?;
                  final drvName = drv['name'] ?? drv['username'] ?? 'Delivery Boy';
                  final drvPhone = drv['phone'] ?? '';
                  final isAssigned = task.driverId == drvId;
                  final stopsCount = widget.state.deliveries.where((d) => d.driverId == drvId).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isAssigned ? UiTone.infoSoft : UiTone.shellBackground,
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                      border: Border.all(
                        color: isAssigned ? UiTone.accentBlue : UiTone.surfaceBorder,
                        width: isAssigned ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAssigned ? UiTone.accentBlue : UiTone.primarySoft,
                        foregroundColor: isAssigned ? Colors.white : UiTone.primary,
                        child: const Text('🛵', style: TextStyle(fontSize: 16)),
                      ),
                      title: Text(drvName, style: UiText.bodyStrong.copyWith(fontSize: 13.5)),
                      subtitle: Text('$drvPhone • $stopsCount Stops Assigned', style: UiText.body.copyWith(fontSize: 11)),
                      trailing: isAssigned
                          ? const Icon(Icons.check_circle_rounded, color: UiTone.accentBlue)
                          : OutlinedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final ok = await widget.state.assignTaskToDriver(task.id, drvId);
                                if (ok && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: UiTone.success,
                                      content: Text('✅ Stop #${task.id} assigned to $drvName!'),
                                    ),
                                  );
                                  setState(() {});
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: UiTone.primary,
                                side: const BorderSide(color: UiTone.primary),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              child: const Text('Assign'),
                            ),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              if (task.driverId != null)
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await widget.state.assignTaskToDriver(task.id, null);
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: UiTone.warning,
                            content: Text('⚠️ Stop moved back to Unassigned / Open Pool.'),
                          ),
                        );
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline, color: UiTone.error, size: 16),
                    label: Text(
                      'Unassign (Move to Open Pool)',
                      style: UiText.label.copyWith(color: UiTone.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIVE / PAUSED SUBSCRIPTION LIST SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSubscriptionListSection(String title, List<SubscriptionModel> subs, String statusType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: UiText.bodyStrong),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusType == 'PAUSED' ? UiTone.warningSoft : UiTone.successSoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Text(
                '${subs.length} ${statusType == 'PAUSED' ? 'Paused' : 'Active'}',
                style: UiText.label.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: statusType == 'PAUSED' ? UiTone.warning : UiTone.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (subs.isEmpty)
          UiEmptyState(
            icon: statusType == 'PAUSED' ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
            title: statusType == 'PAUSED' ? 'No paused subscriptions' : 'No active subscriptions',
            message: statusType == 'PAUSED'
                ? 'Paused plans will appear here.'
                : 'Active plans will appear here.',
            accent: statusType == 'PAUSED' ? UiTone.warning : UiTone.primary,
          )
        else
          ...subs.map((sub) => _buildSubscriptionCard(sub, statusType)),
      ],
    );
  }

  Widget _buildSubscriptionCard(SubscriptionModel sub, String statusType) {
    final product = sub.productDetail;
    final productName = product?.name ?? 'Subscription #${sub.id}';
    final qty = sub.quantity;
    final price = product?.pricePerUnit ?? 0.0;

    return UiInsetCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: statusType == 'PAUSED'
          ? UiTone.warning.withValues(alpha: 0.3)
          : UiTone.surfaceBorder,
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusType == 'PAUSED' ? UiTone.warningSoft : UiTone.primarySoft,
              borderRadius: BorderRadius.circular(UiRadius.sm),
            ),
            child: Center(
              child: Icon(
                statusType == 'PAUSED' ? Icons.pause_rounded : Icons.check_circle_rounded,
                color: statusType == 'PAUSED' ? UiTone.warning : UiTone.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: UiText.bodyStrong.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Customer #${sub.customerId} • ${sub.scheduleType} • $qty units',
                  style: UiText.body.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${UiFormat.price(price * qty)}/day',
                style: UiText.bodyStrong.copyWith(fontSize: 13, color: UiTone.primary),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusType == 'PAUSED' ? UiTone.warningSoft : UiTone.successSoft,
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  statusType,
                  style: UiText.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusType == 'PAUSED' ? UiTone.warning : UiTone.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPRESS ONLY SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildExpressOnlySection(List<LiveOrderModel> express) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('⚡ Express Orders', style: UiText.bodyStrong),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: UiTone.errorSoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Text(
                '${express.length} Orders',
                style: UiText.label.copyWith(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (express.isEmpty)
          UiEmptyState(
            icon: Icons.flash_off_rounded,
            title: 'No express orders',
            message: 'New express orders will show up here.',
            accent: UiTone.error,
          )
        else
          ...express.map((ord) => _buildExpressOrderCard(ord)),
      ],
    );
  }

  Widget _buildSubscriptionCustomerCard(DeliveryTaskModel task) {
    final sub = task.subscriptionDetail;
    final product = sub?.productDetail;
    final isDone = task.status == 'DELIVERED';
    final custPhone = task.customerPhone.isNotEmpty ? task.customerPhone : '+91 9876543210';

    return UiInsetCard(
      margin: const EdgeInsets.only(bottom: 12),
      shadow: UiShadow.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Customer Name & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: UiTone.primary.withValues(alpha: 0.12),
                    child: const Text('🥛', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.customerName,
                        style: UiText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Phone: $custPhone',
                        style: UiText.body.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final subStatus = sub?.status ?? '';
                  final isSkipped = task.status == 'SKIPPED' || subStatus == 'PAUSED';
                  String label = 'SCHEDULED ⏰';
                  Color bg = UiTone.warning.withValues(alpha: 0.15);
                  Color fg = UiTone.warning;

                  if (isDone) {
                    label = 'DELIVERED ✅';
                    bg = UiTone.secondary.withValues(alpha: 0.15);
                    fg = UiTone.primary;
                  } else if (isSkipped) {
                    label = 'VACATION PAUSED 🏖️';
                    bg = UiTone.accentBlue.withValues(alpha: 0.15);
                    fg = UiTone.accentBlue;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      label,
                      style: UiText.caption.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product & Subscription Quantity
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: UiTone.shellBackground, borderRadius: BorderRadius.circular(UiRadius.xs)),
            child: Row(
              children: [
                Text(product?.icon ?? '🥛', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sub?.quantity ?? 1}x ${product?.name ?? "Fresh A2 Cow Milk"}',
                        style: UiText.bodyStrong.copyWith(fontSize: 12),
                      ),
                      Text(
                        '${sub?.scheduleType ?? "DAILY"} • Slot: ${task.slotTime}',
                        style: UiText.body.copyWith(fontSize: 10.5),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (task.slotTime.toUpperCase().contains('PM') || task.slotTime.toUpperCase().contains('EVENING'))
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                              : const Color(0xFF0D7C66).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '📅 ${task.deliveryDate.isNotEmpty ? task.deliveryDate : "Today"} • ${(task.slotTime.toUpperCase().contains("PM") || task.slotTime.toUpperCase().contains("EVENING")) ? "🌙 Evening Shift" : "☀️ Morning Shift"}',
                          style: UiText.caption.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: (task.slotTime.toUpperCase().contains('PM') || task.slotTime.toUpperCase().contains('EVENING'))
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF0D7C66),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  UiFormat.price((sub?.displayPrice ?? 40) * (sub?.quantity ?? 1)),
                  style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900, color: UiTone.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Address & Assigned Driver (Tap to view customer address book)
          InkWell(
            onTap: () => _showCustomerAddressesModal(task),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.place_rounded, size: 14, color: UiTone.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.deliveryAddress.replaceAll(', Hyderabad', ', Telangana').replaceAll('Hyderabad', 'Telangana'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UiText.body.copyWith(fontSize: 11, color: UiTone.ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: UiTone.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Addresses 📖', style: UiText.caption.copyWith(fontSize: 9.5, color: UiTone.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Interactive Assigned Driver Badge / Selector
              InkWell(
                onTap: () => _showAssignDriverModal(task),
                borderRadius: BorderRadius.circular(UiRadius.xs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: task.driverId != null ? UiTone.infoSoft : UiTone.warningSoft,
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                    border: Border.all(
                      color: task.driverId != null
                          ? UiTone.accentBlue.withValues(alpha: 0.4)
                          : UiTone.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.two_wheeler_rounded,
                        size: 14,
                        color: task.driverId != null ? UiTone.accentBlue : UiTone.warning,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        task.driverDetail != null
                            ? '🛵 ${task.driverDetail!.name}'
                            : (task.driverId != null ? '🛵 Driver #${task.driverId}' : '⚠️ Unassigned (Tap to Assign)'),
                        style: UiText.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: task.driverId != null ? UiTone.accentBlue : UiTone.warning,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: task.driverId != null ? UiTone.accentBlue : UiTone.warning,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Prepaid Wallet (Auto)',
                style: UiText.body.copyWith(fontSize: 10.5),
              ),
            ],
          ),
          const Divider(height: 16),

          // Actions: Call Customer + Send WhatsApp Status
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPhone(context, custPhone),
                  icon: const Icon(Icons.phone_rounded, size: 13),
                  label: Text('Call Customer', style: UiText.label.copyWith(fontSize: 11, color: UiTone.primary)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UiTone.primary,
                    side: const BorderSide(color: UiTone.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendWhatsAppMessage(
                    context,
                    task.customerName,
                    custPhone,
                    'Hello ${task.customerName}! Your daily morning subscription (${product?.name}) from $_activeHubName has been dispatched.',
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 13),
                  label: Text('WhatsApp Ping', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.surface)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.secondary,
                    foregroundColor: UiTone.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomerAddressesModal(DeliveryTaskModel task) {
    final custName = task.customerName.isNotEmpty ? task.customerName : 'Customer';
    final custPhone = task.customerPhone;
    final custId = task.subscriptionDetail?.customerId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<CustomerAddressModel>>(
          future: ApiService.fetchCustomerAddresses(customerId: custId, phone: custPhone),
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final addrs = snapshot.data ?? [];

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📍 $custName\'s Address Book',
                            style: UiText.h2.copyWith(fontSize: 16),
                          ),
                          Text(
                            'Customer Doorstep Delivery Locations',
                            style: UiText.caption.copyWith(fontSize: 11, color: UiTone.softText),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: UiTone.softText),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (addrs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: UiTone.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: UiTone.softText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              task.deliveryAddress.isNotEmpty ? task.deliveryAddress : 'Default profile address',
                              style: UiText.body.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...addrs.map((CustomerAddressModel a) {
                      final isDefault = a.isDefault;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDefault ? const Color(0xFFF0FDF4) : UiTone.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDefault ? UiTone.primary.withValues(alpha: 0.4) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDefault ? UiTone.primary : UiTone.border,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                a.addressType == 'WORK'
                                    ? Icons.work_outline_rounded
                                    : (a.addressType == 'OTHER' ? Icons.location_on_rounded : Icons.home_rounded),
                                color: isDefault ? Colors.white : UiTone.ink,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        a.customTag.isNotEmpty ? a.customTag : a.displayType,
                                        style: UiText.bodyStrong.copyWith(fontSize: 13),
                                      ),
                                      if (isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: UiTone.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'PRIMARY DEFAULT ⭐',
                                            style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.bold, color: UiTone.primary),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a.summaryAddress,
                                    style: UiText.body.copyWith(fontSize: 11.5, color: UiTone.ink),
                                  ),
                                  if (a.deliveryInstructions.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '🚪 ${a.deliveryInstructions}',
                                      style: UiText.caption.copyWith(fontSize: 10.5, color: const Color(0xFFD97706)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpressOrderCard(LiveOrderModel ord) {
    final isDelivered = ord.status == 'DELIVERED';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        BookingDetailSheet.showForLiveOrder(context, widget.state, ord);
      },
      borderRadius: BorderRadius.circular(UiRadius.md),
      child: UiInsetCard(
        margin: const EdgeInsets.only(bottom: 12),
        shadow: UiShadow.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: UiTone.accentBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: Text(ord.id, style: UiText.caption.copyWith(color: UiTone.accentBlue, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: UiTone.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: Text('30-MIN EXPRESS', style: UiText.caption.copyWith(color: UiTone.error, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered ? UiTone.secondary.withValues(alpha: 0.15) : UiTone.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    isDelivered ? 'DELIVERED ✅' : 'OUT FOR DELIVERY 🛵',
                    style: UiText.caption.copyWith(
                      color: isDelivered ? UiTone.primary : UiTone.warning,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              'Items: ${ord.items.map((i) => "${i.quantity}x ${i.product.name}").join(", ")}',
              style: UiText.bodyStrong.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (ord.deliverySlot.toUpperCase().contains('PM') || ord.deliverySlot.toUpperCase().contains('EVENING'))
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                    : const Color(0xFF0D7C66).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '📅 ${ord.deliveryDate.isNotEmpty ? ord.deliveryDate : "Today"} • ${(ord.deliverySlot.toUpperCase().contains("PM") || ord.deliverySlot.toUpperCase().contains("EVENING")) ? "🌙 Evening Shift" : "☀️ Morning Shift"} • Slot: ${ord.deliverySlot}',
                style: UiText.caption.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: (ord.deliverySlot.toUpperCase().contains('PM') || ord.deliverySlot.toUpperCase().contains('EVENING'))
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF0D7C66),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Delivery to: ${ord.deliveryAddress}', style: UiText.body.copyWith(fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Total: ${UiFormat.price(ord.totalAmount)}', style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, color: UiTone.primary, fontSize: 12.5)),
                Text('OTP: ${ord.deliveryOtp}', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.accentBlue)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Tap to view order sheet 📄', style: UiText.caption.copyWith(color: UiTone.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 14, color: UiTone.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FLEET DRIVERS SECTION
  // ══════════════════════════════════════════════════════════════════════════
  void _showAddDriverDialog(BuildContext context) {
    final fnCtrl = TextEditingController();
    final lnCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController(text: '15000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.lg)),
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Onboard Delivery Boy to Hub', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fnCtrl,
                decoration: const InputDecoration(labelText: 'First Name', hintText: 'e.g. Ramesh'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lnCtrl,
                decoration: const InputDecoration(labelText: 'Last Name', hintText: 'e.g. Varma'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+91 98765 00000'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: salaryCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fixed Monthly Salary (₹)', hintText: '15000'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTone.primary,
              foregroundColor: UiTone.surface,
            ),
            onPressed: () async {
              if (phoneCtrl.text.trim().isEmpty) return;
              final result = await ApiService.createDriver(
                firstName: fnCtrl.text.trim().isEmpty ? 'Delivery' : fnCtrl.text.trim(),
                lastName: lnCtrl.text.trim().isEmpty ? 'Partner' : lnCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                hubId: widget.state.locationHubs.isNotEmpty ? (widget.state.locationHubs.first['id'] as int? ?? 1) : 1,
                monthlySalary: double.tryParse(salaryCtrl.text.trim()) ?? 15000.0,
              );
              final success = result != null;
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                _loadLiveFleet();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: UiTone.primary,
                      content: Text('🎉 Delivery Partner successfully onboarded & assigned to this Hub!'),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFFDC2626),
                      content: Text('❌ Failed to onboard partner: ${ApiService.lastError ?? "Driver with this phone may already exist."}'),
                    ),
                  );
                }
              }
            },
            child: const Text('Onboard Partner'),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetDriversSection() {
    final drivers = _liveFleet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🛵 Assigned Hub Fleet (${drivers.length}):', style: UiText.bodyStrong),
            ElevatedButton.icon(
              onPressed: () => _showAddDriverDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 14),
              label: Text('Add Delivery Boy', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.surface)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: UiTone.surface,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (drivers.isEmpty)
          UiEmptyState(
            icon: Icons.delivery_dining_rounded,
            title: 'No delivery boys onboarded yet',
            message: 'Tap "Add Delivery Boy" to onboard drivers to this hub.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: drivers.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final drv = drivers[idx];
              final hubNameText = drv['hub'] ?? _activeHubName;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UiTone.surface,
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(color: UiTone.surfaceBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: UiTone.primary.withValues(alpha: 0.12),
                      child: const Text('🛵', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(drv['name'] ?? 'Driver', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                          Text('📍 $hubNameText', style: UiText.label.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: UiTone.primary)),
                          Text(drv['route'] ?? 'Sector Route', style: UiText.body.copyWith(fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(drv['status'] ?? '🟢 Active', style: UiText.label.copyWith(fontSize: 10, color: UiTone.primary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(drv['salary'] ?? '₹15,000/mo', style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900, color: UiTone.primary)),
                        Text(drv['stops'] ?? '12 Stops', style: UiText.body.copyWith(fontSize: 10)),
                        const SizedBox(height: 4),
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, size: 16, color: UiTone.primary),
                          onPressed: () => _callPhone(context, drv['phone'] ?? '+91 9123456789'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HUB PRODUCT CAPACITY SECTION (Full Product Catalog with Live Slots)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildInventoryCratesSection() {
    final inventoryList = _getMergedHubInventory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '📦 Hub Daily Capacity & Crate Stock:',
                style: UiText.h2.copyWith(fontSize: 14.5, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                _loadHubInventory();
                await widget.state.reloadAllData();
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text('Refresh', style: UiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.bold, color: UiTone.primary)),
              style: TextButton.styleFrom(foregroundColor: UiTone.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (inventoryList.isEmpty)
          UiEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No inventory data yet',
            message: 'Product capacity will appear here once configured.',
          )
        else
          ...inventoryList.map((inv) => _buildHubInventoryCard(inv, onUpdated: () => setState(() {}))),
      ],
    );
  }

  Widget _buildHubInventoryCard(Map<String, dynamic> inv, {VoidCallback? onUpdated}) {
    final productName = inv['product_name'] ?? 'Unknown Product';
    final dailyCapacity = inv['daily_capacity_slots'] ?? 150;
    final booked = inv['booked_slots'] ?? 0;
    final available = inv['available_slots'] ?? (dailyCapacity - booked);
    final isAvailable = inv['is_available'] ?? true;
    final productId = inv['product'] ?? 0;
    final icon = inv['icon'] ?? '🥛';
    final unit = inv['unit'] ?? '500 ml';
    final price = inv['price'] ?? 35;
    final fillPercent = dailyCapacity > 0 ? (booked / dailyCapacity).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: booked > 0 ? UiTone.successSoft : UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(
          color: booked > 0
              ? UiTone.success
              : (isAvailable ? UiTone.surfaceBorder : UiTone.error.withValues(alpha: 0.4)),
          width: booked > 0 ? 1.8 : 1.2,
        ),
        boxShadow: booked > 0 ? UiShadow.glowPrimary : UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booked > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: UiTone.successSoft,
                borderRadius: BorderRadius.circular(UiRadius.xs),
                border: Border.all(color: UiTone.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    'ACTIVE DEMAND: $booked CRATES SUBSCRIBED TODAY',
                    style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w900, color: UiTone.success),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UiText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$unit • ${UiFormat.price(price)} MRP',
                      style: UiText.body.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Real-Time Availability Switch Pill
              InkWell(
                onTap: () {
                  final newStatus = !isAvailable;
                  inv['is_available'] = newStatus;
                  onUpdated?.call();
                  setState(() {});
                  widget.state.updateHubProductCapacity(productId, dailyCapacity, isAvailable: newStatus);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1400),
                      backgroundColor: newStatus ? UiTone.primary : UiTone.error,
                      content: Text(newStatus ? '🟢 $productName set to IN STOCK for hub zone.' : '⏸️ $productName set to PAUSED for hub zone.'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(UiRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvailable ? UiTone.successSoft : UiTone.errorSoft,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                        size: 12,
                        color: isAvailable ? UiTone.success : UiTone.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAvailable ? 'IN STOCK' : 'PAUSED',
                        style: UiText.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: isAvailable ? UiTone.success : UiTone.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Real-Time Capacity Usage Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.xs),
            child: LinearProgressIndicator(
              value: fillPercent.toDouble(),
              minHeight: 7,
              backgroundColor: UiTone.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                fillPercent > 0.85
                    ? UiTone.error
                    : (fillPercent > 0.6 ? UiTone.warning : UiTone.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$booked Booked Today',
                style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: UiTone.softText),
              ),
              Text(
                '$available Slots Left (Max $dailyCapacity)',
                style: UiText.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: available > 0 ? UiTone.primary : UiTone.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Instant Real-Time Stepper Actions (-10, +10, +50, Custom)
          Row(
            children: [
              // Stepper: -10
              IconButton.filledTonal(
                icon: const Icon(Icons.remove, size: 14),
                tooltip: 'Decrease 10 Slots',
                style: IconButton.styleFrom(
                  backgroundColor: UiTone.surfaceMuted,
                  foregroundColor: UiTone.ink,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(34, 32),
                ),
                onPressed: dailyCapacity > 10
                    ? () {
                        final newCap = dailyCapacity - 10;
                        inv['daily_capacity_slots'] = newCap;
                        inv['available_slots'] = (newCap - booked).clamp(0, 9999);
                        onUpdated?.call();
                        setState(() {});
                        widget.state.updateHubProductCapacity(productId, newCap, isAvailable: isAvailable);
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              // Stepper: +10
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 14),
                tooltip: 'Add 10 Slots',
                style: IconButton.styleFrom(
                  backgroundColor: UiTone.primarySoft,
                  foregroundColor: UiTone.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(34, 32),
                ),
                onPressed: () {
                  final newCap = dailyCapacity + 10;
                  inv['daily_capacity_slots'] = newCap;
                  inv['available_slots'] = (newCap - booked).clamp(0, 9999);
                  onUpdated?.call();
                  setState(() {});
                  widget.state.updateHubProductCapacity(productId, newCap, isAvailable: isAvailable);
                },
              ),
              const SizedBox(width: 6),
              // Quick +50 Chip
              InkWell(
                onTap: () {
                  final newCap = dailyCapacity + 50;
                  inv['daily_capacity_slots'] = newCap;
                  inv['available_slots'] = (newCap - booked).clamp(0, 9999);
                  onUpdated?.call();
                  setState(() {});
                  widget.state.updateHubProductCapacity(productId, newCap, isAvailable: isAvailable);
                },
                borderRadius: BorderRadius.circular(UiRadius.xs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: UiTone.surfaceMuted,
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                    border: Border.all(color: UiTone.surfaceBorder),
                  ),
                  child: Text('+50', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.ink)),
                ),
              ),
              const SizedBox(width: 8),
              // Custom Edit Dialog Button
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditCapacityDialog(productId, productName, dailyCapacity, onSaved: (newCap) {
                      inv['daily_capacity_slots'] = newCap;
                      inv['available_slots'] = (newCap - booked).clamp(0, 9999);
                      onUpdated?.call();
                      setState(() {});
                    }),
                    icon: const Icon(Icons.tune_rounded, size: 13),
                    label: Text('Custom Limit', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: UiTone.primary)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UiTone.primary,
                      side: const BorderSide(color: UiTone.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditCapacityDialog(int productId, String productName, int currentCapacity, {Function(int)? onSaved}) {
    final controller = TextEditingController(text: currentCapacity.toString());
    final presets = [50, 100, 150, 200, 300, 500, 1000];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.lg)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: UiTone.primarySoft, borderRadius: BorderRadius.circular(UiRadius.sm)),
                  child: const Text('📦', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Capacity Limit', style: UiText.bodyStrong.copyWith(fontSize: 15)),
                      Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: UiText.body.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Preset Slots:', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.softText)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((p) {
                    final isCurrent = controller.text == p.toString();
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          controller.text = p.toString();
                        });
                      },
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCurrent ? UiTone.primary : UiTone.surfaceMuted,
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          border: Border.all(color: isCurrent ? UiTone.primary : UiTone.surfaceBorder),
                        ),
                        child: Text(
                          '$p Slots',
                          style: UiText.label.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? UiTone.surface : UiTone.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: UiText.h2.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: UiTone.ink),
                  decoration: InputDecoration(
                    labelText: 'Exact Daily Capacity Slots',
                    hintText: 'e.g. 200',
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: UiTone.primary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final newCap = int.tryParse(controller.text) ?? currentCapacity;
                  Navigator.pop(ctx);
                  onSaved?.call(newCap);
                  widget.state.updateHubProductCapacity(productId, newCap);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1400),
                      backgroundColor: UiTone.primary,
                      content: Text('⚡ $productName capacity set to $newCap slots in real-time!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  foregroundColor: UiTone.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                ),
                child: const Text('Save Limit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickCommand({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 96,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(UiRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: UiTone.surfaceBorder),
              boxShadow: UiShadow.card,
            ),
            child: Column(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UiText.caption.copyWith(
                      color: UiTone.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UiText.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBroadcastAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('📢 Sent Hub Customer Broadcasts:', style: UiText.bodyStrong.copyWith(fontSize: 14)),
            ElevatedButton.icon(
              onPressed: () => _showBroadcastDialog(context),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: Text('New Alert', style: UiText.label.copyWith(fontWeight: FontWeight.bold, color: UiTone.surface)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: UiTone.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._broadcastAlerts.map((b) => UiInsetCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              shadow: UiShadow.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(b['title'] ?? '', style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: UiTone.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(UiRadius.xs)),
                        child: Text(b['status'] ?? 'SENT', style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.bold, color: UiTone.secondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🕒 ${b['time']}', style: UiText.body.copyWith(fontSize: 11)),
                      Text('👥 Audience: ${b['recipients']}', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPayoutLedgerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('💰 Settlement & Payout Receipts Ledger:', style: UiText.bodyStrong.copyWith(fontSize: 14)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loadPayouts,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text('Refresh', style: UiText.label.copyWith(fontSize: 11, color: UiTone.primary)),
                ),
                Text('${_payoutHistory.length} Receipts', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_payoutHistory.isEmpty)
          UiEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No payout settlements requested yet',
            message: 'Request instant payout to transfer hub earnings directly to your bank account.',
            action: ElevatedButton.icon(
              onPressed: () => _withdrawEarnings(context, widget.state.totalDailyRevenue),
              icon: const Icon(Icons.flash_on_rounded, size: 15),
              label: Text('Request Settlement Transfer 💸', style: UiText.label.copyWith(fontWeight: FontWeight.bold, fontSize: 12, color: UiTone.surface)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: UiTone.surface,
              ),
            ),
          )
        else
          ..._payoutHistory.map((p) => UiInsetCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                shadow: UiShadow.card,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: UiTone.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(UiRadius.xs)),
                          child: const Icon(Icons.receipt_long_rounded, color: UiTone.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.id, style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
                            Text('${p.date} • ${p.bank}', style: UiText.body.copyWith(fontSize: 10.5)),
                            if (p.totalDeliveries > 0)
                              Text('📦 ${p.totalDeliveries} Deliveries • Rev: ${UiFormat.price(p.totalRevenue)}', style: UiText.label.copyWith(fontSize: 10, color: UiTone.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(UiFormat.price(p.amount), style: UiText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: UiTone.primary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: UiTone.successSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                          child: Text(p.status, style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.bold, color: UiTone.success)),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOTTLE RETURNS SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBottleReturnsSection() {
    final depositedCount = _bottleReturns.where((b) => b.status == 'DEPOSITED').length;
    final returnedCount = _bottleReturns.where((b) => b.status == 'RETURNED').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🍼 Bottle Deposits & Returns Ledger:', style: UiText.bodyStrong.copyWith(fontSize: 14)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loadBottleReturns,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text('Refresh', style: UiText.label.copyWith(fontSize: 11, color: UiTone.primary)),
                ),
                TextButton.icon(
                  onPressed: () => _showAddBottleDepositDialog(context),
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: Text('+ Deposit', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildBottleStatChip('📦 Total Recorded', '${_bottleReturns.length}', UiTone.primary),
            const SizedBox(width: 8),
            _buildBottleStatChip('⏳ Pending Return', '$depositedCount', UiTone.warning),
            const SizedBox(width: 8),
            _buildBottleStatChip('✅ Refunded', '$returnedCount', UiTone.success),
          ],
        ),
        const SizedBox(height: 12),
        if (_bottleReturns.isEmpty)
          UiEmptyState(
            icon: Icons.cleaning_services_rounded,
            title: 'No bottle return records yet',
            message: 'Glass bottle deposits collected by drivers or customers will show here for refund processing.',
            action: OutlinedButton.icon(
              onPressed: () => _showAddBottleDepositDialog(context),
              icon: const Icon(Icons.add, size: 14),
              label: Text('Record Customer Bottle Deposit', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
              style: OutlinedButton.styleFrom(foregroundColor: UiTone.primary, side: const BorderSide(color: UiTone.primary)),
            ),
          )
        else
          ..._bottleReturns.map((b) => _buildBottleReturnCard(b)),
      ],
    );
  }

  Widget _buildBottleStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(UiRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
            Text(label, style: UiText.caption.copyWith(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildBottleReturnCard(BottleReturnModel b) {
    final isDeposited = b.status == 'DEPOSITED';
    final isReturned = b.status == 'RETURNED';

    return UiInsetCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      borderColor: isDeposited ? UiTone.warning.withValues(alpha: 0.4) : UiTone.surfaceBorder,
      shadow: UiShadow.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDeposited ? UiTone.warningSoft : (isReturned ? UiTone.successSoft : UiTone.errorSoft),
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                ),
                child: const Center(
                  child: Text('🍼', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.customerName, style: UiText.bodyStrong.copyWith(fontSize: 13)),
                    Text('${b.quantity}x ${b.productName} • Driver: ${b.driverName}', style: UiText.body.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Deposit: ${UiFormat.price(b.depositAmount)}', style: UiText.bodyStrong.copyWith(fontSize: 12, color: UiTone.primary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDeposited ? UiTone.warningSoft : (isReturned ? UiTone.successSoft : UiTone.errorSoft),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      b.status,
                      style: UiText.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDeposited ? UiTone.warning : (isReturned ? UiTone.success : UiTone.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isDeposited) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ApiService.updateBottleReturnStatus(b.id, 'RETURNED');
                        if (success) {
                          _loadBottleReturns();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: UiTone.primary, content: Text('✅ Refunded ${UiFormat.price(b.depositAmount)} deposit to ${b.customerName}\'s wallet!')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.price_check_rounded, size: 14),
                      label: Text('Mark Returned & Refund Deposit 💸', style: UiText.label.copyWith(fontSize: 10.5, fontWeight: FontWeight.bold, color: UiTone.surface)),
                      style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: UiTone.surface),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () async {
                      final success = await ApiService.updateBottleReturnStatus(b.id, 'LOST');
                      if (success) _loadBottleReturns();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: UiTone.error, side: const BorderSide(color: UiTone.error)),
                    child: Text('Lost ❌', style: UiText.label.copyWith(fontSize: 10.5, color: UiTone.error)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showAddBottleDepositDialog(BuildContext context) {
    int qty = 1;
    double deposit = 50.0;
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Record Customer Bottle Deposit 🍼', style: UiText.h2.copyWith(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bottle Quantity:', style: UiText.bodyStrong.copyWith(fontSize: 12)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: qty > 1 ? () => setDlgState(() => qty--) : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                      ),
                      Text('$qty', style: UiText.bodyStrong.copyWith(fontSize: 14)),
                      IconButton(
                        onPressed: () => setDlgState(() => qty++),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Deposit Amount (₹)', border: OutlineInputBorder()),
                controller: TextEditingController(text: '${deposit * qty}'),
                onChanged: (val) => deposit = double.tryParse(val) ?? 50.0,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes / Customer Reference', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await ApiService.createBottleReturn(
                  quantity: qty,
                  depositAmount: deposit,
                  notes: notesCtrl.text,
                );
                if (res != null) {
                  _loadBottleReturns();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: UiTone.primary, content: Text('✅ Bottle deposit recorded successfully!')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: UiTone.surface),
              child: const Text('Record Deposit'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Real-Time Daily Earnings & Volume Card ──

  Widget _buildRealTimeEarningsCard(BuildContext context) {
    final state = widget.state;
    final isTelugu = state.isTelugu;
    final totalRev = state.totalDailyRevenue > 0 ? state.totalDailyRevenue : 14250.0;
    final totalVol = state.totalDailyMilkVolume > 0 ? state.totalDailyMilkVolume : 215.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x2A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTelugu ? 'రియల్-టైమ్ రోజువారీ ఆదాయం' : 'Real-Time Daily Earnings',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      isTelugu ? 'లైవ్' : 'LIVE',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UiFormat.price(totalRev),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTelugu ? 'ఈరోజు మొత్తం ఆదాయం' : "Today's Gross Earnings",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: Colors.white12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${totalVol.toStringAsFixed(1)} L',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTelugu ? 'విక్రయించిన పాలు' : 'Total Litres Dispatched',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderEarningsScreen(state: widget.state),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded, size: 16),
              label: Text(
                isTelugu ? 'పూర్తి ఆదాయ వివరాలు & ఉత్పత్తుల సేల్స్ చూడండి ➔' : 'View Detailed Product Sales & Litres ➔',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily Batch Lab Certification Card & Modal ──

  Widget _buildDailyBatchLabCard(BuildContext context) {
    final batches = widget.state.dailyMilkBatches;
    final latestBatch = batches.isNotEmpty ? batches.first : null;

    final fat = latestBatch?['fat_percentage'] != null ? '${latestBatch!['fat_percentage']}%' : '6.8%';
    final snf = latestBatch?['snf_percentage'] != null ? '${latestBatch!['snf_percentage']}%' : '9.0%';
    final water = latestBatch?['water_percentage'] != null ? '${latestBatch!['water_percentage']}%' : '0.0%';
    final parsedP = latestBatch?['price_per_litre'] != null ? (double.tryParse(latestBatch!['price_per_litre'].toString()) ?? 68.0) : 68.0;
    final price = '${UiFormat.price(parsedP)}/L';
    final product = latestBatch?['product_name']?.toString() ?? 'Pure Buffalo Milk';
    final batchCode = latestBatch?['batch_code']?.toString() ?? 'BATCH-KDD-01';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UiTone.successSoft,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.success.withValues(alpha: 0.4), width: 1.2),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: UiTone.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: UiTone.success, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Milk Batch Quality & Pricing 🥛',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UiText.title.copyWith(fontSize: 13, color: UiTone.success),
                          ),
                          Text(
                            '$product • $batchCode',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UiText.caption.copyWith(color: UiTone.success, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showBatchLabQualityDialog(context),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                label: Text('Certify Batch', style: UiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.surface)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4 Stat Tiles: FAT, SNF, Water %, Rate
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: '🧈',
                  title: 'FAT %',
                  value: fat,
                  color: UiTone.warning,
                  bgColor: UiTone.warningSoft,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  icon: '🔬',
                  title: 'SNF %',
                  value: snf,
                  color: UiTone.accentBlue,
                  bgColor: UiTone.infoSoft,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  icon: '💧',
                  title: 'Water %',
                  value: water,
                  color: UiTone.success,
                  bgColor: UiTone.successSoft,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  icon: '₹',
                  title: 'Rate/L',
                  value: price,
                  color: UiTone.primary,
                  bgColor: UiTone.primarySoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(UiRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 10.5)),
              const SizedBox(width: 2),
              Text(title, style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _showBatchLabQualityDialog(BuildContext context, {bool isGeneratingDeliveries = false}) {
    String selectedProduct = 'Pure Buffalo Milk';
    DateTime selectedDate = DateTime.now();
    final fatCtrl = TextEditingController(text: '6.8');
    final snfCtrl = TextEditingController(text: '9.0');
    final waterCtrl = TextEditingController(text: '0.0');
    final priceCtrl = TextEditingController(text: '68');
    final volumeCtrl = TextEditingController(text: '450');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
            final nowStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
            final isToday = dateStr == nowStr;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(color: UiTone.surfaceBorder, borderRadius: BorderRadius.circular(UiRadius.pill)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(isGeneratingDeliveries ? '🚀' : '🥛', style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isGeneratingDeliveries ? 'Generate Deliveries & Certify Batch' : 'Hub Daily Batch Certification',
                                  style: UiText.h2.copyWith(fontSize: 15.5, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  isGeneratingDeliveries
                                      ? 'Certify today\'s milk quality & create morning drop tasks'
                                      : 'Enter daily lab purity & dynamic litre rate',
                                  style: UiText.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),

                    // 1. Delivery Date Selection
                    Text('1. Delivery Batch Target Date:', style: UiText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: UiTone.ink)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('Today (${DateTime.now().day}/${DateTime.now().month})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          selected: isToday,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedDate = DateTime.now());
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Tomorrow (${DateTime.now().add(const Duration(days: 1)).day}/${DateTime.now().add(const Duration(days: 1)).month})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          selected: selectedDate.day == DateTime.now().add(const Duration(days: 1)).day,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedDate = DateTime.now().add(const Duration(days: 1)));
                          },
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 14)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: UiTone.surfaceMuted,
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                              border: Border.all(color: UiTone.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 14, color: UiTone.softText),
                                const SizedBox(width: 4),
                                Text(dateStr, style: UiText.caption.copyWith(fontWeight: FontWeight.bold, color: UiTone.ink)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. Select Milk Product
                    Text('2. Select Milk Product Variety:', style: UiText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: UiTone.ink)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: UiTone.surfaceMuted,
                        borderRadius: BorderRadius.circular(UiRadius.sm),
                        border: Border.all(color: UiTone.surfaceBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedProduct,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'Pure Buffalo Milk', child: Text('🥛 Pure Buffalo Milk (Standard 6.8% Fat)')),
                            DropdownMenuItem(value: 'Vedic A2 Desi Cow Milk', child: Text('🐄 Vedic A2 Desi Cow Milk (4.5% Fat)')),
                            DropdownMenuItem(value: 'Farm Fresh Cow Milk', child: Text('🥛 Farm Fresh Cow Milk (4.2% Fat)')),
                            DropdownMenuItem(value: 'Fresh Malai Paneer', child: Text('🧀 Fresh Malai Paneer (22.0% Fat)')),
                            DropdownMenuItem(value: 'Vedic Bilona Ghee', child: Text('🧈 Vedic Bilona Ghee (99.7% Fat)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedProduct = val;
                                if (val.contains('Buffalo')) {
                                  fatCtrl.text = '6.8';
                                  snfCtrl.text = '9.0';
                                  priceCtrl.text = '68';
                                } else if (val.contains('A2') || val.contains('Desi')) {
                                  fatCtrl.text = '4.5';
                                  snfCtrl.text = '8.8';
                                  priceCtrl.text = '85';
                                } else if (val.contains('Cow')) {
                                  fatCtrl.text = '4.2';
                                  snfCtrl.text = '8.5';
                                  priceCtrl.text = '60';
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Lab Purity Parameters
                    Text('3. Certified Lab Quality Measurements:', style: UiText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: UiTone.ink)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'FAT %',
                            hint: '6.8',
                            controller: fatCtrl,
                            icon: '🧈',
                            color: UiTone.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'SNF %',
                            hint: '9.0',
                            controller: snfCtrl,
                            icon: '🔬',
                            color: UiTone.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'Water %',
                            hint: '0.0',
                            controller: waterCtrl,
                            icon: '💧',
                            color: UiTone.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4. Litre Rate & Volume
                    Text('4. Dynamic Litre Pricing & Volume:', style: UiText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: UiTone.ink)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'Price / Litre (₹)',
                            hint: '68',
                            controller: priceCtrl,
                            icon: '₹',
                            color: UiTone.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'Total Litres (L)',
                            hint: '450',
                            controller: volumeCtrl,
                            icon: '📦',
                            color: UiTone.softText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Dispatch CTA
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                final fat = double.tryParse(fatCtrl.text) ?? 6.8;
                                final snf = double.tryParse(snfCtrl.text) ?? 9.0;
                                final water = double.tryParse(waterCtrl.text) ?? 0.0;
                                final price = double.tryParse(priceCtrl.text) ?? 68.0;
                                final volume = double.tryParse(volumeCtrl.text) ?? 450.0;

                                // Submit daily batch lab report
                                await ApiService.submitDailyMilkBatch(
                                  batchDate: dateStr,
                                  productName: selectedProduct,
                                  fatPercentage: fat,
                                  snfPercentage: snf,
                                  waterPercentage: water,
                                  pricePerLitre: price,
                                  totalLitres: volume,
                                  temperatureCelsius: 3.8,
                                  hubCode: widget.state.activeHubCode,
                                );

                                // If generating daily tasks or requested, trigger daily tasks generator with lab parameters
                                Map<String, dynamic>? taskRes;
                                if (isGeneratingDeliveries) {
                                  taskRes = await widget.state.generateTodayTasks(
                                    date: dateStr,
                                    productName: selectedProduct,
                                    fatPercentage: fat,
                                    snfPercentage: snf,
                                    waterPercentage: water,
                                    pricePerLitre: price,
                                    totalLitres: volume,
                                    temperatureCelsius: 3.8,
                                    hubCode: widget.state.activeHubCode,
                                  );
                                } else {
                                  await widget.state.reloadAllData();
                                }

                                if (modalCtx.mounted) {
                                  Navigator.pop(ctx);
                                  if (context.mounted) {
                                    final tasksCreated = taskRes?['tasks_created'] ?? 0;
                                    final totalTasks = taskRes?['total_tasks'] ?? tasksCreated;
                                    final subsFound = taskRes?['active_subscriptions_found'] ?? '?';
                                    final hubFilter = taskRes?['hub_filter'] ?? '?';
                                    final String taskMsg;
                                    if (taskRes == null) {
                                      // API returned error
                                      final apiErr = ApiService.lastError ?? 'Unknown error';
                                      taskMsg = '— API Error: $apiErr';
                                    } else if (tasksCreated > 0) {
                                      taskMsg = '& generated $tasksCreated new deliveries for $dateStr!';
                                    } else if (totalTasks > 0) {
                                      taskMsg = '— $totalTasks deliveries already scheduled for $dateStr ✅';
                                    } else {
                                      taskMsg = '— no active subscriptions found for $dateStr (subs: $subsFound, hub: $hubFilter)';
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: UiTone.primary,
                                        content: Text(isGeneratingDeliveries
                                            ? '🚀 Certified $selectedProduct ($fat% Fat, $snf% SNF @ ₹$price/L) $taskMsg'
                                            : '✅ Batch certified for $dateStr: $fat% Fat, $snf% SNF @ ₹$price/L!'),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(isGeneratingDeliveries ? Icons.local_shipping_rounded : Icons.verified_rounded),
                        label: Text(
                          isSubmitting
                              ? 'Certifying & Generating...'
                              : (isGeneratingDeliveries
                                  ? '🚀 Certify Lab & Generate Deliveries'
                                  : '🔬 Certify Lab Report & Dispatch 🚀'),
                          style: UiText.title.copyWith(fontSize: 13.5, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UiTone.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBatchInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: UiTone.surfaceMuted,
        borderRadius: BorderRadius.circular(UiRadius.sm),
        border: Border.all(color: UiTone.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: UiText.caption.copyWith(fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: UiText.h2.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: UiTone.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              hintText: hint,
            ),
          ),
        ],
      ),
    );
  }
}
