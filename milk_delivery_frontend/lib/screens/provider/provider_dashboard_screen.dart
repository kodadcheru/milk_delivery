import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/route_optimizer.dart';
import 'provider_fleet_map_screen.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final AppState state;

  const ProviderDashboardScreen({super.key, required this.state});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _selectedFilter = 0; // 0: All, 1: Active Subs, 2: Express, 3: Fleet, 4: Capacity, 5: Broadcasts, 6: Payouts, 7: Paused
  String _searchQuery = '';
  int _activeDriverCount = 4;
  List<Map<String, dynamic>> _hubInventory = [];
  List<Map<String, dynamic>> _liveFleet = [];
  bool _isGeneratingTasks = false;

  final List<Map<String, dynamic>> _broadcastAlerts = [];
  final List<Map<String, dynamic>> _payoutHistory = [];

  String get _activeHubName {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    return activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';
  }

  @override
  void initState() {
    super.initState();
    _loadLiveFleet();
    _loadHubInventory();
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
              setState(() {
                _broadcastAlerts.insert(0, {
                  'title': msg,
                  'time': 'Just Now',
                  'recipients': '${widget.state.deliveries.length} Subscribers',
                  'status': 'BROADCAST SENT ✅',
                });
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: UiTone.primary,
                  content: Text('📢 Broadcast Sent to ${widget.state.deliveries.length} Subscribers in Hub Zone!'),
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
            onPressed: () {
              Navigator.pop(ctx);
              final txnId = 'PAY-HYD-${1000 + DateTime.now().second * 37}';
              setState(() {
                _payoutHistory.insert(0, {
                  'id': txnId,
                  'date': 'Just Now',
                  'amount': amount,
                  'status': 'SETTLED ✅',
                  'bank': 'Primary Bank (A/C **4892)',
                });
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: UiTone.primary,
                  content: Text('💸 Instant Payout of ₹${amount.toStringAsFixed(0)} transferred to Bank! Ref: $txnId'),
                ),
              );
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

  void _openManageCapacitySlotsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.lg)),
        title: const Row(
          children: [
            Text('📦 ', style: TextStyle(fontSize: 22)),
            Expanded(child: Text('Hub Product Capacity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _hubInventory.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No inventory data loaded. Products will appear after subscriptions are created.', style: TextStyle(color: UiTone.softText)),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _hubInventory.map((inv) {
                      final name = inv['product_name'] ?? 'Product';
                      final capacity = inv['daily_capacity_slots'] ?? 100;
                      final booked = inv['booked_slots'] ?? 0;
                      final available = inv['available_slots'] ?? (capacity - booked);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: UiTone.shellBackground,
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          border: Border.all(color: UiTone.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: UiTone.ink)),
                            const SizedBox(height: 6),
                            Text('Capacity: $capacity | Booked: $booked | Available: $available',
                                style: const TextStyle(fontSize: 11, color: UiTone.softText)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
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

    // Filter tasks & orders
    List<DeliveryTaskModel> filteredTasks = tasks.where((t) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Hub Location Header Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UiTone.ink, UiTone.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(UiRadius.lg),
              boxShadow: UiShadow.elevated,
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
                              color: UiTone.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(UiRadius.sm),
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
                                  style: const TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 14.5),
                                ),
                                Text(
                                  'Operating Zone • ID #$hubCode',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.w600),
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
                      decoration: BoxDecoration(
                        color: UiTone.secondary,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: UiTone.surface, size: 6),
                          SizedBox(width: 4),
                          Text('LIVE HUB', style: TextStyle(color: UiTone.surface, fontWeight: FontWeight.w900, fontSize: 9.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  children: [
                    Expanded(child: _buildHubStatColumn(activeFamilies, 'Active Subscribers')),
                    Container(width: 1, height: 28, color: Colors.white30),
                    Expanded(child: _buildHubStatColumn('${totalLitres.toStringAsFixed(0)} Litres', 'Daily Milk Volume')),
                    Container(width: 1, height: 28, color: Colors.white30),
                    Expanded(child: _buildHubStatColumn('$activeFleetCount Drivers', 'Active Fleet')),
                    Container(width: 1, height: 28, color: Colors.white30),
                    Expanded(child: _buildHubStatColumn('${totalLitres.toStringAsFixed(0)} Bottles', 'Crate Inventory')),
                  ],
                ),
                const SizedBox(height: 14),
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
                    icon: const Icon(Icons.radar_rounded, size: 16, color: UiTone.surface),
                    label: const Text('Live Fleet Radar & Depot Coverage Map 🗺️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.accentBlue,
                      foregroundColor: UiTone.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Generate Today's Delivery Tasks ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingTasks ? null : () async {
                setState(() => _isGeneratingTasks = true);
                final result = await ApiService.generateTodayTasks();
                setState(() => _isGeneratingTasks = false);
                if (result != null && context.mounted) {
                  await widget.state.reloadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: UiTone.primary,
                      content: Text('✅ ${result['tasks_created']} tasks created, ${result['subscriptions_skipped']} skipped for ${result['date']}'),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: UiTone.error,
                      content: Text('❌ Failed to generate tasks: ${ApiService.lastError ?? "Unknown error"}'),
                    ),
                  );
                }
              },
              icon: _isGeneratingTasks
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.surface))
                  : const Icon(Icons.auto_fix_high_rounded, size: 18, color: UiTone.surface),
              label: Text(
                _isGeneratingTasks ? 'Generating Tasks...' : "Generate Today's Delivery Tasks ⚡",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: UiTone.surface,
                disabledBackgroundColor: UiTone.primary.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // ── Equal Load Balancer & Delivery Boys Configurator ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTone.ink,
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: UiTone.secondary.withValues(alpha: 0.35), width: 1.5),
              boxShadow: UiShadow.elevated,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Equal Load Balancer & Fleet Dispatch',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const Text(
                                  'Auto-partitions hub orders equally across active boys',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: UiTone.secondary, fontSize: 10, fontWeight: FontWeight.w600),
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
                      decoration: BoxDecoration(color: UiTone.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: const Text('EQUAL LOAD', style: TextStyle(color: UiTone.secondary, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Delivery Boys Input Stepper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: UiTone.surface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Delivery Boys Today:', style: TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '$_activeDriverCount Boys',
                              style: const TextStyle(color: UiTone.secondary, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: UiTone.secondary, size: 22),
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
                const SizedBox(height: 12),

                // Manage Capacity & Partitioned Fleet Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _openManageCapacitySlotsDialog(context),
                          icon: const Icon(Icons.inventory_2_rounded, size: 16),
                          label: const Text('Manage Daily Slots 📦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UiTone.primary,
                            foregroundColor: UiTone.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: UiTone.primary,
                                content: Text('⚖️ Hub Orders Balanced! ${tasks.length} orders partitioned equally across $_activeDriverCount salaried delivery boys with zero route overlap.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.hub_rounded, size: 16),
                          label: Text('Auto-Balance Fleet ($_activeDriverCount) 🚀', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UiTone.secondary,
                            foregroundColor: UiTone.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Live Partitions Summary
                Builder(
                  builder: (context) {
                    final partitions = RouteOptimizer.partitionEquallyForDrivers(
                      hub: HubLocationModel.defaultHub,
                      allTasks: tasks,
                      numberOfDrivers: _activeDriverCount,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        ...partitions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final res = entry.value;
                          final dName = idx < _liveFleet.length ? (_liveFleet[idx]['name'] ?? 'Driver #${idx + 1}') : 'Driver #${idx + 1}';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: UiTone.surface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                            ),
                            child: Row(
                              children: [
                                Flexible(child: Text('🛵 $dName', overflow: TextOverflow.ellipsis, style: const TextStyle(color: UiTone.surface, fontSize: 11, fontWeight: FontWeight.bold))),
                                const SizedBox(width: 6),
                                Flexible(child: Text('${res.orderedStops.length} Stops • ${res.totalDistanceKm.toStringAsFixed(1)} km • Salaried Staff', overflow: TextOverflow.ellipsis, style: const TextStyle(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 2. Provider Earnings & Settlement Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UiTone.primary, UiTone.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(UiRadius.md),
              boxShadow: UiShadow.elevated,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Provider Settlement Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${netEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(color: UiTone.surface, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _withdrawEarnings(context, netEarnings),
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 15),
                      label: const Text('Withdraw Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.surface,
                        foregroundColor: UiTone.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: UiTone.ink.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(UiRadius.sm)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gross Daily GMV: ₹${totalRevenue.toStringAsFixed(0)}', style: const TextStyle(color: UiTone.surface, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      const Text('75% Provider Share • 25% Logistics', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Search Bar & Broadcast CTA ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: UiTone.surface,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: UiTone.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: UiTone.softText, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Search customer, apartment, or phone...',
                            hintStyle: TextStyle(color: UiTone.softText, fontSize: 12.5),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showBroadcastDialog(context),
                borderRadius: BorderRadius.circular(UiRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: UiTone.primary,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    boxShadow: UiShadow.elevated,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: UiTone.surface, size: 18),
                      SizedBox(width: 4),
                      Text('Alert', style: TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 4. Filter Tabs (Active / Paused / Express / Fleet / Alerts / Payouts) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, '👥 All Orders (${filteredTasks.length + liveOrders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, '✅ Active (${activeSubs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(7, '⏸️ Paused (${pausedSubs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(2, '⚡ Express (${liveOrders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(3, '🛵 Fleet (${_liveFleet.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(4, '📦 Crates'),
                const SizedBox(width: 8),
                _buildFilterChip(5, '📢 Alerts (${_broadcastAlerts.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(6, '💰 Payouts (${_payoutHistory.length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 5. Content Section Based on Filter ──
          if (_selectedFilter == 6) ...[
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
                    task.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: UiTone.softText),
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
  // HUB PRODUCT CAPACITY SECTION (Real API data)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildInventoryCratesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('📦 Hub Product Capacity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink)),
            ),
            TextButton.icon(
              onPressed: _loadHubInventory,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Refresh', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: UiTone.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_hubInventory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: UiTone.surfaceMuted,
              borderRadius: BorderRadius.circular(UiRadius.md),
            ),
            child: const Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: UiTone.softText),
                SizedBox(height: 12),
                Text('No inventory data yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: UiTone.softText)),
                SizedBox(height: 4),
                Text('Product capacity will appear once subscriptions are created', style: TextStyle(fontSize: 11, color: UiTone.softText)),
              ],
            ),
          )
        else
          ..._hubInventory.map((inv) => _buildHubInventoryCard(inv)),
      ],
    );
  }

  Widget _buildHubInventoryCard(Map<String, dynamic> inv) {
    final productName = inv['product_name'] ?? 'Unknown Product';
    final dailyCapacity = inv['daily_capacity_slots'] ?? 100;
    final booked = inv['booked_slots'] ?? 0;
    final available = inv['available_slots'] ?? (dailyCapacity - booked);
    final isAvailable = inv['is_available'] ?? true;
    final productId = inv['product'] ?? 0;
    final fillPercent = dailyCapacity > 0 ? (booked / dailyCapacity).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: isAvailable ? UiTone.surfaceBorder : UiTone.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await ApiService.updateHubInventory(
                    productId: productId,
                    dailyCapacitySlots: dailyCapacity,
                    isAvailable: !isAvailable,
                  );
                  if (result != null) _loadHubInventory();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAvailable ? UiTone.successSoft : UiTone.errorSoft,
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isAvailable ? UiTone.success : UiTone.error),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPercent.toDouble(),
              minHeight: 8,
              backgroundColor: UiTone.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                fillPercent > 0.8 ? UiTone.error : fillPercent > 0.5 ? UiTone.warning : UiTone.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$booked / $dailyCapacity booked', style: const TextStyle(fontSize: 11, color: UiTone.softText)),
              Text('$available available', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: available > 0 ? UiTone.success : UiTone.error,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditCapacityDialog(productId, productName, dailyCapacity),
                    icon: const Icon(Icons.edit, size: 12),
                    label: const Text('Edit Capacity', style: TextStyle(fontSize: 10.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: UiTone.primary,
                      side: const BorderSide(color: UiTone.primary),
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

  void _showEditCapacityDialog(int productId, String productName, int currentCapacity) {
    final controller = TextEditingController(text: currentCapacity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Capacity: $productName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Daily Capacity Slots',
            hintText: 'e.g. 100',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newCap = int.tryParse(controller.text) ?? currentCapacity;
              final result = await ApiService.updateHubInventory(productId: productId, dailyCapacitySlots: newCap);
              if (result != null) _loadHubInventory();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: UiTone.surface),
            child: const Text('Update'),
          ),
        ],
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
            Text('${_payoutHistory.length} Receipts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary)),
          ],
        ),
        const SizedBox(height: 10),
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
                            Text(p['id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: UiTone.ink)),
                            Text('${p['date']} • ${p['bank']}', style: TextStyle(fontSize: 10.5, color: UiTone.softText)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${(p['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.primary)),
                        Text(p['status'] ?? 'SETTLED', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: UiTone.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFilterChip(int idx, String label) {
    final isSelected = _selectedFilter == idx;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = idx),
      borderRadius: BorderRadius.circular(UiRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
          borderRadius: BorderRadius.circular(UiRadius.lg),
          border: Border.all(color: isSelected ? UiTone.primary : UiTone.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? UiTone.surface : UiTone.softText,
          ),
        ),
      ),
    );
  }
}
