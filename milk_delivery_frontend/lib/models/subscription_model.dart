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

  SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.productId,
    this.productDetail,
    required this.quantity,
    required this.scheduleType,
    required this.startDate,
    required this.status,
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
    );
  }

  SubscriptionModel copyWith({
    int? quantity,
    String? scheduleType,
    String? status,
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
    );
  }
}
