import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/route_optimizer.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/delivery_chat_sheet.dart';
import 'help_support_screen.dart';

import '../../services/api_service.dart';

class LiveDriverTrackingScreen extends StatefulWidget {
  final AppState state;
  final LiveOrderModel? liveOrder;
  final DeliveryTaskModel? subscriptionTask;
  final String orderTitle;
  final String deliveryAddress;
  final String driverName;
  final String driverPhone;
  final String deliveryOtp;

  const LiveDriverTrackingScreen({
    super.key,
    required this.state,
    this.liveOrder,
    this.subscriptionTask,
    this.orderTitle = 'Fresh Farm Milk & Morning Essentials',
    this.deliveryAddress = 'Doorstep Delivery Location',
    this.driverName = '',
    this.driverPhone = '',
    this.deliveryOtp = '',
  });

  @override
  State<LiveDriverTrackingScreen> createState() => _LiveDriverTrackingScreenState();
}

class _LiveDriverTrackingScreenState extends State<LiveDriverTrackingScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late final AnimationController _pulseAnimController;
  late final Animation<double> _pulseAnimation;
  AnimationController? _markerAnimController;
  Animation<double>? _markerAnimation;

  // Customer doorstep coordinates
  late LatLng _customerLocation;

  // Driver moving coordinates
  late LatLng _driverLocation;
  double _driverBearing = 0.0;

  // Route polyline coordinates simulating real road path
  List<LatLng> _routePoints = [];
  Timer? _liveGpsTimer;

  int _etaMinutes = 12;
  double _distanceKm = 2.1;
  bool _isTrafficEnabled = false;
  String _driverStatusText = 'On the way';

  @override
  void initState() {
    super.initState();

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );

    // 1. Dynamically resolve Customer Doorstep (Real address coordinates)
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
      custLat = widget.state.currentUser!.latitude!;
      custLon = widget.state.currentUser!.longitude!;
    } else if (widget.state.currentLat != 0) {
      custLat = widget.state.currentLat;
      custLon = widget.state.currentLon;
    }
    _customerLocation = LatLng(custLat, custLon);

    // 2. Dynamically resolve Driver / Hub Starting Location
    double originLat = custLat - 0.008;
    double originLon = custLon - 0.009;

    if (widget.subscriptionTask?.driverDetail?.latitude != null && widget.subscriptionTask!.driverDetail!.latitude != 0) {
      originLat = widget.subscriptionTask!.driverDetail!.latitude;
      originLon = widget.subscriptionTask!.driverDetail!.longitude;
    } else if (widget.state.locationHubs.isNotEmpty) {
      final hub = widget.state.locationHubs.first;
      final hLat = hub['latitude'];
      final hLon = hub['longitude'];
      if (hLat != null && hLon != null) {
        originLat = (hLat is num) ? hLat.toDouble() : (double.tryParse(hLat.toString()) ?? originLat);
        originLon = (hLon is num) ? hLon.toDouble() : (double.tryParse(hLon.toString()) ?? originLon);
      }
    }
    _driverLocation = LatLng(originLat, originLon);

    // 3. Compute real-time Haversine distance and dynamic ETA
    _distanceKm = RouteOptimizer.calculateDistanceKm(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _customerLocation.latitude,
      _customerLocation.longitude,
    );
    _etaMinutes = ((_distanceKm / 22.0) * 60).ceil().clamp(1, 60);

    // 4. Load initial real road polyline
    _routePoints = [_driverLocation, _customerLocation];
    _fetchRealRoadNetwork();

    // 5. Start real-time live GPS polling
    _fetchLiveDriverGps();
    _liveGpsTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLiveDriverGps());
  }

  Future<void> _fetchLiveDriverGps() async {
    if (!mounted) return;

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

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        final newPos = LatLng(lat, lng);
        final distanceMoved = RouteOptimizer.calculateDistanceKm(
          _driverLocation.latitude,
          _driverLocation.longitude,
          lat,
          lng,
        );

        if (distanceMoved > 0.003) {
          _animateDriverMarkerTo(newPos);
          final remainingKm = RouteOptimizer.calculateDistanceKm(
            lat,
            lng,
            _customerLocation.latitude,
            _customerLocation.longitude,
          );

          setState(() {
            _distanceKm = remainingKm;
            _etaMinutes = ((_distanceKm / 22.0) * 60).ceil().clamp(1, 60);
            if (locData['driver_status'] != null) {
              _driverStatusText = locData['driver_status'].toString();
            }
          });

          if (distanceMoved > 0.03) {
            _fetchRealRoadNetwork();
          }
        }
      }
    }
  }

  void _animateDriverMarkerTo(LatLng newPosition) {
    final bearing = _calculateBearing(_driverLocation, newPosition);
    final startPos = _driverLocation;

    _markerAnimController?.dispose();
    _markerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _markerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _markerAnimController!, curve: Curves.easeInOut),
    )..addListener(() {
        if (!mounted) return;
        final t = _markerAnimation?.value ?? 1.0;
        final curLat = startPos.latitude + (newPosition.latitude - startPos.latitude) * t;
        final curLng = startPos.longitude + (newPosition.longitude - startPos.longitude) * t;
        setState(() {
          _driverLocation = LatLng(curLat, curLng);
          if (bearing != 0.0) _driverBearing = bearing;
        });
      });

    _markerAnimController!.forward();
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180.0;
    final lon1 = start.longitude * pi / 180.0;
    final lat2 = end.latitude * pi / 180.0;
    final lon2 = end.longitude * pi / 180.0;

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    return (radians * 180.0 / pi + 360.0) % 360.0;
  }

  Future<void> _fetchRealRoadNetwork() async {
    try {
      final realRoads = await RouteOptimizer.fetchRealRoadPolyline([_driverLocation, _customerLocation]);
      if (mounted && realRoads.length > 1) {
        setState(() {
          _routePoints = realRoads;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _liveGpsTimer?.cancel();
    _markerAnimController?.dispose();
    _pulseAnimController.dispose();
    super.dispose();
  }

  void _centerMap() {
    if (_mapController == null) return;
    final southWestLat = min(_driverLocation.latitude, _customerLocation.latitude) - 0.003;
    final southWestLon = min(_driverLocation.longitude, _customerLocation.longitude) - 0.003;
    final northEastLat = max(_driverLocation.latitude, _customerLocation.latitude) + 0.003;
    final northEastLon = max(_driverLocation.longitude, _customerLocation.longitude) + 0.003;

    final bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLon),
      northeast: LatLng(northEastLat, northEastLon),
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 70),
    );
  }

  void _callDriver() async {
    HapticFeedback.lightImpact();
    final phone = widget.driverPhone.isNotEmpty
        ? widget.driverPhone
        : (widget.liveOrder?.driverPhone ?? widget.subscriptionTask?.driverDetail?.phone ?? '');

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Delivery partner contact number is not available yet.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Could not open phone dialer for $phone')),
        );
      }
    }
  }

  void _sendWhatsAppMessage() async {
    HapticFeedback.lightImpact();
    final phone = widget.driverPhone.isNotEmpty
        ? widget.driverPhone
        : (widget.liveOrder?.driverPhone ?? widget.subscriptionTask?.driverDetail?.phone ?? '');

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Delivery partner WhatsApp number is not available yet.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = '91${cleanPhone.substring(1)}';
    }

    final dName = widget.driverName.isNotEmpty
        ? widget.driverName
        : (widget.liveOrder?.driverName ?? widget.subscriptionTask?.driverDetail?.firstName ?? 'Delivery Partner');
    final orderId = widget.liveOrder?.id ?? (widget.subscriptionTask != null ? '#${widget.subscriptionTask!.id}' : '');

    final msgText = 'Hi $dName, I am tracking my MilkDrop Express Order $orderId. Please deliver to: ${widget.deliveryAddress}. Thank you!';
    final encodedMsg = Uri.encodeComponent(msgText);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final altUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg');
        await launchUrl(altUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp. Please ensure WhatsApp is installed.')),
        );
      }
    }
  }

  void _copyOtp() {
    final otp = widget.deliveryOtp.isNotEmpty ? widget.deliveryOtp : (widget.liveOrder?.deliveryOtp ?? '');
    Clipboard.setData(ClipboardData(text: otp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: UiTone.primary,
        content: Text('🔑 OTP $otp copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered = _distanceKm <= 0.1 ||
        (widget.liveOrder?.status == 'DELIVERED') ||
        (widget.subscriptionTask?.status == 'DELIVERED');

    final driverName = widget.driverName.isNotEmpty ? widget.driverName : (widget.liveOrder?.driverName ?? widget.subscriptionTask?.driverDetail?.firstName ?? 'Assigned Partner');
    final resolvedAddress = widget.deliveryAddress.isNotEmpty ? widget.deliveryAddress : 'Doorstep Delivery Location';
    final otp = widget.deliveryOtp.isNotEmpty ? widget.deliveryOtp : (widget.liveOrder?.deliveryOtp ?? '');

    return Scaffold(
      backgroundColor: UiTone.ink,
      body: Stack(
        children: [
          // ── 1. Full Screen Interactive Map ──
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
            trafficEnabled: _isTrafficEnabled,
            markers: {
              Marker(
                markerId: const MarkerId('customer'),
                position: _customerLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: '📍 Your Doorstep Delivery'),
              ),
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverLocation,
                rotation: _driverBearing,
                flat: true,
                anchor: const Offset(0.5, 0.5),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: InfoWindow(
                  title: '🛵 $driverName',
                  snippet: '$_driverStatusText • $_etaMinutes mins (${_distanceKm.toStringAsFixed(1)} km)',
                ),
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

          // ── 2. Top Floating Navigation & Radar Controls ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Back Button with Glassmorphism
                  Container(
                    decoration: BoxDecoration(
                      color: UiTone.ink.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: UiShadow.card,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Live GPS Radar Status Pill
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: UiTone.ink.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        boxShadow: UiShadow.card,
                      ),
                      child: Row(
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: UiTone.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDelivered ? '📍 Reached Doorstep' : '🟢 Live Delivery Radar',
                              style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Map Re-Center Button
                  Container(
                    decoration: BoxDecoration(
                      color: UiTone.ink.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: UiShadow.card,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: UiTone.primary, size: 20),
                      tooltip: 'Center on Route',
                      onPressed: _centerMap,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Support Emergency Button
                  Container(
                    decoration: BoxDecoration(
                      color: UiTone.ink.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: UiShadow.card,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 20),
                      tooltip: 'Help Desk',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => HelpSupportScreen(
                              state: widget.state,
                              initialTopic: 'Live delivery partner tracking inquiry',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Draggable Mobility Booking Sheet ──
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.22,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.22, 0.44, 0.88],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: UiTone.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: UiShadow.floating,
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  children: [
                    // Grab Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: UiTone.surfaceBorder,
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                        ),
                      ),
                    ),

                    // ── A. ETA & Secret Doorstep OTP Banner ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: UiGradient.hero,
                        borderRadius: BorderRadius.circular(UiRadius.xl),
                        boxShadow: UiShadow.glowPrimary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                ),
                                child: const Text('⚡', style: TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDelivered ? 'Arrived at Doorstep!' : 'Arriving in $_etaMinutes Mins',
                                    style: UiText.h2.copyWith(color: Colors.white, fontSize: 17),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_distanceKm.toStringAsFixed(1)} km away • Farm Chilled 4°C',
                                    style: UiText.caption.copyWith(color: Colors.white70, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Doorstep OTP Badge with Copy
                          GestureDetector(
                            onTap: _copyOtp,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(UiRadius.md),
                                boxShadow: UiShadow.card,
                              ),
                              child: Column(
                                children: [
                                  Text('DOORSTEP OTP', style: UiText.caption.copyWith(color: UiTone.primary, fontSize: 8.5, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text(
                                    otp,
                                    style: UiText.h1.copyWith(color: UiTone.primary, letterSpacing: 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── B. 5-Stage Live Order Stepper ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: UiTone.shellBackground,
                        borderRadius: BorderRadius.circular(UiRadius.lg),
                        border: Border.all(color: UiTone.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Live Delivery Progress', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: UiTone.primarySoft,
                                  borderRadius: BorderRadius.circular(UiRadius.xs),
                                ),
                                child: Text('🧪 LAB TESTED BATCH', style: UiText.caption.copyWith(color: UiTone.primary, fontSize: 9.5, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildStepIndicator('1. Tested', true, Icons.science_rounded),
                              _buildStepLine(true),
                              _buildStepIndicator('2. Packed', true, Icons.inventory_2_rounded),
                              _buildStepLine(true),
                              _buildStepIndicator('3. On Route', true, Icons.moped_rounded),
                              _buildStepLine(_distanceKm <= 0.3),
                              _buildStepIndicator('4. Doorstep', _distanceKm <= 0.3, Icons.door_front_door_rounded),
                              _buildStepLine(isDelivered),
                              _buildStepIndicator('5. Verified', isDelivered, Icons.verified_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── C. Delivery Partner Identity & Vehicle Card ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: UiTone.surface,
                        borderRadius: BorderRadius.circular(UiRadius.xl),
                        border: Border.all(color: UiTone.surfaceBorder),
                        boxShadow: UiShadow.card,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: UiTone.primarySoft,
                                    child: const Text('👨‍🌾', style: TextStyle(fontSize: 26)),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: UiTone.secondary, shape: BoxShape.circle),
                                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            driverName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: UiText.h2.copyWith(fontSize: 15.5),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: UiTone.successSoft,
                                            borderRadius: BorderRadius.circular(UiRadius.xs),
                                          ),
                                          child: Text('VERIFIED', style: UiText.caption.copyWith(color: UiTone.success, fontSize: 9, fontWeight: FontWeight.w900)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 12, color: UiTone.softText),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.driverPhone.isNotEmpty ? widget.driverPhone : (widget.liveOrder?.driverPhone.isNotEmpty == true ? widget.liveOrder!.driverPhone : 'Assigned Partner'),
                                          style: UiText.caption.copyWith(fontSize: 11.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                        const SizedBox(width: 3),
                                        Text('4.9 ★', style: UiText.caption.copyWith(fontSize: 11, color: UiTone.softText, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '🛵 ${widget.liveOrder?.driverVehicle ?? "Electric Scooter (TS 09 EB 4092)"} • Hub Delivery Partner',
                                      style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.primary, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: UiTone.surfaceBorder),
                          const SizedBox(height: 12),
                          // 1-Click Call, In-App Chat & WhatsApp Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _callDriver,
                                  icon: const Icon(Icons.phone_in_talk_rounded, size: 15, color: UiTone.primary),
                                  label: Text('Call', style: UiText.label.copyWith(color: UiTone.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    side: const BorderSide(color: UiTone.primary, width: 1.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    DeliveryChatSheet.show(
                                      context,
                                      taskId: widget.subscriptionTask?.id,
                                      orderId: widget.liveOrder?.id,
                                      driverName: driverName.isNotEmpty ? driverName : 'Delivery Partner',
                                      driverPhone: widget.driverPhone.isNotEmpty ? widget.driverPhone : (widget.liveOrder?.driverPhone ?? widget.subscriptionTask?.driverDetail?.phone ?? ''),
                                      customerName: widget.state.currentUser?.name ?? 'Customer',
                                      customerPhone: widget.state.currentUser?.phone ?? '',
                                      orderTitle: widget.orderTitle,
                                      deliveryAddress: resolvedAddress,
                                    );
                                  },
                                  icon: const Icon(Icons.forum_rounded, size: 15, color: Colors.white),
                                  label: Text('Live Chat', style: UiText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: UiTone.primaryDark,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _sendWhatsAppMessage,
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.white),
                                  label: Text('WhatsApp', style: UiText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── D. Delivery Location & Instructions ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: UiTone.shellBackground,
                        borderRadius: BorderRadius.circular(UiRadius.lg),
                        border: Border.all(color: UiTone.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: UiTone.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('Doorstep Destination', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            resolvedAddress,
                            style: UiText.caption.copyWith(color: UiTone.ink, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: UiTone.warningSoft,
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                              border: Border.all(color: UiTone.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active_outlined, size: 13, color: UiTone.warning),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Instruction: Ring doorbell and place in cold insulated milk bag.',
                                    style: UiText.caption.copyWith(color: UiTone.warning, fontSize: 10.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── E. Booking Summary & Lab Parameters ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: UiTone.surface,
                        borderRadius: BorderRadius.circular(UiRadius.lg),
                        border: Border.all(color: UiTone.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order Items', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                              Text(widget.orderTitle, style: UiText.caption.copyWith(color: UiTone.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final titleLower = (widget.liveOrder?.items.map((i) => i.product.name).join(' ') ?? widget.orderTitle).toLowerCase();
                              final isMeat = titleLower.contains('meat') || titleLower.contains('chicken') || titleLower.contains('mutton') || titleLower.contains('fish');
                              final isEggs = !isMeat && titleLower.contains('egg');
                              final isWater = !isMeat && !isEggs && (titleLower.contains('water') || titleLower.contains('can') || titleLower.contains('dispenser'));

                              if (isMeat) {
                                return Row(
                                  children: [
                                    _buildLabBadge('TYPE', 'Fresh Cut'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('SAFETY', 'Antibiotic-0'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('TEMP', '4°C ❄️'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('SEAL', 'FSSAI ✅'),
                                  ],
                                );
                              }

                              if (isEggs) {
                                return Row(
                                  children: [
                                    _buildLabBadge('GRADE', 'Farm Fresh'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('FEED', '100% Grain'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('DAMAGE', '0% Guarantee'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('SEAL', 'Inspected ✅'),
                                  ],
                                );
                              }

                              if (isWater) {
                                return Row(
                                  children: [
                                    _buildLabBadge('PURITY', 'RO + UV'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('TDS', 'Balanced'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('CAN', 'BPA-Free'),
                                    const SizedBox(width: 8),
                                    _buildLabBadge('SEAL', 'Sealed ✅'),
                                  ],
                                );
                              }

                              // Default Dairy Badges
                              return Row(
                                children: [
                                  _buildLabBadge('FAT', '4.5%'),
                                  const SizedBox(width: 8),
                                  _buildLabBadge('SNF', '8.8%'),
                                  const SizedBox(width: 8),
                                  _buildLabBadge('TEMP', '4°C ❄️'),
                                  const SizedBox(width: 8),
                                  _buildLabBadge('SEAL', 'FSSAI ✅'),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool isCompleted, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isCompleted ? UiTone.primary : UiTone.surfaceBorder,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 11, color: isCompleted ? Colors.white : Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isCompleted ? UiTone.primary : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2.5,
        color: isCompleted ? UiTone.primary : UiTone.surfaceBorder,
        margin: const EdgeInsets.only(bottom: 14),
      ),
    );
  }

  Widget _buildLabBadge(String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: UiTone.surfaceMuted,
          borderRadius: BorderRadius.circular(UiRadius.xs),
          border: Border.all(color: UiTone.surfaceBorder),
        ),
        child: Column(
          children: [
            Text(title, style: UiText.caption.copyWith(fontSize: 8.5, color: UiTone.softText, fontWeight: FontWeight.w800)),
            Text(val, style: UiText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w900, color: UiTone.ink)),
          ],
        ),
      ),
    );
  }
}

