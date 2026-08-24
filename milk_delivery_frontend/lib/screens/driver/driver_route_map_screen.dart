import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../providers/app_state.dart';
import '../../services/route_optimizer.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/ui_kit/ui_kit.dart';

class DriverRouteMapScreen extends StatefulWidget {
  final AppState state;
  final List<DeliveryTaskModel> tasks;

  const DriverRouteMapScreen({
    super.key,
    required this.state,
    required this.tasks,
  });

  @override
  State<DriverRouteMapScreen> createState() => _DriverRouteMapScreenState();
}

class _DriverRouteMapScreenState extends State<DriverRouteMapScreen> {
  GoogleMapController? _mapController;
  int _selectedTaskIndex = 0;
  late RouteOptimizationResult _tspResult;
  late List<DeliveryTaskModel> _orderedTasks;

  // Depot location — read from active hub, fallback to Kodad default
  LatLng get _depotLocation {
    final hub = widget.state.nearestCoveringHub;
    if (hub != null) {
      final lat = double.tryParse(hub['latitude']?.toString() ?? '') ?? 17.001734;
      final lng = double.tryParse(hub['longitude']?.toString() ?? '') ?? 79.9625;
      return LatLng(lat, lng);
    }
    return const LatLng(17.001734, 79.9625);
  }

  // Delivery partner location
  late LatLng _driverLocation;

  @override
  void initState() {
    super.initState();
    final hubModel = HubLocationModel(
      id: widget.state.nearestCoveringHub?['hub_code']?.toString() ?? 'HUB-KDD-01',
      name: widget.state.nearestCoveringHub?['name']?.toString() ?? 'Kodad Depot',
      address: widget.state.nearestCoveringHub?['address']?.toString() ?? '2X27+M36, Kodad, Telangana 508206, India',
      latitude: _depotLocation.latitude,
      longitude: _depotLocation.longitude,
      managerName: widget.state.nearestCoveringHub?['manager_name']?.toString() ?? 'srinuvasa reddy',
      managerPhone: widget.state.nearestCoveringHub?['manager_phone']?.toString() ?? '8885199878',
    );
    _tspResult = RouteOptimizer.optimizeBatchRoute(hub: hubModel, tasks: widget.tasks);
    _orderedTasks = _tspResult.orderedStops;
    _driverLocation = LatLng(_depotLocation.latitude + 0.004, _depotLocation.longitude + 0.003);
  }

