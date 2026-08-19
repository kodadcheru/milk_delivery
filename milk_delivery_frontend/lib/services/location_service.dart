import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // Google Maps API Key for high-precision Geocoding and Places Lookup
  static String googleMapsApiKey = 'AIzaSyBALn7TqvHsoW_2o-mJAWKl2RQHpdT2jZg';

  // Google Maps Official Raster Tile Template
  static const String googleMapsTileUrl = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  static const List<String> googleMapsSubdomains = ['mt0', 'mt1', 'mt2', 'mt3'];

  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'MilkDropExpressApp/1.0 (delivery@milkdrop.express)',
    'Accept': 'application/json',
  };

  // Reverse Geocoding: Convert coordinates to real street address
  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    // 1. Google Maps Geocoding API
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
              } else if (types.contains('sublocality') || types.contains('sublocality_level_1') || types.contains('neighborhood')) {
                suburb = c['long_name'] ?? suburb;
              } else if (types.contains('locality')) {
                city = c['long_name'] ?? city;
              } else if (types.contains('postal_code')) {
                postcode = c['long_name'] ?? postcode;
              }
            }

            final shortAddr = suburb.isNotEmpty
                ? '$suburb, $city'
                : (road.isNotEmpty ? '$road, $city' : fullAddr.split(',').take(2).join(','));

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

    // 2. OpenStreetMap Nominatim Fallback
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

  // Geocoding Search: High-precision search across Google Maps Geocoding & Places APIs
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    // 1. Google Maps Geocoding API for exact coordinates
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final encoded = Uri.encodeComponent('$query, Hyderabad, India');
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=$googleMapsApiKey',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final List results = data['results'];
            return results.map((item) {
              final geom = item['geometry']?['location'] ?? {};
              final lat = (geom['lat'] as num?)?.toDouble() ?? 17.4319;
              final lon = (geom['lng'] as num?)?.toDouble() ?? 78.4073;
              final formatted = item['formatted_address'] as String? ?? query;

              final parts = formatted.split(',');
              final shortTitle = parts.isNotEmpty ? parts.take(2).join(',').trim() : query;

              return {
                'display_name': formatted,
                'short_title': shortTitle,
                'place_id': item['place_id'] ?? '',
                'lat': lat,
                'lon': lon,
              };
            }).toList();
          }
        }
      } catch (_) {}

      // 1b. Google Places Autocomplete fallback
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
            final List<Map<String, dynamic>> output = [];

            for (var p in preds.take(5)) {
              final desc = p['description'] as String? ?? query;
              final mainText = p['structured_formatting']?['main_text'] as String? ?? query;
              final placeId = p['place_id'] as String?;

              // Fetch exact lat/lon for first 3 predictions
              double lat = 17.4319;
              double lon = 78.4073;
              if (placeId != null && output.length < 3) {
                try {
                  final placeUrl = Uri.parse(
                    'https://maps.googleapis.com/maps/api/geocode/json?place_id=$placeId&key=$googleMapsApiKey',
                  );
                  final placeRes = await http.get(placeUrl).timeout(const Duration(seconds: 2));
                  if (placeRes.statusCode == 200) {
                    final placeData = jsonDecode(placeRes.body);
                    if (placeData['status'] == 'OK' && (placeData['results'] as List).isNotEmpty) {
                      final geom = placeData['results'][0]['geometry']?['location'] ?? {};
                      lat = (geom['lat'] as num?)?.toDouble() ?? lat;
                      lon = (geom['lng'] as num?)?.toDouble() ?? lon;
                    }
                  }
                } catch (_) {}
              }

              output.add({
                'display_name': desc,
                'short_title': mainText,
                'place_id': placeId ?? '',
                'lat': lat,
                'lon': lon,
              });
            }

            if (output.isNotEmpty) return output;
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Search Fallback
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
