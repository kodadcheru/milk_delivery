import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final AppState state;
  final double? initialLat;
  final double? initialLon;

  const MapLocationPickerScreen({
    super.key,
    required this.state,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late LatLng _currentCenter;
  bool _isDragging = false;
  bool _isGeocoding = false;
  bool _isLocating = false;

  Timer? _debounceTimer;

  // Address details
  String _shortAddress = 'Locating doorstep...';
  String _fullAddress = '';
  String _areaCity = '';

  final _houseNoController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedTag = 'HOME'; // HOME, WORK, OTHER

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final lat = widget.initialLat ?? widget.state.currentLat;
    final lon = widget.initialLon ?? widget.state.currentLon;
    _currentCenter = LatLng(lat, lon);

    _reverseGeocodeLocation(_currentCenter.latitude, _currentCenter.longitude);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _houseNoController.dispose();
    _landmarkController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocodeLocation(double lat, double lon) async {
    setState(() => _isGeocoding = true);
    final data = await LocationService.reverseGeocode(lat, lon);
    if (!mounted) return;

    if (data != null) {
      setState(() {
        _shortAddress = data['short_address'] ?? 'Road No. 36, Jubilee Hills';
        _fullAddress = data['full_address'] ?? '';
        _areaCity = '${data['suburb'] ?? 'Jubilee Hills'}, ${data['city'] ?? 'Hyderabad'}';
        _isGeocoding = false;
      });
    } else {
      setState(() {
        _shortAddress = 'Jubilee Hills, Hyderabad';
        _areaCity = 'Hyderabad, Telangana';
        _isGeocoding = false;
      });
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      if (!_isDragging) {
        setState(() => _isDragging = true);
      }
      _currentCenter = camera.center;

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _isDragging = false);
        _reverseGeocodeLocation(_currentCenter.latitude, _currentCenter.longitude);
      });
    }
  }

  Future<void> _useCurrentDeviceLocation() async {
    setState(() => _isLocating = true);
    try {
      final success = await widget.state.requestDeviceGPS();
      if (success) {
        final lat = widget.state.currentLat;
        final lon = widget.state.currentLon;
        _currentCenter = LatLng(lat, lon);
        _mapController.move(_currentCenter, 16.5);
        await _reverseGeocodeLocation(lat, lon);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0D7C66),
              duration: Duration(seconds: 2),
              content: Text('📍 Centered on your high-precision device GPS!'),
            ),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLocating = false);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await LocationService.searchPlaces(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> place) {
    final lat = place['lat'] as double;
    final lon = place['lon'] as double;
    _currentCenter = LatLng(lat, lon);
    _mapController.move(_currentCenter, 16.5);
    _searchController.clear();
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();
    _reverseGeocodeLocation(lat, lon);
  }

  void _confirmAndSaveLocation() async {
    final house = _houseNoController.text.trim();
    final landmark = _landmarkController.text.trim();

    String formatted = _shortAddress;
    if (house.isNotEmpty) {
      formatted = '$house, $_shortAddress';
    }
    if (landmark.isNotEmpty) {
      formatted = '$formatted (Near $landmark)';
    }

    await widget.state.updateDeliveryLocation(
      formatted,
      _currentCenter.latitude,
      _currentCenter.longitude,
    );

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0D7C66),
          content: Text('✅ Delivery address updated to: $formatted'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── 1. Interactive Flutter Map with High-Resolution Tiles ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.0,
              minZoom: 4.0,
              maxZoom: 18.5,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.milkdrop.express',
                maxZoom: 19,
              ),
            ],
          ),

          // ── 2. Fixed Animated Center Crosshairs Pin (Zepto/Swiggy Style) ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Pulsating Pin
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(0, _isDragging ? -14 : 0, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isGeocoding)
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                                )
                              else
                                const Icon(Icons.location_on, color: Color(0xFF10B981), size: 13),
                              const SizedBox(width: 4),
                              const Text(
                                'Set Doorstep Here',
                                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.location_pin,
                          size: 44,
                          color: Color(0xFFE11D48),
                        ),
                      ],
                    ),
                  ),
                  // Ground Target Shadow
                  Container(
                    width: _isDragging ? 8 : 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Top Floating Search Bar & Back Button ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchPlaces,
                            decoration: const InputDecoration(
                              hintText: 'Search locality, apartment, street...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D7C66)),
                            ),
                          )
                        else if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.search_rounded, color: Color(0xFF0D7C66), size: 22),
                          ),
                      ],
                    ),
                  ),

                  // Search Results Dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final place = _searchResults[idx];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined, color: Color(0xFF0D7C66)),
                            title: Text(
                              place['short_title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              place['display_name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                            onTap: () => _selectSearchResult(place),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── 4. "Use Current Location" Floating Action Button ──
          Positioned(
            right: 16,
            bottom: 275,
            child: FloatingActionButton.extended(
              heroTag: 'use_current_gps',
              onPressed: _isLocating ? null : _useCurrentDeviceLocation,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0D7C66),
              elevation: 4,
              icon: _isLocating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D7C66)))
                  : const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF0D7C66)),
              label: Text(
                _isLocating ? 'Locating...' : 'Use Current Location 📍',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ),

          // ── 5. Sliding Doorstep Confirmation Bottom Sheet ──
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Detected Location Card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFF0D7C66), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shortAddress,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fullAddress.isNotEmpty ? _fullAddress : _areaCity,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📍 GPS: ${_currentCenter.latitude.toStringAsFixed(4)}° N, ${_currentCenter.longitude.toStringAsFixed(4)}° E',
                              style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // House / Flat & Landmark Text Fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _houseNoController,
                          decoration: InputDecoration(
                            hintText: 'House / Flat / Floor No.',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11.5),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _landmarkController,
                          decoration: InputDecoration(
                            hintText: 'Nearby Landmark',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11.5),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Save Address Tags (Home, Work, Other)
                  Row(
                    children: [
                      _buildTagChip('HOME', '🏡 Home'),
                      const SizedBox(width: 8),
                      _buildTagChip('WORK', '🏢 Work'),
                      const SizedBox(width: 8),
                      _buildTagChip('OTHER', '📍 Other'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Primary Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndSaveLocation,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Confirm Location & Pin Doorstep 📍',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String key, String label) {
    final isSelected = _selectedTag == key;
    return InkWell(
      onTap: () => setState(() => _selectedTag = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66).withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFF0F172A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
