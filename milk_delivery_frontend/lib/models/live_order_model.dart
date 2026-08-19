import 'product_model.dart';

class OrderItemModel {
  final ProductModel product;
  final int quantity;
  final double unitPrice;

  OrderItemModel({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => unitPrice * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      product: ProductModel.fromJson(json['product'] ?? {}),
      quantity: json['quantity'] ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class LiveOrderModel {
  final String id; // e.g. MD-8492
  final String orderType; // EXPRESS, ONE_TIME, SUBSCRIPTION_ORDER
  final List<OrderItemModel> items;
  final double totalAmount;
  final String status; // PLACED, PREPARING, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
  final String deliveryDate;
  final String deliverySlot;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String deliveryOtp;
  final String driverName;
  final String driverPhone;
  final String paymentStatus;
  final String createdAt;
  final String? deliveredAt;
  final String proofImageUrl;

  LiveOrderModel({
    required this.id,
    this.orderType = 'ONE_TIME',
    required this.items,
    required this.totalAmount,
    required this.status,
    this.deliveryDate = 'Tomorrow',
    this.deliverySlot = '05:30 AM - 07:00 AM',
    this.deliveryAddress = 'Jubilee Hills, Hyderabad',
    this.deliveryLatitude = 17.4319,
    this.deliveryLongitude = 78.4073,
    this.deliveryOtp = '4892',
    this.driverName = 'Suresh Rao (Partner #4)',
    this.driverPhone = '+91 9123456789',
    this.paymentStatus = 'PAID (Wallet Auto-Debit)',
    required this.createdAt,
    this.deliveredAt,
    this.proofImageUrl = '',
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  LiveOrderModel copyWith({
    String? status,
    String? deliveryDate,
    String? deliverySlot,
    String? deliveredAt,
    String? proofImageUrl,
  }) {
    return LiveOrderModel(
      id: id,
      orderType: orderType,
      items: items,
      totalAmount: totalAmount,
      status: status ?? this.status,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      deliveryAddress: deliveryAddress,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryOtp: deliveryOtp,
      driverName: driverName,
      driverPhone: driverPhone,
      paymentStatus: paymentStatus,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
    );
  }

  factory LiveOrderModel.fromJson(Map<String, dynamic> json) {
    var itemList = <OrderItemModel>[];
    if (json['items'] != null) {
      itemList = (json['items'] as List).map((i) => OrderItemModel.fromJson(i)).toList();
    }

    return LiveOrderModel(
      id: json['id']?.toString() ?? 'MD-101',
      orderType: json['order_type'] ?? 'ONE_TIME',
      items: itemList,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'PLACED',
      deliveryDate: json['delivery_date'] ?? 'Tomorrow',
      deliverySlot: json['delivery_slot'] ?? '05:30 AM - 07:00 AM',
      deliveryAddress: json['delivery_address'] ?? 'Jubilee Hills, Hyderabad',
      deliveryLatitude: double.tryParse(json['delivery_latitude']?.toString() ?? '17.4319') ?? 17.4319,
      deliveryLongitude: double.tryParse(json['delivery_longitude']?.toString() ?? '78.4073') ?? 78.4073,
      deliveryOtp: json['delivery_otp'] ?? '4892',
      driverName: json['driver_name'] ?? 'Suresh Rao',
      driverPhone: json['driver_phone'] ?? '+91 9123456789',
      paymentStatus: json['payment_status'] ?? 'PAID (Wallet)',
      createdAt: json['created_at'] ?? 'Today',
      deliveredAt: json['delivered_at'],
      proofImageUrl: json['proof_image_url'] ?? '',
    );
  }
}
