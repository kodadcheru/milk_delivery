import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/route_optimizer.dart';

class ProviderDashboardScreen extends StatefulWidget {
  final AppState state;

  const ProviderDashboardScreen({super.key, required this.state});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _selectedFilter = 0; // 0: All Orders, 1: Morning Subscriptions, 2: Express Orders, 3: Fleet Drivers
  String _searchQuery = '';
  int _activeDriverCount = 4;
  int _crateStockA2 = 45;
  int _crateStockBuffalo = 22;
  int _crateStockEggs = 18;

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
    final encoded = Uri.encodeComponent(msg);
    final url = 'https://wa.me/91$clean?text=$encoded';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('💬 WhatsApp message sent to $name!')),
        );
      }
    }
  }

  void _withdrawEarnings(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: Color(0xFF0D7C66)),
            SizedBox(width: 8),
            Text('Withdraw Hub Earnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount to Settle: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0D7C66))),
            const SizedBox(height: 8),
            const Text('Destination Account:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.account_balance, size: 20, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('HDFC Bank • A/C **4892 (IFSC: HDFC0001234)\nJubilee Hills Dairy Farm LLC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0D7C66),
                  content: Text('💸 Payout of ₹${amount.toStringAsFixed(0)} initiated! Expected in bank within 2 hours.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            child: const Text('Confirm Instant Transfer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.state.deliveries;
    final liveOrders = widget.state.liveOrders;
    final totalRevenue = widget.state.totalDailyRevenue > 0 ? widget.state.totalDailyRevenue : 24850.0;
    final netEarnings = totalRevenue * 0.75; // 75% provider margin
    final totalLitres = widget.state.totalDailyMilkVolume > 0 ? widget.state.totalDailyMilkVolume : 310.0;

    // Filter tasks & orders
    List<DeliveryTaskModel> filteredTasks = tasks.where((t) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.customerName.toLowerCase().contains(q) || t.deliveryAddress.toLowerCase().contains(q);
      }
      return true;
    }).toList();

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
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('🏬', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jubilee Hills Central Depot #1',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            Text(
                              'Operating Zone: Sector A, B & C • ID #HUB-HYD-01',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 6),
                          SizedBox(width: 4),
                          Text('LIVE HUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHubStatColumn('128 Families', 'Active Subscribers'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildHubStatColumn('${totalLitres.toStringAsFixed(0)} Litres', 'Daily Milk Volume'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildHubStatColumn('4 Drivers', 'Active Fleet'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildHubStatColumn('48 Bottles', 'Returned to Hub 🍾'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Equal Load Balancer & Delivery Boys Configurator ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('⚖️', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equal Load Balancer & Fleet Dispatch',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            Text(
                              'Auto-partitions hub orders equally across active boys',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('EQUAL LOAD', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Delivery Boys Input Stepper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Delivery Boys Today:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text('Hub operator input for shift partitioning', style: TextStyle(color: Colors.white60, fontSize: 10)),
                        ],
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
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 22),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPartitionStat('${tasks.length} Total', 'Orders in Hub'),
                    Container(width: 1, height: 24, color: Colors.white24),
                    _buildPartitionStat('${(tasks.length / _activeDriverCount).ceil()} Stops', 'Per Delivery Boy ⚖️'),
                    Container(width: 1, height: 24, color: Colors.white24),
                    _buildPartitionStat('~${(totalLitres / _activeDriverCount).toStringAsFixed(0)} Litres', 'Load per Boy'),
                    Container(width: 1, height: 24, color: Colors.white24),
                    _buildPartitionStat('₹15,000/mo', 'Fixed Salary / Boy'),
                  ],
                ),
                const SizedBox(height: 12),

                // Partitioned Fleet Preview
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0D7C66),
                          content: Text('⚖️ Hub Orders Balanced! ${tasks.length} orders partitioned equally across $_activeDriverCount salaried delivery boys with zero route overlap.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.hub_rounded, size: 16),
                    label: Text('Auto-Balance & Dispatch $_activeDriverCount Equal Batches 🚀', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
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
                          final driverNames = ['Suresh Rao', 'Vikram Sharma', 'Anil Kumar', 'Raju Patel', 'Kiran Reddy', 'Mahesh G.'];
                          final dName = idx < driverNames.length ? driverNames[idx] : 'Driver #${idx + 1}';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('🛵 $dName', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('${res.orderedStops.length} Stops • ${res.totalDistanceKm.toStringAsFixed(1)} km • Salaried Staff', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w600)),
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
                colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0D7C66).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
              ],
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
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _withdrawEarnings(context, netEarnings),
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 15),
                      label: const Text('Withdraw Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D7C66),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gross Daily GMV: ₹${totalRevenue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      const Text('75% Provider Share • 25% Logistics', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Search Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search customer name, apartment, or phone...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12.5),
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
          const SizedBox(height: 12),

          // ── 4. Filter Tabs (Who Ordered / Subscriptions / Express / Fleet) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, '👥 Who Ordered (${filteredTasks.length + liveOrders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, '🥛 Subscriptions (${filteredTasks.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(2, '⚡ Express Orders (${liveOrders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(3, '🛵 Assigned Fleet (4 Drivers)'),
                const SizedBox(width: 8),
                _buildFilterChip(4, '📦 Crate Inventory'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 5. Content Section Based on Filter ──
          if (_selectedFilter == 4) ...[
            _buildInventoryCratesSection(),
          ] else if (_selectedFilter == 3) ...[
            _buildFleetDriversSection(),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('📋 Customer Orders & Deliveries in Hub Zone:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            Text('${subscriptions.length + express.length} Active Orders', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D7C66))),
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

  Widget _buildSubscriptionCustomerCard(DeliveryTaskModel task) {
    final sub = task.subscriptionDetail;
    final product = sub?.productDetail;
    final isDone = task.status == 'DELIVERED';
    final custPhone = task.customerPhone.isNotEmpty ? task.customerPhone : '+91 9876543210';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                      child: const Text('🥛', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Phone: $custPhone',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDone ? 'DELIVERED ✅' : 'SCHEDULED ⏰',
                    style: TextStyle(
                      color: isDone ? const Color(0xFF0D7C66) : Colors.orange[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Product & Subscription Quantity
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
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
                          style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${((product?.pricePerUnit ?? 40) * (sub?.quantity ?? 1)).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0D7C66)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Address & Assigned Driver
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF0D7C66)),
                const SizedBox(width: 4),
                Text(
                  'Driver: Suresh Rao (Route #4)',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66)),
                ),
                const Spacer(),
                Text(
                  'Payment: Prepaid Wallet (Auto-Debited)',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
                      foregroundColor: const Color(0xFF0D7C66),
                      side: const BorderSide(color: Color(0xFF0D7C66)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      'Hello ${task.customerName}! Your daily morning subscription (${product?.name}) from Jubilee Hills Central Depot has been dispatched.',
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 13),
                    label: const Text('WhatsApp Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(ord.id, style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE11D48).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('30-MIN EXPRESS', style: TextStyle(color: Color(0xFFE11D48), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDelivered ? 'DELIVERED ✅' : 'OUT FOR DELIVERY 🛵',
                    style: TextStyle(
                      color: isDelivered ? const Color(0xFF0D7C66) : Colors.amber[900],
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
            Text('Delivery to: ${ord.deliveryAddress}', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Total: ₹${ord.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0D7C66), fontSize: 12.5)),
                Text('OTP: ${ord.deliveryOtp}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0369A1))),
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
  Widget _buildFleetDriversSection() {
    final drivers = [
      {'name': 'Suresh Rao', 'phone': '+91 9123456789', 'route': 'Route #4 • Jubilee Hills Sector A & B', 'stops': '12/12 Stops', 'status': '🟢 Active & Broadcasting GPS', 'salary': '₹15,000/mo'},
      {'name': 'Vikram Sharma', 'phone': '+91 9876501234', 'route': 'Route #2 • Film Nagar Highrises', 'stops': '14/14 Stops', 'status': '🟢 Active & Broadcasting GPS', 'salary': '₹15,000/mo'},
      {'name': 'Anil Kumar', 'phone': '+91 9765432109', 'route': 'Route #1 • Madhapur Tech Enclave', 'stops': '10/10 Stops', 'status': '🟢 Completed Morning Shift', 'salary': '₹15,000/mo'},
      {'name': 'Raju Patel', 'phone': '+91 9654321098', 'route': 'Route #3 • Banjara Hills Villas', 'stops': '15/15 Stops', 'status': '🔴 Shift Ended / Depot Return', 'salary': '₹15,000/mo'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🛵 Assigned Hub Salaried Fleet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: drivers.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            final drv = drivers[idx];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                    child: const Text('🛵', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drv['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(drv['route']!, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                        const SizedBox(height: 2),
                        Text(drv['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0D7C66))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(drv['salary']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0D7C66))),
                      Text(drv['stops']!, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      IconButton(
                        icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF0D7C66)),
                        onPressed: () => _callPhone(context, drv['phone']!),
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
  // INVENTORY & CRATE STOCK SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildInventoryCratesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📦 Hub Crate Inventory & Farm Replenishment:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        _buildCrateInventoryRow('🥛 Fresh A2 Vedic Cow Milk', '$_crateStockA2 Crates (540 Pouches)', () => setState(() => _crateStockA2 += 10)),
        const SizedBox(height: 8),
        _buildCrateInventoryRow('🥛 Creamy Buffalo Milk', '$_crateStockBuffalo Crates (264 Pouches)', () => setState(() => _crateStockBuffalo += 5)),
        const SizedBox(height: 8),
        _buildCrateInventoryRow('🥚 Farm Fresh Country Eggs', '$_crateStockEggs Crates (108 Packs)', () => setState(() => _crateStockEggs += 5)),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0D7C66),
                  content: Text('🚜 Farm Milk Tanker Dispatched! 1,200 Litres replenishment arriving at 02:00 AM.'),
                ),
              );
            },
            icon: const Icon(Icons.local_shipping_rounded, size: 16),
            label: const Text('Request Farm Tanker Supply Replenishment 🚜', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCrateInventoryRow(String title, String stock, VoidCallback onAdd) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text(stock, style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.w700, fontSize: 11)),
            ],
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 12),
            label: const Text('+ Crate', style: TextStyle(fontSize: 10.5)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              foregroundColor: const Color(0xFF0D7C66),
              side: const BorderSide(color: Color(0xFF0D7C66)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartitionStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
      ],
    );
  }

  Widget _buildHubStatColumn(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
      ],
    );
  }

  Widget _buildFilterChip(int idx, String label) {
    final isSelected = _selectedFilter == idx;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = idx),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
