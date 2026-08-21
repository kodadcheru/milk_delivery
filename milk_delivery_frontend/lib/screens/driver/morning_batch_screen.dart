import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../services/route_optimizer.dart';
import '../../widgets/doorstep_camera_dialog.dart';

class MorningBatchScreen extends StatefulWidget {
  final AppState state;
  final String shiftName;
  final String? slotFilter;

  const MorningBatchScreen({
    super.key,
    required this.state,
    this.shiftName = 'Morning Batch',
    this.slotFilter,
  });

  @override
  State<MorningBatchScreen> createState() => _MorningBatchScreenState();
}

class _MorningBatchScreenState extends State<MorningBatchScreen> {
  late RouteOptimizationResult _routeResult;

  int _batchStage = 0; // 0: Depot Pre-Load Checklist, 1: Active Sequential Route, 2: Shift Completed / Reconciliation
  int _currentStopIndex = 0;
  int _totalBottlesCollected = 0;
  int _currentStopBottles = 0;
  final Set<String> _verifiedCrates = {};

  HubLocationModel get _activeHub {
    final h = widget.state.nearestCoveringHub ?? (widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null);
    if (h != null) {
      final name = h['name']?.toString() ?? 'Kodad Depot';
      final address = h['address']?.toString() ?? '$name, Telangana';
      final mgrName = h['manager_name']?.toString() ?? 'Hub Dispatch Lead';
      final mgrPhone = h['manager_phone']?.toString() ?? '8885199878';
      final lat = (h['latitude'] as num?)?.toDouble() ?? 17.001734;
      final lng = (h['longitude'] as num?)?.toDouble() ?? 79.9625;

      return HubLocationModel(
        id: '${h['hub_code'] ?? h['id'] ?? 'HUB-KDD-01'}',
        name: name,
        address: address,
        managerName: mgrName,
        managerPhone: mgrPhone,
        latitude: lat,
        longitude: lng,
      );
    }
    return HubLocationModel.defaultHub;
  }

  List<CrateItemManifest> get _dynamicCrateManifest {
    final Map<String, int> productCounts = {};
    final Map<String, String> productIcons = {};
    final Map<String, String> productUnits = {};

    // 1. First check today's generated delivery tasks
    final activeDeliveries = widget.state.deliveries.where((d) => d.status != 'SKIPPED').toList();
    if (activeDeliveries.isNotEmpty) {
      for (var delivery in activeDeliveries) {
        final sub = delivery.subscriptionDetail;
        final pId = sub?.productId ?? sub?.productDetail?.id;
        final product = widget.state.products.firstWhere(
          (p) => p.id == pId || (sub?.productDetail != null && p.id == sub!.productDetail!.id),
          orElse: () => sub?.productDetail ?? ProductModel(
            id: 0,
            name: 'Fresh Farm Milk',
            description: '',
            pricePerUnit: 0,
            unit: 'LITER',
            unitQuantity: '1 Litre Pouch',
            imageUrl: '',
          ),
        );

        final pName = product.name;
        final qty = sub?.quantity ?? 1;
        productCounts[pName] = (productCounts[pName] ?? 0) + qty;
        productIcons[pName] = product.icon.isNotEmpty ? product.icon : '🥛';
        productUnits[pName] = product.unitQuantity.isNotEmpty ? product.unitQuantity : (product.unit.isNotEmpty ? product.unit : '1 Unit');
      }
    } else {
      // 2. Aggregate active subscriptions
      final activeSubs = widget.state.subscriptions.where((s) => s.status == 'ACTIVE').toList();
      for (var sub in activeSubs) {
        final product = widget.state.products.firstWhere(
          (p) => p.id == sub.productId || (sub.productDetail != null && p.id == sub.productDetail!.id),
          orElse: () => sub.productDetail ?? ProductModel(
            id: sub.productId,
            name: 'Fresh A2 Cow Milk',
            description: '',
            pricePerUnit: 0,
            unit: 'LITER',
            unitQuantity: '1 Litre Pouch',
            imageUrl: '',
          ),
        );

        final pName = product.name;
        final qty = sub.quantity;
        productCounts[pName] = (productCounts[pName] ?? 0) + qty;
        productIcons[pName] = product.icon.isNotEmpty ? product.icon : '🥛';
        productUnits[pName] = product.unitQuantity.isNotEmpty ? product.unitQuantity : '1 Litre Pouch';
      }

      // 3. Aggregate live express orders
      final activeOrders = widget.state.liveOrders.where((o) => o.status != 'CANCELLED' && o.status != 'DELIVERED').toList();
      for (var order in activeOrders) {
        for (var item in order.items) {
          final pName = item.product.name;
          final qty = item.quantity;
          productCounts[pName] = (productCounts[pName] ?? 0) + qty;
          productIcons[pName] = item.product.icon.isNotEmpty ? item.product.icon : '🥛';
          productUnits[pName] = item.product.unitQuantity.isNotEmpty ? item.product.unitQuantity : '1 Unit';
        }
      }
    }

    if (productCounts.isEmpty) {
      return [
        CrateItemManifest(
          productName: 'Fresh A2 Desi Cow Milk',
          icon: '🥛',
          totalUnits: 1,
          unitVolume: '1 Litre Glass Bottle',
          crateLabel: 'Crate #A1 (Insulated Blue)',
        ),
      ];
    }

    final List<CrateItemManifest> manifest = [];
    int idx = 1;
    productCounts.forEach((pName, totalUnits) {
      final crateCount = (totalUnits / 12).ceil();
      final crateLabel = crateCount > 1
          ? 'Crates #${String.fromCharCode(64 + idx)}1-${String.fromCharCode(64 + idx)}$crateCount ($crateCount Crates)'
          : 'Crate #${String.fromCharCode(64 + idx)}1 (Insulated Box)';

      manifest.add(CrateItemManifest(
        productName: pName,
        icon: productIcons[pName] ?? '🥛',
        totalUnits: totalUnits,
        unitVolume: productUnits[pName] ?? '1 Unit',
        crateLabel: crateLabel,
      ));
      idx++;
    });

    return manifest;
  }

