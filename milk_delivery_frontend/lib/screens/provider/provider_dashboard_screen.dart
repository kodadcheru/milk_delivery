import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../models/subscription_model.dart';
import '../../models/bottle_return_model.dart';
import '../../models/provider_payout_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/hub_realtime_service.dart';
import 'provider_fleet_map_screen.dart';
import '../driver/morning_batch_screen.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final AppState state;

  const ProviderDashboardScreen({super.key, required this.state});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _selectedFilter = 0; // 0: All, 1: Active Subs, 2: Express, 3: Fleet, 4: Capacity, 5: Broadcasts, 6: Payouts, 7: Paused, 8: Bottles
  String _searchQuery = '';
  int _activeDriverCount = 4;
  List<Map<String, dynamic>> _hubInventory = [];
  List<Map<String, dynamic>> _liveFleet = [];
  bool _isGeneratingTasks = false;
  Timer? _hubRealtimeTimer;

  final List<Map<String, dynamic>> _broadcastAlerts = [];
  List<ProviderPayoutModel> _payoutHistory = [];
  List<BottleReturnModel> _bottleReturns = [];

  String get _activeHubName {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    return activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';
  }

  @override
  void initState() {
    super.initState();
    _loadAllHubData();
    _hubRealtimeTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadAllHubData());
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
    final fleet = await ApiService.fetchFleet();
    if (mounted && fleet.isNotEmpty) {
      setState(() {
        _liveFleet = fleet;
        _activeDriverCount = fleet.length;
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
        title: const Row(
          children: [
            Text('📢', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Hub Broadcast Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send instant push & SMS notification to all active subscribers in Hub zone:', style: TextStyle(fontSize: 11.5, color: UiTone.ink)),
              const SizedBox(height: 10),
              const Text('Quick Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary)),
              const SizedBox(height: 4),
              ...presets.map((p) => InkWell(
                    onTap: () => controller.text = p,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: UiTone.surfaceMuted, borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: Text(p, style: const TextStyle(fontSize: 11, color: UiTone.softText)),
                    ),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
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
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              final msg = controller.text.trim();
              Navigator.pop(ctx);
              HubRealtimeService.sendBroadcast(msg);
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
            label: const Text('Send Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: UiTone.primary),
            SizedBox(width: 8),
            Text('Instant Bank Payout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Provider Balance: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: UiTone.primary)),
            const SizedBox(height: 8),
            const Text('Destination Settlement Account:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                      activeHub != null && activeHub['bank_account'] != null
                          ? '${activeHub['bank_account']}'
                          : 'Primary Bank Account (A/C **4892)\nDaily Auto-Payout • Instant Transfer',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
                      content: Text('💸 Instant Payout of ₹${newPayout.amount.toStringAsFixed(0)} transferred to Bank! Ref: ${newPayout.id}'),
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
            label: const Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
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
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Top drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F5F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('📦', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hub Daily Slots & Inventory',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Live product capacity limits, booked crates & availability',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: inventoryList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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

    // Filter tasks & orders (only upcoming active non-paused orders appear on provider home dashboard by default)
    List<DeliveryTaskModel> filteredTasks = tasks.where((t) {
      final sub = t.subscriptionDetail;
      final isSubPaused = sub != null && sub.status == 'PAUSED';
      if (_selectedFilter == 0 && (t.status == 'DELIVERED' || t.status == 'COMPLETED' || t.status == 'SKIPPED' || isSubPaused)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.customerName.toLowerCase().contains(q) || t.deliveryAddress.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Central Dairy Depot') : 'Central Dairy Depot';
    final hubCode = activeHub != null ? (activeHub['hub_code'] ?? 'HUB-01') : 'HUB-01';

    final uniqueCustomers = tasks.map((t) => t.customerName).toSet().length;
    final activeFamilies = uniqueCustomers > 0 ? '$uniqueCustomers Families' : '${tasks.length} Families';
    final activeFleetCount = _liveFleet.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Hero Hub Header Card ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x250D7C66), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D7C66).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text('🏬', style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hubName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text(
                                  'Operating Zone • ID #$hubCode',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 6),
                          SizedBox(width: 4),
                          Text('LIVE HUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  children: [
                    Expanded(child: _buildHubStatColumn(activeFamilies, 'Active Families')),
                    Container(width: 1, height: 28, color: Colors.white30),
                    Expanded(child: _buildHubStatColumn('${totalLitres.toStringAsFixed(0)} Litres', 'Daily Volume')),
                    Container(width: 1, height: 28, color: Colors.white30),
                    Expanded(child: _buildHubStatColumn('$activeFleetCount Drivers', 'Active Fleet')),
                    Container(width: 1, height: 28, color: Colors.white30),
                    Expanded(child: _buildHubStatColumn('${totalLitres.toStringAsFixed(0)} Bottles', 'Crates Ready')),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
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
                    icon: const Icon(Icons.radar_rounded, size: 16, color: Colors.white),
                    label: const Text('Live Fleet Radar & Depot Coverage Map 🗺️', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Today's Daily Batch Lab Quality & Litre Rate ──
          _buildDailyBatchLabCard(context),
          const SizedBox(height: 14),

          // ── Quick Command Shortcuts Grid (4 Hub Actions) ──
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MorningBatchScreen(state: widget.state)),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                      boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.inventory_rounded, color: Color(0xFF2563EB), size: 22),
                        SizedBox(height: 6),
                        Text('Batch Packing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF1E40AF))),
                        Text('Crate manifest', style: TextStyle(fontSize: 9.5, color: Color(0xFF3B82F6))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _showBatchLabQualityDialog(context, isGeneratingDeliveries: true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.autorenew_rounded, color: Color(0xFF2563EB), size: 22),
                        SizedBox(height: 6),
                        Text('Gen Tasks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF0F172A))),
                        Text('Create batch', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _openManageCapacitySlotsDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.tune_rounded, color: Color(0xFF0D7C66), size: 22),
                        SizedBox(height: 6),
                        Text('Daily Slots', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF0F172A))),
                        Text('Limits & stock', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _showBroadcastDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.campaign_rounded, color: Color(0xFFE67E22), size: 22),
                        SizedBox(height: 6),
                        Text('Broadcast', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF0F172A))),
                        Text('Push alerts', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _withdrawEarnings(context, netEarnings),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D7C66), size: 22),
                        const SizedBox(height: 6),
                        Text('₹${netEarnings.toStringAsFixed(0)} Pay', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF0D7C66))),
                        const Text('Settlement', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Generate Today's Delivery Tasks ──
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _showBatchLabQualityDialog(context, isGeneratingDeliveries: true),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18, color: Colors.white),
              label: const Text(
                "Generate Today's Delivery Tasks ⚡",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Equal Load Balancer & Delivery Boys Configurator ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.2),
              boxShadow: const [BoxShadow(color: Color(0x100F172A), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('⚖️', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Equal Load Balancer & Fleet Dispatch',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                Text(
                                  'Auto-partitions hub orders equally across active boys',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Text('EQUAL LOAD', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Delivery Boys Input Stepper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Delivery Boys Today:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text('Hub operator input for shift partitioning', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                            onPressed: _activeDriverCount > 1 ? () => setState(() => _activeDriverCount--) : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$_activeDriverCount Boys',
                              style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 13.5),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF34D399), size: 22),
                            onPressed: _activeDriverCount < 10 ? () => setState(() => _activeDriverCount++) : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Equal Partition Telemetry
                Row(
                  children: [
                    Expanded(child: _buildPartitionStat('${tasks.length} Total', 'Hub Orders')),
                    Container(width: 1, height: 24, color: Colors.white24),
                    Expanded(child: _buildPartitionStat('${(tasks.length / _activeDriverCount).ceil()} Stops', 'Per Driver ⚖️')),
                    Container(width: 1, height: 24, color: Colors.white24),
                    Expanded(child: _buildPartitionStat('~${(totalLitres / _activeDriverCount).toStringAsFixed(0)}L', 'Load / Driver')),
                    Container(width: 1, height: 24, color: Colors.white24),
                    Expanded(child: _buildPartitionStat('₹15k/mo', 'Fixed Salary')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 3. Integrated Search Bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: Color(0xFF0D7C66), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Search customer, apartment, or mobile...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 4. Filter Tabs Carousel ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip(0, '⚡ Upcoming Orders', filteredTasks.length + liveOrders.length),
                const SizedBox(width: 8),
                _buildFilterChip(1, '✅ Active Subs', activeSubs.length),
                const SizedBox(width: 8),
                _buildFilterChip(7, '⏸️ Paused Subs', pausedSubs.length),
                const SizedBox(width: 8),
                _buildFilterChip(2, '⚡ Express Orders', liveOrders.length),
                const SizedBox(width: 8),
                _buildFilterChip(3, '🛵 Fleet Status', _liveFleet.length),
                const SizedBox(width: 8),
                _buildFilterChip(4, '📦 Crates & Stock', 0),
                const SizedBox(width: 8),
                _buildFilterChip(8, '🍼 Bottles Returned', _bottleReturns.length),
                const SizedBox(width: 8),
                _buildFilterChip(5, '📢 Alerts Broadcasted', _broadcastAlerts.length),
                const SizedBox(width: 8),
                _buildFilterChip(6, '💰 Bank Payouts', _payoutHistory.length),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 5. Content Section Based on Filter ──
          if (_selectedFilter == 8) ...[
            _buildBottleReturnsSection(),
          ] else if (_selectedFilter == 6) ...[
            _buildPayoutLedgerSection(),
          ] else if (_selectedFilter == 5) ...[
            _buildBroadcastAlertsSection(),
          ] else if (_selectedFilter == 4) ...[
            _buildInventoryCratesSection(),
          ] else if (_selectedFilter == 3) ...[
            _buildFleetDriversSection(),
          ] else if (_selectedFilter == 7) ...[
            _buildSubscriptionListSection('⏸️ Paused Subscriptions', pausedSubs, 'PAUSED'),
          ] else if (_selectedFilter == 1) ...[
            _buildSubscriptionListSection('✅ Active Subscriptions', activeSubs, 'ACTIVE'),
          ] else if (_selectedFilter == 2) ...[
            _buildExpressOnlySection(liveOrders),
          ] else ...[
            _buildOrdersRosterSection(filteredTasks, liveOrders),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WHO ORDERED ROSTER SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOrdersRosterSection(List<DeliveryTaskModel> subscriptions, List<LiveOrderModel> express) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '📋 Customer Orders in Hub Zone:',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink),
              ),
            ),
            const SizedBox(width: 6),
            Text('${subscriptions.length + express.length} Active Orders', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary)),
          ],
        ),
        const SizedBox(height: 10),

        // Express Orders First
        if (_selectedFilter == 0 || _selectedFilter == 2)
          ...express.map((ord) => _buildExpressOrderCard(ord)),

        // Daily Subscriptions
        if (_selectedFilter == 0 || _selectedFilter == 1)
          ...subscriptions.map((task) => _buildSubscriptionCustomerCard(task)),
      ],
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
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusType == 'PAUSED' ? UiTone.warningSoft : UiTone.successSoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Text(
                '${subs.length} ${statusType == 'PAUSED' ? 'Paused' : 'Active'}',
                style: TextStyle(
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: UiTone.surfaceMuted,
              borderRadius: BorderRadius.circular(UiRadius.md),
            ),
            child: Column(
              children: [
                Icon(
                  statusType == 'PAUSED' ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
                  size: 48,
                  color: UiTone.softText,
                ),
                const SizedBox(height: 12),
                Text(
                  statusType == 'PAUSED' ? 'No paused subscriptions' : 'No active subscriptions',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: UiTone.softText),
                ),
              ],
            ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.md),
        side: BorderSide(
          color: statusType == 'PAUSED' ? UiTone.warning.withValues(alpha: 0.3) : UiTone.surfaceBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customer #${sub.customerId} • ${sub.scheduleType} • $qty units',
                    style: const TextStyle(fontSize: 11, color: UiTone.softText),
                  ),
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(price * qty).toStringAsFixed(0)}/day',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.primary),
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
                    style: TextStyle(
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
            const Expanded(
              child: Text('⚡ Express Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: UiTone.errorSoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Text(
                '${express.length} Orders',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (express.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: UiTone.surfaceMuted,
              borderRadius: BorderRadius.circular(UiRadius.md),
            ),
            child: const Column(
              children: [
                Icon(Icons.flash_off_rounded, size: 48, color: UiTone.softText),
                SizedBox(height: 12),
                Text('No express orders', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: UiTone.softText)),
              ],
            ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: UiTone.ink),
                        ),
                        Text(
                          'Phone: $custPhone',
                          style: TextStyle(fontSize: 10.5, color: UiTone.softText),
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
                        style: TextStyle(
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '${sub?.scheduleType ?? "DAILY"} • Slot: ${task.slotTime}',
                          style: TextStyle(color: UiTone.softText, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${((product?.pricePerUnit ?? 40) * (sub?.quantity ?? 1)).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: UiTone.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Address & Assigned Driver
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: UiTone.softText),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.deliveryAddress.replaceAll(', Hyderabad', ', Telangana').replaceAll('Hyderabad', 'Telangana'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: UiTone.softText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.two_wheeler_rounded, size: 14, color: UiTone.primary),
                const SizedBox(width: 4),
                Text(
                  _liveFleet.isNotEmpty
                      ? 'Driver: ${_liveFleet[task.id % _liveFleet.length]['name']} (Route #${task.id % 5 + 1})'
                      : 'Driver Partner (Route #${task.id % 5 + 1})',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: UiTone.primary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Prepaid Wallet (Auto)',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: UiTone.softText),
                  ),
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
                    label: const Text('Call Customer', style: TextStyle(fontSize: 11)),
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
                    label: const Text('WhatsApp Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildExpressOrderCard(LiveOrderModel ord) {
    final isDelivered = ord.status == 'DELIVERED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      child: Text(ord.id, style: const TextStyle(color: UiTone.accentBlue, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: UiTone.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: const Text('30-MIN EXPRESS', style: TextStyle(color: UiTone.error, fontSize: 9, fontWeight: FontWeight.bold)),
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
                    style: TextStyle(
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text('Delivery to: ${ord.deliveryAddress}', style: TextStyle(color: UiTone.softText, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Total: ₹${ord.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: UiTone.primary, fontSize: 12.5)),
                Text('OTP: ${ord.deliveryOtp}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.accentBlue)),
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
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: UiTone.primary),
            SizedBox(width: 8),
            Text('Onboard Delivery Boy to Hub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              final success = await ApiService.createHubDriver(
                firstName: fnCtrl.text.trim().isEmpty ? 'Delivery' : fnCtrl.text.trim(),
                lastName: lnCtrl.text.trim().isEmpty ? 'Partner' : lnCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                hubId: widget.state.locationHubs.isNotEmpty ? (widget.state.locationHubs.first['id'] as int? ?? 1) : 1,
                monthlySalary: double.tryParse(salaryCtrl.text.trim()) ?? 15000.0,
              );
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
            Text('🛵 Assigned Hub Fleet (${drivers.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            ElevatedButton.icon(
              onPressed: () => _showAddDriverDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 14),
              label: const Text('Add Delivery Boy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.sm),
              border: Border.all(color: UiTone.surfaceBorder),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.delivery_dining_rounded, size: 36, color: UiTone.softText),
                  SizedBox(height: 8),
                  Text('No delivery boys onboarded yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.softText)),
                  SizedBox(height: 4),
                  Text('Tap "Add Delivery Boy" to onboard drivers to this hub.', style: TextStyle(fontSize: 11, color: UiTone.softText)),
                ],
              ),
            ),
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
                        Text(drv['name'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('📍 $hubNameText', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: UiTone.primary)),
                        Text(drv['route'] ?? 'Sector Route', style: TextStyle(fontSize: 10, color: UiTone.softText)),
                        const SizedBox(height: 2),
                        Text(drv['status'] ?? '🟢 Active', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: UiTone.primary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(drv['salary'] ?? '₹15,000/mo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: UiTone.primary)),
                      Text(drv['stops'] ?? '12 Stops', style: TextStyle(fontSize: 10, color: UiTone.softText)),
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
            const Expanded(
              child: Text(
                '📦 Hub Daily Capacity & Crate Stock:',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A)),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                _loadHubInventory();
                await widget.state.reloadAllData();
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Refresh', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF0D7C66)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (inventoryList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('No inventory data yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B))),
              ],
            ),
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
        color: booked > 0 ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: booked > 0
              ? const Color(0xFF10B981)
              : (isAvailable ? const Color(0xFFE2E8F0) : const Color(0xFFFECDD3)),
          width: booked > 0 ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: booked > 0 ? const Color(0x1210B981) : const Color(0x060F172A),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booked > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    'ACTIVE DEMAND: $booked CRATES SUBSCRIBED TODAY',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '$unit • ₹$price MRP',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                      backgroundColor: newStatus ? const Color(0xFF0D7C66) : const Color(0xFFDC2626),
                      content: Text(newStatus ? '🟢 $productName set to IN STOCK for hub zone.' : '⏸️ $productName set to PAUSED for hub zone.'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                        size: 12,
                        color: isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAvailable ? 'IN STOCK' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fillPercent.toDouble(),
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                fillPercent > 0.85
                    ? const Color(0xFFDC2626)
                    : (fillPercent > 0.6 ? const Color(0xFFD97706) : const Color(0xFF0D7C66)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$booked Booked Today',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
              Text(
                '$available Slots Left (Max $dailyCapacity)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: available > 0 ? const Color(0xFF0D7C66) : const Color(0xFFDC2626),
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
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF0F172A),
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
                  backgroundColor: const Color(0xFFE6F5F0),
                  foregroundColor: const Color(0xFF0D7C66),
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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('+50', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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
                    label: const Text('Custom Limit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D7C66),
                      side: const BorderSide(color: Color(0xFF0D7C66)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE6F5F0), borderRadius: BorderRadius.circular(10)),
                  child: const Text('📦', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Capacity Limit', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Preset Slots:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isCurrent ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '$p Slots',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : const Color(0xFF334155),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Exact Daily Capacity Slots',
                    hintText: 'e.g. 200',
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D7C66), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                      backgroundColor: const Color(0xFF0D7C66),
                      content: Text('⚡ $productName capacity set to $newCap slots in real-time!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7C66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Limit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPartitionStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: UiTone.secondary, fontSize: 12.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildHubStatColumn(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: UiTone.surface, fontSize: 12.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildBroadcastAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('📢 Sent Hub Customer Broadcasts:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            ElevatedButton.icon(
              onPressed: () => _showBroadcastDialog(context),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: const Text('New Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: UiTone.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._broadcastAlerts.map((b) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(b['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: UiTone.ink)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: UiTone.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(UiRadius.xs)),
                          child: Text(b['status'] ?? 'SENT', style: const TextStyle(color: UiTone.secondary, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🕒 ${b['time']}', style: TextStyle(fontSize: 11, color: UiTone.softText)),
                        Text('👥 Audience: ${b['recipients']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
                      ],
                    ),
                  ],
                ),
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
            const Text('💰 Settlement & Payout Receipts Ledger:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loadPayouts,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                ),
                Text('${_payoutHistory.length} Receipts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_payoutHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: UiTone.surfaceMuted,
              borderRadius: BorderRadius.circular(UiRadius.md),
            ),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 44, color: UiTone.softText),
                const SizedBox(height: 10),
                const Text('No payout settlements requested yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.softText)),
                const SizedBox(height: 4),
                const Text('Request instant payout to transfer hub earnings directly to your bank account', style: TextStyle(fontSize: 11, color: UiTone.softText), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _withdrawEarnings(context, widget.state.totalDailyRevenue),
                  icon: const Icon(Icons.flash_on_rounded, size: 15),
                  label: const Text('Request Settlement Transfer 💸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: UiTone.surface,
                  ),
                ),
              ],
            ),
          )
        else
          ..._payoutHistory.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                              Text(p.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: UiTone.ink)),
                              Text('${p.date} • ${p.bank}', style: const TextStyle(fontSize: 10.5, color: UiTone.softText)),
                              if (p.totalDeliveries > 0)
                                Text('📦 ${p.totalDeliveries} Deliveries • Rev: ₹${p.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: UiTone.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.primary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: UiTone.successSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                            child: Text(p.status, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: UiTone.success)),
                          ),
                        ],
                      ),
                    ],
                  ),
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
            const Text('🍼 Bottle Deposits & Returns Ledger:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loadBottleReturns,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                ),
                TextButton.icon(
                  onPressed: () => _showAddBottleDepositDialog(context),
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: const Text('+ Deposit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: UiTone.surfaceMuted,
              borderRadius: BorderRadius.circular(UiRadius.md),
            ),
            child: Column(
              children: [
                const Icon(Icons.cleaning_services_rounded, size: 44, color: UiTone.softText),
                const SizedBox(height: 10),
                const Text('No bottle return records yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.softText)),
                const SizedBox(height: 4),
                const Text('Glass bottle deposits collected by drivers or customers will show here for refund processing.', style: TextStyle(fontSize: 11, color: UiTone.softText), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showAddBottleDepositDialog(context),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Record Customer Bottle Deposit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(foregroundColor: UiTone.primary, side: const BorderSide(color: UiTone.primary)),
                ),
              ],
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
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
            Text(label, style: const TextStyle(fontSize: 9.5, color: UiTone.softText), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildBottleReturnCard(BottleReturnModel b) {
    final isDeposited = b.status == 'DEPOSITED';
    final isReturned = b.status == 'RETURNED';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.md),
        side: BorderSide(
          color: isDeposited ? UiTone.warning.withValues(alpha: 0.4) : UiTone.surfaceBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      Text(b.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
                      Text('${b.quantity}x ${b.productName} • Driver: ${b.driverName}', style: const TextStyle(fontSize: 11, color: UiTone.softText)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Deposit: ₹${b.depositAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: UiTone.primary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDeposited ? UiTone.warningSoft : (isReturned ? UiTone.successSoft : UiTone.errorSoft),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text(
                        b.status,
                        style: TextStyle(
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
                                SnackBar(backgroundColor: UiTone.primary, content: Text('✅ Refunded ₹${b.depositAmount.toStringAsFixed(0)} deposit to ${b.customerName}\'s wallet!')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.price_check_rounded, size: 14),
                        label: const Text('Mark Returned & Refund Deposit 💸', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
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
                      child: const Text('Lost ❌', style: TextStyle(fontSize: 10.5)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
          title: const Text('Record Customer Bottle Deposit 🍼', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bottle Quantity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: qty > 1 ? () => setDlgState(() => qty--) : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                      ),
                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildFilterChip(int idx, String label, int count) {
    final isSelected = _selectedFilter == idx;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = idx),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            if (isSelected)
              const BoxShadow(color: Color(0x200D7C66), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
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
    final price = latestBatch?['price_per_litre'] != null ? '₹${(latestBatch!['price_per_litre'] as num).toStringAsFixed(0)}/L' : '₹68/L';
    final product = latestBatch?['product_name']?.toString() ?? 'Pure Buffalo Milk';
    final batchCode = latestBatch?['batch_code']?.toString() ?? 'BATCH-KDD-01';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Milk Batch Quality & Pricing 🥛',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                      ),
                      Text(
                        '$product • $batchCode',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showBatchLabQualityDialog(context),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                label: const Text('Certify Batch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  icon: '🔬',
                  title: 'SNF %',
                  value: snf,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  icon: '💧',
                  title: 'Water %',
                  value: water,
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFDCFCE7),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  icon: '₹',
                  title: 'Rate/L',
                  value: price,
                  color: const Color(0xFF0D7C66),
                  bgColor: const Color(0xFFE6F5F0),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 10.5)),
              const SizedBox(width: 2),
              Text(title, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _showBatchLabQualityDialog(BuildContext context, {bool isGeneratingDeliveries = false}) {
    String selectedProduct = 'Pure Buffalo Milk';
    DateTime selectedDate = isGeneratingDeliveries ? DateTime.now().add(const Duration(days: 1)) : DateTime.now();
    final fatCtrl = TextEditingController(text: '6.8');
    final snfCtrl = TextEditingController(text: '9.0');
    final waterCtrl = TextEditingController(text: '0.0');
    final priceCtrl = TextEditingController(text: '68');
    final volumeCtrl = TextEditingController(text: '450');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
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
                                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  isGeneratingDeliveries
                                      ? 'Certify today\'s milk quality & create morning drop tasks'
                                      : 'Enter daily lab purity & dynamic litre rate',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                    const Text('1. Delivery Batch Target Date:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
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
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. Select Milk Product
                    const Text('2. Select Milk Product Variety:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    const Text('3. Certified Lab Quality Measurements:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'FAT %',
                            hint: '6.8',
                            controller: fatCtrl,
                            icon: '🧈',
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'SNF %',
                            hint: '9.0',
                            controller: snfCtrl,
                            icon: '🔬',
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'Water %',
                            hint: '0.0',
                            controller: waterCtrl,
                            icon: '💧',
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4. Litre Rate & Volume
                    const Text('4. Dynamic Litre Pricing & Volume:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'Price / Litre (₹)',
                            hint: '68',
                            controller: priceCtrl,
                            icon: '₹',
                            color: const Color(0xFF0D7C66),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildBatchInputField(
                            label: 'Total Litres (L)',
                            hint: '450',
                            controller: volumeCtrl,
                            icon: '📦',
                            color: const Color(0xFF475569),
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
                                  taskRes = await widget.state.generateDailyTasks(
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
                                    final tasksCount = taskRes?['tasks_created'] ?? 0;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF0D7C66),
                                        content: Text(isGeneratingDeliveries
                                            ? '🚀 Certified $selectedProduct ($fat% Fat, $snf% SNF @ ₹$price/L) & generated $tasksCount deliveries for $dateStr!'
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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
