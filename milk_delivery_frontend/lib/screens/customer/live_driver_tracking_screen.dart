import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import 'help_support_screen.dart';

class LiveDriverTrackingScreen extends StatefulWidget {
  final AppState state;
  final LiveOrderModel? liveOrder;
  final String orderTitle;
  final String deliveryAddress;
  final String driverName;
  final String driverPhone;
  final String deliveryOtp;

  const LiveDriverTrackingScreen({
    super.key,
    required this.state,
    this.liveOrder,
    this.orderTitle = 'Fresh Farm Milk & Morning Essentials',
    this.deliveryAddress = 'Doorstep Delivery Location',
    this.driverName = 'Assigned Partner',
    this.driverPhone = '',
    this.deliveryOtp = '4892',
  });

  @override
  State<LiveDriverTrackingScreen> createState() => _LiveDriverTrackingScreenState();
}

class _LiveDriverTrackingScreenState extends State<LiveDriverTrackingScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late final AnimationController _radarAnimController;

  // Customer doorstep coordinates (Jubilee Hills, Hyderabad default or user profile GPS)
  late LatLng _customerLocation;

  // Driver moving coordinates
  late LatLng _driverLocation;

  // Route polyline coordinates simulating real road path
  late List<LatLng> _routePoints;
  int _currentRouteIndex = 0;
  Timer? _driverMovementTimer;

  int _etaMinutes = 14;
  double _distanceKm = 2.4;


  @override
  void initState() {
    super.initState();
    // GoogleMapController set via onMapCreated

    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    final userLat = widget.state.currentUser?.latitude ?? 17.4319;
    final userLon = widget.state.currentUser?.longitude ?? 78.4073;
    _customerLocation = LatLng(userLat, userLon);

    // Initial driver spawn location (~2.4 km away in Banjara Hills / Madhapur)
    _driverLocation = LatLng(_customerLocation.latitude - 0.016, _customerLocation.longitude - 0.018);

    // Pre-calculate realistic waypoint path to customer doorstep
    _generateRouteWaypoints();

    // Start live continuous simulation of moving driver
    _startDriverTrackingSimulation();
  }

  void _generateRouteWaypoints() {
    final start = _driverLocation;
    final end = _customerLocation;

    _routePoints = [
      start,
      LatLng(start.latitude + 0.003, start.longitude + 0.002),
      LatLng(start.latitude + 0.006, start.longitude + 0.005),
      LatLng(start.latitude + 0.009, start.longitude + 0.009),
      LatLng(start.latitude + 0.012, start.longitude + 0.013),
      LatLng(start.latitude + 0.014, start.longitude + 0.016),
      end,
    ];
  }

  void _startDriverTrackingSimulation() {
    _driverMovementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;

      if (_currentRouteIndex < _routePoints.length - 1) {
        setState(() {
          _currentRouteIndex++;
          _driverLocation = _routePoints[_currentRouteIndex];

          if (_etaMinutes > 2) _etaMinutes -= 2;
          if (_distanceKm > 0.3) _distanceKm = (_distanceKm - 0.35).clamp(0.1, 10.0);
        });

        // Smoothly adjust map view between driver & customer
        final centerLat = (_driverLocation.latitude + _customerLocation.latitude) / 2;
        final centerLon = (_driverLocation.longitude + _customerLocation.longitude) / 2;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLon), 15.0));
      } else {
        // Driver has reached doorstep
        setState(() {
          _etaMinutes = 1;
          _distanceKm = 0.1;
        });
      }
    });
  }

  @override
  void dispose() {
    _driverMovementTimer?.cancel();
    _radarAnimController.dispose();
    super.dispose();
  }

  void _callDriver() async {
    final cleanPhone = widget.driverPhone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.ink,
      appBar: AppBar(
        backgroundColor: UiTone.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UiTone.surface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live GPS Delivery Radar', style: TextStyle(color: UiTone.surface, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('🟢 Real-Time Driver Tracking Active', style: TextStyle(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Live Support',
            icon: const Icon(Icons.support_agent_rounded, color: UiTone.surface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => HelpSupportScreen(state: widget.state, initialTopic: 'I am tracking my live order delivery'),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── 1. Google Maps Real-Time Map ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (_driverLocation.latitude + _customerLocation.latitude) / 2,
                (_driverLocation.longitude + _customerLocation.longitude) / 2,
              ),
              zoom: 14.8,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              // Customer Doorstep Pin
              Marker(
                markerId: const MarkerId('customer'),
                position: _customerLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: 'Your Doorstep'),
              ),
              // Moving Driver Marker
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: InfoWindow(title: widget.driverName, snippet: '🛵 On the way'),
              ),
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                width: 5,
                color: UiTone.primary,
              ),
            },
          ),

          // ── 2. Top Floating ETA Card ──
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: UiTone.ink.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                boxShadow: UiShadow.elevated,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: UiTone.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                        ),
                        child: const Icon(Icons.electric_bolt_rounded, color: UiTone.secondary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _distanceKm <= 0.1 ? 'Arrived at Doorstep!' : 'Arriving in $_etaMinutes mins',
                            style: const TextStyle(color: UiTone.surface, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} km away • Speed 32 km/h',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: UiTone.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('OTP', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800)),
                        Text(widget.deliveryOtp, style: const TextStyle(color: UiTone.surface, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Bottom Sliding Driver Details & Order Card ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              decoration: const BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: UiShadow.floating,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Progress Tracker
                  Row(
                    children: [
                      _buildProgressStep('Packed', true),
                      _buildProgressLine(true),
                      _buildProgressStep('On Way', true),
                      _buildProgressLine(_distanceKm <= 0.1),
                      _buildProgressStep('Doorstep', _distanceKm <= 0.1),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Driver Details Tile
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UiTone.shellBackground,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: UiTone.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: UiTone.primary.withValues(alpha: 0.15),
                          child: const Text('👨‍🌾', style: TextStyle(fontSize: 22)),
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
                                      widget.driverName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded, color: UiTone.secondary, size: 14),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                                  SizedBox(width: 2),
                                  Text('4.9 Rating • TS 09 EQ 4821 (EV Scooter)', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _callDriver,
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: UiTone.secondary,
                              borderRadius: BorderRadius.circular(UiRadius.sm),
                              boxShadow: UiShadow.glowPrimary,
                            ),
                            child: const Icon(Icons.call_rounded, color: UiTone.surface, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delivery Location Strip
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: UiTone.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.deliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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

  Widget _buildProgressStep(String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isCompleted ? UiTone.primary : UiTone.surfaceBorder,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 10, color: isCompleted ? Colors.white : Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isCompleted ? UiTone.primary : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 3,
        color: isCompleted ? UiTone.primary : UiTone.surfaceBorder,
        margin: const EdgeInsets.only(bottom: 14),
      ),
    );
  }
}
