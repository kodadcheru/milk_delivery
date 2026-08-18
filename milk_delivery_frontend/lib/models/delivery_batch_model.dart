import 'delivery_task_model.dart';

class HubLocationModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String managerName;
  final String managerPhone;

  const HubLocationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.managerName,
    required this.managerPhone,
  });

  static const HubLocationModel defaultHub = HubLocationModel(
    id: 'HUB-JUBILEE-01',
    name: 'Jubilee Hills Central Depot #1',
    address: 'Plot 42, Road #36, Jubilee Hills, Hyderabad',
    latitude: 17.4320,
    longitude: 78.4070,
    managerName: 'Rajesh V. (Dispatch Lead)',
    managerPhone: '+91 98888 77777',
  );
}

class CrateItemManifest {
  final String productName;
  final String icon;
  final int totalUnits;
  final String unitVolume;
  final String crateLabel;

  const CrateItemManifest({
    required this.productName,
    required this.icon,
    required this.totalUnits,
    required this.unitVolume,
    required this.crateLabel,
  });
}

class RouteOptimizationResult {
  final List<DeliveryTaskModel> orderedStops;
  final double totalDistanceKm;
  final double unoptimizedDistanceKm;
  final double distanceSavedKm;
  final double fuelSavedLiters;
  final double co2SavedKg;
  final double fuelCostSavedRupees;

  const RouteOptimizationResult({
    required this.orderedStops,
    required this.totalDistanceKm,
    required this.unoptimizedDistanceKm,
    required this.distanceSavedKm,
    required this.fuelSavedLiters,
    required this.co2SavedKg,
    required this.fuelCostSavedRupees,
  });
}

class DeliveryBatchModel {
  final String batchCode;
  final HubLocationModel hub;
  final String shiftDate;
  final String slotTime;
  final String driverName;
  final String status; // PREPARING, LOADED, IN_TRANSIT, COMPLETED
  final List<CrateItemManifest> crateManifest;
  final List<DeliveryTaskModel> stops;
  final int bottlesCollected;
  final double totalDistanceKm;
  final double fuelSavedLiters;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const DeliveryBatchModel({
    required this.batchCode,
    required this.hub,
    required this.shiftDate,
    required this.slotTime,
    required this.driverName,
    required this.status,
    required this.crateManifest,
    required this.stops,
    this.bottlesCollected = 0,
    this.totalDistanceKm = 0.0,
    this.fuelSavedLiters = 0.0,
    this.startedAt,
    this.completedAt,
  });

  int get completedStopsCount => stops.where((s) => s.status == 'DELIVERED').length;
  int get totalStopsCount => stops.length;
  bool get isAllCompleted => totalStopsCount > 0 && completedStopsCount == totalStopsCount;
}
