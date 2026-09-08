import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/route_optimizer.dart';
import '../delivery_chat_sheet.dart';
import '../../screens/customer/live_driver_tracking_screen.dart';

/// Next-Gen Service-Mobile Active Booking Live Map Hero Card
/// Pinned at the top of orders & subscriptions whenever an order or daily task is in-transit.
class ActiveBookingLiveMapCard extends StatefulWidget {
  final AppState state;
  final LiveOrderModel? liveOrder;
  final DeliveryTaskModel? subscriptionTask;
  final bool isTelugu;

  const ActiveBookingLiveMapCard({
    super.key,
    required this.state,
    this.liveOrder,
    this.subscriptionTask,
    this.isTelugu = false,
  });

  @override
  State<ActiveBookingLiveMapCard> createState() => _ActiveBookingLiveMapCardState();
}

class _ActiveBookingLiveMapCardState extends State<ActiveBookingLiveMapCard> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late final AnimationController _pulseController;
  Timer? _gpsPollingTimer;

  late LatLng _customerLocation;
  late LatLng _driverLocation;
  List<LatLng> _routePoints = [];

  int _etaMinutes = 10;
  double _distanceKm = 1.8;
  int _dropsAhead = 0;
  String _driverName = '';
  String _driverPhone = '';
  String _vehicleNumber = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initCoordinatesAndData();
    _fetchLiveDriverGps();
    _gpsPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLiveDriverGps());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gpsPollingTimer?.cancel();
    super.dispose();
  }

  void _initCoordinatesAndData() {
    // 1. Resolve Customer coordinates from order, subscription task, active address, or app state
    double custLat = 17.001734;
    double custLon = 79.9625;

    if (widget.subscriptionTask != null && widget.subscriptionTask!.customerLatitude != 0) {
      custLat = widget.subscriptionTask!.customerLatitude;
      custLon = widget.subscriptionTask!.customerLongitude;
    } else if (widget.liveOrder != null && widget.liveOrder!.deliveryLatitude != 0) {
      custLat = widget.liveOrder!.deliveryLatitude;
      custLon = widget.liveOrder!.deliveryLongitude;
    } else if (widget.state.activeAddress != null && widget.state.activeAddress!.latitude != 0) {
      custLat = widget.state.activeAddress!.latitude;
      custLon = widget.state.activeAddress!.longitude;
    } else if (widget.state.currentUser?.latitude != null && widget.state.currentUser!.latitude != 0) {
      custLat = widget.state.currentUser!.latitude;
      custLon = widget.state.currentUser!.longitude;
    } else if (widget.state.currentLat != 0) {
      custLat = widget.state.currentLat;
      custLon = widget.state.currentLon;
    }

    _customerLocation = LatLng(custLat, custLon);

    // Initial driver location offset
    _driverLocation = LatLng(
      custLat - 0.012,
      custLon - 0.009,
    );

    // Initial metadata
    if (widget.liveOrder != null) {
      _driverName = widget.liveOrder!.driverName.isNotEmpty ? widget.liveOrder!.driverName : 'Assigned Partner';
      _driverPhone = widget.liveOrder!.driverPhone;
      _vehicleNumber = widget.liveOrder!.driverVehicle;
      if (widget.liveOrder!.etaMinutes > 0) {
        _etaMinutes = widget.liveOrder!.etaMinutes;
      }
    } else if (widget.subscriptionTask != null) {
      _driverName = widget.subscriptionTask!.driverDetail?.fullName.isNotEmpty == true
          ? widget.subscriptionTask!.driverDetail!.fullName
          : 'Assigned Partner';
      _driverPhone = widget.subscriptionTask!.driverDetail?.phone ?? '';
      _dropsAhead = widget.subscriptionTask!.dropsAhead;
    }

    _distanceKm = RouteOptimizer.calculateDistanceKm(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _customerLocation.latitude,
      _customerLocation.longitude,
    );
    if (_etaMinutes <= 0) {
      _etaMinutes = ((_distanceKm / 20.0) * 60).ceil().clamp(2, 45);
    }

    _routePoints = [_driverLocation, _customerLocation];
    _fetchRoadPolyline();
  }

  Future<void> _fetchRoadPolyline() async {
    try {
      final poly = await RouteOptimizer.fetchRealRoadPolyline([_driverLocation, _customerLocation]);
      if (mounted && poly.isNotEmpty) {
        setState(() {
          _routePoints = poly;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchLiveDriverGps() async {
    if (!mounted) return;
    try {
      final orderId = widget.liveOrder?.id ?? widget.subscriptionTask?.id.toString();
      final driverId = widget.subscriptionTask?.driverId ?? widget.subscriptionTask?.driverDetail?.id;

      final locData = await ApiService.fetchDriverLiveLocation(
        orderId: orderId,
        driverId: driverId,
      );

      if (locData != null && mounted) {
        final lat = (locData['latitude'] is num)
            ? (locData['latitude'] as num).toDouble()
            : double.tryParse(locData['latitude']?.toString() ?? '');
        final lng = (locData['longitude'] is num)
            ? (locData['longitude'] as num).toDouble()
            : double.tryParse(locData['longitude']?.toString() ?? '');

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          final newDriverLoc = LatLng(lat, lng);
          final updatedDist = RouteOptimizer.calculateDistanceKm(
            lat,
            lng,
            _customerLocation.latitude,
            _customerLocation.longitude,
          );

          setState(() {
            _driverLocation = newDriverLoc;
            _distanceKm = updatedDist;
            _etaMinutes = ((_distanceKm / 20.0) * 60).ceil().clamp(1, 45);

            if (locData['driver_name'] != null && locData['driver_name'].toString().isNotEmpty) {
              _driverName = locData['driver_name'].toString();
            }
            if (locData['driver_phone'] != null && locData['driver_phone'].toString().isNotEmpty) {
              _driverPhone = locData['driver_phone'].toString();
            }
            if (locData['vehicle_number'] != null && locData['vehicle_number'].toString().isNotEmpty) {
              _vehicleNumber = locData['vehicle_number'].toString();
            }
            if (locData['drops_ahead'] != null) {
              _dropsAhead = int.tryParse(locData['drops_ahead'].toString()) ?? _dropsAhead;
            }
          });

          _updateMapBounds();
        }
      }
    } catch (_) {}
  }

  void _updateMapBounds() {
    if (_mapController == null) return;
    final minLat = min(_driverLocation.latitude, _customerLocation.latitude) - 0.002;
    final maxLat = max(_driverLocation.latitude, _customerLocation.latitude) + 0.002;
    final minLng = min(_driverLocation.longitude, _customerLocation.longitude) - 0.002;
    final maxLng = max(_driverLocation.longitude, _customerLocation.longitude) + 0.002;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        35,
      ),
    );
  }

  void _openFullTracking() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveDriverTrackingScreen(
          state: widget.state,
          liveOrder: widget.liveOrder,
          subscriptionTask: widget.subscriptionTask,
          orderTitle: widget.liveOrder != null
              ? (widget.liveOrder!.items.isNotEmpty ? widget.liveOrder!.items.first.product.name : 'Express Order')
              : (widget.subscriptionTask?.productName ?? 'Morning Milk Delivery'),
          deliveryAddress: widget.liveOrder?.deliveryAddress ?? widget.subscriptionTask?.deliveryAddress ?? 'Doorstep Location',
          driverName: _driverName,
          driverPhone: _driverPhone,
          deliveryOtp: widget.liveOrder?.deliveryOtp ?? '',
        ),
      ),
    );
  }

  Future<void> _callDriver() async {
    HapticFeedback.lightImpact();
    final phone = _driverPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(widget.isTelugu ? 'డ్రైవర్ ఫోన్ నంబర్ ఇంకా అందుబాటులో లేదు' : 'Driver phone number is not available yet'),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat() {
    HapticFeedback.lightImpact();
    DeliveryChatSheet.show(
      context,
      orderId: widget.liveOrder?.id,
      taskId: widget.subscriptionTask?.id,
      driverName: _driverName.isNotEmpty ? _driverName : 'Delivery Partner',
      driverPhone: _driverPhone,
      customerName: widget.state.currentUser?.fullName ?? 'Customer',
      customerPhone: widget.state.currentUser?.phone ?? '',
      orderTitle: widget.liveOrder != null
          ? 'Express Order #${widget.liveOrder!.id}'
          : 'Daily Drop #${widget.subscriptionTask?.id}',
      deliveryAddress: widget.liveOrder?.deliveryAddress ?? widget.subscriptionTask?.deliveryAddress ?? '',
    );
  }

  void _copyOtp(String otp) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: otp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D7C66),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(widget.isTelugu ? 'OTP $otp కాపీ చేయబడింది! డ్రైవర్‌తో పంచుకోండి.' : 'OTP $otp copied! Share with driver.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTelugu = widget.isTelugu;
    final orderId = widget.liveOrder?.id ?? (widget.subscriptionTask != null ? '#${widget.subscriptionTask!.id}' : '');
    final otp = widget.liveOrder?.deliveryOtp ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Header with live status & ETA ──
          GestureDetector(
            onTap: _openFullTracking,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D7C66), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Animated Pulsing Beacon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2 + (_pulseController.value * 0.25)),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🛵', style: TextStyle(fontSize: 18)),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isTelugu ? 'డ్రైవర్ దారిలో ఉన్నారు!' : 'Driver on the way!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            if (_dropsAhead > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isTelugu ? '$_dropsAhead స్టాప్ దూరంలో' : '$_dropsAhead stops away',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.liveOrder != null ? 'Express Order $orderId' : 'Morning Drop $orderId',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Dynamic ETA Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF0D7C66)),
                        const SizedBox(width: 2),
                        Text(
                          '~$_etaMinutes min',
                          style: const TextStyle(
                            color: Color(0xFF0D7C66),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Embedded Google Map Preview (Interactive & Expandable) ──
          GestureDetector(
            onTap: _openFullTracking,
            behavior: HitTestBehavior.translucent,
            child: SizedBox(
              height: 140,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (_driverLocation.latitude + _customerLocation.latitude) / 2,
                        (_driverLocation.longitude + _customerLocation.longitude) / 2,
                      ),
                      zoom: 14.2,
                    ),
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) _updateMapBounds();
                      });
                    },
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('customer_dest'),
                        position: _customerLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        infoWindow: const InfoWindow(title: '🏠 Your Doorstep'),
                      ),
                      Marker(
                        markerId: const MarkerId('driver_pos'),
                        position: _driverLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                        infoWindow: InfoWindow(title: '🛵 $_driverName'),
                      ),
                    },
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('preview_route'),
                        points: _routePoints,
                        width: 4,
                        color: const Color(0xFF0D7C66),
                        jointType: JointType.round,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                      ),
                    },
                  ),
                  // Tap to expand floating badge overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            isTelugu ? 'మ్యాప్ విస్తరించు' : 'Tap to expand',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Distance badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Text(
                        '📍 ${_distanceKm.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Bottom Driver Info & Quick Action Controls ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                // Partner Avatar + Details
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('👨🏽‍🌾', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverName.isNotEmpty ? _driverName : (isTelugu ? 'డెలివరీ భాగస్వామి' : 'Delivery Partner'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _vehicleNumber.isNotEmpty ? _vehicleNumber : (isTelugu ? 'ఎక్స్‌ప్రెస్ వెహికల్' : 'Express Delivery'),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // OTP Chip (if present)
                if (otp.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _copyOtp(otp),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'OTP',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            otp,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Action: In-App Chat
                InkWell(
                  onTap: _openChat,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF0D7C66)),
                  ),
                ),
                const SizedBox(width: 6),

                // Action: Direct Phone Call
                InkWell(
                  onTap: _callDriver,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(Icons.call_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
