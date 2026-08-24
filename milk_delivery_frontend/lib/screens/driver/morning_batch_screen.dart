import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';
import '../../widgets/ui_kit/ui_kit.dart';
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

  bool _isLoading = true;
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
      final lat = double.tryParse(h['latitude']?.toString() ?? '17.001734') ?? 17.001734;
      final lng = double.tryParse(h['longitude']?.toString() ?? '79.9625') ?? 79.9625;

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
    _loadFreshData();
  }

  Future<void> _loadFreshData() async {
    await widget.state.reloadAllData();
    if (mounted) {
      setState(() {
        _optimizeRoute();
        for (var c in _dynamicCrateManifest) {
          _verifiedCrates.add(c.crateLabel);
        }
        _isLoading = false;
      });
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
      onConfirmProof: (proofUrl) async {
        widget.state.markDeliveryCompleted(stop.id, proofUrl);
        
        // Sync bottle returns to backend
        if (_currentStopBottles > 0) {
          await ApiService.createBottleReturn(
            customerId: stop.subscriptionDetail?.customerId ?? 0,
            productId: stop.subscriptionDetail?.productId ?? 0,
            quantity: _currentStopBottles,
            depositAmount: _currentStopBottles * 10.0,
          );
        }
        
        setState(() {
          _totalBottlesCollected += _currentStopBottles;
          _currentStopBottles = 0;
          if (_currentStopIndex + 1 < _routeResult.orderedStops.length) {
            _currentStopIndex++;
          } else {
            _batchStage = 2;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: UiTone.primary,
              content: Text('✅ Stop #${_currentStopIndex + 1} Delivered! Photo proof saved & wallet debited.'),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Morning Batch Mode 🥛',
                style: UiText.h2.copyWith(color: Colors.white, fontSize: 16)),
            Text('05:00 AM – 07:00 AM • Fuel-Optimized Route',
                style: UiText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5)),
          ],
        ),
        backgroundColor: UiTone.ink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: UiTone.primary))
          : _buildStageBody(),
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

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: _loadFreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                              style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: UiTone.secondary, size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_activeHub.address,
                          style: UiText.caption.copyWith(fontSize: 11, color: UiTone.softText)),
                      const SizedBox(height: 4),
                      Text(
                        _activeHub.managerName,
                        style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.primary, fontWeight: FontWeight.bold),
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
              borderRadius: BorderRadius.circular(UiRadius.lg),
              boxShadow: UiShadow.glowPrimary,
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
                          const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hub Shortest Path Optimized',
                              overflow: TextOverflow.ellipsis,
                              style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(UiRadius.xs)),
                      child: Text('ZERO BACKTRACKING', style: UiText.caption.copyWith(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTelemetryColumn('${_routeResult.totalDistanceKm.toStringAsFixed(1)} km', 'Loop Dist')),
                    Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.3)),
                    Expanded(child: _buildTelemetryColumn('${_routeResult.fuelSavedLiters.toStringAsFixed(2)} L', 'Fuel Saved')),
                    Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.3)),
                    Expanded(child: _buildTelemetryColumn(UiFormat.price(_routeResult.fuelCostSavedRupees), 'Savings')),
                    Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.3)),
                    Expanded(child: _buildTelemetryColumn('${_routeResult.co2SavedKg.toStringAsFixed(1)} kg', 'CO2 Offset')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Today's Daily Batch Lab Certification Card ──
          _buildDailyBatchCard(context),
          const SizedBox(height: 18),

          // ── Crate Inventory Pre-Load Manifest ──
          UiSectionHeader(
            title: '📦 Crate Pre-Load Checklist',
            padding: const EdgeInsets.only(bottom: 8),
            action: Text(
              '$totalUnits Total Units',
              style: UiText.label.copyWith(
                  fontWeight: FontWeight.w800, color: UiTone.primary),
            ),
          ),

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
                    color: isChecked ? UiTone.surface : UiTone.errorSoft,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(
                      color: isChecked ? UiTone.secondary : UiTone.error.withValues(alpha: 0.35),
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
                            Text(crate.productName, style: UiText.bodyStrong.copyWith(fontSize: 13)),
                            Text('${crate.crateLabel} • ${crate.unitVolume}',
                                style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.softText)),
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
                          style: UiText.caption.copyWith(fontWeight: FontWeight.w900, fontSize: 12, color: UiTone.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isChecked ? UiTone.secondary : UiTone.softText,
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
                style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13),
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
                style: UiText.h2.copyWith(fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: UiTone.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Done',
                  style: UiText.caption.copyWith(color: UiTone.primary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.xs),
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
                        style: UiText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    Text(
                      'Slot: ${currentStop.slotTime}',
                      style: UiText.caption.copyWith(color: UiTone.accentBlue, fontWeight: FontWeight.w700, fontSize: 11),
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
                            style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          Text(
                            currentStop.customerPhone,
                            style: UiText.caption.copyWith(fontSize: 11, color: UiTone.softText),
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
                              style: UiText.bodyStrong.copyWith(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '📝 Doorstep Note: ${currentStop.deliveryInstructions}',
                        style: UiText.caption.copyWith(color: UiTone.warning, fontSize: 11, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
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
                    label: Text('Turn-by-Turn GPS Navigation 🗺️', style: UiText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.accentBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Items to Drop
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UiTone.surfaceMuted, borderRadius: BorderRadius.circular(UiRadius.sm)),
                  child: Row(
                    children: [
                      Text(currentStop.subscriptionDetail?.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${currentStop.subscriptionDetail?.quantity ?? 1}x ${currentStop.subscriptionDetail?.productDetail?.name ?? "A2 Cow Milk Pouch"}',
                          style: UiText.bodyStrong.copyWith(fontSize: 12.5),
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
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🍾', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('Empty Bottles Collected:',
                              style: UiText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: UiTone.accentBlue)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: UiTone.accentBlue),
                            onPressed: _currentStopBottles > 0 ? () => setState(() => _currentStopBottles--) : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$_currentStopBottles',
                              style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.accentBlue),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: UiTone.accentBlue),
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
                    label: Text(
                      'Drop & Photo Proof (Complete Stop 📸)',
                      style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 12.5),
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
          const UiSectionHeader(
            title: 'Optimized Morning Route Sequence',
            padding: EdgeInsets.only(bottom: 8),
          ),

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
                      : (isCompleted ? UiTone.surfaceMuted : UiTone.surface),
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
                          : (isCurrent ? UiTone.primary : UiText.muted),
                      child: isCompleted
                          ? const Icon(Icons.check, color: UiTone.surface, size: 14)
                          : Text('${idx + 1}', style: UiText.caption.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.customerName, style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
                          Text(stop.deliveryAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.softText)),
                        ],
                      ),
                    ),
                    Text(
                      isCompleted ? 'DELIVERED' : (isCurrent ? 'ACTIVE' : 'NEXT'),
                      style: UiText.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? UiTone.primary : (isCurrent ? UiTone.accentBlue : UiTone.softText),
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

          Text('Morning Batch Completed! 🎉', style: UiText.h1.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text('All morning subscriptions delivered 100% on time.', style: UiText.body.copyWith(fontSize: 12, color: UiTone.softText)),
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
                      Text('Return to ${_activeHub.name}', style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13)),
                      Text('Deposit empty crates & $_totalBottlesCollected collected glass bottles', style: UiText.caption.copyWith(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
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
              borderRadius: BorderRadius.circular(UiRadius.lg),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Shift Attendance Status', style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    Text('VERIFIED BY HUB ✅', style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.primary)),
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
              onPressed: () async {
                // Reload fresh data so dashboard reflects completed batch
                await widget.state.reloadAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: UiTone.primary,
                      content: Text('🎉 Morning batch finalized! All data synced.'),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
              ),
              child: Text('Finish Batch & Return to Dashboard', style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryColumn(String val, String label) {
    return Column(
      children: [
        Text(val, style: UiText.h2.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        Text(label, style: UiText.caption.copyWith(color: Colors.white.withValues(alpha: 0.7), fontSize: 9.5)),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: UiText.body.copyWith(fontSize: 12, color: UiTone.softText)),
        Text(value, style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
      ],
    );
  }

  // ── Daily Batch Lab Certification Card & Modal ──

  Widget _buildDailyBatchCard(BuildContext context) {
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
        boxShadow: [
          BoxShadow(
            color: UiTone.success.withValues(alpha: 0.08),
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
                      color: UiTone.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: UiTone.success, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Milk Batch Certified 🥛',
                        style: UiText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800, color: UiTone.success),
                      ),
                      Text(
                        '$product • $batchCode',
                        style: UiText.caption.copyWith(fontSize: 11, color: UiTone.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showBatchLabQualityDialog(context),
                icon: const Icon(Icons.edit_note_rounded, size: 14, color: UiTone.success),
                label: Text('Update / Add', style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: UiTone.success)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: UiTone.success),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              Text(title, style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _showBatchLabQualityDialog(BuildContext context) {
    String selectedProduct = 'Pure Buffalo Milk';
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
                        decoration: BoxDecoration(color: UiTone.surfaceBorder, borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🥛', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daily Batch Lab Certification', style: UiText.h2.copyWith(fontSize: 16)),
                                Text('Enter lab quality parameters & litre rate', style: UiText.caption.copyWith(fontSize: 11, color: UiTone.softText)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),

                    // 1. Select Milk Product
                    Text('1. Select Milk Product:', style: UiText.bodyStrong.copyWith(fontSize: 12.5, color: UiTone.softText)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: UiTone.shellBackground,
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

                    // 2. Lab Purity Parameters
                    Text('2. Lab Quality Measurements:', style: UiText.bodyStrong.copyWith(fontSize: 12.5, color: UiTone.softText)),
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

                    // 3. Litre Rate & Volume
                    Text('3. Litre Pricing & Batch Volume:', style: UiText.bodyStrong.copyWith(fontSize: 12.5, color: UiTone.softText)),
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

                                final res = await ApiService.submitDailyMilkBatch(
                                  productName: selectedProduct,
                                  fatPercentage: fat,
                                  snfPercentage: snf,
                                  waterPercentage: water,
                                  pricePerLitre: price,
                                  totalLitres: volume,
                                  temperatureCelsius: 3.8,
                                  hubCode: widget.state.activeHubCode,
                                );

                                if (modalCtx.mounted) {
                                  Navigator.pop(ctx);
                                  await widget.state.reloadAllData();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: UiTone.primary,
                                        content: Text(res != null
                                            ? '✅ Today\'s $selectedProduct batch certified: $fat% Fat, $snf% SNF @ ₹$price/L!'
                                            : 'Failed to record batch'),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.verified_rounded),
                        label: Text(
                          isSubmitting ? 'Certifying Batch...' : '🔬 Certify Lab Report & Dispatch 🚀',
                          style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 14),
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
        color: UiTone.shellBackground,
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
                  style: UiText.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: UiText.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.w900),
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
