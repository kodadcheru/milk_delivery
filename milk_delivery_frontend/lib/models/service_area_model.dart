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
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 5.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 17.4320,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 78.4070,
      status: json['status'] as String? ?? 'ACTIVE',
      activeHouseholds: json['active_households'] as int? ?? 100,
      popularSocieties: json['popular_societies'] as String? ?? 'Gated Societies & Villas',
      hubName: hub?['name'] as String? ?? 'Jubilee Hills Central Depot #1',
      hubCode: hub?['hub_code'] as String? ?? 'HUB-HYD-01',
    );
  }

  static List<ServiceAreaModel> get defaultAreas => const [
    ServiceAreaModel(
      id: 1,
      name: 'Jubilee Hills (Sector A, B & C)',
      city: 'Hyderabad',
      pincodes: '500033, 500096',
      radiusKm: 4.5,
      latitude: 17.4320,
      longitude: 78.4070,
      status: 'ACTIVE',
      activeHouseholds: 128,
      popularSocieties: 'Jubilee Hills Enclave, Road 36 Villas, Daspalla Hills',
      hubName: 'Jubilee Hills Central Depot #1',
      hubCode: 'HUB-HYD-01',
    ),
    ServiceAreaModel(
      id: 2,
      name: 'Film Nagar & Prashasan Nagar',
      city: 'Hyderabad',
      pincodes: '500096',
      radiusKm: 3.8,
      latitude: 17.4190,
      longitude: 78.4110,
      status: 'ACTIVE',
      activeHouseholds: 64,
      popularSocieties: 'Film Nagar Cultural Society, MLA Colony, Film Nagar Hills',
      hubName: 'Jubilee Hills Central Depot #1',
      hubCode: 'HUB-HYD-01',
    ),
    ServiceAreaModel(
      id: 3,
      name: 'Banjara Hills (Road 1 to 14)',
      city: 'Hyderabad',
      pincodes: '500034',
      radiusKm: 5.0,
      latitude: 17.4156,
      longitude: 78.4350,
      status: 'ACTIVE',
      activeHouseholds: 94,
      popularSocieties: 'Banjara Heights, Road #12 Lux, Green Valley Enclave',
      hubName: 'Banjara Hills Micro-Depot #2',
      hubCode: 'HUB-HYD-02',
    ),
    ServiceAreaModel(
      id: 4,
      name: 'Madhapur & Hitec City Core',
      city: 'Hyderabad',
      pincodes: '500081',
      radiusKm: 5.5,
      latitude: 17.4483,
      longitude: 78.3915,
      status: 'ACTIVE',
      activeHouseholds: 160,
      popularSocieties: 'My Home Bhooja, Rainbow Vistas, Jayabheri Silicon County',
      hubName: 'Madhapur Tech Enclave Depot #3',
      hubCode: 'HUB-HYD-03',
    ),
    ServiceAreaModel(
      id: 5,
      name: 'Gachibowli Financial District',
      city: 'Hyderabad',
      pincodes: '500032, 500075',
      radiusKm: 6.0,
      latitude: 17.4401,
      longitude: 78.3489,
      status: 'ACTIVE',
      activeHouseholds: 142,
      popularSocieties: 'Aparna Sarovar, Golf View Apartments, Golf Edge',
      hubName: 'Madhapur Tech Enclave Depot #3',
      hubCode: 'HUB-HYD-03',
    ),
    ServiceAreaModel(
      id: 6,
      name: 'Kondapur & Botanical Garden',
      city: 'Hyderabad',
      pincodes: '500084',
      radiusKm: 4.0,
      latitude: 17.4699,
      longitude: 78.3578,
      status: 'EXPANDING',
      activeHouseholds: 48,
      popularSocieties: 'My Home Mangala, Fortune Fields, Raghava Iris',
      hubName: 'Madhapur Tech Enclave Depot #3',
      hubCode: 'HUB-HYD-03',
    ),
    ServiceAreaModel(
      id: 7,
      name: 'Kukatpally Housing Board (KPHB)',
      city: 'Hyderabad',
      pincodes: '500072',
      radiusKm: 5.0,
      latitude: 17.4938,
      longitude: 78.3995,
      status: 'WAITLIST',
      activeHouseholds: 210,
      popularSocieties: 'Lodha Bellezza, Malaysian Township, Vertex Pleasant',
      hubName: 'Pending Depot Allocation',
      hubCode: 'WAITLIST',
    ),
  ];
}
