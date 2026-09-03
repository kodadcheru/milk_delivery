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
    final plusCodeRegex = RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}$');
    if (formattedAddress.isNotEmpty) {
      final clean = formattedAddress
          .replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4},?\s*'), '')
          .replaceAll(RegExp(r',\s*[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}'), '')
          .trim();
      if (clean.isNotEmpty) return clean;
    }
    final parts = <String>[];
    if (flatHouseNo.isNotEmpty && !plusCodeRegex.hasMatch(flatHouseNo)) parts.add(flatHouseNo);
    if (buildingName.isNotEmpty && !plusCodeRegex.hasMatch(buildingName)) parts.add(buildingName);
    if (streetAddress.isNotEmpty) {
      final cleanStreet = streetAddress
          .replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4},?\s*'), '')
          .replaceAll(RegExp(r',\s*[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}'), '')
          .trim();
      if (cleanStreet.isNotEmpty) parts.add(cleanStreet);
    }
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    return parts.isNotEmpty ? parts.join(', ') : (streetAddress.isNotEmpty ? streetAddress : 'Main Road, Kodad');
  }

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) {
    String flat = json['flat_house_no']?.toString() ?? '';
    String building = json['building_name']?.toString() ?? '';
    String street = json['street_address']?.toString() ?? '';
    final String rawFormatted = json['formatted_address']?.toString() ?? '';

    // Clean raw Plus Codes like 2X27+P3X from flat/building
    final plusCodeRegex = RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}$');
    if (plusCodeRegex.hasMatch(flat)) {
      flat = '';
    }
    if (plusCodeRegex.hasMatch(building)) {
      building = '';
    }

    // Service-Mobile Resilient String Fallback: If discrete fields are blank, split CSV
    if (flat.isEmpty && building.isEmpty && street.isNotEmpty && street.contains(',')) {
      final parts = street.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final cleanParts = parts.where((p) => !plusCodeRegex.hasMatch(p)).toList();
      if (cleanParts.length >= 3) {
        flat = cleanParts[0];
        building = cleanParts[1];
        street = cleanParts.sublist(2).join(', ');
      } else if (cleanParts.length == 2) {
        flat = cleanParts[0];
        street = cleanParts[1];
      } else if (cleanParts.length == 1) {
        street = cleanParts[0];
      }
    }

    return CustomerAddressModel(
      id: json['id'] ?? 0,
      userId: json['user'] is int
          ? json['user']
          : (int.tryParse(json['user']?.toString() ?? '') ??
              (json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '')) ??
              (json['customer_id'] is int ? json['customer_id'] : int.tryParse(json['customer_id']?.toString() ?? ''))),
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
    final effectiveStreet = streetAddress.trim().isNotEmpty
        ? streetAddress.trim()
        : (summaryAddress.trim().isNotEmpty ? summaryAddress.trim() : 'Main Road, Kodad');

    return {
      'id': id,
      if (userId != null && userId! > 0) 'user': userId,
      if (userId != null && userId! > 0) 'user_id': userId,
      if (userId != null && userId! > 0) 'customer_id': userId,
      'address_type': addressType,
      'custom_tag': customTag,
      'flat_house_no': flatHouseNo,
      'floor': floor,
      'building_name': buildingName,
      'street_address': effectiveStreet,
      'landmark': landmark,
      'city': city.isNotEmpty ? city : 'Kodad',
      'pincode': pincode.isNotEmpty ? pincode : '508206',
      'latitude': double.parse(latitude.toStringAsFixed(8)),
      'longitude': double.parse(longitude.toStringAsFixed(8)),
      'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
    };
  }

  CustomerAddressModel copyWith({
    int? id,
    int? userId,
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
      userId: userId ?? this.userId,
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
