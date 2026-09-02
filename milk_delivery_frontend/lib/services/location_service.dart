import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class LocationService {
  // Google Maps API Key loaded from AppConfig (configurable via --dart-define)
  static String get googleMapsApiKey => AppConfig.googleMapsApiKey;

  // Google Maps Official Raster Tile Template
  static const String googleMapsTileUrl = 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  static const List<String> googleMapsSubdomains = ['mt0', 'mt1', 'mt2', 'mt3'];

  // In-Memory Fast Response Caches (~1.1 meter ground resolution)
  static final Map<String, Map<String, dynamic>> _reverseCache = {};
  static final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  /// High-Precision Google Maps Reverse Geocoding (< 5-10m Accuracy)
  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    final cacheKey = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    if (_reverseCache.containsKey(cacheKey)) {
      return _reverseCache[cacheKey];
    }

    // Google Maps Geocoding API with Deep Hierarchical Parsing
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googleMapsApiKey',
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

  /// High-Precision Google Maps Places & Address Search
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final normQuery = query.trim().toLowerCase();
    if (normQuery.isEmpty) return [];

    if (_searchCache.containsKey(normQuery)) {
      return _searchCache[normQuery]!;
    }

    // Google Maps Geocoding API for exact coordinates
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final encoded = Uri.encodeComponent('$query, India');
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=$googleMapsApiKey',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final List results = data['results'];
            final list = <Map<String, dynamic>>[];

            for (var r in results.take(6)) {
              final loc = r['geometry']?['location'] ?? {};
              final lat = double.tryParse(loc['lat']?.toString() ?? '0') ?? 0.0;
              final lon = double.tryParse(loc['lng']?.toString() ?? '0') ?? 0.0;
              final formatted = r['formatted_address']?.toString() ?? '';
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

    return [];
  }

  /// Extracts a clean, concise City or Town name (e.g. 'Kodad', 'Hyderabad', 'Suryapet')
  static String extractCityOrTown(String? raw, {String fallback = 'Kodad'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final clean = raw.trim();
    if (clean.toLowerCase().contains('kodad')) return 'Kodad';
    if (clean.toLowerCase().contains('hyderabad')) return 'Hyderabad';
    if (clean.toLowerCase().contains('suryapet')) return 'Suryapet';
    if (clean.toLowerCase().contains('khammam')) return 'Khammam';
    if (clean.toLowerCase().contains('vijayawada')) return 'Vijayawada';
    if (clean.toLowerCase().contains('nalgonda')) return 'Nalgonda';

    final parts = clean.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      for (final p in parts) {
        final lower = p.toLowerCase();
        if (!p.contains(RegExp(r'\d')) &&
            p.length <= 24 &&
            !lower.contains('road') &&
            !lower.contains('colony') &&
            !lower.contains('nagar') &&
            !lower.contains('street') &&
            !lower.contains('flat') &&
            !lower.contains('house') &&
            !lower.contains('lane') &&
            !lower.contains('door')) {
          return p;
        }
      }
      return parts.first;
    }
    return fallback;
  }

  /// Fast debounced place autocomplete suggestions
  static Future<List<Map<String, dynamic>>> fetchPlaceSuggestions(String query) async {
    final norm = query.trim().toLowerCase();
    if (norm.isEmpty) return [];

    if (_searchCache.containsKey('sug_$norm')) {
      return _searchCache['sug_$norm']!;
    }

    if (googleMapsApiKey.isNotEmpty) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encoded&components=country:in&key=$googleMapsApiKey',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && (data['predictions'] as List).isNotEmpty) {
            final List preds = data['predictions'];
            final results = <Map<String, dynamic>>[];
            for (var p in preds.take(6)) {
              final structured = p['structured_formatting'] ?? {};
              final mainText = structured['main_text'] ?? p['description']?.toString().split(',').first ?? '';
              final secondaryText = structured['secondary_text'] ?? p['description'] ?? '';
              results.add({
                'title': mainText.toString(),
                'subtitle': secondaryText.toString(),
                'place_id': p['place_id']?.toString() ?? '',
                'full_address': p['description']?.toString() ?? '',
                'short_address': mainText.toString(),
              });
            }
            if (results.isNotEmpty) {
              _searchCache['sug_$norm'] = results;
              return results;
            }
          }
        }
      } catch (_) {}
    }

    return searchPlaces(query);
  }
}
