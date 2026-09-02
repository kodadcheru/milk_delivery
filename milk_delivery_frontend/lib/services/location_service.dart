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

  // Curated Directory of Known Service Localities & Hubs (Zero-Latency Offline Fallback)
  static final List<Map<String, dynamic>> _knownLocalities = [
    {
      'title': 'Gandhi Nagar',
      'short_title': 'Gandhi Nagar',
      'subtitle': 'Azad Nagar, Kodad, Telangana 508206',
      'display_name': 'Gandhi Nagar, Kodad, Telangana 508206',
      'short_address': 'Gandhi Nagar, Kodad',
      'full_address': 'Gandhi Nagar, Azad Nagar, Kodad, Telangana 508206',
      'summary_address': 'Gandhi Nagar, Kodad',
      'road': 'Gandhi Nagar Road',
      'suburb': 'Azad Nagar',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.00382,
      'lon': 79.95830,
    },
    {
      'title': 'Azad Nagar',
      'short_title': 'Azad Nagar',
      'subtitle': 'Kodad, Telangana 508206',
      'display_name': 'Azad Nagar, Kodad, Telangana 508206',
      'short_address': 'Azad Nagar, Kodad',
      'full_address': 'Azad Nagar, Kodad, Telangana 508206',
      'summary_address': 'Azad Nagar, Kodad',
      'road': 'Azad Road',
      'suburb': 'Azad Nagar',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.00173,
      'lon': 79.95540,
    },
    {
      'title': 'Huzurnagar Road',
      'short_title': 'Huzurnagar Road',
      'subtitle': 'Kodad, Telangana 508206',
      'display_name': 'Huzurnagar Road, Kodad, Telangana 508206',
      'short_address': 'Huzurnagar Road, Kodad',
      'full_address': 'Huzurnagar Road, Kodad, Telangana 508206',
      'summary_address': 'Huzurnagar Road, Kodad',
      'road': 'Huzurnagar Main Road',
      'suburb': 'Huzurnagar Bypass',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.00650,
      'lon': 79.96720,
    },
    {
      'title': 'Balaji Nagar',
      'short_title': 'Balaji Nagar',
      'subtitle': 'Kodad, Telangana 508206',
      'display_name': 'Balaji Nagar, Kodad, Telangana 508206',
      'short_address': 'Balaji Nagar, Kodad',
      'full_address': 'Balaji Nagar, Kodad, Telangana 508206',
      'summary_address': 'Balaji Nagar, Kodad',
      'road': 'Balaji Temple Road',
      'suburb': 'Balaji Nagar',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 16.99820,
      'lon': 79.96540,
    },
    {
      'title': 'Dwaraka Nagar',
      'short_title': 'Dwaraka Nagar',
      'subtitle': 'Kodad, Telangana 508206',
      'display_name': 'Dwaraka Nagar, Kodad, Telangana 508206',
      'short_address': 'Dwaraka Nagar, Kodad',
      'full_address': 'Dwaraka Nagar, Kodad, Telangana 508206',
      'summary_address': 'Dwaraka Nagar, Kodad',
      'road': 'Dwaraka Nagar 1st Line',
      'suburb': 'Dwaraka Nagar',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.00410,
      'lon': 79.96910,
    },
    {
      'title': 'Ranga Theatre Road',
      'short_title': 'Ranga Theatre Road',
      'subtitle': 'Cinema Street, Kodad, Telangana 508206',
      'display_name': 'Ranga Theatre Road, Kodad, Telangana 508206',
      'short_address': 'Ranga Theatre Road, Kodad',
      'full_address': 'Ranga Theatre Road, Cinema Street, Kodad, Telangana 508206',
      'summary_address': 'Ranga Theatre Road, Kodad',
      'road': 'Cinema Road',
      'suburb': 'Old Town',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.00050,
      'lon': 79.96100,
    },
    {
      'title': 'RTC Bus Stand Area',
      'short_title': 'RTC Bus Stand',
      'subtitle': 'Main Cross Roads, Kodad, Telangana 508206',
      'display_name': 'RTC Bus Stand Area, Kodad, Telangana 508206',
      'short_address': 'RTC Bus Stand, Kodad',
      'full_address': 'RTC Bus Stand Area, Main Cross Roads, Kodad, Telangana 508206',
      'summary_address': 'RTC Bus Stand, Kodad',
      'road': 'Bus Stand Road',
      'suburb': 'Central Depot',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.00280,
      'lon': 79.96420,
    },
    {
      'title': 'Khammam Road',
      'short_title': 'Khammam Road',
      'subtitle': 'Near Bypass, Kodad, Telangana 508206',
      'display_name': 'Khammam Road, Kodad, Telangana 508206',
      'short_address': 'Khammam Road, Kodad',
      'full_address': 'Khammam Road, Near Bypass, Kodad, Telangana 508206',
      'summary_address': 'Khammam Road, Kodad',
      'road': 'SH 2 Highway',
      'suburb': 'North Kodad',
      'city': 'Kodad',
      'postcode': '508206',
      'lat': 17.01200,
      'lon': 79.96200,
    },
    {
      'title': 'Suryapet Central',
      'short_title': 'Suryapet Central',
      'subtitle': 'Clock Tower, Suryapet, Telangana 508213',
      'display_name': 'Clock Tower, Suryapet, Telangana 508213',
      'short_address': 'Suryapet Central',
      'full_address': 'Clock Tower Road, Suryapet, Telangana 508213',
      'summary_address': 'Suryapet Central',
      'road': 'Clock Tower Road',
      'suburb': 'Main Bazaar',
      'city': 'Suryapet',
      'postcode': '508213',
      'lat': 17.14390,
      'lon': 79.62390,
    },
    {
      'title': 'Khammam Central',
      'short_title': 'Khammam Central',
      'subtitle': 'Wyra Road, Khammam, Telangana 507001',
      'display_name': 'Wyra Road, Khammam, Telangana 507001',
      'short_address': 'Khammam Central',
      'full_address': 'Wyra Road, Khammam, Telangana 507001',
      'summary_address': 'Khammam Central',
      'road': 'Wyra Road',
      'suburb': 'City Center',
      'city': 'Khammam',
      'postcode': '507001',
      'lat': 17.24730,
      'lon': 80.15140,
    },
    {
      'title': 'Gachibowli',
      'short_title': 'Gachibowli',
      'subtitle': 'Financial District, Hyderabad, Telangana 500032',
      'display_name': 'Gachibowli, Hyderabad, Telangana 500032',
      'short_address': 'Gachibowli, Hyderabad',
      'full_address': 'Gachibowli, Financial District, Hyderabad, Telangana 500032',
      'summary_address': 'Gachibowli, Hyderabad',
      'road': 'Old Mumbai Highway',
      'suburb': 'Gachibowli',
      'city': 'Hyderabad',
      'postcode': '500032',
      'lat': 17.4401,
      'lon': 78.3489,
    },
    {
      'title': 'Madhapur',
      'short_title': 'Madhapur',
      'subtitle': 'Hitec City, Hyderabad, Telangana 500081',
      'display_name': 'Madhapur, Hyderabad, Telangana 500081',
      'short_address': 'Madhapur, Hyderabad',
      'full_address': 'Madhapur, Hitec City, Hyderabad, Telangana 500081',
      'summary_address': 'Madhapur, Hyderabad',
      'road': 'Hitec City Main Road',
      'suburb': 'Madhapur',
      'city': 'Hyderabad',
      'postcode': '500081',
      'lat': 17.4483,
      'lon': 78.3915,
    },
  ];

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
            String city = 'Kodad';
            String postcode = '508206';
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

            final finalShort = shortAddr.isNotEmpty ? shortAddr : fullAddr;
            final result = {
              'title': finalShort.split(',').first.trim(),
              'short_title': finalShort.split(',').first.trim(),
              'name': finalShort.split(',').first.trim(),
              'subtitle': fullAddr,
              'display_name': fullAddr,
              'short_address': finalShort,
              'full_address': fullAddr,
              'summary_address': fullAddr,
              'house_no': houseNo,
              'building': building,
              'suburb': suburb.isNotEmpty ? suburb : 'Local Sector',
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
      'title': 'Doorstep Delivery Location',
      'short_title': 'Doorstep Delivery Location',
      'name': 'Doorstep Delivery Location',
      'subtitle': 'Kodad Depot, Telangana',
      'display_name': 'Doorstep Delivery Point, Kodad Depot',
      'short_address': 'Doorstep Delivery Location',
      'full_address': 'Doorstep Delivery Point, Kodad Depot, Telangana 508206',
      'summary_address': 'Doorstep Delivery Point, Kodad Depot',
      'road': 'Main Street',
      'suburb': 'Local Area',
      'city': 'Kodad',
      'postcode': '508206',
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

    final list = <Map<String, dynamic>>[];

    // 1. Instant match against known local hubs and Telangana localities
    final localMatches = _knownLocalities.where((loc) {
      final t = (loc['title'] ?? '').toString().toLowerCase();
      final s = (loc['subtitle'] ?? '').toString().toLowerCase();
      final c = (loc['city'] ?? '').toString().toLowerCase();
      return t.contains(normQuery) || s.contains(normQuery) || c.contains(normQuery);
    }).toList();
    list.addAll(localMatches);

    // 2. Google Maps Geocoding API for exact coordinates
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

            for (var r in results.take(6)) {
              final loc = r['geometry']?['location'] ?? {};
              final lat = double.tryParse(loc['lat']?.toString() ?? '0') ?? 0.0;
              final lon = double.tryParse(loc['lng']?.toString() ?? '0') ?? 0.0;
              final formatted = r['formatted_address']?.toString() ?? '';
              final components = r['address_components'] as List? ?? [];

              String road = '';
              String suburb = '';
              String city = 'Kodad';
              String postcode = '';

              for (var c in components) {
                final types = (c['types'] as List? ?? []).map((e) => e.toString()).toList();
                if (types.contains('route')) road = c['long_name'] ?? road;
                if (types.contains('sublocality') || types.contains('neighborhood')) suburb = c['long_name'] ?? suburb;
                if (types.contains('locality')) city = c['long_name'] ?? city;
                if (types.contains('postal_code')) postcode = c['long_name'] ?? postcode;
              }

              final title = suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : formatted.split(',').first);

              // Avoid duplicate if already matched locally
              if (!list.any((item) => (item['title'] == title || item['full_address'] == formatted))) {
                list.add({
                  'title': title,
                  'short_title': title,
                  'name': title,
                  'subtitle': formatted,
                  'display_name': formatted,
                  'short_address': suburb.isNotEmpty ? '$suburb, $city' : formatted.split(',').take(2).join(','),
                  'full_address': formatted,
                  'summary_address': formatted,
                  'road': road,
                  'suburb': suburb,
                  'city': city,
                  'postcode': postcode,
                  'lat': lat,
                  'lon': lon,
                });
              }
            }
          }
        }
      } catch (_) {}
    }

    if (list.isNotEmpty) {
      _searchCache[normQuery] = list;
    }
    return list;
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

    final results = <Map<String, dynamic>>[];

    // 1. Match local known directory first
    final localMatches = _knownLocalities.where((loc) {
      final t = (loc['title'] ?? '').toString().toLowerCase();
      final s = (loc['subtitle'] ?? '').toString().toLowerCase();
      final c = (loc['city'] ?? '').toString().toLowerCase();
      return t.contains(norm) || s.contains(norm) || c.contains(norm);
    }).toList();
    results.addAll(localMatches);

    // 2. Google Places Autocomplete API
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
            for (var p in preds.take(6)) {
              final structured = p['structured_formatting'] ?? {};
              final mainText = structured['main_text'] ?? p['description']?.toString().split(',').first ?? '';
              final secondaryText = structured['secondary_text'] ?? p['description'] ?? '';
              final fullDesc = p['description']?.toString() ?? mainText.toString();

              if (!results.any((r) => r['title'] == mainText.toString() || r['full_address'] == fullDesc)) {
                results.add({
                  'title': mainText.toString(),
                  'short_title': mainText.toString(),
                  'name': mainText.toString(),
                  'subtitle': secondaryText.toString(),
                  'display_name': fullDesc,
                  'place_id': p['place_id']?.toString() ?? '',
                  'full_address': fullDesc,
                  'summary_address': fullDesc,
                  'short_address': mainText.toString(),
                });
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to geocoding if nothing found
    if (results.isEmpty) {
      return searchPlaces(query);
    }

    _searchCache['sug_$norm'] = results;
    return results;
  }

  /// High-Precision Place Details to resolve exact LatLng from Place ID
  static Future<Map<String, dynamic>?> fetchPlaceDetails(String placeId) async {
    if (placeId.isEmpty || googleMapsApiKey.isEmpty) return null;
    final cacheKey = 'details_$placeId';
    if (_reverseCache.containsKey(cacheKey)) return _reverseCache[cacheKey];

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,name,formatted_address,address_components&key=$googleMapsApiKey',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final r = data['result'];
          final loc = r['geometry']?['location'];
          final lat = double.tryParse(loc?['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(loc?['lng']?.toString() ?? '') ?? 0.0;
          final name = r['name']?.toString() ?? '';
          final formatted = r['formatted_address']?.toString() ?? '';

          final resMap = {
            'lat': lat,
            'lon': lon,
            'title': name.isNotEmpty ? name : formatted.split(',').first,
            'short_title': name.isNotEmpty ? name : formatted.split(',').first,
            'name': name.isNotEmpty ? name : formatted.split(',').first,
            'subtitle': formatted,
            'display_name': formatted,
            'full_address': formatted,
            'summary_address': formatted,
            'short_address': name.isNotEmpty ? name : formatted.split(',').first,
          };
          _reverseCache[cacheKey] = resMap;
          return resMap;
        }
      }
    } catch (_) {}
    return null;
  }
}
