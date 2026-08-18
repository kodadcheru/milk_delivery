import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../providers/app_state.dart';
import '../../services/route_optimizer.dart';
import '../../widgets/doorstep_camera_dialog.dart';

class MorningBatchScreen extends StatefulWidget {
  final AppState state;

  const MorningBatchScreen({super.key, required this.state});

  @override
  State<MorningBatchScreen> createState() => _MorningBatchScreenState();
}

class _MorningBatchScreenState extends State<MorningBatchScreen> {
  final HubLocationModel _hub = HubLocationModel.defaultHub;
  late RouteOptimizationResult _routeResult;

  int _batchStage = 0; // 0: Depot Pre-Load Checklist, 1: Active Sequential Route, 2: Shift Completed / Reconciliation
  int _currentStopIndex = 0;
  int _totalBottlesCollected = 0;
  int _currentStopBottles = 0;
  final Set<String> _verifiedCrates = {};

  final List<CrateItemManifest> _crateManifest = const [
    CrateItemManifest(
      productName: 'Fresh A2 Cow Milk',
      icon: '🥛',
      totalUnits: 12,
      unitVolume: '1 Litre Pouch',
      crateLabel: 'Crate #A1 (Insulated Blue)',
    ),
    CrateItemManifest(
      productName: 'Creamy Buffalo Milk',
      icon: '🥛',
      totalUnits: 6,
      unitVolume: '500 ml Pouch',
      crateLabel: 'Crate #B2 (Insulated Red)',
    ),
    CrateItemManifest(
      productName: 'Farm Fresh Country Eggs',
      icon: '🥚',
      totalUnits: 4,
      unitVolume: 'Pack of 6',
      crateLabel: 'Crate #C3 (Padded Box)',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _optimizeRoute();
    // Default all crates checked for quick start
    for (var c in _crateManifest) {
      _verifiedCrates.add(c.crateLabel);
    }
  }

  void _optimizeRoute() {
    final tasks = widget.state.deliveries;
    _routeResult = RouteOptimizer.optimizeBatchRoute(hub: _hub, tasks: tasks);
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
            backgroundColor: const Color(0xFF0D7C66),
            content: Text('✅ Stop #$_currentStopIndex Delivered! Photo proof saved & wallet debited.'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Morning Batch Mode 🥛', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('05:00 AM – 07:00 AM • Fuel-Optimized Route', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
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
    final totalUnits = _crateManifest.fold<int>(0, (sum, c) => sum + c.totalUnits);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hub Origin Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 24),
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
                              _hub.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_hub.address, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        'Dispatch Lead: ${_hub.managerName}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF0D7C66), fontWeight: FontWeight.bold),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text('Hub Shortest Path Optimized', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('ZERO BACKTRACKING', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTelemetryColumn('${_routeResult.totalDistanceKm.toStringAsFixed(1)} km', 'Total Loop Distance'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildTelemetryColumn('${_routeResult.fuelSavedLiters.toStringAsFixed(2)} L', 'Fuel Saved'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildTelemetryColumn('₹${_routeResult.fuelCostSavedRupees.toStringAsFixed(0)}', 'Petrol Savings'),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildTelemetryColumn('${_routeResult.co2SavedKg.toStringAsFixed(1)} kg', 'CO2 Offset 🌱'),
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
              const Text('📦 Crate Inventory Pre-Load Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
              Text('$totalUnits Total Units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D7C66))),
            ],
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _crateManifest.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final crate = _crateManifest[idx];
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.white : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isChecked ? const Color(0xFF10B981) : const Color(0xFFFDA4AF),
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
                            Text(crate.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            Text('${crate.crateLabel} • ${crate.unitVolume}', style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${crate.totalUnits} Units',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0D7C66)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isChecked ? const Color(0xFF10B981) : Colors.grey,
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
                    backgroundColor: Color(0xFF0D7C66),
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
                backgroundColor: const Color(0xFF0D7C66),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Done',
                  style: const TextStyle(color: Color(0xFF0D7C66), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // ── CURRENT ACTIVE DOORSTEP STOP (HERO CARD) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0D7C66), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        color: const Color(0xFF0D7C66),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CURRENT STOP #${_currentStopIndex + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
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
                      backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                      child: const Text('🏡', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStop.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            currentStop.customerPhone.isNotEmpty ? currentStop.customerPhone : '+91 9876543210',
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
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doorstep Address
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
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
                      backgroundColor: const Color(0xFF0284C7),
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
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
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
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
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
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Full Route Stops Timeline ──
          const Text('Optimized Morning Route Sequence:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
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
                      ? const Color(0xFF0D7C66).withValues(alpha: 0.08)
                      : (isCompleted ? const Color(0xFFF1F5F9) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isCompleted
                          ? const Color(0xFF10B981)
                          : (isCurrent ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1)),
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        color: isCompleted ? const Color(0xFF0D7C66) : (isCurrent ? const Color(0xFF0284C7) : Colors.grey),
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
    final totalEarnings = 350 + (stops.length * 25) + 100 + (_totalBottlesCollected * 5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Celebration Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),

          const Text('Morning Batch Completed! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('All morning subscriptions delivered 100% on time.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),

          // Return to Hub Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.warehouse_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Return to Depot Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Deposit empty crates & $_totalBottlesCollected collected glass bottles', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Shift Earnings Breakdown Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Base Morning Shift Pay', '₹350'),
                const Divider(height: 16),
                _buildReceiptRow('${stops.length} Completed Drops (₹25/drop)', '₹${stops.length * 25}'),
                const Divider(height: 16),
                _buildReceiptRow('On-Time Delivery Bonus (<07:00 AM)', '₹100'),
                const Divider(height: 16),
                _buildReceiptRow('$_totalBottlesCollected Glass Bottles Collected (₹5/bottle)', '₹${_totalBottlesCollected * 5}'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Shift Payout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('₹$totalEarnings', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0D7C66))),
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
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
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
