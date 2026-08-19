class UserModel {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String role; // CUSTOMER, DRIVER, ADMIN
  final String phone;
  final String address;
  final String city;
  final double walletBalance;
  final String deliveryInstructions;
  final String deliverySlotPreference;
  final double latitude;
  final double longitude;

  final double monthlySalary;
  final String vehicleNumber;
  final String drivingLicense;

  UserModel({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.phone,
    required this.address,
    required this.city,
    required this.walletBalance,
    required this.deliveryInstructions,
    this.deliverySlotPreference = '05:30 AM - 07:00 AM',
    this.latitude = 17.4319,
    this.longitude = 78.4073,
    this.monthlySalary = 15000.0,
    this.vehicleNumber = '',
    this.drivingLicense = '',
  });

  String get fullName => '$firstName $lastName'.trim().isEmpty ? (username.isNotEmpty ? username : 'Customer') : '$firstName $lastName'.trim();

  bool get isCustomer => role.toUpperCase() == 'CUSTOMER';
  bool get isDriver => role.toUpperCase() == 'DRIVER';
  bool get isAdmin => role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'PROVIDER';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? 'Hyderabad',
      walletBalance: double.tryParse(json['wallet_balance']?.toString() ?? '0') ?? 0.0,
      deliveryInstructions: json['delivery_instructions'] ?? '',
      deliverySlotPreference: json['delivery_slot_preference'] ?? '05:30 AM - 07:00 AM',
      latitude: double.tryParse(json['latitude']?.toString() ?? '17.4319') ?? 17.4319,
      longitude: double.tryParse(json['longitude']?.toString() ?? '78.4073') ?? 78.4073,
      monthlySalary: double.tryParse(json['monthly_salary']?.toString() ?? '15000') ?? 15000.0,
      vehicleNumber: json['vehicle_number'] ?? '',
      drivingLicense: json['driving_license'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'city': city,
      'wallet_balance': walletBalance.toStringAsFixed(2),
      'delivery_instructions': deliveryInstructions,
      'delivery_slot_preference': deliverySlotPreference,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? city,
    double? walletBalance,
    String? deliveryInstructions,
    String? deliverySlotPreference,
    String? role,
    double? latitude,
    double? longitude,
  }) {
    return UserModel(
      id: id,
      username: username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      walletBalance: walletBalance ?? this.walletBalance,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      deliverySlotPreference: deliverySlotPreference ?? this.deliverySlotPreference,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