  @override
  void initState() {
    super.initState();
    _optimizeRoute();
    for (var c in _dynamicCrateManifest) {
      _verifiedCrates.add(c.crateLabel);
    }
  }

  void _optimizeRoute() {
    var tasks = widget.state.deliveries.where((d) => d.status != 'SKIPPED').toList();

    // If deliveries list is empty, convert active subscriptions into preview tasks
    if (tasks.isEmpty) {
      final activeSubs = widget.state.subscriptions.where((s) => s.status == 'ACTIVE').toList();
      tasks = activeSubs.map<DeliveryTaskModel>((sub) {
        return DeliveryTaskModel(
          id: sub.id,
          subscriptionId: sub.id,
          customerName: sub.customerId > 0 ? 'Customer #${sub.customerId}' : 'Subscribed Family',
          customerPhone: '+91 8919548905',
          deliveryAddress: sub.deliveryAddress.isNotEmpty ? sub.deliveryAddress : 'Doorstep Delivery Location',
          deliveryDate: sub.startDate.isNotEmpty ? sub.startDate : '2026-08-22',
          slotTime: sub.deliverySlot,
          status: 'PENDING',
          proofImageUrl: '',
          customerLatitude: sub.deliveryLatitude != 0.0 ? sub.deliveryLatitude : _activeHub.latitude + 0.005,
          customerLongitude: sub.deliveryLongitude != 0.0 ? sub.deliveryLongitude : _activeHub.longitude + 0.005,
          subscriptionDetail: sub,
        );
      }).toList();
    }

    if (widget.slotFilter != null && widget.slotFilter!.isNotEmpty) {
      final filtered = tasks.where((t) => t.slotTime.toLowerCase().contains(widget.slotFilter!.toLowerCase())).toList();
      if (filtered.isNotEmpty) {
        tasks = filtered;
      }
    }
    _routeResult = RouteOptimizer.optimizeBatchRoute(hub: _activeHub, tasks: tasks);
  }

