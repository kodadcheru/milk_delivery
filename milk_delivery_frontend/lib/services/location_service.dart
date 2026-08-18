import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // Google Maps API Key for high-precision Geocoding and Places Lookup
  static String googleMapsApiKey = 'AIzaSyBALn7TqvHsoW_2o-mJAWKl2RQHpdT2jZg';

  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'MilkDropExpressApp/1.0 (delivery@milkdrop.express)',
    'Accept': 'application/json',
  };

  // Reverse Geocoding: Convert coordinates to real street address
  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    // 1. Try Google Maps Geocoding if API key is provided
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googleMapsApiKey',
        );
        final res = await http.get(googleUrl).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final first = data['results'][0];
            final fullAddr = first['formatted_address'] as String;
            final components = first['address_components'] as List? ?? [];

            String road = '';
            String suburb = '';
            String city = 'Hyderabad';
            String postcode = '500033';

            for (var c in components) {
              final types = (c['types'] as List? ?? []).map((e) => e.toString()).toList();
              if (types.contains('route') || types.contains('street_number')) {
                road = c['long_name'] ?? road;
              } else if (types.contains('sublocality') || types.contains('neighborhood')) {
                suburb = c['long_name'] ?? suburb;
              } else if (types.contains('locality')) {
                city = c['long_name'] ?? city;
              } else if (types.contains('postal_code')) {
                postcode = c['long_name'] ?? postcode;
              }
            }

            final shortAddr = suburb.isNotEmpty ? '$suburb, $city' : (road.isNotEmpty ? '$road, $city' : fullAddr.split(',').take(2).join(','));

            return {
              'short_address': shortAddr,
              'full_address': fullAddr,
              'road': road.isNotEmpty ? road : 'Road No. 36',
              'suburb': suburb.isNotEmpty ? suburb : 'Jubilee Hills',
              'city': city,
              'postcode': postcode,
              'lat': lat,
              'lon': lon,
            };
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Nominatim Reverse Geocoding
    try {
      final url = Uri.parse('$_nominatimBaseUrl/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1');
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'] ?? {};

        final road = addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? 'Road No. 36';
        final suburb = addr['suburb'] ?? addr['residential'] ?? addr['neighbourhood'] ?? 'Jubilee Hills';
        final city = addr['city'] ?? addr['town'] ?? addr['state_district'] ?? 'Hyderabad';
        final state = addr['state'] ?? 'Telangana';
        final postcode = addr['postcode'] ?? '500033';

        final shortAddress = '$road, $suburb, $city';
        final fullAddress = '$road, $suburb, $city, $state - $postcode';

        return {
          'short_address': shortAddress,
          'full_address': fullAddress,
          'road': road,
          'suburb': suburb,
          'city': city,
          'postcode': postcode,
          'lat': lat,
          'lon': lon,
        };
      }
    } catch (_) {}

    // Fallback default coordinates
    return {
      'short_address': 'Road No. 36, Jubilee Hills, Hyderabad',
      'full_address': 'Flat 402, Green Acres, Road No. 36, Jubilee Hills, Hyderabad - 500033',
      'road': 'Road No. 36',
      'suburb': 'Jubilee Hills',
      'city': 'Hyderabad',
      'postcode': '500033',
      'lat': lat,
      'lon': lon,
    };
  }

  // Geocoding Search: Search street / locality names across Google Maps or OpenStreetMap
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    // 1. Try Google Places if key is provided
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
            return preds.map((p) {
              return {
                'display_name': p['description'] ?? query,
                'short_title': p['structured_formatting']?['main_text'] ?? query,
                'place_id': p['place_id'],
                'lat': 17.4319,
                'lon': 78.4073,
              };
            }).toList();
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Search
    try {
      final encoded = Uri.encodeComponent('$query, India');
      final url = Uri.parse('$_nominatimBaseUrl/search?q=$encoded&format=json&addressdetails=1&limit=5');
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) {
          final addr = item['address'] ?? {};
          final name = item['display_name'] ?? query;
          final lat = double.tryParse(item['lat']?.toString() ?? '17.4319') ?? 17.4319;
          final lon = double.tryParse(item['lon']?.toString() ?? '78.4073') ?? 78.4073;

          final road = addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? query;
          final city = addr['city'] ?? addr['town'] ?? addr['state'] ?? 'Hyderabad';

          return {
            'display_name': name,
            'short_title': '$road, $city',
            'lat': lat,
            'lon': lon,
          };
        }).toList();
      }
    } catch (_) {}

    return [
      {
        'display_name': '$query, Jubilee Hills, Hyderabad, Telangana, India',
        'short_title': '$query, Hyderabad',
        'lat': 17.4319,
        'lon': 78.4073,
      },
    ];
  }
}
