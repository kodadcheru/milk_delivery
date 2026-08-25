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

  // Customer doorstep coordinates
  late LatLng _customerLocation;

  // Driver moving coordinates
  late LatLng _driverLocation;

  // Route polyline coordinates simulating real road path
  late List<LatLng> _routePoints;
  int _currentRouteIndex = 0;
  Timer? _driverMovementTimer;

  int _etaMinutes = 12;
  double _distanceKm = 2.1;
  bool _isTrafficEnabled = false;

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

    // 1. Dynamically resolve Customer Doorstep    // Hardcoded to Kodad coordinates
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

    // 2. Dynamically resolve Location Hub / Driver Starting GPS Coordinates
    double originLat = custLat - 0.015;
    double originLon = custLon - 0.018;

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

    // 4. Generate dynamic road-interpolated waypoints
    _generateRouteWaypoints();
    _startDriverTrackingSimulation();
  }

  void _generateRouteWaypoints() {
    final start = _driverLocation;
    final end = _customerLocation;
    const steps = 12;
    final points = <LatLng>[start];

    final deltaLat = (end.latitude - start.latitude) / steps;
    final deltaLon = (end.longitude - start.longitude) / steps;

    for (int i = 1; i < steps; i++) {
      // Introduce subtle curvature mimicking urban road grid
      final curve = sin(i * pi / steps) * 0.0015;
      points.add(
        LatLng(
          start.latitude + (deltaLat * i) + curve,
          start.longitude + (deltaLon * i) - (curve * 0.4),
        ),
      );
    }
    points.add(end);
    _routePoints = points;
  }

  void _startDriverTrackingSimulation() {
    _driverMovementTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;

      if (_currentRouteIndex < _routePoints.length - 1) {
        setState(() {
          _currentRouteIndex++;
          _driverLocation = _routePoints[_currentRouteIndex];
          _distanceKm = RouteOptimizer.calculateDistanceKm(
            _driverLocation.latitude,
            _driverLocation.longitude,
            _customerLocation.latitude,
            _customerLocation.longitude,
          );
          _etaMinutes = ((_distanceKm / 22.0) * 60).ceil().clamp(1, 60);
        });

        final centerLat = (_driverLocation.latitude + _customerLocation.latitude) / 2;
        final centerLon = (_driverLocation.longitude + _customerLocation.longitude) / 2;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLon), 15.2),
        );
      } else {
        setState(() {
          _distanceKm = 0.0;
          _etaMinutes = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _driverMovementTimer?.cancel();
    _pulseAnimController.dispose();
    super.dispose();
  }

  void _centerMap() {
    final centerLat = (_driverLocation.latitude + _customerLocation.latitude) / 2;
    final centerLon = (_driverLocation.longitude + _customerLocation.longitude) / 2;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLon), 15.2),
    );
  }

  void _callDriver() async {
    final phone = widget.driverPhone.isNotEmpty ? widget.driverPhone : (widget.liveOrder?.driverPhone ?? widget.subscriptionTask?.driverDetail?.phone ?? '');
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: UiTone.primary, content: Text('📞 Dialing: $phone')),
        );
      }
    }
  }

  void _sendWhatsAppMessage() async {
    final phone = widget.driverPhone.isNotEmpty ? widget.driverPhone : (widget.liveOrder?.driverPhone ?? widget.subscriptionTask?.driverDetail?.phone ?? '');
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final dName = widget.driverName.isNotEmpty ? widget.driverName : (widget.liveOrder?.driverName ?? widget.subscriptionTask?.driverDetail?.firstName ?? 'Delivery Partner');
    final msg = Uri.encodeComponent(
      'Hi $dName, I am tracking my MilkDrop order. Please deliver to: ${widget.deliveryAddress}. Thank you!',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.')),
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
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: InfoWindow(title: '🛵 $driverName', snippet: 'On the way'),
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
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                        const SizedBox(width: 3),
                                        Text('4.9 (1,240 drops) • 🛵 EV Scooter', style: UiText.caption.copyWith(fontSize: 11.5, color: UiTone.softText)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Reg: TS 09 EQ 4821 • FSSAI Certified', style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.primary, fontWeight: FontWeight.w700)),
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
                                      driverName: driverName,
                                      driverPhone: widget.driverPhone,
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
                          Row(
                            children: [
                              _buildLabBadge('FAT', '4.5%'),
                              const SizedBox(width: 8),
                              _buildLabBadge('SNF', '8.8%'),
                              const SizedBox(width: 8),
                              _buildLabBadge('TEMP', '4°C ❄️'),
                              const SizedBox(width: 8),
                              _buildLabBadge('SEAL', 'FSSAI ✅'),
                            ],
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

