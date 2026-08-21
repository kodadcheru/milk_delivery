import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';

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
          'name': h['name'] ?? 'Kodad Central Depot',
          'code': h['hub_code'] ?? 'HUB-KDD-01',
          'lat': lat,
          'lng': lng,
          'color': const Color(0xFF10B981),
          'radiusKm': (h['coverage_radius_km'] as num?)?.toDouble() ?? 5.0,
        };
      }).toList();
    }
    return [
      {
        'name': 'Kodad Central Dairy Depot',
        'code': 'HUB-KDD-01',
        'lat': 17.001734,
        'lng': 79.9625,
        'color': const Color(0xFF10B981),
        'radiusKm': 5.0,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    // GoogleMapController set via onMapCreated
  }

  void _callDriver(String phone) async {
    final clean = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double hubLat = _hubs.isNotEmpty ? (_hubs.first['lat'] as double) : 17.001734;
    final double hubLng = _hubs.isNotEmpty ? (_hubs.first['lng'] as double) : 79.9625;

    // Generate driver coordinates spread around active hub operating sector
    final List<Map<String, dynamic>> driversWithCoords = [];
    final drivers = widget.fleetDrivers.isNotEmpty
        ? widget.fleetDrivers
        : [
            {'id': 1, 'name': 'Route Partner #1', 'phone': '+91 9123456789', 'hub': _hubs.first['name'], 'completed_stops': 12, 'assigned_stops': 14, 'salary': '₹15,000 / mo'},
            {'id': 2, 'name': 'Route Partner #2', 'phone': '+91 9876501234', 'hub': _hubs.first['name'], 'completed_stops': 10, 'assigned_stops': 12, 'salary': '₹15,000 / mo'},
          ];

    final offsets = [
      LatLng(hubLat + 0.0042, hubLng + 0.0035),
      LatLng(hubLat - 0.0035, hubLng - 0.0048),
      LatLng(hubLat + 0.0058, hubLng - 0.0028),
      LatLng(hubLat - 0.0025, hubLng + 0.0052),
      LatLng(hubLat + 0.0018, hubLng - 0.0061),
    ];

    for (int i = 0; i < drivers.length; i++) {
      final d = Map<String, dynamic>.from(drivers[i]);
      if (d['latitude'] != null && d['longitude'] != null) {
        d['coord'] = LatLng((d['latitude'] as num).toDouble(), (d['longitude'] as num).toDouble());
      } else {
        d['coord'] = offsets[i % offsets.length];
      }
      driversWithCoords.add(d);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Fleet Radar & Depot Coverage',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(
              '${driversWithCoords.length} Salaried Partners • ${_hubs.first['name']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
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
                    isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueGreen,
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
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131E32),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF0284C7)]),
                            borderRadius: BorderRadius.circular(12),
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
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedDriver!['hub']} • ₹15,000 / mo',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_selectedDriver!['completed_stops'] ?? 10}/${_selectedDriver!['assigned_stops'] ?? 12} Drops',
                            style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w800, fontSize: 11),
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
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.phone, size: 18),
                            label: const Text('Call Partner', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => _callDriver(_selectedDriver!['phone'] ?? '+919123456789'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
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
