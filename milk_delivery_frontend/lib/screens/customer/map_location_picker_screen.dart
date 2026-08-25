import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

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
  GoogleMapController? _mapController;
  late LatLng _currentCenter;
  bool _isDragging = false;
  bool _isGeocoding = false;
  bool _isLocating = false;

  Timer? _debounceTimer;

  // Address details
  String _shortAddress = 'Locating doorstep...';
  String _fullAddress = '';
  String _areaCity = '';
  Map<String, dynamic>? _lastGeocodedData;

  final _houseNoController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedTag = 'HOME'; // HOME, WORK, OTHER

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSavingLocation = false;

  @override
  void initState() {
    super.initState();
    // GoogleMapController set via onMapCreated
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
        _lastGeocodedData = data;
        _shortAddress = data['short_address'] ?? 'Road No. 36, Jubilee Hills';
        _fullAddress = data['full_address'] ?? '';
        _areaCity = '${data['suburb'] ?? 'Jubilee Hills'}, ${data['city'] ?? 'Hyderabad'}';
        _isGeocoding = false;
      });
      AppTheme.hapticSuccess();
    } else {
      setState(() {
        _lastGeocodedData = null;
        _shortAddress = 'Jubilee Hills, Hyderabad';
        _areaCity = 'Hyderabad, Telangana';
        _isGeocoding = false;
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
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentCenter, 16.5));
        await _reverseGeocodeLocation(lat, lon);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: UiTone.primary,
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
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentCenter, 16.5));
    _searchController.clear();
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();
    _reverseGeocodeLocation(lat, lon);
  }

  void _confirmAndSaveLocation() async {
    if (_isSavingLocation) return;
    setState(() => _isSavingLocation = true);

    final house = _houseNoController.text.trim();
    final landmark = _landmarkController.text.trim();

    String formatted = _shortAddress;
    if (house.isNotEmpty) {
      formatted = '$house, $_shortAddress';
    }
    if (landmark.isNotEmpty) {
      formatted = '$formatted (Near $landmark)';
    }

    try {
      await widget.state.updateDeliveryLocation(
        formatted,
        _currentCenter.latitude,
        _currentCenter.longitude,
      );
    } catch (_) {}

    if (mounted) {
      setState(() => _isSavingLocation = false);
      final payload = <String, dynamic>{
        'lat': _currentCenter.latitude,
        'lon': _currentCenter.longitude,
        'short_address': _shortAddress,
        'full_address': _fullAddress.isNotEmpty ? _fullAddress : _shortAddress,
        'road': _lastGeocodedData?['road'] ?? '',
        'suburb': _lastGeocodedData?['suburb'] ?? '',
        'city': _lastGeocodedData?['city'] ?? 'Kodad',
        'postcode': _lastGeocodedData?['postcode'] ?? '508206',
        'house_no': house,
        'landmark': landmark,
        'tag': _selectedTag,
        'formatted': formatted,
      };
      if (Navigator.canPop(context)) {
        Navigator.pop(context, payload);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: UiTone.primary,
          content: Text('✅ Delivery address updated to: $formatted'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.ink,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── 1. Google Maps ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (CameraPosition pos) {
              if (!_isDragging) {
                setState(() => _isDragging = true);
                AppTheme.hapticLight();
              }
              _currentCenter = pos.target;
            },
            onCameraIdle: () {
              if (_isDragging) {
                setState(() => _isDragging = false);
                _reverseGeocodeLocation(_currentCenter.latitude, _currentCenter.longitude);
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── 2. Fixed Animated Center Crosshairs Pin (Zepto/Swiggy Style) ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Pulsating High-Precision Pin
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(0, _isDragging ? -16 : 0, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Live Address Floating Bubble over Pin
                        Container(
                          constraints: const BoxConstraints(maxWidth: 240),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: UiTone.ink,
                            borderRadius: BorderRadius.circular(UiRadius.lg),
                            border: Border.all(color: UiTone.primary.withValues(alpha: 0.6), width: 1.2),
                            boxShadow: UiShadow.elevated,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isGeocoding)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary),
                                )
                              else
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: UiTone.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: UiShadow.glowPrimary,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isGeocoding ? 'Detecting exact point...' : _shortAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: UiTone.surface,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.location_pin,
                          size: 46,
                          color: UiTone.error,
                        ),
                      ],
                    ),
                  ),
                  // High-Precision Ground Target Ring & Shadow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: _isDragging ? 32 : 24,
                        height: _isDragging ? 32 : 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: UiTone.primary.withValues(alpha: _isDragging ? 0.25 : 0.15),
                          border: Border.all(color: UiTone.primary, width: 1),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: UiTone.primary,
                          shape: BoxShape.circle,
                          boxShadow: UiShadow.glowPrimary,
                        ),
                      ),
                    ],
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
                      color: UiTone.surface,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      boxShadow: UiShadow.elevated,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: UiTone.ink),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary),
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
                            child: Icon(Icons.search_rounded, color: UiTone.primary, size: 22),
                          ),
                      ],
                    ),
                  ),

                  // Search Results Dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: UiTone.surface,
                        borderRadius: BorderRadius.circular(UiRadius.md),
                        boxShadow: UiShadow.elevated,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final place = _searchResults[idx];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined, color: UiTone.primary),
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
              backgroundColor: UiTone.surface,
              foregroundColor: UiTone.primary,
              elevation: 4,
              icon: _isLocating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary))
                  : const Icon(Icons.my_location_rounded, size: 18, color: UiTone.primary),
              label: Text(
                _isLocating ? 'Locating...' : 'Use Current Location 📍',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: UiTone.ink),
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
                color: UiTone.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: UiShadow.floating,
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
                          color: UiTone.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: UiTone.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shortAddress,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: UiTone.ink),
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
                              style: const TextStyle(color: UiTone.accentBlue, fontSize: 10, fontWeight: FontWeight.bold),
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
                            fillColor: UiTone.surfaceMuted,
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
                            fillColor: UiTone.surfaceMuted,
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
                      onPressed: _isSavingLocation ? null : _confirmAndSaveLocation,
                      icon: _isSavingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.surface))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _isSavingLocation ? 'Saving Doorstep Pin...' : 'Confirm Location & Pin Doorstep 📍',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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
      borderRadius: BorderRadius.circular(UiRadius.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary.withValues(alpha: 0.15) : UiTone.surfaceMuted,
          borderRadius: BorderRadius.circular(UiRadius.xs),
          border: Border.all(color: isSelected ? UiTone.primary : UiTone.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? UiTone.primary : UiTone.ink,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
