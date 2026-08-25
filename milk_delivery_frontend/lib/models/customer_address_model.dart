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
    this.city = '',
    this.pincode = '',
    this.latitude = 17.001734,
    this.longitude = 79.9625,
    this.deliveryInstructions = '',
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
    String flat = json['flat_house_no']?.toString() ?? '';
    String building = json['building_name']?.toString() ?? '';
    String street = json['street_address']?.toString() ?? '';
    final String rawFormatted = json['formatted_address']?.toString() ?? '';

    // Service-Mobile Resilient String Fallback: If discrete fields are blank, split CSV
    if (flat.isEmpty && building.isEmpty && street.isNotEmpty && street.contains(',')) {
      final parts = street.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 3) {
        flat = parts[0];
        building = parts[1];
        street = parts.sublist(2).join(', ');
      } else if (parts.length == 2) {
        flat = parts[0];
        street = parts[1];
      }
    }

    return CustomerAddressModel(
      id: json['id'] ?? 0,
      userId: json['user'],
      addressType: json['address_type'] ?? 'HOME',
      displayType: json['display_type'] ?? 'Home',
      customTag: json['custom_tag'] ?? '',
      flatHouseNo: flat,
      floor: json['floor'] ?? '',
      buildingName: building,
      streetAddress: street,
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? '',
      pincode: json['pincode'] ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '17.001734') ?? 17.001734,
      longitude: double.tryParse(json['longitude']?.toString() ?? '79.9625') ?? 79.9625,
      deliveryInstructions: json['delivery_instructions'] ?? '',
      isDefault: json['is_default'] ?? false,
      formattedAddress: rawFormatted,
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
}
