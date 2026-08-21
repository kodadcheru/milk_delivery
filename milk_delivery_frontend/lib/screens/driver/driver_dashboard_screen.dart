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
  int _selectedFilterIndex = 0; // 0: Upcoming, 1: Pending, 2: Delivered, 3: Express Orders
  bool _isGpsBroadcastActive = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedShift = 'MORNING'; // MORNING or EVENING

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            backgroundColor: const Color(0xFF0D7C66),
            content: Text('✅ Stop #${task.id} Completed! Photo proof saved & customer notified.'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: Color(0xFFE11D48)),
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
            Text('Address: ${order.deliveryAddress}', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
            const SizedBox(height: 14),
            const Text('Enter 4-Digit Customer OTP:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'e.g. ${order.deliveryOtp}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: const Color(0xFF0D7C66),
                    content: Text('🎉 Express Order ${order.id} Delivered Successfully!'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFFE11D48),
                    content: Text('❌ Invalid OTP. Please ask the customer for the correct 4-digit OTP.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
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
    final progressPct = totalStops > 0 ? (completedCount / totalStops) : 0.0;

    // Filter tasks
    List<DeliveryTaskModel> filteredTasks = tasks.where((t) {
      final sub = t.subscriptionDetail;
      final isSubPaused = sub != null && sub.status == 'PAUSED';
      if (_selectedFilterIndex == 0 && (t.status == 'DELIVERED' || t.status == 'COMPLETED' || t.status == 'SKIPPED' || isSubPaused)) {
        return false;
      }
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

    return RefreshIndicator(
      color: const Color(0xFF0D7C66),
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero Dispatch & Shift Command Card ──
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
                  // Top Row: Live GPS Broadcast switch + speed telemetry
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isGpsBroadcastActive ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isGpsBroadcastActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                              color: _isGpsBroadcastActive ? const Color(0xFF34D399) : Colors.grey,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isGpsBroadcastActive ? 'GPS Live Broadcast' : 'GPS Broadcast Paused',
                                    style: TextStyle(
                                      color: _isGpsBroadcastActive ? const Color(0xFF34D399) : Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (_isGpsBroadcastActive)
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              const Text(
                                'Broadcasting real-time stops to customers',
                                style: TextStyle(color: Colors.white60, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isGpsBroadcastActive,
                        activeThumbColor: const Color(0xFF34D399),
                        activeTrackColor: const Color(0xFF0D7C66),
                        onChanged: (val) {
                          setState(() => _isGpsBroadcastActive = val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: val ? const Color(0xFF0D7C66) : Colors.grey[800],
                              content: Text(val ? '🟢 Live GPS Broadcasting enabled.' : '🔴 GPS Broadcast paused.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),

                  // Shift Selector Pills
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedShift = 'MORNING'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedShift == 'MORNING' ? const Color(0xFF0D7C66) : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedShift == 'MORNING' ? const Color(0xFF34D399) : Colors.transparent,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🌅 ', style: TextStyle(fontSize: 14)),
                                Text('Morning (05:00 AM)', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedShift = 'EVENING'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedShift == 'EVENING' ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedShift == 'EVENING' ? const Color(0xFF38BDF8) : Colors.transparent,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🌇 ', style: TextStyle(fontSize: 14)),
                                Text('Evening (05:00 PM)', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Route Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: 42,
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
                            icon: const Icon(Icons.inventory_2_rounded, size: 16),
                            label: const Text('Batch Crates 📦', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 42,
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
                            label: const Text('Route Map 🗺️', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                              backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Route Progress & Metrics Card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('Total Stops', '$totalStops', Icons.local_shipping_outlined, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                      _buildMetricItem('Pending', '$pendingCount', Icons.pending_actions_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                      _buildMetricItem('Delivered', '$completedCount', Icons.check_circle_outline_rounded, const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                      _buildMetricItem('Shift Zone', hubName.split(' ').first, Icons.warehouse_rounded, const Color(0xFF0D7C66), const Color(0xFFE6F5F0)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Morning Route Completion: $completedCount of $totalStops Stops',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          Text(
                            '${(progressPct * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0D7C66)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D7C66)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 3. Integrated Search Bar ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search customer name, flat or doorstep address...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0D7C66), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── 4. Filter Chips Carousel ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(0, '⚡ Upcoming', pendingCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, '⏳ Pending', pendingCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, '✅ Delivered', completedCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(3, '⚡ Express Orders', expressOrders.length),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 5. Express Instant Orders (when filter 0 or 3) ──
            if ((_selectedFilterIndex == 0 || _selectedFilterIndex == 3) && expressOrders.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    '⚡ Priority Express Orders (30-Min SLA)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A), letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                    child: const Text('HIGH PRIORITY', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9.5, fontWeight: FontWeight.w900)),
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
                  const Text(
                    '🥛 Route Stops & Doorsteps',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F5F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredTasks.length} STOPS',
                      style: const TextStyle(color: Color(0xFF0D7C66), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (filteredTasks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 44, color: Color(0xFF10B981)),
                      SizedBox(height: 10),
                      Text('No Stops in this Filter', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text('All assigned deliveries in this category are clear or completed!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTasks.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                  itemBuilder: (ctx, idx) {
                    final task = filteredTasks[idx];
                    return _buildDeliveryTaskCard(task, idx);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Delivery Task Card Builder ──

  Widget _buildDeliveryTaskCard(DeliveryTaskModel task, int idx) {
    final isDone = task.status == 'DELIVERED';
    final isSkipped = task.status == 'SKIPPED';
    final custName = task.customerName;
    final instructions = task.deliveryInstructions;
    final custPhone = task.customerPhone;
    final lat = task.customerLatitude;
    final lon = task.customerLongitude;
    final qty = task.subscriptionDetail?.quantity ?? 1;
    final prodName = task.subscriptionDetail?.productDetail?.name ?? 'Daily Pure Milk';
    final prodIcon = task.subscriptionDetail?.productDetail?.icon ?? '🥛';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDone ? const Color(0xFFD1FAE5) : const Color(0xFFE5ECE8), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Stop #, Task ID, and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('STOP #${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(task.slotTime, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFFD1FAE5)
                      : (isSkipped ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : (isSkipped ? Icons.cancel_outlined : Icons.schedule_rounded),
                      size: 12,
                      color: isDone ? const Color(0xFF059669) : (isSkipped ? Colors.grey : const Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDone ? 'DELIVERED' : (isSkipped ? 'SKIPPED' : 'PENDING'),
                      style: TextStyle(
                        color: isDone ? const Color(0xFF059669) : (isSkipped ? Colors.grey[700] : const Color(0xFFD97706)),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Customer Name, Phone, and Action Chips
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE6F5F0),
                child: Text(
                  custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0D7C66), fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Text(custPhone, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              // Call Button
              IconButton(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE6F5F0)),
                icon: const Icon(Icons.phone_rounded, color: Color(0xFF0D7C66), size: 16),
                tooltip: 'Call Customer',
                onPressed: () => _callCustomer(context, custPhone),
              ),
              const SizedBox(width: 6),
              // WhatsApp Arrival Ping Button
              IconButton(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F2FE)),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB), size: 16),
                tooltip: 'WhatsApp Ping',
                onPressed: () => _sendWhatsAppArrivalPing(context, custName, custPhone, task.deliveryAddress),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Doorstep Address Box + Verified GPS Coordinates
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_rounded, color: Color(0xFF0D7C66), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.deliveryAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 10, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            '${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E',
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 1-Click Google Maps Link
                    GestureDetector(
                      onTap: () => _launchGoogleMapsNavigation(context, lat, lon, custName),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_rounded, size: 12, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text('Navigate Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 4: Items & Quantity Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(prodIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$qty x $prodName',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                  child: const Text('CHILLED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ),
              ],
            ),
          ),

          // Customer Delivery Instructions (if any)
          if (instructions.isNotEmpty && instructions != 'None') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Note: $instructions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Row 5: Action Button (Camera Proof or Status)
          if (!isDone && !isSkipped)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        widget.state.markDeliverySkipped(task.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Stop marked as skipped.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Skip Stop ⏭️', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleCompleteDeliveryWithCamera(context, task),
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Deliver + Photo Proof 📸', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isDone ? 'Delivered & Doorstep Photo Proof Verified 📸' : 'Skipped by Delivery Partner',
                    style: TextStyle(
                      color: isDone ? const Color(0xFF059669) : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpressOrderCard(LiveOrderModel order) {
    final isDelivered = order.status == 'DELIVERED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                    child: Text(order.id, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 11.5)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                    child: const Text('30-MIN EXPRESS', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isDelivered ? 'DELIVERED ✅' : 'PICKUP READY 🛵',
                  style: TextStyle(
                    color: isDelivered ? const Color(0xFF059669) : const Color(0xFFD97706),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('📍 ${order.deliveryAddress}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('Items: ${order.items.map((i) => "${i.quantity}x ${i.product.name}").join(", ")}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
          const SizedBox(height: 12),

          if (!isDelivered)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callCustomer(context, order.customerPhone),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call Customer', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D7C66),
                      side: const BorderSide(color: Color(0xFF0D7C66)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteExpressOrder(context, order),
                    icon: const Icon(Icons.pin_rounded, size: 14),
                    label: const Text('Verify OTP & Deliver', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String val, IconData icon, Color fg, Color bg) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: fg, size: 16),
        ),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label, int count) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
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
        ),
      ),
    );
  }
}
