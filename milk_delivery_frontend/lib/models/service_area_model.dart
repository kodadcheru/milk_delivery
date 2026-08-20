class ServiceAreaModel {
  final int id;
  final String name;
  final String city;
  final String pincodes;
  final double radiusKm;
  final double latitude;
  final double longitude;
  final String status; // 'ACTIVE', 'EXPANDING', 'WAITLIST'
  final int activeHouseholds;
  final String popularSocieties;
  final String hubName;
  final String hubCode;

  const ServiceAreaModel({
    required this.id,
    required this.name,
    required this.city,
    required this.pincodes,
    required this.radiusKm,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.activeHouseholds,
    required this.popularSocieties,
    required this.hubName,
    required this.hubCode,
  });

  factory ServiceAreaModel.fromJson(Map<String, dynamic> json) {
    final hub = json['hub_detail'] as Map<String, dynamic>?;

    return ServiceAreaModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Hyderabad Cluster',
      city: json['city'] as String? ?? 'Hyderabad',
      pincodes: json['pincodes'] as String? ?? '500033',
      radiusKm: double.tryParse(json['radius_km']?.toString() ?? '5.0') ?? 5.0,
      latitude: double.tryParse(json['latitude']?.toString() ?? '17.4320') ?? 17.4320,
      longitude: double.tryParse(json['longitude']?.toString() ?? '78.4070') ?? 78.4070,
      status: json['status'] as String? ?? 'ACTIVE',
      activeHouseholds: json['active_households'] as int? ?? 100,
      popularSocieties: json['popular_societies'] as String? ?? 'Gated Societies & Villas',
      hubName: hub?['name'] as String? ?? 'Operations Depot',
      hubCode: hub?['hub_code'] as String? ?? 'HUB-OPS',
    );
  }

  static const fallbackArea = ServiceAreaModel(
    id: 0,
    name: 'Standard Delivery Area',
    city: 'Hyderabad',
    pincodes: '500033',
    radiusKm: 10.0,
    latitude: 17.4319,
    longitude: 78.4073,
    status: 'ACTIVE',
    activeHouseholds: 0,
    popularSocieties: 'Local Delivery Zones',
    hubName: 'Operations Depot',
    hubCode: 'HUB-OPS',
  );

  static List<ServiceAreaModel> get defaultAreas => const [];
}
