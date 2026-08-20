import 'subscription_model.dart';
import 'user_model.dart';

class DeliveryTaskModel {
  final int id;
  final int subscriptionId;
  final SubscriptionModel? subscriptionDetail;
  final int? driverId;
  final UserModel? driverDetail;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String deliveryInstructions;
  final String deliveryDate;
  final String slotTime;
  final String status; // PENDING, DELIVERED, SKIPPED
  final String proofImageUrl;
  final String? deliveredAt;
  final double customerLatitude;
  final double customerLongitude;

  DeliveryTaskModel({
    required this.id,
    required this.subscriptionId,
    this.subscriptionDetail,
    this.driverId,
    this.driverDetail,
    this.customerName = 'Customer',
    this.customerPhone = '',
    this.deliveryAddress = 'Doorstep Delivery Location',
    this.deliveryInstructions = 'Ring bell twice and leave in doorstep box',
    required this.deliveryDate,
    required this.slotTime,
    required this.status,
    required this.proofImageUrl,
    this.deliveredAt,
    this.customerLatitude = 17.4319,
    this.customerLongitude = 78.4073,
  });

  factory DeliveryTaskModel.fromJson(Map<String, dynamic> json) {
    SubscriptionModel? subDetail;
    if (json['subscription_detail'] != null) {
      subDetail = SubscriptionModel.fromJson(json['subscription_detail']);
    }

    UserModel? drvDetail;
    if (json['driver_detail'] != null) {
      drvDetail = UserModel.fromJson(json['driver_detail']);
    }

    double parsedLat = 16.9950;
    double parsedLon = 79.9670;

    if (json['customer_latitude'] != null) {
      final v = double.tryParse(json['customer_latitude'].toString());
      if (v != null && v != 0.0) parsedLat = v;
    } else if (subDetail != null && subDetail.deliveryLatitude != 0.0) {
      parsedLat = subDetail.deliveryLatitude;
    }

    if (json['customer_longitude'] != null) {
      final v = double.tryParse(json['customer_longitude'].toString());
      if (v != null && v != 0.0) parsedLon = v;
    } else if (subDetail != null && subDetail.deliveryLongitude != 0.0) {
      parsedLon = subDetail.deliveryLongitude;
    }

    return DeliveryTaskModel(
      id: json['id'] ?? 0,
      subscriptionId: json['subscription'] ?? 0,
      subscriptionDetail: subDetail,
      driverId: json['driver'],
      driverDetail: drvDetail,
      customerName: json['customer_name'] ?? 'Customer',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? 'Doorstep Delivery Location',
      deliveryInstructions: json['delivery_instructions'] ?? 'Leave near doorstep box',
      deliveryDate: json['delivery_date'] ?? '',
      slotTime: json['slot_time'] ?? '05:30 AM - 07:00 AM',
      status: json['status'] ?? 'PENDING',
      proofImageUrl: json['proof_image_url'] ?? '',
      deliveredAt: json['delivered_at'],
      customerLatitude: parsedLat,
      customerLongitude: parsedLon,
    );
  }

  DeliveryTaskModel copyWith({
    String? status,
    String? proofImageUrl,
    String? deliveredAt,
  }) {
    return DeliveryTaskModel(
      id: id,
      subscriptionId: subscriptionId,
      subscriptionDetail: subscriptionDetail,
      driverId: driverId,
      driverDetail: driverDetail,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryInstructions: deliveryInstructions,
      deliveryDate: deliveryDate,
      slotTime: slotTime,
      status: status ?? this.status,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
    );
  }

  bool get isDelivered => status == 'DELIVERED';
}
