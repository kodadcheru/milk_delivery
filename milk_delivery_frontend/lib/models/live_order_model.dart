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
  final String customerName;
  final String customerPhone;
  final String driverName;
  final String driverPhone;
  final String driverVehicle;
  final String paymentStatus;
  final String createdAt;
  final String? deliveredAt;
  final String proofImageUrl;
  final double fatPercentage;
  final double snfPercentage;
  final double waterPercentage;
  final double batchPricePerLitre;
  final String batchCode;
  final String deliveryType;
  final int etaMinutes;
  final String? estimatedDeliveryTime;
  final String paymentMethod;
  final bool isCod;
  final bool cashCollected;
  final double cashAmount;

  LiveOrderModel({
    required this.id,
    this.orderType = 'ONE_TIME',
    required this.items,
    required this.totalAmount,
    required this.status,
    this.deliveryDate = 'Tomorrow',
    this.deliverySlot = '05:30 AM - 07:00 AM',
    this.deliveryAddress = 'Doorstep Delivery Location',
    this.deliveryLatitude = 17.4319,
    this.deliveryLongitude = 78.4073,
    this.deliveryOtp = '4892',
    this.customerName = 'Customer',
    this.customerPhone = '',
    this.driverName = 'Assigning Delivery Partner...',
    this.driverPhone = '',
    this.driverVehicle = 'Electric Scooter (TS 09 EB 4092)',
    this.paymentStatus = 'PAID (Wallet Auto-Debit)',
    required this.createdAt,
    this.deliveredAt,
    this.proofImageUrl = '',
    this.fatPercentage = 0.0,
    this.snfPercentage = 0.0,
    this.waterPercentage = 0.0,
    this.batchPricePerLitre = 0.0,
    this.batchCode = '',
    this.deliveryType = 'SCHEDULED',
    this.etaMinutes = 0,
    this.estimatedDeliveryTime,
    this.paymentMethod = 'WALLET',
    this.isCod = false,
    this.cashCollected = false,
    this.cashAmount = 0.0,
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  LiveOrderModel copyWith({
    String? status,
    String? deliveryDate,
    String? deliverySlot,
    String? deliveredAt,
    String? proofImageUrl,
    double? fatPercentage,
    double? snfPercentage,
    double? waterPercentage,
    double? batchPricePerLitre,
    String? batchCode,
    String? deliveryType,
    int? etaMinutes,
    String? estimatedDeliveryTime,
    String? driverVehicle,
    String? paymentMethod,
    bool? isCod,
    bool? cashCollected,
    double? cashAmount,
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
      customerName: customerName,
      customerPhone: customerPhone,
      driverName: driverName,
      driverPhone: driverPhone,
      driverVehicle: driverVehicle ?? this.driverVehicle,
      paymentStatus: paymentStatus,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      fatPercentage: fatPercentage ?? this.fatPercentage,
      snfPercentage: snfPercentage ?? this.snfPercentage,
      waterPercentage: waterPercentage ?? this.waterPercentage,
      batchPricePerLitre: batchPricePerLitre ?? this.batchPricePerLitre,
      batchCode: batchCode ?? this.batchCode,
      deliveryType: deliveryType ?? this.deliveryType,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isCod: isCod ?? this.isCod,
      cashCollected: cashCollected ?? this.cashCollected,
      cashAmount: cashAmount ?? this.cashAmount,
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
      deliveryDate: json['delivery_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      deliverySlot: json['delivery_slot'] ?? '05:30 AM - 07:00 AM',
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLatitude: double.tryParse(json['delivery_latitude']?.toString() ?? '0') ?? 0.0,
      deliveryLongitude: double.tryParse(json['delivery_longitude']?.toString() ?? '0') ?? 0.0,
      deliveryOtp: json['delivery_otp'] ?? '',
      customerName: json['customer_name'] ?? (json['customer_detail'] != null ? '${json['customer_detail']['first_name'] ?? ''} ${json['customer_detail']['last_name'] ?? ''}'.trim() : 'Customer'),
      customerPhone: json['customer_phone'] ?? (json['customer_detail'] != null ? json['customer_detail']['phone'] ?? '' : ''),
      driverName: json['driver_name'] ?? 'Assigning Partner...',
      driverPhone: json['driver_phone'] ?? '',
      driverVehicle: json['driver_vehicle'] ?? 'Electric Scooter (TS 09 EB 4092)',
      paymentStatus: json['payment_status'] ?? 'PAID (Wallet)',
      createdAt: json['created_at'] ?? 'Today',
      deliveredAt: json['delivered_at'],
      proofImageUrl: json['proof_image_url'] ?? '',
      fatPercentage: double.tryParse(json['fat_percentage']?.toString() ?? '0') ?? 0.0,
      snfPercentage: double.tryParse(json['snf_percentage']?.toString() ?? '0') ?? 0.0,
      waterPercentage: double.tryParse(json['water_percentage']?.toString() ?? '0') ?? 0.0,
      batchPricePerLitre: double.tryParse(json['batch_price_per_litre']?.toString() ?? '0') ?? 0.0,
      batchCode: json['batch_code']?.toString() ?? '',
      deliveryType: json['delivery_type'] ?? 'SCHEDULED',
      etaMinutes: json['eta_minutes'] ?? 0,
      estimatedDeliveryTime: json['estimated_delivery_time']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'WALLET',
      isCod: json['is_cod'] == true,
      cashCollected: json['cash_collected'] == true,
      cashAmount: double.tryParse(json['cash_amount']?.toString() ?? '0') ?? 0.0,
    );
  }
}
