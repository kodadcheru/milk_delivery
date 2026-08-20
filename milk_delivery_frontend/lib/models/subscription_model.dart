import 'product_model.dart';

class SubscriptionModel {
  final int id;
  final int customerId;
  final int productId;
  final ProductModel? productDetail;
  final int quantity;
  final String scheduleType; // DAILY, ALTERNATE, CUSTOM, ONCE
  final String startDate;
  final String status; // ACTIVE, PAUSED, CANCELLED
  final String deliveryAddress;
  final String deliverySlot;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String deliveryInstructions;
  final String packSize;

  SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.productId,
    this.productDetail,
    required this.quantity,
    required this.scheduleType,
    required this.startDate,
    required this.status,
    this.deliveryAddress = 'Doorstep Drop',
    this.deliverySlot = '05:30 AM - 07:00 AM',
    this.deliveryLatitude = 17.4319,
    this.deliveryLongitude = 78.4073,
    this.deliveryInstructions = '',
    this.packSize = '1 Litre',
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    ProductModel? pDetail;
    if (json['product_detail'] != null) {
      pDetail = ProductModel.fromJson(json['product_detail']);
    }

    return SubscriptionModel(
      id: json['id'] ?? 0,
      customerId: json['customer'] ?? 0,
      productId: json['product'] ?? 0,
      productDetail: pDetail,
      quantity: json['quantity'] ?? 1,
      scheduleType: json['schedule_type'] ?? 'DAILY',
      startDate: json['start_date'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      deliveryAddress: json['delivery_address'] ?? 'Doorstep Drop',
      deliverySlot: json['delivery_slot'] ?? '05:30 AM - 07:00 AM',
      deliveryLatitude: double.tryParse(json['delivery_latitude']?.toString() ?? '17.4319') ?? 17.4319,
      deliveryLongitude: double.tryParse(json['delivery_longitude']?.toString() ?? '78.4073') ?? 78.4073,
      deliveryInstructions: json['delivery_instructions'] ?? '',
      packSize: json['pack_size'] ?? '1 Litre',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer': customerId,
      'product': productId,
      'quantity': quantity,
      'schedule_type': scheduleType,
      'start_date': startDate,
      'status': status,
      'delivery_address': deliveryAddress,
      'delivery_slot': deliverySlot,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_instructions': deliveryInstructions,
      'pack_size': packSize,
    };
  }

  SubscriptionModel copyWith({
    int? quantity,
    String? scheduleType,
    String? status,
    String? deliveryAddress,
    String? deliverySlot,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryInstructions,
    String? packSize,
  }) {
    return SubscriptionModel(
      id: id,
      customerId: customerId,
      productId: productId,
      productDetail: productDetail,
      quantity: quantity ?? this.quantity,
      scheduleType: scheduleType ?? this.scheduleType,
      startDate: startDate,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      packSize: packSize ?? this.packSize,
    );
  }
}
