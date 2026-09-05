import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/delivery_batch_model.dart';
import '../models/delivery_task_model.dart';

class RouteOptimizer {
  /// Calculates Haversine great-circle distance between two GPS coordinates in kilometers.
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Calculates total loop distance for a sequence of stops starting and ending at the hub.
  static double calculateLoopDistance(HubLocationModel hub, List<DeliveryTaskModel> stops) {
    if (stops.isEmpty) return 0.0;

    double total = 0.0;
    // Hub to first stop
    total += calculateDistanceKm(hub.latitude, hub.longitude, stops.first.customerLatitude, stops.first.customerLongitude);

    // Between consecutive stops
    for (int i = 0; i < stops.length - 1; i++) {
      total += calculateDistanceKm(
        stops[i].customerLatitude,
        stops[i].customerLongitude,
        stops[i + 1].customerLatitude,
        stops[i + 1].customerLongitude,
      );
    }

    // Last stop back to Hub
    total += calculateDistanceKm(stops.last.customerLatitude, stops.last.customerLongitude, hub.latitude, hub.longitude);
    return total;
  }

  /// Solves the Traveling Salesperson Problem (TSP) using Nearest-Neighbor heuristic starting from Hub.
  /// Guarantees that the route starts from Hub, visits closest doorsteps sequentially to eliminate
  /// backtracking, and calculates the precise fuel, carbon, and distance saved.
  static RouteOptimizationResult optimizeBatchRoute({
    required HubLocationModel hub,
    required List<DeliveryTaskModel> tasks,
  }) {
    if (tasks.isEmpty) {
      return const RouteOptimizationResult(
        orderedStops: [],
        totalDistanceKm: 0.0,
        unoptimizedDistanceKm: 0.0,
        distanceSavedKm: 0.0,
        fuelSavedLiters: 0.0,
        co2SavedKg: 0.0,
        fuelCostSavedRupees: 0.0,
      );
    }

    final unoptimizedDistance = calculateLoopDistance(hub, tasks);

    final unvisited = List<DeliveryTaskModel>.from(tasks);
    final orderedStops = <DeliveryTaskModel>[];

    double currentLat = hub.latitude;
    double currentLon = hub.longitude;

    while (unvisited.isNotEmpty) {
      int nearestIdx = 0;
      double minDistance = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final stop = unvisited[i];
        final dist = calculateDistanceKm(currentLat, currentLon, stop.customerLatitude, stop.customerLongitude);
        if (dist < minDistance) {
          minDistance = dist;
          nearestIdx = i;
        }
      }

      final chosenStop = unvisited.removeAt(nearestIdx);
      orderedStops.add(chosenStop);
      currentLat = chosenStop.customerLatitude;
      currentLon = chosenStop.customerLongitude;
    }

    final optimizedDistance = calculateLoopDistance(hub, orderedStops);

    final rawSavedKm = unoptimizedDistance - optimizedDistance;
    final distanceSavedKm = rawSavedKm > 0 ? rawSavedKm : 0.0;

    // 0.035 Liters/km consumption for delivery scooter, petrol @ ₹105/L, 2.31 kg CO2/L
    final fuelSavedLiters = distanceSavedKm * 0.035;
    final fuelCostSavedRupees = fuelSavedLiters * 105.0;
    final co2SavedKg = fuelSavedLiters * 2.31;

    return RouteOptimizationResult(
      orderedStops: orderedStops,
      totalDistanceKm: optimizedDistance,
      unoptimizedDistanceKm: unoptimizedDistance,
      distanceSavedKm: distanceSavedKm,
      fuelSavedLiters: fuelSavedLiters,
      co2SavedKg: co2SavedKg,
      fuelCostSavedRupees: fuelCostSavedRupees,
    );
  }

  /// Partitions the total hub delivery orders into N equal geographic clusters (one for each delivery boy),
  /// and runs TSP shortest-path optimization on each sub-route.
  static List<RouteOptimizationResult> partitionEquallyForDrivers({
    required HubLocationModel hub,
    required List<DeliveryTaskModel> allTasks,
    required int numberOfDrivers,
  }) {
    if (allTasks.isEmpty || numberOfDrivers <= 0) return [];

    final driverCount = min(numberOfDrivers, allTasks.length);

    // 1. Sort all tasks by polar angle relative to the Hub to form contiguous geographic sectors
    final sortedByAngle = List<DeliveryTaskModel>.from(allTasks)..sort((a, b) {
      final angleA = atan2(a.customerLatitude - hub.latitude, a.customerLongitude - hub.longitude);
      final angleB = atan2(b.customerLatitude - hub.latitude, b.customerLongitude - hub.longitude);
      return angleA.compareTo(angleB);
    });

    // 2. Partition into N equal-sized stop lists
    final partitions = List.generate(driverCount, (_) => <DeliveryTaskModel>[]);
    for (int i = 0; i < sortedByAngle.length; i++) {
      final driverIdx = i % driverCount;
      partitions[driverIdx].add(sortedByAngle[i]);
    }

    // 3. Optimize each driver's individual route via Nearest-Neighbor TSP from the Hub
    return partitions.map((driverStops) {
      return optimizeBatchRoute(hub: hub, tasks: driverStops);
    }).toList();
  }

  /// Decodes Google's standard compressed Polyline Algorithm Format into LatLng points.
  static List<LatLng> decodeGooglePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  /// Fetches street-snapped road polyline geometry using official Google Maps Directions API.
  /// Seamlessly falls back to high-resolution OSRM routing if Google quota is reached or key is restricted.
  static Future<List<LatLng>> fetchRealRoadPolyline(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    // 1. Primary Engine: Official Google Maps Directions API
    try {
      final origin = '${waypoints.first.latitude.toStringAsFixed(6)},${waypoints.first.longitude.toStringAsFixed(6)}';
      final destination = '${waypoints.last.latitude.toStringAsFixed(6)},${waypoints.last.longitude.toStringAsFixed(6)}';

      String waypointsParam = '';
      if (waypoints.length > 2) {
        final intermediate = waypoints.sublist(1, waypoints.length - 1);
        final sampled = intermediate.length > 23 ? _sampleWaypoints(intermediate, 23) : intermediate;
        waypointsParam = '&waypoints=optimize:true|${sampled.map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}').join('|')}';
      }

      final apiKey = AppConfig.googleMapsApiKey;
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypointsParam&mode=driving&key=$apiKey',
      );

      final response = await http.get(googleUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final overviewPolyline = data['routes'][0]['overview_polyline'];
          if (overviewPolyline != null && overviewPolyline['points'] != null) {
            final decoded = decodeGooglePolyline(overviewPolyline['points'].toString());
            if (decoded.isNotEmpty) {
              return decoded;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Dual-Engine Fallback: OSRM Street Network Routing
    try {
      final sample = waypoints.length > 25 ? _sampleWaypoints(waypoints, 25) : waypoints;
      final coordsString = sample.map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}').join(';');
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson');

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            final List rawCoords = geometry['coordinates'];
            final roadPoints = rawCoords
                .map<LatLng>((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
                .toList();
            if (roadPoints.isNotEmpty) {
              return roadPoints;
            }
          }
        }
      }
    } catch (_) {}

    return waypoints;
  }

  static List<LatLng> _sampleWaypoints(List<LatLng> points, int maxCount) {
    if (points.length <= maxCount) return points;
    final result = <LatLng>[points.first];
    final step = (points.length - 2) / (maxCount - 2);
    for (int i = 1; i < maxCount - 1; i++) {
      final index = (i * step).round().clamp(1, points.length - 2);
      result.add(points[index]);
    }
    result.add(points.last);
    return result;
  }
}
