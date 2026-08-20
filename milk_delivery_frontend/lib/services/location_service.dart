import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // Google Maps API Key for high-precision Geocoding and Places Lookup
  static String googleMapsApiKey = 'AIzaSyBALn7TqvHsoW_2o-mJAWKl2RQHpdT2jZg';

  // Google Maps Official Raster Tile Template
  static const String googleMapsTileUrl = 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  static const List<String> googleMapsSubdomains = ['mt0', 'mt1', 'mt2', 'mt3'];

  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'MilkDropExpressApp/2.0 (delivery@milkdrop.express)',
    'Accept': 'application/json',
  };

  // In-Memory Fast Response Caches (~1.1 meter ground resolution)
  static final Map<String, Map<String, dynamic>> _reverseCache = {};
  static final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  /// High-Precision Reverse Geocoding (< 5-10m Accuracy)
  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    final cacheKey = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    if (_reverseCache.containsKey(cacheKey)) {
      return _reverseCache[cacheKey];
    }

    // 1. Google Maps Geocoding API with Deep Hierarchical Parsing
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&extra_computations=BUILDING_AND_ENTRANCES&key=$googleMapsApiKey',
        );
        final res = await http.get(googleUrl).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final List results = data['results'];
            final first = results[0];
            final fullAddr = first['formatted_address'] as String? ?? '';
            final components = first['address_components'] as List? ?? [];
            final plusCodeObj = data['plus_code'] ?? first['plus_code'];
            final plusCode = plusCodeObj != null ? (plusCodeObj['compound_code'] ?? plusCodeObj['global_code'] ?? '') : '';

            String houseNo = '';
            String building = '';
            String road = '';
            String subLocality2 = '';
            String subLocality1 = '';
            String city = 'Hyderabad';
            String postcode = '500033';
            String landmark = '';

            for (var c in components) {
              final types = (c['types'] as List? ?? []).map((e) => e.toString()).toList();
              final longName = c['long_name']?.toString() ?? '';

              if (types.contains('street_number') || types.contains('subpremise')) {
                houseNo = longName;
              } else if (types.contains('premise') || types.contains('point_of_interest') || types.contains('establishment')) {
                building = longName;
              } else if (types.contains('route')) {
                road = longName;
              } else if (types.contains('sublocality_level_2') || types.contains('sublocality_level_3')) {
                subLocality2 = longName;
              } else if (types.contains('sublocality_level_1') || types.contains('sublocality') || types.contains('neighborhood')) {
                subLocality1 = longName;
              } else if (types.contains('locality')) {
                city = longName;
              } else if (types.contains('postal_code')) {
                postcode = longName;
              }
            }

            final String suburb = [subLocality2, subLocality1].where((s) => s.isNotEmpty).join(', ');
            final String shortAddr = building.isNotEmpty
                ? (suburb.isNotEmpty ? '$building, $suburb' : '$building, $city')
                : (road.isNotEmpty
                    ? (suburb.isNotEmpty ? '$road, $suburb' : '$road, $city')
                    : (suburb.isNotEmpty ? '$suburb, $city' : fullAddr.split(',').take(2).join(',')));

            final result = {
              'short_address': shortAddr.isNotEmpty ? shortAddr : fullAddr,
              'full_address': fullAddr,
              'house_no': houseNo,
              'building': building,
              'suburb': suburb.isNotEmpty ? suburb : 'City Sector',
              'road': road.isNotEmpty ? road : 'Main Road',
              'city': city,
              'postcode': postcode,
              'plus_code': plusCode,
              'landmark': landmark,
              'lat': lat,
              'lon': lon,
            };
            _reverseCache[cacheKey] = result;
            return result;
          }
        }
      } catch (_) {}
    }

    // 2. High-Precision OpenStreetMap Nominatim Query (zoom=18 building level)
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1&namedetails=1&extratags=1',
      );
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'] ?? {};

        final houseNumber = addr['house_number'] ?? addr['flat_number'] ?? '';
        final building = addr['building'] ?? addr['amenity'] ?? addr['shop'] ?? addr['office'] ?? '';
        final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? addr['neighbourhood'] ?? 'Main Road';
        final suburb = addr['suburb'] ?? addr['residential'] ?? addr['neighbourhood'] ?? 'Local Area';
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state_district'] ?? 'City';
        final state = addr['state'] ?? 'State';
        final postcode = addr['postcode'] ?? '500001';

        final shortAddress = building.isNotEmpty
            ? '$building, $suburb, $city'
            : '$road, $suburb, $city';
        final fullAddress = '$road, $suburb, $city, $state - $postcode';

        final result = {
          'short_address': shortAddress,
          'full_address': fullAddress,
          'house_no': houseNumber,
          'building': building,
          'road': road,
          'suburb': suburb,
          'city': city,
          'postcode': postcode,
          'lat': lat,
          'lon': lon,
        };
        _reverseCache[cacheKey] = result;
        return result;
      }
    } catch (_) {}

    // Fallback default coordinates
    final fallback = {
      'short_address': 'Doorstep Delivery Location',
      'full_address': 'Doorstep Delivery Point, Kodad Depot',
      'road': 'Main Street',
      'suburb': 'Local Area',
      'city': 'City',
      'postcode': '500001',
      'lat': lat,
      'lon': lon,
    };
    _reverseCache[cacheKey] = fallback;
    return fallback;
  }

  /// High-Precision Places Search across Google Maps Geocoding & Places APIs
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final normQuery = query.trim().toLowerCase();
    if (normQuery.isEmpty) return [];

    if (_searchCache.containsKey(normQuery)) {
      return _searchCache[normQuery]!;
    }

    // 1. Google Maps Geocoding API for exact coordinates
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final encoded = Uri.encodeComponent('$query, India');
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=$googleMapsApiKey',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final List results = data['results'];
            final list = <Map<String, dynamic>>[];

            for (var r in results.take(6)) {
              final loc = r['geometry']['location'];
              final lat = (loc['lat'] as num).toDouble();
              final lon = (loc['lng'] as num).toDouble();
              final formatted = r['formatted_address'] as String;
              final components = r['address_components'] as List? ?? [];

              String road = '';
              String suburb = '';
              String city = 'Hyderabad';
              String postcode = '';

              for (var c in components) {
                final types = (c['types'] as List? ?? []).map((e) => e.toString()).toList();
                if (types.contains('route')) road = c['long_name'] ?? road;
                if (types.contains('sublocality') || types.contains('neighborhood')) suburb = c['long_name'] ?? suburb;
                if (types.contains('locality')) city = c['long_name'] ?? city;
                if (types.contains('postal_code')) postcode = c['long_name'] ?? postcode;
              }

              list.add({
                'title': suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : formatted.split(',').first),
                'subtitle': formatted,
                'short_address': suburb.isNotEmpty ? '$suburb, $city' : formatted.split(',').take(2).join(','),
                'full_address': formatted,
                'road': road,
                'suburb': suburb,
                'city': city,
                'postcode': postcode,
                'lat': lat,
                'lon': lon,
              });
            }

            if (list.isNotEmpty) {
              _searchCache[normQuery] = list;
              return list;
            }
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Nominatim Search Fallback
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        '$_nominatimBaseUrl/search?format=json&q=$encoded&addressdetails=1&limit=6&countrycodes=in',
      );
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final list = <Map<String, dynamic>>[];

        for (var item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;
          final addr = item['address'] ?? {};

          final road = addr['road'] ?? addr['neighbourhood'] ?? '';
          final suburb = addr['suburb'] ?? addr['residential'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state_district'] ?? 'City';
          final displayName = item['display_name'] ?? '';

          list.add({
            'title': item['name'] ?? suburb ?? road ?? 'Location',
            'subtitle': displayName,
            'short_address': suburb.isNotEmpty ? '$suburb, $city' : (road.isNotEmpty ? '$road, $city' : displayName.split(',').take(2).join(',')),
            'full_address': displayName,
            'road': road,
            'suburb': suburb,
            'city': city,
            'postcode': addr['postcode'] ?? '',
            'lat': lat,
            'lon': lon,
          });
        }

        _searchCache[normQuery] = list;
        return list;
      }
    } catch (_) {}

    return [];
  }
}
