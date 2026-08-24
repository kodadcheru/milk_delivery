import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/ui_kit/ui_kit.dart';

class ProviderFleetMapScreen extends StatefulWidget {
  final AppState state;
  final List<Map<String, dynamic>> fleetDrivers;

  const ProviderFleetMapScreen({
    super.key,
    required this.state,
    required this.fleetDrivers,
  });

  @override
  State<ProviderFleetMapScreen> createState() => _ProviderFleetMapScreenState();
}

class _ProviderFleetMapScreenState extends State<ProviderFleetMapScreen> {
  GoogleMapController? _mapController;
  Map<String, dynamic>? _selectedDriver;
  late List<Map<String, dynamic>> _liveDrivers;
  Timer? _fleetTimer;

  List<Map<String, dynamic>> get _hubs {
    if (widget.state.locationHubs.isNotEmpty) {
      return widget.state.locationHubs.map((h) {
        final double rawLat = (h['latitude'] as num?)?.toDouble() ?? 17.001734;
        final double rawLng = (h['longitude'] as num?)?.toDouble() ?? 79.9625;
        // Ensure coordinates point to actual hub location instead of default Hyderabad
        final double lat = (rawLat >= 17.40 && rawLat <= 17.46 && rawLng >= 78.35 && rawLng <= 78.48)
            ? 17.001734
            : rawLat;
        final double lng = (rawLat >= 17.40 && rawLat <= 17.46 && rawLng >= 78.35 && rawLng <= 78.48)
            ? 79.9625
            : rawLng;

        return {
          'name': h['name'] ?? 'Kodad Depot',
          'code': h['hub_code'] ?? 'HUB-KDD-01',
          'lat': lat,
          'lng': lng,
          'color': UiTone.secondary,
          'radiusKm': (h['coverage_radius_km'] as num?)?.toDouble() ?? 8.5,
        };
      }).toList();
    }
    return [
      {
        'name': 'Kodad Depot',
        'code': 'HUB-KDD-01',
        'lat': 17.001734,
        'lng': 79.9625,
        'color': UiTone.secondary,
        'radiusKm': 8.5,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _liveDrivers = List.from(widget.fleetDrivers);
    _fetchLiveFleet();
    _fleetTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLiveFleet());
  }

  @override
  void dispose() {
    _fleetTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveFleet() async {
    final drivers = await ApiService.fetchFleet();
    if (drivers.isNotEmpty && mounted) {
      setState(() {
        _liveDrivers = drivers;
        if (_selectedDriver != null) {
          _selectedDriver = drivers.firstWhere(
            (d) => d['id'] == _selectedDriver!['id'],
            orElse: () => _selectedDriver!,
          );
        }
      });
    }
  }

  void _callDriver(String phone) async {
    final clean = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  double _driverMarkerHue(Map<String, dynamic> driver) {
    final lastUpdated = driver['last_location_updated'];
    if (lastUpdated == null) return BitmapDescriptor.hueRed;
    try {
      final dt = DateTime.parse(lastUpdated);
      final age = DateTime.now().difference(dt);
      if (age.inSeconds < 30) return BitmapDescriptor.hueGreen;
      if (age.inSeconds < 120) return BitmapDescriptor.hueOrange;
      return BitmapDescriptor.hueRed;
    } catch (_) {
      return BitmapDescriptor.hueRed;
    }
  }

  String _relativeTime(String? isoString) {
    if (isoString == null) return 'No GPS data';
    try {
      final dt = DateTime.parse(isoString);
      final age = DateTime.now().difference(dt);
      if (age.inSeconds < 10) return 'Just now';
      if (age.inSeconds < 60) return '${age.inSeconds}s ago';
      if (age.inMinutes < 60) return '${age.inMinutes}m ago';
      return '${age.inHours}h ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double hubLat = _hubs.isNotEmpty ? (_hubs.first['lat'] as double) : 17.001734;
    final double hubLng = _hubs.isNotEmpty ? (_hubs.first['lng'] as double) : 79.9625;

    final List<Map<String, dynamic>> driversWithCoords = [];
    final drivers = _liveDrivers.isNotEmpty
        ? _liveDrivers
        : (widget.fleetDrivers.isNotEmpty ? widget.fleetDrivers : []);

    for (int i = 0; i < drivers.length; i++) {
      final d = Map<String, dynamic>.from(drivers[i]);
      final latVal = d['latitude'] ?? d['lat'];
      final lngVal = d['longitude'] ?? d['lng'];
      // Use REAL coordinates from backend — only offset if truly missing
      if (latVal != null && lngVal != null && (latVal as num).toDouble() != 0.0 && (lngVal as num).toDouble() != 0.0) {
        d['coord'] = LatLng(latVal.toDouble(), lngVal.toDouble());
        d['is_live'] = true;
      } else {
        // Fallback offset for drivers with no GPS data
        d['coord'] = LatLng(hubLat + 0.003 * (i % 2 == 0 ? 1 : -1), hubLng + 0.003 * (i % 2 == 0 ? -1 : 1));
        d['is_live'] = false;
      }
      driversWithCoords.add(d);
    }

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
              'Live Fleet Radar & Depot Coverage',
              style: UiText.h2.copyWith(fontSize: 16, color: Colors.white),
            ),
            Text(
              '${driversWithCoords.length} Salaried Partners • ${_hubs.first['name']}',
              style: UiText.label.copyWith(fontSize: 11, color: UiTone.secondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // ── Google Maps View ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(hubLat, hubLng),
              zoom: 13.5,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            circles: _hubs.map((h) {
              return Circle(
                circleId: CircleId('hub_circle_${h['code']}'),
                center: LatLng(h['lat'], h['lng']),
                radius: 4000,
                fillColor: (h['color'] as Color).withValues(alpha: 0.12),
                strokeColor: (h['color'] as Color).withValues(alpha: 0.6),
                strokeWidth: 2,
              );
            }).toSet(),
            markers: {
              // 1. Hub Markers
              ..._hubs.map((h) {
                return Marker(
                  markerId: MarkerId('hub_${h['code']}'),
                  position: LatLng(h['lat'], h['lng']),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                  infoWindow: InfoWindow(title: '${h['name']} (${h['code']})'),
                );
              }),

              // 2. Salaried Delivery Partners
              ...driversWithCoords.map((d) {
                final isSelected = _selectedDriver != null && _selectedDriver!['id'] == d['id'];
                final LatLng pt = d['coord'] as LatLng;

                return Marker(
                  markerId: MarkerId('driver_${d['id']}'),
                  position: pt,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    isSelected ? BitmapDescriptor.hueAzure : _driverMarkerHue(d),
                  ),
                  infoWindow: InfoWindow(
                    title: d['name'] ?? 'Driver',
                    snippet: 'Salary: ${d['salary']} | Stops: ${d['completed_stops']}/${d['assigned_stops']}',
                  ),
                  onTap: () {
                    setState(() => _selectedDriver = d);
                    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pt, 14.5));
                  },
                );
              }),
            },
          ),

          // ── Bottom Driver Profile Card ──
          if (_selectedDriver != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: UiInsetCard(
                padding: const EdgeInsets.all(18),
                radius: UiRadius.lg,
                borderColor: UiTone.primary.withValues(alpha: 0.3),
                shadow: UiShadow.floating,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: UiGradient.primary,
                            borderRadius: BorderRadius.circular(UiRadius.sm),
                          ),
                          child: const Center(
                            child: Icon(Icons.delivery_dining, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDriver!['name'] ?? 'Delivery Partner',
                                style: UiText.bodyStrong.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedDriver!['hub']} • ₹15,000 / mo',
                                style: UiText.body.copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _driverMarkerHue(_selectedDriver!) == BitmapDescriptor.hueGreen
                                          ? UiTone.success
                                          : _driverMarkerHue(_selectedDriver!) == BitmapDescriptor.hueOrange
                                              ? UiTone.warning
                                              : UiTone.error,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _relativeTime(_selectedDriver!['last_location_updated']),
                                    style: UiText.caption.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: UiTone.primarySoft,
                            borderRadius: BorderRadius.circular(UiRadius.xs),
                          ),
                          child: Text(
                            '${_selectedDriver!['completed_stops'] ?? 10}/${_selectedDriver!['assigned_stops'] ?? 12} Drops',
                            style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: UiTone.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UiTone.primary,
                              foregroundColor: UiTone.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                            ),
                            icon: const Icon(Icons.phone, size: 18),
                            label: Text('Call Partner', style: UiText.label.copyWith(fontWeight: FontWeight.w700, color: UiTone.surface)),
                            onPressed: () => _callDriver(_selectedDriver!['phone'] ?? '+919123456789'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.close, color: UiTone.softText),
                          onPressed: () => setState(() => _selectedDriver = null),
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
