class CustomerAddressModel {
  final int id;
  final int? userId;
  final String addressType; // HOME, WORK, OTHER
  final String displayType;
  final String customTag;
  final String flatHouseNo;
  final String floor;
  final String buildingName;
  final String streetAddress;
  final String landmark;
  final String city;
  final String pincode;
  final double latitude;
  final double longitude;
  final String deliveryInstructions;
  final bool isDefault;
  final String formattedAddress;

  CustomerAddressModel({
    required this.id,
    this.userId,
    this.addressType = 'HOME',
    this.displayType = 'Home',
    this.customTag = '',
    this.flatHouseNo = '',
    this.floor = '',
    this.buildingName = '',
    required this.streetAddress,
    this.landmark = '',
    this.city = 'Hyderabad',
    this.pincode = '500033',
    this.latitude = 17.4319,
    this.longitude = 78.4073,
    this.deliveryInstructions = 'Leave in doorstep milk basket, ring bell',
    this.isDefault = false,
    this.formattedAddress = '',
  });

  String get icon {
    switch (addressType.toUpperCase()) {
      case 'HOME':
        return '🏠';
      case 'WORK':
        return '💼';
      case 'OTHER':
      default:
        return '📍';
    }
  }

  String get title {
    if (customTag.isNotEmpty) return customTag;
    switch (addressType.toUpperCase()) {
      case 'HOME':
        return 'Home';
      case 'WORK':
        return 'Work / Office';
      case 'OTHER':
      default:
        return 'Other Location';
    }
  }

  String get summaryAddress {
    if (formattedAddress.isNotEmpty) return formattedAddress;
    final parts = <String>[];
    if (flatHouseNo.isNotEmpty) parts.add(flatHouseNo);
    if (buildingName.isNotEmpty) parts.add(buildingName);
    if (streetAddress.isNotEmpty) parts.add(streetAddress);
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    return parts.isNotEmpty ? parts.join(', ') : streetAddress;
  }

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) {
    return CustomerAddressModel(
      id: json['id'] ?? 0,
      userId: json['user'],
      addressType: json['address_type'] ?? 'HOME',
      displayType: json['display_type'] ?? 'Home',
      customTag: json['custom_tag'] ?? '',
      flatHouseNo: json['flat_house_no'] ?? '',
      floor: json['floor'] ?? '',
      buildingName: json['building_name'] ?? '',
      streetAddress: json['street_address'] ?? 'Road No. 36, Jubilee Hills',
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? 'Hyderabad',
      pincode: json['pincode'] ?? '500033',
      latitude: double.tryParse(json['latitude']?.toString() ?? '17.4319') ?? 17.4319,
      longitude: double.tryParse(json['longitude']?.toString() ?? '78.4073') ?? 78.4073,
      deliveryInstructions: json['delivery_instructions'] ?? 'Leave in doorstep basket',
      isDefault: json['is_default'] ?? false,
      formattedAddress: json['formatted_address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address_type': addressType,
      'custom_tag': customTag,
      'flat_house_no': flatHouseNo,
      'floor': floor,
      'building_name': buildingName,
      'street_address': streetAddress,
      'landmark': landmark,
      'city': city,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
    };
  }

  CustomerAddressModel copyWith({
    int? id,
    String? addressType,
    String? customTag,
    String? flatHouseNo,
    String? floor,
    String? buildingName,
    String? streetAddress,
    String? landmark,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool? isDefault,
    String? formattedAddress,
  }) {
    return CustomerAddressModel(
      id: id ?? this.id,
      userId: userId,
      addressType: addressType ?? this.addressType,
      displayType: displayType,
      customTag: customTag ?? this.customTag,
      flatHouseNo: flatHouseNo ?? this.flatHouseNo,
      floor: floor ?? this.floor,
      buildingName: buildingName ?? this.buildingName,
      streetAddress: streetAddress ?? this.streetAddress,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      isDefault: isDefault ?? this.isDefault,
      formattedAddress: formattedAddress ?? this.formattedAddress,
    );
  }

  static List<CustomerAddressModel> get defaultSampleAddresses => [
    CustomerAddressModel(
      id: 1,
      addressType: 'HOME',
      customTag: 'Home',
      flatHouseNo: 'Flat 402, Block C',
      floor: '4th Floor',
      buildingName: 'My Home Bhooja',
      streetAddress: 'Road No. 36, Jubilee Hills',
      landmark: 'Near Peddamma Temple',
      city: 'Hyderabad',
      pincode: '500033',
      latitude: 17.4319,
      longitude: 78.4073,
      deliveryInstructions: 'Leave in milk box at doorstep. Do not ring bell before 06:00 AM.',
      isDefault: true,
    ),
    CustomerAddressModel(
      id: 2,
      addressType: 'WORK',
      customTag: 'Office',
      flatHouseNo: 'Tower 3, 8th Floor',
      floor: '8th Floor',
      buildingName: 'Cyber Towers Tech Park',
      streetAddress: 'Hitec City Main Road, Madhapur',
      landmark: 'Near Hitec City Metro',
      city: 'Hyderabad',
      pincode: '500081',
      latitude: 17.4483,
      longitude: 78.3915,
      deliveryInstructions: 'Handover to 8th Floor reception desk.',
      isDefault: false,
    ),
  ];
}
