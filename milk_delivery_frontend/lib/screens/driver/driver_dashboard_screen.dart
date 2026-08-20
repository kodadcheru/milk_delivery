import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../widgets/doorstep_camera_dialog.dart';
import 'driver_route_map_screen.dart';
import 'morning_batch_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  final AppState state;

  const DriverDashboardScreen({super.key, required this.state});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Pending, 2: Delivered, 3: Express Orders
  bool _isGpsBroadcastActive = true;
  String _searchQuery = '';
  String _selectedShift = 'MORNING'; // MORNING or EVENING

  void _callCustomer(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📞 Calling customer ($phone)...')),
        );
      }
    }
  }

  void _sendWhatsAppArrivalPing(BuildContext context, String customerName, String phone, String address) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = Uri.encodeComponent(
      '👋 Hello $customerName! Your fresh MilkDrop morning delivery has been safely placed at your doorstep ($address). Enjoy your farm-fresh milk! 🥛',
    );
    final url = 'https://wa.me/91$cleanPhone?text=$msg';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('💬 WhatsApp ping sent to $customerName!')),
        );
      }
    }
  }

  void _launchGoogleMapsNavigation(BuildContext context, double lat, double lon, String customerName) async {
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving';
    final uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.accentBlue,
            content: Text('🗺️ Launching Google Maps Navigation to $customerName (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📍 Navigating to coordinates: $lat, $lon')),
        );
      }
    }
  }

  void _handleCompleteDeliveryWithCamera(BuildContext context, DeliveryTaskModel task) {
    DoorstepCameraDialog.show(
      context,
      customerName: task.customerName,
      deliveryAddress: task.deliveryAddress,
      latitude: task.customerLatitude,
      longitude: task.customerLongitude,
      onConfirmProof: (proofUrl) {
        widget.state.markDeliveryCompleted(task.id, proofUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('✅ Stop #${task.id} Completed! Photo proof uploaded & customer wallet debited.'),
          ),
        );
      },
    );
  }

  void _handleCompleteExpressOrder(BuildContext context, LiveOrderModel order) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: UiTone.error),
            const SizedBox(width: 8),
            Text('Complete ${order.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName.isNotEmpty ? order.customerName : "Customer"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Address: ${order.deliveryAddress}', style: TextStyle(color: Colors.grey[700], fontSize: 11.5)),
            const SizedBox(height: 14),
            const Text('Enter 4-Digit Customer OTP:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'e.g. ${order.deliveryOtp}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (otpController.text.trim() == order.deliveryOtp) {
                Navigator.pop(ctx);
                widget.state.updateOrderStatus(order.id, 'DELIVERED');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: UiTone.primary,
                    content: Text('🎉 Express Order ${order.id} Delivered Successfully!'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: UiTone.error,
                    content: Text('❌ Invalid OTP. Please ask the customer for the correct 4-digit OTP.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.state.deliveries;
    final expressOrders = widget.state.liveOrders;

    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';

    final completedCount = tasks.where((t) => t.status == 'DELIVERED').length;
    final pendingCount = tasks.where((t) => t.status == 'PENDING').length;
    final totalStops = tasks.length;

    // Filter tasks
    List<DeliveryTaskModel> filteredTasks = tasks.where((t) {
      if (_selectedFilterIndex == 1 && t.status != 'PENDING') return false;
      if (_selectedFilterIndex == 2 && t.status != 'DELIVERED') return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = t.customerName.toLowerCase().contains(query);
        final matchesAddr = t.deliveryAddress.toLowerCase().contains(query);
        return matchesName || matchesAddr;
      }
      return true;
    }).toList();

    final driverUser = widget.state.currentUser;
    final salaryMetricText = (driverUser != null && driverUser.monthlySalary > 0)
        ? '₹${driverUser.monthlySalary.toStringAsFixed(0)}'
        : '₹15,000';

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Live GPS Shift Broadcast & Speed Status ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: UiTone.ink,
              borderRadius: BorderRadius.circular(UiRadius.md),
              boxShadow: UiShadow.card,
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isGpsBroadcastActive ? UiTone.secondary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isGpsBroadcastActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                              color: _isGpsBroadcastActive ? UiTone.secondary : Colors.grey,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _isGpsBroadcastActive ? 'GPS Broadcast ACTIVE' : 'GPS Broadcast PAUSED',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _isGpsBroadcastActive ? UiTone.secondary : Colors.white70,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (_isGpsBroadcastActive)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: UiTone.secondary, shape: BoxShape.circle),
                                      ),
                                  ],
                                ),
                                const Text(
                                  'Broadcasting live coordinates to map',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white60, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isGpsBroadcastActive,
                      activeThumbColor: UiTone.secondary,
                      onChanged: (val) {
                        setState(() => _isGpsBroadcastActive = val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: val ? UiTone.primary : Colors.grey[800],
                            content: Text(val ? '🟢 Live GPS Broadcasting to customers enabled.' : '🔴 GPS Broadcast paused.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed_rounded, color: UiTone.secondary, size: 14),
                        SizedBox(width: 4),
                        Text('32 km/h', style: TextStyle(color: UiTone.surface, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.battery_charging_full_rounded, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Text('84% EV Battery', style: TextStyle(color: UiTone.surface, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer_rounded, color: Colors.cyan, size: 14),
                        SizedBox(width: 4),
                        Text('Shift: 1h 42m', style: TextStyle(color: UiTone.surface, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Shift Selector & Batch Mode Launcher (Hub-Origin Fuel Optimized) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), UiTone.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: UiTone.secondary.withValues(alpha: 0.4), width: 1.5),
              boxShadow: UiShadow.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shift Selector Pills
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedShift = 'MORNING'),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedShift == 'MORNING' ? UiTone.secondary : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(UiRadius.xs),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🌅 ', style: TextStyle(fontSize: 13)),
                              Text('Morning Shift', style: TextStyle(color: UiTone.surface, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedShift = 'EVENING'),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedShift == 'EVENING' ? UiTone.accentBlue : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(UiRadius.xs),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🌇 ', style: TextStyle(fontSize: 13)),
                              Text('Evening Shift', style: TextStyle(color: UiTone.surface, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(_selectedShift == 'MORNING' ? '🥛' : '🌆', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedShift == 'MORNING' ? 'Morning Batch Delivery Mode' : 'Evening Batch Delivery Mode',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                Text(
                                  _selectedShift == 'MORNING' ? '05:00 AM – 08:30 AM Shift • Hub-Origin TSP' : '05:00 PM – 07:00 PM Shift • Hub-Origin TSP',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _selectedShift == 'MORNING' ? UiTone.secondary : const Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: UiTone.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.eco_rounded, color: UiTone.secondary, size: 12),
                          SizedBox(width: 3),
                          Text('SAVE 56% FUEL', style: TextStyle(color: UiTone.secondary, fontSize: 9, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Optimizes route directly from $hubName. Eliminates zig-zag backtracking and saves fuel with rapid doorstep drop mode.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final filterTag = _selectedShift == 'MORNING' ? 'AM' : 'PM';
                            final shiftLabel = _selectedShift == 'MORNING' ? 'Morning Batch' : 'Evening Batch';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => MorningBatchScreen(
                                  state: widget.state,
                                  shiftName: shiftLabel,
                                  slotFilter: filterTag,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                          label: Text(_selectedShift == 'MORNING' ? 'Start Morning 🚀' : 'Start Evening 🚀', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedShift == 'MORNING' ? UiTone.secondary : UiTone.accentBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final filterTag = _selectedShift == 'MORNING' ? 'am' : 'pm';
                            final shiftTasks = widget.state.deliveries.where((t) => t.slotTime.toLowerCase().contains(filterTag)).toList();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => DriverRouteMapScreen(
                                  state: widget.state,
                                  tasks: shiftTasks.isNotEmpty ? shiftTasks : widget.state.deliveries,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map_rounded, size: 16, color: Color(0xFF38BDF8)),
                          label: const Text('Route Map 🗺️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: UiTone.surface)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: UiTone.accentBlue),
                            backgroundColor: UiTone.accentBlue.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 2. Today's Shift Performance & Salary Metrics ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UiTone.primary, UiTone.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(UiRadius.md),
              boxShadow: UiShadow.card,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Total Stops', '$totalStops'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildMetric('Pending', '$pendingCount'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildMetric('Delivered', '$completedCount'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildMetric('Monthly Salary', salaryMetricText),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                  ),
                  child: const Text(
                    '🛡️ Monthly Salaried Partner • Paid by Hub Owner • Free Customer Delivery',
                    style: TextStyle(color: UiTone.surface, fontSize: 10, fontWeight: FontWeight.w700),
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
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.sm),
              border: Border.all(color: UiTone.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search customer name or doorstep address...',
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

          // ── 4. Filter Chips (All / Pending / Delivered / Express) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'All Stops ($totalStops)'),
                const SizedBox(width: 8),
                _buildFilterChip(1, '⏳ Pending ($pendingCount)'),
                const SizedBox(width: 8),
                _buildFilterChip(2, '✅ Delivered ($completedCount)'),
                const SizedBox(width: 8),
                _buildFilterChip(3, '⚡ Express Orders (${expressOrders.length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 5. Express Instant Orders (when filter 0 or 3) ──
          if ((_selectedFilterIndex == 0 || _selectedFilterIndex == 3) && expressOrders.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '⚡ Priority Express Orders (30-Min SLA)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: UiTone.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(UiRadius.xs)),
                  child: const Text('HIGH PRIORITY', style: TextStyle(color: UiTone.error, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...expressOrders.map((order) => _buildExpressOrderCard(order)),
            const SizedBox(height: 16),
          ],

          // ── 6. Daily Subscriptions Route Stops List ──
          if (_selectedFilterIndex != 3) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '🥛 Morning Route Stops (05:30 AM Shift)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UiTone.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: UiTone.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    '${filteredTasks.length} STOPS',
                    style: const TextStyle(color: UiTone.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (filteredTasks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: UiTone.shellBackground,
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(color: UiTone.surfaceBorder),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 40, color: UiTone.secondary),
                    SizedBox(height: 8),
                    Text('No Stops Match Your Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    SizedBox(height: 4),
                    Text('All assigned deliveries in this category are completed or clear!', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTasks.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final task = filteredTasks[idx];
                  return _buildDeliveryTaskCard(task, idx);
                },
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }

  Widget _buildDeliveryTaskCard(DeliveryTaskModel task, int idx) {
    final isDone = task.status == 'DELIVERED';
    final isSkipped = task.status == 'SKIPPED';
    final custName = task.customerName;
    final instructions = task.deliveryInstructions;
    final custPhone = task.customerPhone;
    final lat = task.customerLatitude;
    final lon = task.customerLongitude;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop Index & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: UiTone.ink,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text('STOP #${idx + 1}', style: const TextStyle(color: UiTone.surface, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Task #${task.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDone
                        ? UiTone.secondary.withValues(alpha: 0.15)
                        : (isSkipped ? Colors.grey.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    isDone ? 'DELIVERED ✅' : (isSkipped ? 'SKIPPED ❌' : 'PENDING ⏰'),
                    style: TextStyle(
                      color: isDone ? UiTone.primary : (isSkipped ? Colors.grey[800] : Colors.amber[900]),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer Name & Contact Actions (Call + WhatsApp)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: UiTone.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: UiTone.primary, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        custName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: UiTone.ink),
                      ),
                      Text(
                        custPhone,
                        style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _callCustomer(context, custPhone),
                  icon: const Icon(Icons.phone_rounded, size: 12),
                  label: const Text('Call', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    foregroundColor: UiTone.primary,
                    side: const BorderSide(color: UiTone.primary),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _sendWhatsAppArrivalPing(context, custName, custPhone, task.deliveryAddress),
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: UiTone.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                      border: Border.all(color: UiTone.secondary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: UiTone.primary, size: 13),
                        SizedBox(width: 3),
                        Text('Ping', style: TextStyle(color: UiTone.primary, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Doorstep Address & GPS Pin Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UiTone.shellBackground,
                borderRadius: BorderRadius.circular(UiRadius.sm),
                border: Border.all(color: UiTone.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_rounded, color: UiTone.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.deliveryAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: UiTone.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, size: 10, color: UiTone.accentBlue),
                            const SizedBox(width: 4),
                            Text(
                              '${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E',
                              style: const TextStyle(color: UiTone.accentBlue, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Doorstep Verified Pin', style: TextStyle(fontSize: 9.5, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 1-Click Google Maps Navigation Button
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _launchGoogleMapsNavigation(context, lat, lon, custName),
                icon: const Icon(Icons.navigation_rounded, size: 15, color: UiTone.surface),
                label: const Text(
                  '1-Click Google Maps Navigation 🗺️',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.accentBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Product Item Detail Strip
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UiTone.surfaceMuted,
                borderRadius: BorderRadius.circular(UiRadius.xs),
              ),
              child: Row(
                children: [
                  Text(task.subscriptionDetail?.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${task.subscriptionDetail?.quantity ?? 1}x ${task.subscriptionDetail?.productDetail?.name ?? "Daily Milk Pouch"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Text(
                    task.slotTime,
                    style: TextStyle(color: Colors.grey[700], fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Doorstep Instruction Note
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Note: $instructions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10.5, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Mark Delivered + Photo Proof Action
            if (!isDone && !isSkipped)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.state.markDeliverySkipped(task.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Stop marked as skipped.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UiTone.error,
                        side: const BorderSide(color: UiTone.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                      child: const Text('Skip / Absent', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleCompleteDeliveryWithCamera(context, task),
                      icon: const Icon(Icons.camera_alt_rounded, size: 15),
                      label: const Text('Mark Delivered + Proof', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: UiTone.secondary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isDone ? 'Delivered & Photo Proof Verified 📸' : 'Skipped by Partner',
                    style: TextStyle(
                      color: isDone ? UiTone.primary : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpressOrderCard(LiveOrderModel order) {
    final isDelivered = order.status == 'DELIVERED';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Text(order.id, style: const TextStyle(color: UiTone.accentBlue, fontWeight: FontWeight.w900, fontSize: 11.5)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered ? UiTone.secondary.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    isDelivered ? 'DELIVERED ✅' : 'PICKUP READY 🛵',
                    style: TextStyle(
                      color: isDelivered ? UiTone.primary : Colors.amber[900],
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text('📍 ${order.deliveryAddress}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Items: ${order.items.map((i) => "${i.quantity}x ${i.product.name}").join(", ")}', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
            const SizedBox(height: 10),

            if (!isDelivered)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callCustomer(context, order.customerPhone),
                      icon: const Icon(Icons.phone, size: 14),
                      label: const Text('Call Customer', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UiTone.primary,
                        side: const BorderSide(color: UiTone.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleCompleteExpressOrder(context, order),
                      icon: const Icon(Icons.pin_rounded, size: 14),
                      label: const Text('Verify OTP & Deliver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: UiTone.surface, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(UiRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
          borderRadius: BorderRadius.circular(UiRadius.lg),
          border: Border.all(
            color: isSelected ? UiTone.primary : const Color(0xFFCBD5E1),
          ),
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