  void _launchGoogleMapsNavigation(double lat, double lon, String customerName) async {
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving';
    final uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.accentBlue,
            content: Text('🗺️ Launching Google Maps turn-by-turn navigation to $customerName'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📍 Navigating to coordinates: $lat, $lon')),
        );
      }
    }
  }

  void _launchFullMultiStopGoogleMapsRoute(List<DeliveryTaskModel> tasks) async {
    if (tasks.isEmpty) return;

    final origin = '${_depotLocation.latitude},${_depotLocation.longitude}';
    final destination = '${tasks.last.customerLatitude},${tasks.last.customerLongitude}';

    String waypointsParam = '';
    if (tasks.length > 1) {
      final intermediate = tasks.sublist(0, tasks.length - 1);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('🗺️ Launching Full Multi-Stop Google Maps Route (${tasks.length} Drops)'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 Opening Google Maps route...')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _orderedTasks;
    final List<LatLng> routePoints = [_depotLocation, _driverLocation];
    for (var t in tasks) {
      routePoints.add(LatLng(t.customerLatitude, t.customerLongitude));
    }

    final selectedTask = tasks.isNotEmpty && _selectedTaskIndex < tasks.length
        ? tasks[_selectedTaskIndex]
        : null;

    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';

    return Scaffold(
      backgroundColor: UiTone.ink,
      appBar: AppBar(
        backgroundColor: UiTone.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Morning Route Map Navigation',
              style: UiText.h2.copyWith(fontSize: 16, color: Colors.white),
            ),
            Text(
              '${tasks.length} Drops • $hubName Sector',
              style: UiText.label.copyWith(fontSize: 11, color: UiTone.secondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: UiTone.accentBlue),
            tooltip: 'Open Full Multi-Stop Google Maps Route',
            onPressed: () => _launchFullMultiStopGoogleMapsRoute(tasks),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: UiTone.secondary),
            onPressed: () {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation, 14.5));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Maps View ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _depotLocation,
              zoom: 13.8,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            polylines: {
              Polyline(
                polylineId: const PolylineId('driver_route'),
                points: routePoints,
                width: 4,
                color: UiTone.primary,
              ),
            },
            markers: {
              // 1. Hub Depot Marker
              Marker(
                markerId: const MarkerId('depot'),
                position: _depotLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                infoWindow: const InfoWindow(title: 'Fulfillment Depot Hub'),
              ),
              // 2. Driver Live Location Marker
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: const InfoWindow(title: 'Your Location (Live)'),
              ),
              // 3. Customer Stop Markers
              ...tasks.asMap().entries.map((entry) {
                final idx = entry.key;
                final task = entry.value;
                final isDelivered = task.isDelivered;
                final isSelected = idx == _selectedTaskIndex;

                return Marker(
                  markerId: MarkerId('task_${task.id}'),
                  position: LatLng(task.customerLatitude, task.customerLongitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    isDelivered
                        ? BitmapDescriptor.hueGreen
                        : (isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed),
                  ),
                  infoWindow: InfoWindow(
                    title: 'Stop #${idx + 1}: ${task.customerName}',
                    snippet: '${task.subscriptionDetail?.productDetail?.name ?? "Fresh Milk"} - ${task.status}',
                  ),
                  onTap: () {
                    setState(() => _selectedTaskIndex = idx);
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(task.customerLatitude, task.customerLongitude),
                        15.0,
                      ),
                    );
                  },
                );
              }),
            },
          ),

          // ── Top Route Summary Pill ──
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: UiInsetCard(
              onTap: () => _launchFullMultiStopGoogleMapsRoute(tasks),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shadow: UiShadow.floating,
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, color: UiTone.accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TSP Shortest Path Navigation 🚀',
                          style: UiText.bodyStrong.copyWith(fontSize: 11, color: UiTone.accentBlue),
                        ),
                        Text(
                          'Saved ${_tspResult.distanceSavedKm.toStringAsFixed(1)} km & ${_tspResult.fuelSavedLiters.toStringAsFixed(2)}L fuel (${tasks.length} Drops)',
                          style: UiText.body.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: UiTone.successSoft,
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      '${tasks.where((t) => t.isDelivered).length}/${tasks.length} Done',
                      style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: UiTone.success),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Selected Stop Action Card ──
          if (selectedTask != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: UiInsetCard(
                padding: const EdgeInsets.all(18),
                radius: UiRadius.lg,
                borderColor: UiTone.accentBlue.withValues(alpha: 0.3),
                shadow: UiShadow.floating,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: UiTone.infoSoft,
                            borderRadius: BorderRadius.circular(UiRadius.xs),
                          ),
                          child: Text(
                            'STOP #${_selectedTaskIndex + 1}',
                            style: UiText.caption.copyWith(color: UiTone.accentBlue, fontWeight: FontWeight.w900, fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedTask.customerName,
                            style: UiText.bodyStrong.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          selectedTask.slotTime,
                          style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedTask.deliveryAddress,
                      style: UiText.body.copyWith(fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UiTone.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                            ),
                            icon: const Icon(Icons.navigation, size: 18),
                            label: Text('Navigate with Google Maps', style: UiText.bodyStrong.copyWith(fontSize: 13, color: Colors.white)),
                            onPressed: () {
                              _launchGoogleMapsNavigation(
                                selectedTask.customerLatitude,
                                selectedTask.customerLongitude,
                                selectedTask.customerName,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
