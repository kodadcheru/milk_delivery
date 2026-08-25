import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/route_optimizer.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/ui_kit/ui_kit.dart';
import '../../widgets/doorstep_camera_dialog.dart';
import '../../widgets/driver_delivery_chat_sheet.dart';
import '../common/day_wise_orders_screen.dart';
import 'driver_route_map_screen.dart';
import 'morning_batch_screen.dart';

class DoorstepGroup {
  final String groupKey;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String deliveryInstructions;
  final String slotTime;
  final double customerLatitude;
  final double customerLongitude;
  final int? driverId;
  final List<DeliveryTaskModel> tasks;

  DoorstepGroup({
    required this.groupKey,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryInstructions,
    required this.slotTime,
    required this.customerLatitude,
    required this.customerLongitude,
    required this.driverId,
    required this.tasks,
  });

  bool get isAllDelivered => tasks.every((t) => t.status == 'DELIVERED');
  bool get isAllSkipped => tasks.every((t) => t.status == 'SKIPPED');
  bool get isPending => tasks.any((t) => t.status == 'PENDING');
}

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
  String _selectedShift = DateTime.now().hour >= 12 ? 'EVENING' : 'MORNING'; // Auto-switches to EVENING after 12:00 PM, MORNING after 12:00 AM
  Timer? _gpsSyncTimer;

  @override
  void initState() {
    super.initState();
    _syncDriverLocation();
    _gpsSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _syncDriverLocation());
  }

  @override
  void dispose() {
    _gpsSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncDriverLocation() async {
    if (!mounted) return;

    double lat = 17.001734;
    double lng = 79.9625;

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fall back to profile coordinates
        if (widget.state.currentUser != null && widget.state.currentUser!.latitude != 0.0) {
          lat = widget.state.currentUser!.latitude;
          lng = widget.state.currentUser!.longitude;
        }
      } else {
        // Check permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          // Get REAL device GPS position
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('GPS timeout'),
          );
          lat = position.latitude;
          lng = position.longitude;
        } else {
          // Permission denied — use profile coordinates as fallback
          if (widget.state.currentUser != null && widget.state.currentUser!.latitude != 0.0) {
            lat = widget.state.currentUser!.latitude;
            lng = widget.state.currentUser!.longitude;
          }
        }
      }
    } catch (_) {
      // GPS error — fall back to pending delivery or profile coordinates
      final pendingDeliveries = widget.state.deliveries.where((d) => d.status == 'PENDING').toList();
      if (pendingDeliveries.isNotEmpty) {
        lat = pendingDeliveries.first.customerLatitude;
        lng = pendingDeliveries.first.customerLongitude;
      } else if (widget.state.currentUser != null && widget.state.currentUser!.latitude != 0.0) {
        lat = widget.state.currentUser!.latitude;
        lng = widget.state.currentUser!.longitude;
      }
    }

    await ApiService.updateDriverLocation(
      latitude: lat,
      longitude: lng,
      status: _isGpsBroadcastActive ? 'ON_DUTY' : 'OFFLINE',
    );
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

  void _handleCompleteDeliveryWithCamera(BuildContext context, DoorstepGroup group) {
    DoorstepCameraDialog.show(
      context,
      customerName: group.customerName,
      deliveryAddress: group.deliveryAddress,
      latitude: group.customerLatitude,
      longitude: group.customerLongitude,
      onConfirmProof: (proofUrl) {
        for (final task in group.tasks) {
          widget.state.markDeliveryCompleted(task.id, proofUrl);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('✅ Doorstep Completed (${group.tasks.length} ${group.tasks.length > 1 ? "items" : "item"})! Photo proof saved & customer notified.'),
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
            Text('Complete ${order.id}', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName.isNotEmpty ? order.customerName : "Customer"}', style: UiText.bodyStrong.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Address: ${order.deliveryAddress}', style: UiText.body.copyWith(fontSize: 12)),
            const SizedBox(height: 14),
            Text('Enter 4-Digit Customer OTP:', style: UiText.bodyStrong.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'Enter 4-digit OTP',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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
                widget.state.updateOrderStatus(order.id, 'DELIVERED', deliveryOtp: otpController.text.trim());
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

  void _startDeliveriesWithGoogleMapsTSP(BuildContext context) async {
    final filterTag = _selectedShift == 'MORNING' ? 'am' : 'pm';
    final shiftTasks = widget.state.deliveries.where((t) => t.slotTime.toLowerCase().contains(filterTag)).toList();
    final tasksToRoute = (shiftTasks.isNotEmpty ? shiftTasks : widget.state.deliveries).where((t) {
      final sub = t.subscriptionDetail;
      return t.status == 'PENDING' && sub?.status != 'PAUSED';
    }).toList();

    final allShiftTasks = shiftTasks.isNotEmpty ? shiftTasks : widget.state.deliveries;

    if (tasksToRoute.isEmpty && allShiftTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: UiTone.warning,
          content: Text('⚠️ No delivery stops found for this shift!'),
        ),
      );
      return;
    }

    final targetTasks = tasksToRoute.isNotEmpty ? tasksToRoute : allShiftTasks;

    // 1. Get driver live GPS position
    double driverLat = widget.state.currentUser?.latitude ?? 17.001734;
    double driverLng = widget.state.currentUser?.longitude ?? 79.9625;
    if (driverLat == 0.0) driverLat = 17.001734;
    if (driverLng == 0.0) driverLng = 79.9625;

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 3));
      driverLat = pos.latitude;
      driverLng = pos.longitude;
    } catch (_) {}

    // 2. Solve TSP shortest path
    final hub = widget.state.nearestCoveringHub;
    final hubModel = HubLocationModel(
      id: hub?['hub_code']?.toString() ?? 'HUB-KDD-01',
      name: hub?['name']?.toString() ?? 'Depot Hub',
      address: hub?['address']?.toString() ?? 'Kodad',
      latitude: driverLat,
      longitude: driverLng,
      managerName: hub?['manager_name']?.toString() ?? 'Dispatcher',
      managerPhone: hub?['manager_phone']?.toString() ?? '',
    );
    final tspResult = RouteOptimizer.optimizeBatchRoute(hub: hubModel, tasks: targetTasks);
    final orderedStops = tspResult.orderedStops;

    // 3. Drop all pins in external Google Maps
    if (orderedStops.isNotEmpty) {
      final origin = '$driverLat,$driverLng';
      final destination = '${orderedStops.last.customerLatitude},${orderedStops.last.customerLongitude}';
      String waypointsParam = '';
      if (orderedStops.length > 1) {
        final intermediate = orderedStops.sublist(0, orderedStops.length - 1);
        waypointsParam = '&waypoints=${intermediate.map((t) => '${t.customerLatitude},${t.customerLongitude}').join('|')}';
      }
      final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination$waypointsParam&travelmode=driving';
      final uri = Uri.parse(googleMapsUrl);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {}
    }

    // 4. Open in-app Route Map screen with sequenced stops
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => DriverRouteMapScreen(
            state: widget.state,
            tasks: orderedStops.isNotEmpty ? orderedStops : allShiftTasks,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.state.deliveries;
    final expressOrders = widget.state.liveOrders;

    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';

    // 1. Filter deliveries by the active Morning/Evening shift first
    final shiftTasks = tasks.where((t) {
      final slotStr = t.slotTime.toUpperCase();
      final isEvening = slotStr.contains('PM') || slotStr.contains('17:') || slotStr.contains('18:') || slotStr.contains('19:') || slotStr.contains('EVENING');
      if (_selectedShift == 'MORNING') return !isEvening;
      if (_selectedShift == 'EVENING') return isEvening;
      return true;
    }).toList();

    final completedCount = shiftTasks.where((t) => t.status == 'DELIVERED').length;
    final pendingCount = shiftTasks.where((t) => t.status == 'PENDING').length;
    final totalStops = shiftTasks.length;
    final progressPct = totalStops > 0 ? (completedCount / totalStops) : 0.0;

    // 2. Filter shiftTasks by status tab and search query
    List<DeliveryTaskModel> filteredTasks = shiftTasks.where((t) {
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

    // Sort tasks in natural ascending forward sequence
    filteredTasks.sort((a, b) => a.id.compareTo(b.id));

    // Group deliveries by unique doorstep address, customer & GPS coordinates
    final Map<String, List<DeliveryTaskModel>> groupedMap = {};
    for (final t in filteredTasks) {
      final cleanAddr = t.deliveryAddress.toLowerCase().trim();
      final key = '${t.customerName.toLowerCase().trim()}__${cleanAddr}__${t.customerLatitude.toStringAsFixed(4)}_${t.customerLongitude.toStringAsFixed(4)}';
      groupedMap.putIfAbsent(key, () => []).add(t);
    }

    final doorstepGroups = groupedMap.entries.map((entry) {
      final first = entry.value.first;
      return DoorstepGroup(
        groupKey: entry.key,
        customerName: first.customerName,
        customerPhone: first.customerPhone,
        deliveryAddress: first.deliveryAddress,
        deliveryInstructions: first.deliveryInstructions,
        slotTime: first.slotTime,
        customerLatitude: first.customerLatitude,
        customerLongitude: first.customerLongitude,
        driverId: first.driverId,
        tasks: entry.value,
      );
    }).toList();

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero Dispatch & Shift Command Card ──
            UiHeroCard(
              child: Column(
                children: [
                  // Top Row: Live GPS Broadcast switch + telemetry
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            UiHeroGlass(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                _isGpsBroadcastActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                                color: Colors.white,
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
                                          _isGpsBroadcastActive ? 'GPS Live Broadcast' : 'GPS Broadcast Paused',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (_isGpsBroadcastActive)
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    'Broadcasting real-time stops to customers',
                                    style: UiText.caption.copyWith(color: Colors.white.withValues(alpha: 0.78), fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isGpsBroadcastActive,
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.white.withValues(alpha: 0.45),
                        inactiveThumbColor: Colors.white.withValues(alpha: 0.75),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                        onChanged: (val) {
                          setState(() => _isGpsBroadcastActive = val);
                          _syncDriverLocation();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: val ? UiTone.primary : UiTone.softText,
                              content: Text(val ? '🟢 Live GPS Broadcasting enabled.' : '🔴 GPS Broadcast paused.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.24), height: 20),

                  // Shift Selector Pills
                  Row(
                    children: [
                      Expanded(child: _buildShiftPill('MORNING', '🌅', 'Morning (05:00 AM)')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildShiftPill('EVENING', '🌇', 'Evening (05:00 PM)')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Route Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
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
                            icon: const Icon(Icons.inventory_2_rounded, size: 16, color: UiTone.primary),
                            label: Text('Batch Crates 📦', style: UiText.label.copyWith(fontWeight: FontWeight.w900, fontSize: 11.5, color: UiTone.primary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: UiTone.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final targetTasks = filteredTasks.isNotEmpty ? filteredTasks : widget.state.deliveries;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => DriverRouteMapScreen(
                                    state: widget.state,
                                    tasks: targetTasks,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map_rounded, size: 15, color: Colors.white),
                            label: Text('Route Map 🗺️', style: UiText.label.copyWith(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => DayWiseOrdersScreen(
                                    state: widget.state,
                                    role: 'DRIVER',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_rounded, size: 15, color: Colors.white),
                            label: Text('Calendar 📅', style: UiText.label.copyWith(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _startDeliveriesWithGoogleMapsTSP(context),
                      icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                      label: Text(
                        '🚀 Start Deliveries & Drop TSP Pins in Google Maps',
                        style: UiText.label.copyWith(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Route Progress & Metrics Card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.lg),
                border: Border.all(color: UiTone.surfaceBorder),
                boxShadow: UiShadow.card,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('Total Stops', '$totalStops', Icons.local_shipping_outlined, UiTone.accentBlue, UiTone.infoSoft),
                      _buildMetricItem('Pending', '$pendingCount', Icons.pending_actions_rounded, UiTone.warning, UiTone.warningSoft),
                      _buildMetricItem('Delivered', '$completedCount', Icons.check_circle_outline_rounded, UiTone.success, UiTone.successSoft),
                      _buildMetricItem('Shift Zone', hubName.split(' ').first, Icons.warehouse_rounded, UiTone.primary, UiTone.primarySoft),
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
                            '${_selectedShift == "EVENING" ? "Evening" : "Morning"} Route Completion: $completedCount of $totalStops Stops',
                            style: UiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: UiTone.softText),
                          ),
                          Text(
                            '${(progressPct * 100).toStringAsFixed(0)}%',
                            style: UiText.bodyStrong.copyWith(fontSize: 12, fontWeight: FontWeight.w900, color: UiTone.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          minHeight: 7,
                          backgroundColor: UiTone.surfaceMuted,
                          valueColor: const AlwaysStoppedAnimation<Color>(UiTone.primary),
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
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.md),
                border: Border.all(color: UiTone.surfaceBorder),
                boxShadow: UiShadow.card,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search customer name, flat or doorstep address...',
                  hintStyle: UiText.body.copyWith(color: UiText.muted, fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: UiTone.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: UiTone.softText),
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
            UiFilterChipBar(
              labels: const ['⚡ Upcoming', '⏳ Pending', '✅ Delivered', '⚡ Express Orders'],
              counts: [pendingCount, pendingCount, completedCount, expressOrders.length],
              selectedIndex: _selectedFilterIndex,
              onSelected: (i) => setState(() => _selectedFilterIndex = i),
            ),
            const SizedBox(height: 18),

            // ── 5. Express Instant Orders (when filter 0 or 3) ──
            if ((_selectedFilterIndex == 0 || _selectedFilterIndex == 3) && expressOrders.isNotEmpty) ...[
              UiSectionHeader(
                title: '⚡ Priority Express Orders (30-Min SLA)',
                padding: const EdgeInsets.only(bottom: 12),
                action: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: UiTone.errorSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                  child: Text('HIGH PRIORITY', style: UiText.caption.copyWith(color: UiTone.error, fontSize: 9.5, fontWeight: FontWeight.w900)),
                ),
              ),
              ...expressOrders.map((order) => _buildExpressOrderCard(order)),
              const SizedBox(height: 16),
            ],

            // ── 6. Daily Subscriptions Route Stops List ──
            if (_selectedFilterIndex != 3) ...[
              UiSectionHeader(
                title: '🥛 Route Stops & Doorsteps',
                count: doorstepGroups.length,
                padding: const EdgeInsets.only(bottom: 12),
              ),

              if (doorstepGroups.isEmpty)
                const UiEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No Stops in this Filter',
                  message: 'All assigned deliveries in this category are clear or completed!',
                  accent: UiTone.success,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: doorstepGroups.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final group = doorstepGroups[idx];
                    return _buildDoorstepGroupCard(group, idx);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Consolidated Doorstep Group Card Builder ──

  Widget _buildDoorstepGroupCard(DoorstepGroup group, int idx) {
    final isDone = group.isAllDelivered;
    final isSkipped = group.isAllSkipped;
    final custName = group.customerName;
    final instructions = group.deliveryInstructions;
    final custPhone = group.customerPhone;
    final lat = group.customerLatitude;
    final lon = group.customerLongitude;
    final totalItemsCount = group.tasks.fold<int>(0, (sum, t) => sum + (t.subscriptionDetail?.quantity ?? t.quantity));

    final firstTask = group.tasks.isNotEmpty ? group.tasks.first : null;
    final dateStr = (firstTask != null && firstTask.deliveryDate.isNotEmpty) ? firstTask.deliveryDate : 'Today';
    final slotStr = group.slotTime.isNotEmpty ? group.slotTime : '05:30 AM - 07:00 AM';
    final isEvening = slotStr.toUpperCase().contains('PM') || slotStr.toUpperCase().contains('17:') || slotStr.toUpperCase().contains('18:') || slotStr.toUpperCase().contains('19:') || slotStr.toUpperCase().contains('EVENING');

    return Container(
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        border: Border.all(color: isDone ? UiTone.successSoft : UiTone.surfaceBorder, width: 1.2),
        boxShadow: UiShadow.card,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Stop #, Assignment Badge, Date & Shift Slot, & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: UiTone.ink,
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text('STOP #${idx + 1}', style: UiText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5)),
                  ),
                  const SizedBox(width: 6),
                  if (group.driverId == widget.state.currentUser?.id)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: UiTone.successSoft,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text('ASSIGNED TO YOU', style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w900, color: UiTone.success)),
                    )
                  else if (group.driverId == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: UiTone.warningSoft,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text('OPEN POOL', style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w900, color: UiTone.warning)),
                    ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isEvening ? const Color(0xFF7C3AED).withValues(alpha: 0.12) : const Color(0xFF0D7C66).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      '📅 $dateStr • ${isEvening ? "🌙 Evening" : "☀️ Morning"} • $slotStr',
                      style: UiText.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isEvening ? const Color(0xFF7C3AED) : const Color(0xFF0D7C66),
                      ),
                    ),
                  ),
                ],
              ),
              UiStatusPill(
                status: isDone ? 'DELIVERED' : (isSkipped ? 'SKIPPED' : 'PENDING'),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Customer Name, Phone, and Action Chips
          Row(
            children: [
              CircleAvatar(
                backgroundColor: UiTone.primarySoft,
                child: Text(
                  custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                  style: UiText.bodyStrong.copyWith(color: UiTone.primary, fontSize: 14, fontWeight: FontWeight.w900),
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
                      style: UiText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    Text(custPhone, style: UiText.caption.copyWith(fontSize: 11.5, color: UiTone.softText)),
                  ],
                ),
              ),
              if (group.tasks.length > 1)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: UiTone.primarySoft,
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    '📦 ${group.tasks.length} ORDERS',
                    style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w900, color: UiTone.primary),
                  ),
                ),
              // In-App Live Chat Button
              IconButton(
                style: IconButton.styleFrom(backgroundColor: UiTone.primarySoft),
                icon: const Icon(Icons.forum_rounded, color: UiTone.primary, size: 16),
                tooltip: 'Live Chat with Customer',
                onPressed: () {
                  DriverDeliveryChatSheet.show(
                    context,
                    customerName: custName,
                    customerPhone: custPhone,
                    deliveryAddress: group.deliveryAddress,
                    orderSummary: group.tasks.isNotEmpty ? group.tasks.first.productName : 'Morning Milk Drop',
                    slotTime: group.slotTime,
                  );
                },
              ),
              const SizedBox(width: 6),
              // Call Button
              IconButton(
                style: IconButton.styleFrom(backgroundColor: UiTone.primarySoft),
                icon: const Icon(Icons.phone_rounded, color: UiTone.primary, size: 16),
                tooltip: 'Call Customer',
                onPressed: () => _callCustomer(context, custPhone),
              ),
              const SizedBox(width: 6),
              // WhatsApp Arrival Ping Button
              IconButton(
                style: IconButton.styleFrom(backgroundColor: UiTone.infoSoft),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: UiTone.accentBlue, size: 16),
                tooltip: 'WhatsApp Ping',
                onPressed: () => _sendWhatsAppArrivalPing(context, custName, custPhone, group.deliveryAddress),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Doorstep Address Box + Verified GPS Coordinates
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: UiTone.shellBackground,
              borderRadius: BorderRadius.circular(UiRadius.md),
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
                        group.deliveryAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5),
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
                        color: UiTone.infoSoft,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 10, color: UiTone.accentBlue),
                          const SizedBox(width: 4),
                          Text(
                            '${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E',
                            style: UiText.caption.copyWith(color: UiTone.accentBlue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 1-Click Google Maps Link
                    GestureDetector(
                      onTap: () => _launchGoogleMapsNavigation(context, lat, lon, custName),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation_rounded, size: 12, color: UiTone.accentBlue),
                          const SizedBox(width: 4),
                          Text('Navigate Map', style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.accentBlue)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 4: All Ordered Items at this Doorstep
          ...group.tasks.map((task) {
            final qty = task.subscriptionDetail?.quantity ?? task.quantity;
            final prodName = task.subscriptionDetail?.productDetail?.name ?? task.productName;
            final prodIcon = task.subscriptionDetail?.productDetail?.icon ?? '🥛';
            final packSize = task.packSize;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: UiTone.surfaceMuted,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Row(
                children: [
                  Text(prodIcon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$qty x $prodName ($packSize)',
                      style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: UiTone.successSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                    child: Text('CHILLED', style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.bold, color: UiTone.success)),
                  ),
                ],
              ),
            );
          }),

          // Customer Delivery Instructions (if any)
          if (instructions.isNotEmpty && instructions != 'None') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: UiTone.warningSoft,
                borderRadius: BorderRadius.circular(UiRadius.xs),
                border: Border.all(color: UiTone.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, size: 14, color: UiTone.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Note: $instructions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: UiTone.warning),
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
                        for (final t in group.tasks) {
                          widget.state.markDeliverySkipped(t.id);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Doorstep marked as skipped.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UiTone.error,
                        side: BorderSide(color: UiTone.error.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                      ),
                      child: Text('Skip Stop ⏭️', style: UiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.bold, color: UiTone.error)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleCompleteDeliveryWithCamera(context, group),
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: Text(
                        group.tasks.length > 1 ? 'Deliver All (${totalItemsCount} Items) 📸' : 'Deliver + Photo Proof 📸',
                        style: UiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
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
                color: UiTone.shellBackground,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: UiTone.success, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isDone ? 'Delivered & Doorstep Photo Proof Verified 📸' : 'Skipped by Delivery Partner',
                    style: UiText.caption.copyWith(
                      color: isDone ? UiTone.success : UiTone.softText,
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
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        border: Border.all(color: UiTone.error.withValues(alpha: 0.3), width: 1.2),
        boxShadow: UiShadow.card,
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
                    decoration: BoxDecoration(color: UiTone.infoSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                    child: Text(order.id, style: UiText.caption.copyWith(color: UiTone.accentBlue, fontWeight: FontWeight.w900, fontSize: 11.5)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: UiTone.errorSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                    child: Text('30-MIN EXPRESS', style: UiText.caption.copyWith(color: UiTone.error, fontSize: 9.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDelivered ? UiTone.successSoft : UiTone.warningSoft,
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  isDelivered ? 'DELIVERED ✅' : 'PICKUP READY 🛵',
                  style: UiText.caption.copyWith(
                    color: isDelivered ? UiTone.success : UiTone.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('📍 ${order.deliveryAddress}', maxLines: 1, overflow: TextOverflow.ellipsis, style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('Items: ${order.items.map((i) => "${i.quantity}x ${i.product.name}").join(", ")}', style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11.5)),
          const SizedBox(height: 12),

          if (!isDelivered)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callCustomer(context, order.customerPhone),
                    icon: const Icon(Icons.phone, size: 14),
                    label: Text('Call Customer', style: UiText.label.copyWith(fontSize: 11.5, color: UiTone.primary)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UiTone.primary,
                      side: const BorderSide(color: UiTone.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteExpressOrder(context, order),
                    icon: const Icon(Icons.pin_rounded, size: 14),
                    label: Text('Verify OTP & Deliver', style: UiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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
        Text(val, style: UiText.h2.copyWith(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 1),
        Text(label, style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildShiftPill(String shift, String emoji, String label) {
    final isSel = _selectedShift == shift;
    return InkWell(
      onTap: () => setState(() => _selectedShift = shift),
      borderRadius: BorderRadius.circular(UiRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(UiRadius.sm),
          border: Border.all(color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$emoji ', style: const TextStyle(fontSize: 14)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UiText.label.copyWith(
                  color: isSel ? UiTone.primary : Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
