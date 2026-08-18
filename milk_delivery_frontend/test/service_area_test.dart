import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/service_area_model.dart';

void main() {
  group('ServiceAreaModel Tests', () {
    test('Default areas are populated with valid data', () {
      final areas = ServiceAreaModel.defaultAreas;
      expect(areas.isNotEmpty, isTrue);
      expect(areas.any((a) => a.name.contains('Jubilee Hills')), isTrue);
      expect(areas.any((a) => a.status == 'ACTIVE'), isTrue);
      expect(areas.any((a) => a.status == 'WAITLIST'), isTrue);
    });

    test('ServiceAreaModel parses JSON correctly', () {
      final json = {
        'id': 10,
        'name': 'Gachibowli Outer Ring',
        'city': 'Hyderabad',
        'pincodes': '500032, 500075',
        'radius_km': 6.0,
        'latitude': 17.4401,
        'longitude': 78.3489,
        'status': 'ACTIVE',
        'active_households': 150,
        'popular_societies': 'Aparna Sarovar',
        'hub_detail': {
          'name': 'Madhapur Tech Depot',
          'hub_code': 'HUB-HYD-03',
        },
      };

      final model = ServiceAreaModel.fromJson(json);
      expect(model.id, equals(10));
      expect(model.name, equals('Gachibowli Outer Ring'));
      expect(model.hubName, equals('Madhapur Tech Depot'));
      expect(model.radiusKm, equals(6.0));
      expect(model.status, equals('ACTIVE'));
    });
  });
}
