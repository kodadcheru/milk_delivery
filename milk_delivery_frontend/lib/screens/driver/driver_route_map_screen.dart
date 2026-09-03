import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/delivery_batch_model.dart';
import '../../models/delivery_task_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/route_optimizer.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/ui_kit/ui_kit.dart';
import '../../widgets/driver_delivery_chat_sheet.dart';

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
  StreamSubscription<Position>? _positionSubscription;
  bool _hasInitialGpsFix = false;
  double _driverHeading = 0.0;
  List<LatLng> _realRoadPolylinePoints = [];
  bool _isLoadingRoadGeometry = false;

  // Depot location — read from active hub, fallback to Kodad default
  LatLng get _depotLocation {
    final hub = widget.state.nearestCoveringHub;
    if (hub != null) {
      final lat = double.tryParse(hub['latitude']?.toString() ?? '') ?? AppConfig.defaultLatitude;
      final lng = double.tryParse(hub['longitude']?.toString() ?? '') ?? AppConfig.defaultLongitude;
      return LatLng(lat, lng);
    }
    return const LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
  }

  // Delivery partner location
  late LatLng _driverLocation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize fallback location from current user profile or hub depot
    if (widget.state.currentUser != null &&
        widget.state.currentUser!.latitude != 0.0 &&
        widget.state.currentUser!.longitude != 0.0) {
      _driverLocation = LatLng(
        widget.state.currentUser!.latitude,
        widget.state.currentUser!.longitude,
      );
    } else if (widget.state.currentLat != 0.0 && widget.state.currentLon != 0.0) {
      _driverLocation = LatLng(widget.state.currentLat, widget.state.currentLon);
    } else {
      _driverLocation = _depotLocation;
    }

    final hubModel = HubLocationModel(
      id: widget.state.nearestCoveringHub?['hub_code']?.toString() ?? 'HUB-DEFAULT',
      name: widget.state.nearestCoveringHub?['name']?.toString() ?? AppConfig.defaultHubName,
      address: widget.state.nearestCoveringHub?['address']?.toString() ?? AppConfig.defaultHubAddress,
      latitude: _depotLocation.latitude,
      longitude: _depotLocation.longitude,
      managerName: widget.state.nearestCoveringHub?['manager_name']?.toString() ?? 'Hub Operations Desk',
      managerPhone: widget.state.nearestCoveringHub?['manager_phone']?.toString() ?? AppConfig.supportPhone,
    );
    _tspResult = RouteOptimizer.optimizeBatchRoute(hub: hubModel, tasks: widget.tasks);
    _orderedTasks = _tspResult.orderedStops;

    // 2. Fetch Real-World Road Network Polyline (Street Geometry)
    _loadRealRoadGeometry();

    // 3. Start Live Real-time GPS stream
    _startLiveGpsTracking();
  }

  Future<void> _loadRealRoadGeometry() async {
    if (!mounted) return;
    setState(() => _isLoadingRoadGeometry = true);

    final tasks = _orderedTasks;
    final allCompleted = tasks.isNotEmpty && tasks.every((t) => t.isDelivered || t.status == 'DELIVERED' || t.status == 'SKIPPED');

    final List<LatLng> waypoints = allCompleted
        ? [_driverLocation, _depotLocation]
        : [_depotLocation, _driverLocation];
    if (!allCompleted) {
      for (var t in tasks) {
        waypoints.add(LatLng(t.customerLatitude, t.customerLongitude));
      }
    }

    final realPoints = await RouteOptimizer.fetchRealRoadPolyline(waypoints);
    if (mounted) {
      setState(() {
        _realRoadPolylinePoints = realPoints;
        _isLoadingRoadGeometry = false;
      });
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180.0);
    final lon1 = start.longitude * (pi / 180.0);
    final lat2 = end.latitude * (pi / 180.0);
    final lon2 = end.longitude * (pi / 180.0);

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    return (radians * (180.0 / pi) + 360.0) % 360.0;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLiveGpsTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

      // Initial fast fix
      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 4), onTimeout: () => throw TimeoutException('GPS timeout'));

      if (mounted) {
        setState(() {
          _driverLocation = LatLng(initialPos.latitude, initialPos.longitude);
          _hasInitialGpsFix = true;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation, 15.0));
      }

      // Continuous live updates with smooth heading rotation
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // High precision 3-meter road movement
      );

      _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) {
          if (!mounted) return;
          final newLoc = LatLng(pos.latitude, pos.longitude);
          final bearing = pos.heading != 0.0 ? pos.heading : _driverHeading;

          setState(() {
            _driverLocation = newLoc;
            _driverHeading = bearing;
            _hasInitialGpsFix = true;
          });

          // Sync real-time location to backend fleet dispatcher
          ApiService.updateDriverLocation(
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _launchGoogleMapsNavigation(double lat, double lon, String customerName) async {
    final origin = '${_driverLocation.latitude},${_driverLocation.longitude}';
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$lat,$lon&travelmode=driving';
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
            content: Text('🗺️ Turn-by-turn navigation to $customerName from your location'),
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

    final origin = '${_driverLocation.latitude},${_driverLocation.longitude}';
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
    final allCompleted = tasks.isNotEmpty && tasks.every((t) => t.isDelivered || t.status == 'DELIVERED' || t.status == 'SKIPPED');

    final List<LatLng> routePoints = allCompleted
        ? [_driverLocation, _depotLocation]
        : [_depotLocation, _driverLocation];
    if (!allCompleted) {
      for (var t in tasks) {
        routePoints.add(LatLng(t.customerLatitude, t.customerLongitude));
      }
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
              allCompleted ? 'Shift Completed • Return to Depot' : 'Morning Route Map Navigation',
              style: UiText.h2.copyWith(fontSize: 16, color: Colors.white),
            ),
            Text(
              allCompleted
                  ? 'All ${tasks.length} Drops Delivered • $hubName'
                  : '${tasks.length} Drops • $hubName Sector',
              style: UiText.label.copyWith(
                fontSize: 11,
                color: allCompleted ? UiTone.success : UiTone.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              allCompleted ? Icons.warehouse_rounded : Icons.map_outlined,
              color: allCompleted ? UiTone.success : UiTone.accentBlue,
            ),
            tooltip: allCompleted ? 'Navigate Return to Depot' : 'Open Full Multi-Stop Google Maps Route',
            onPressed: () {
              if (allCompleted) {
                _launchGoogleMapsNavigation(_depotLocation.latitude, _depotLocation.longitude, hubName);
              } else {
                _launchFullMultiStopGoogleMapsRoute(tasks);
              }
            },
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
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            polylines: {
              Polyline(
                polylineId: PolylineId(allCompleted ? 'return_depot_route' : 'real_road_route'),
                points: _realRoadPolylinePoints.isNotEmpty ? _realRoadPolylinePoints : routePoints,
                width: 5,
                color: allCompleted ? UiTone.success : UiTone.primary,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            },
            markers: {
              // 1. Hub Depot Marker
              Marker(
                markerId: const MarkerId('depot'),
                position: _depotLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                infoWindow: InfoWindow(title: '🏬 $hubName (Fulfillment Base)'),
              ),
              // 2. Driver Live Location Marker (Smoothly Rotated Towards Direction of Travel)
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverLocation,
                rotation: _driverHeading,
                flat: true,
                anchor: const Offset(0.5, 0.5),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: InfoWindow(
                  title: '🛵 Your Live Location',
                  snippet: 'Heading: ${_driverHeading.toStringAsFixed(0)}° • Real-Time GPS Tracking',
                ),
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
                    title: 'Stop #${idx + 1}: ${task.customerName} ${isDelivered ? "✓ (Delivered)" : ""}',
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
              onTap: () {
                if (allCompleted) {
                  _launchGoogleMapsNavigation(_depotLocation.latitude, _depotLocation.longitude, hubName);
                } else {
                  _launchFullMultiStopGoogleMapsRoute(tasks);
                }
              },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shadow: UiShadow.floating,
              borderColor: allCompleted ? UiTone.success.withValues(alpha: 0.4) : null,
              child: Row(
                children: [
                  Icon(
                    allCompleted ? Icons.check_circle_rounded : Icons.map_rounded,
                    color: allCompleted ? UiTone.success : UiTone.accentBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          allCompleted
                              ? '🎉 Shift Completed • 100% Drops Delivered!'
                              : 'TSP Shortest Path Navigation 🚀',
                          style: UiText.bodyStrong.copyWith(
                            fontSize: 11.5,
                            color: allCompleted ? UiTone.success : UiTone.accentBlue,
                          ),
                        ),
                        Text(
                          allCompleted
                              ? 'Tap to navigate return to $hubName for crate reconciliation'
                              : 'Saved ${_tspResult.distanceSavedKm.toStringAsFixed(1)} km & ${_tspResult.fuelSavedLiters.toStringAsFixed(2)}L fuel (${tasks.length} Drops)',
                          style: UiText.body.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: allCompleted ? UiTone.success : UiTone.successSoft,
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      allCompleted
                          ? '100% Done'
                          : '${tasks.where((t) => t.isDelivered).length}/${tasks.length} Done',
                      style: UiText.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: allCompleted ? Colors.white : UiTone.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Card: Shift Completed Return-to-Depot vs Selected Stop ──
          if (allCompleted)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: UiInsetCard(
                padding: const EdgeInsets.all(18),
                radius: UiRadius.lg,
                borderColor: UiTone.success.withValues(alpha: 0.4),
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
                            color: UiTone.successSoft,
                            borderRadius: BorderRadius.circular(UiRadius.xs),
                          ),
                          child: Text(
                            'SHIFT COMPLETED',
                            style: UiText.caption.copyWith(color: UiTone.success, fontWeight: FontWeight.w900, fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All ${tasks.length} Deliveries Done! 🎉',
                            style: UiText.bodyStrong.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'All customer milk bottles safely placed at doorsteps. Please return to $hubName to reconcile empty glass bottles and crates.',
                      style: UiText.body.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UiTone.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                        ),
                        icon: const Icon(Icons.warehouse_rounded, size: 18),
                        label: Text(
                          '🏬 Navigate Return to Depot ($hubName)',
                          style: UiText.bodyStrong.copyWith(fontSize: 13, color: Colors.white),
                        ),
                        onPressed: () {
                          _launchGoogleMapsNavigation(
                            _depotLocation.latitude,
                            _depotLocation.longitude,
                            hubName,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (selectedTask != null)
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
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UiTone.primary,
                            side: const BorderSide(color: UiTone.primary, width: 1.4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                          ),
                          icon: const Icon(Icons.forum_rounded, size: 18),
                          label: Text('Chat', style: UiText.bodyStrong.copyWith(fontSize: 13, color: UiTone.primary)),
                          onPressed: () {
                            DriverDeliveryChatSheet.show(
                              context,
                              taskId: selectedTask.id,
                              customerName: selectedTask.customerName,
                              customerPhone: selectedTask.customerPhone,
                              driverName: widget.state.currentUser?.name ?? 'Delivery Partner',
                              driverPhone: widget.state.currentUser?.phone ?? '',
                              deliveryAddress: selectedTask.deliveryAddress,
                              orderSummary: selectedTask.productName.isNotEmpty ? selectedTask.productName : 'Milk Drop',
                              slotTime: selectedTask.slotTime,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UiTone.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                            ),
                            icon: const Icon(Icons.navigation, size: 18),
                            label: Text('Navigate', style: UiText.bodyStrong.copyWith(fontSize: 13, color: Colors.white)),
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
