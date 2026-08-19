import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../providers/app_state.dart';

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
  late final MapController _mapController;
  int _selectedTaskIndex = 0;

  // Hyderabad Jubilee Hills Central Depot #1 coordinates
  final LatLng _depotLocation = const LatLng(17.4320, 78.4070);

  // Delivery partner location
  late LatLng _driverLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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
            backgroundColor: const Color(0xFF0284C7),
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

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final List<LatLng> routePoints = [_depotLocation, _driverLocation];
    for (var t in tasks) {
      routePoints.add(LatLng(t.customerLatitude, t.customerLongitude));
    }

    final selectedTask = tasks.isNotEmpty && _selectedTaskIndex < tasks.length
        ? tasks[_selectedTaskIndex]
        : null;

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
              'Morning Route Map Navigation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(
              '${tasks.length} Drops • Jubilee Hills Depot #1 Sector',
              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFF10B981)),
            onPressed: () {
              _mapController.move(_driverLocation, 14.5);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Interactive Map View ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _depotLocation,
              initialZoom: 13.8,
              minZoom: 11.0,
              maxZoom: 18.0,
            ),
            children: [
              // Google Maps Styled / CartoDB Tile Layer
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.milkdrop.express',
              ),

              // Route Polyline connecting Depot to all stops
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 4.5,
                    color: const Color(0xFF0D7C66),
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),

              // Markers for Depot, Driver, and Customer Stops
              MarkerLayer(
                markers: [
                  // 1. Hub Depot Marker
                  Marker(
                    point: _depotLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6366F1), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🏬', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),

                  // 2. Delivery Partner Live GPS Marker
                  Marker(
                    point: _driverLocation,
                    width: 52,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.two_wheeler, color: Colors.white, size: 26),
                      ),
                    ),
                  ),

                  // 3. Customer Stops
                  ...tasks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final task = entry.value;
                    final isDelivered = task.isDelivered;
                    final isSelected = idx == _selectedTaskIndex;

                    return Marker(
                      point: LatLng(task.customerLatitude, task.customerLongitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedTaskIndex = idx);
                          _mapController.move(LatLng(task.customerLatitude, task.customerLongitude), 15.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isDelivered
                                ? const Color(0xFF10B981)
                                : (isSelected ? const Color(0xFF0284C7) : const Color(0xFFEF4444)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 3.0 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: isDelivered
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── Top Route Summary Pill ──
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Optimized Polar Route: ${tasks.length} Drops (05:30 AM - 07:00 AM)',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tasks.where((t) => t.isDelivered).length}/${tasks.length} Done',
                      style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w800),
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
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131E32),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'STOP #${_selectedTaskIndex + 1}',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedTask.customerName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          selectedTask.slotTime,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedTask.deliveryAddress,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.navigation, size: 18),
                            label: const Text('Navigate with Google Maps', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
