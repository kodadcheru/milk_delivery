import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/delivery_batch_model.dart';
import 'package:milk_delivery_frontend/models/delivery_task_model.dart';
import 'package:milk_delivery_frontend/services/route_optimizer.dart';

void main() {
  group('RouteOptimizer Tests', () {
    const hub = HubLocationModel(
      id: 'HUB-TEST-01',
      name: 'Test Dispatch Depot',
      address: 'Jubilee Hills Central',
      latitude: 17.4320,
      longitude: 78.4070,
      managerName: 'Rajesh V.',
      managerPhone: '+91 98888 77777',
    );

    final mockTasks = [
      DeliveryTaskModel(
        id: 1,
        subscriptionId: 101,
        customerName: 'Far Stop A',
        deliveryDate: '2026-08-19',
        slotTime: '05:30 AM - 07:00 AM',
        status: 'PENDING',
        proofImageUrl: '',
        customerLatitude: 17.4450, // Far North
        customerLongitude: 78.4190,
      ),
      DeliveryTaskModel(
        id: 2,
        subscriptionId: 102,
        customerName: 'Near Stop B',
        deliveryDate: '2026-08-19',
        slotTime: '05:30 AM - 07:00 AM',
        status: 'PENDING',
        proofImageUrl: '',
        customerLatitude: 17.4330, // Very close to Hub (17.4320, 78.4070)
        customerLongitude: 78.4080,
      ),
      DeliveryTaskModel(
        id: 3,
        subscriptionId: 103,
        customerName: 'Medium Stop C',
        deliveryDate: '2026-08-19',
        slotTime: '05:30 AM - 07:00 AM',
        status: 'PENDING',
        proofImageUrl: '',
        customerLatitude: 17.4380, // Medium distance
        customerLongitude: 78.4120,
      ),
    ];

    test('Haversine distance calculates positive non-zero distance for distinct coordinates', () {
      final distance = RouteOptimizer.calculateDistanceKm(
        17.4320, 78.4070,
        17.4450, 78.4190,
      );
      expect(distance > 0, isTrue);
      expect(distance < 10.0, isTrue);
    });

    test('TSP Nearest-Neighbor sorts nearest stop to Hub first', () {
      final result = RouteOptimizer.optimizeBatchRoute(
        hub: hub,
        tasks: mockTasks,
      );

      expect(result.orderedStops.length, equals(3));
      // Stop 2 is nearest to hub, so it should be Stop 1 in sequence
      expect(result.orderedStops.first.id, equals(2));
      // Stop 3 is next nearest
      expect(result.orderedStops[1].id, equals(3));
      // Stop 1 is furthest
      expect(result.orderedStops.last.id, equals(1));
    });

    test('RouteOptimizer generates fuel, cost, and CO2 savings', () {
      final result = RouteOptimizer.optimizeBatchRoute(
        hub: hub,
        tasks: mockTasks,
      );

      expect(result.totalDistanceKm > 0, isTrue);
      expect(result.fuelSavedLiters > 0, isTrue);
      expect(result.fuelCostSavedRupees > 0, isTrue);
      expect(result.co2SavedKg > 0, isTrue);
    });
  });
}