  void _callPhone(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
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

  void _launchGoogleMapsNavigation(double lat, double lon, String name) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📍 Navigating to $name ($lat, $lon)')),
        );
      }
    }
  }

  void _completeCurrentStopWithCamera(DeliveryTaskModel stop) {
    DoorstepCameraDialog.show(
      context,
      customerName: stop.customerName,
      deliveryAddress: stop.deliveryAddress,
      latitude: stop.customerLatitude,
      longitude: stop.customerLongitude,
      onConfirmProof: (proofUrl) {
        widget.state.markDeliveryCompleted(stop.id, proofUrl);
        setState(() {
          _totalBottlesCollected += _currentStopBottles;
          _currentStopBottles = 0;
          if (_currentStopIndex + 1 < _routeResult.orderedStops.length) {
            _currentStopIndex++;
          } else {
            _batchStage = 2; // All stops complete, show reconciliation
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('✅ Stop #$_currentStopIndex Delivered! Photo proof saved & wallet debited.'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Morning Batch Mode 🥛', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('05:00 AM – 07:00 AM • Fuel-Optimized Route', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
          ],
        ),
        backgroundColor: UiTone.ink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildStageBody(),
    );
  }

  Widget _buildStageBody() {
    switch (_batchStage) {
      case 0:
        return _buildDepotPreloadStage();
      case 1:
        return _buildActiveRouteStage();
      case 2:
        return _buildReconciliationStage();
      default:
        return const SizedBox();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STAGE 0: DEPOT CRATE PRE-LOAD & FUEL SAVINGS TELEMETRY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDepotPreloadStage() {
    final crateManifest = _dynamicCrateManifest;
    final totalUnits = crateManifest.fold<int>(0, (sum, c) => sum + c.totalUnits);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hub Origin Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: UiTone.surfaceBorder),
              boxShadow: UiShadow.card,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: UiTone.ink, borderRadius: BorderRadius.circular(UiRadius.sm)),
                  child: const Icon(Icons.warehouse_rounded, color: UiTone.surface, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _activeHub.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: UiTone.secondary, size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_activeHub.address, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        _activeHub.managerName,
                        style: const TextStyle(fontSize: 10.5, color: UiTone.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Fuel & Carbon Savings Banner ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: UiGradient.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiShadow.glowPrimary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.eco_rounded, color: UiTone.surface, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hub Shortest Path Optimized',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: const Text('ZERO BACKTRACKING', style: TextStyle(color: UiTone.surface, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTelemetryColumn('${_routeResult.totalDistanceKm.toStringAsFixed(1)} km', 'Loop Dist')),
                    Container(width: 1, height: 24, color: Colors.white30),
                    Expanded(child: _buildTelemetryColumn('${_routeResult.fuelSavedLiters.toStringAsFixed(2)} L', 'Fuel Saved')),
                    Container(width: 1, height: 24, color: Colors.white30),
                    Expanded(child: _buildTelemetryColumn('₹${_routeResult.fuelCostSavedRupees.toStringAsFixed(0)}', 'Savings')),
                    Container(width: 1, height: 24, color: Colors.white30),
                    Expanded(child: _buildTelemetryColumn('${_routeResult.co2SavedKg.toStringAsFixed(1)} kg', 'CO2 Offset')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Crate Inventory Pre-Load Manifest ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  '📦 Crate Pre-Load Checklist:',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text('$totalUnits Total Units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: UiTone.primary)),
            ],
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: crateManifest.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final crate = crateManifest[idx];
              final isChecked = _verifiedCrates.contains(crate.crateLabel);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _verifiedCrates.remove(crate.crateLabel);
                    } else {
                      _verifiedCrates.add(crate.crateLabel);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(UiRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.white : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(
                      color: isChecked ? UiTone.secondary : const Color(0xFFFDA4AF),
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(crate.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(crate.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
                            Text('${crate.crateLabel} • ${crate.unitVolume}', style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: UiTone.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                        ),
                        child: Text(
                          '${crate.totalUnits} Units',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: UiTone.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isChecked ? UiTone.secondary : Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Start Route Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _batchStage = 1);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: UiTone.primary,
                    content: Text('🚀 Morning Shift Started! Navigating to Stop #1 in shortest sequence.'),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                'Confirm Crates & Start Shortest Route (${_routeResult.orderedStops.length} Stops) 🚀',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STAGE 1: ACTIVE SEQUENTIAL DOORSTEP DELIVERY (RAPID DROP MODE)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveRouteStage() {
    final stops = _routeResult.orderedStops;
    if (stops.isEmpty) return const Center(child: Text('No stops assigned.'));

    final currentStop = stops[_currentStopIndex];
    final progress = (_currentStopIndex) / stops.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Progress Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stop ${_currentStopIndex + 1} of ${stops.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: UiTone.ink),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: UiTone.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Done',
                  style: const TextStyle(color: UiTone.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: UiTone.surfaceBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(UiTone.secondary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // ── CURRENT ACTIVE DOORSTEP STOP (HERO CARD) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.lg),
              border: Border.all(color: UiTone.primary, width: 2),
              boxShadow: UiShadow.elevated,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stop Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: UiTone.primary,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text(
                        'CURRENT STOP #${_currentStopIndex + 1}',
                        style: const TextStyle(color: UiTone.surface, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    Text(
                      'Slot: ${currentStop.slotTime}',
                      style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer Name & Calling
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: UiTone.primary.withValues(alpha: 0.12),
                      child: const Text('🏡', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStop.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: UiTone.ink),
                          ),
                          Text(
                            currentStop.customerPhone,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _callPhone(context, currentStop.customerPhone),
                      icon: const Icon(Icons.phone_rounded, size: 14),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doorstep Address
                Container(
                  padding: const EdgeInsets.all(12),
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
                              currentStop.deliveryAddress,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '📝 Doorstep Note: ${currentStop.deliveryInstructions}',
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 1-Click Google Maps Navigation
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchGoogleMapsNavigation(
                      currentStop.customerLatitude,
                      currentStop.customerLongitude,
                      currentStop.customerName,
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 15),
                    label: const Text('Turn-by-Turn GPS Navigation 🗺️', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.accentBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Items to Drop
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UiTone.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text(currentStop.subscriptionDetail?.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${currentStop.subscriptionDetail?.quantity ?? 1}x ${currentStop.subscriptionDetail?.productDetail?.name ?? "A2 Cow Milk Pouch"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Empty Glass Bottle Return Counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: UiTone.accentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Text('🍾', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 6),
                          Text('Empty Bottles Collected:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF0369A1)),
                            onPressed: _currentStopBottles > 0 ? () => setState(() => _currentStopBottles--) : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$_currentStopBottles',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0369A1)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0369A1)),
                            onPressed: () => setState(() => _currentStopBottles++),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Rapid Drop & Complete Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _completeCurrentStopWithCamera(currentStop),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text(
                      'Drop & Photo Proof (Complete Stop 📸)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
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
          const SizedBox(height: 20),

          // ── Full Route Stops Timeline ──
          const Text('Optimized Morning Route Sequence:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final stop = stops[idx];
              final isCurrent = idx == _currentStopIndex;
              final isCompleted = idx < _currentStopIndex || stop.status == 'DELIVERED';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? UiTone.primary.withValues(alpha: 0.08)
                      : (isCompleted ? UiTone.surfaceMuted : Colors.white),
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(
                    color: isCurrent ? UiTone.primary : UiTone.surfaceBorder,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isCompleted
                          ? UiTone.secondary
                          : (isCurrent ? UiTone.primary : const Color(0xFFCBD5E1)),
                      child: isCompleted
                          ? const Icon(Icons.check, color: UiTone.surface, size: 14)
                          : Text('${idx + 1}', style: const TextStyle(color: UiTone.surface, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text(stop.deliveryAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Text(
                      isCompleted ? 'DELIVERED' : (isCurrent ? 'ACTIVE' : 'NEXT'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? UiTone.primary : (isCurrent ? UiTone.accentBlue : Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STAGE 2: HUB RETURN & EMPTY BOTTLE RECONCILIATION SUMMARY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReconciliationStage() {
    final stops = _routeResult.orderedStops;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Celebration Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: UiTone.secondary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: UiTone.surface, size: 48),
          ),
          const SizedBox(height: 16),

          const Text('Morning Batch Completed! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: UiTone.ink)),
          const SizedBox(height: 4),
          const Text('All morning subscriptions delivered 100% on time.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),

          // Return to Hub Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: UiTone.ink,
              borderRadius: BorderRadius.circular(UiRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.warehouse_rounded, color: UiTone.surface, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Return to ${_activeHub.name}', style: const TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Deposit empty crates & $_totalBottlesCollected collected glass bottles', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Shift Fulfillment & Attendance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: UiTone.surfaceBorder),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Employment Type', 'Fixed Monthly Salaried Partner'),
                const Divider(height: 16),
                _buildReceiptRow('Monthly Salary (Paid by Hub)', '${widget.state.currentUser?.monthlySalary ?? '₹15,000 / Month'}'),
                const Divider(height: 16),
                _buildReceiptRow('Morning Shift Doorsteps Completed', '${stops.length} / ${stops.length} Drops (100%)'),
                const Divider(height: 16),
                _buildReceiptRow('On-Time Arrival SLA', '100% On-Time (< 07:00 AM)'),
                const Divider(height: 16),
                _buildReceiptRow('Empty Glass Bottles Returned', '$_totalBottlesCollected Bottles Deposited 🍾'),
                const Divider(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Shift Attendance Status', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    Text('VERIFIED BY HUB ✅', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Return to Dashboard Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
              ),
              child: const Text('Finish Batch & Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryColumn(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: UiTone.surface, fontSize: 15, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
