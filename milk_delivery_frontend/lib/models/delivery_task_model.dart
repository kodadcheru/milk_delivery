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
  final String productName;
  final String productImage;
  final int quantity;
  final String packSize;
  final double pricePerUnit;
  final double fatPercentage;
  final double snfPercentage;
  final double waterPercentage;
  final double batchPricePerLitre;
  final String batchCode;
  final double temperatureCelsius;

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
    this.productName = 'Farm Fresh Cow Milk',
    this.productImage = 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
    this.quantity = 1,
    this.packSize = '1 Litre',
    this.pricePerUnit = 72.0,
    this.fatPercentage = 6.8,
    this.snfPercentage = 9.0,
    this.waterPercentage = 0.0,
    this.batchPricePerLitre = 68.0,
    this.batchCode = 'BATCH-TODAY-01',
    this.temperatureCelsius = 3.8,
  });

  String get displayProductName => (subscriptionDetail?.productDetail?.name.isNotEmpty == true)
      ? subscriptionDetail!.productDetail!.name
      : (productName.isNotEmpty ? productName : 'Farm Fresh Cow Milk');

  String get displayProductImage => (subscriptionDetail?.productDetail?.imageUrl.isNotEmpty == true)
      ? subscriptionDetail!.productDetail!.imageUrl
      : (productImage.isNotEmpty ? productImage : 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80');

  int get displayQuantity => (subscriptionDetail != null && subscriptionDetail!.quantity > 0)
      ? subscriptionDetail!.quantity
      : (quantity > 0 ? quantity : 1);

  String get displayPackSize => (subscriptionDetail?.packSize.isNotEmpty == true)
      ? subscriptionDetail!.packSize
      : (packSize.isNotEmpty ? packSize : '1 Litre');

  factory DeliveryTaskModel.fromJson(Map<String, dynamic> json) {
    SubscriptionModel? subDetail;
    if (json['subscription_detail'] != null && json['subscription_detail'] is Map<String, dynamic>) {
      subDetail = SubscriptionModel.fromJson(json['subscription_detail']);
    }

    UserModel? drvDetail;
    if (json['driver_detail'] != null && json['driver_detail'] is Map<String, dynamic>) {
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

    final rawPrice = json['price_per_unit'] ?? (subDetail?.productDetail?.pricePerUnit);
    final parsedPrice = double.tryParse(rawPrice?.toString() ?? '72.0') ?? 72.0;

    final parsedFat = double.tryParse(json['fat_percentage']?.toString() ?? '6.8') ?? 6.8;
    final parsedSnf = double.tryParse(json['snf_percentage']?.toString() ?? '9.0') ?? 9.0;
    final parsedWater = double.tryParse(json['water_percentage']?.toString() ?? '0.0') ?? 0.0;
    final parsedBatchPrice = double.tryParse(json['batch_price_per_litre']?.toString() ?? '$parsedPrice') ?? parsedPrice;
    final parsedBatchCode = json['batch_code']?.toString() ?? 'BATCH-LIVE-01';
    final parsedTemp = double.tryParse(json['temperature_celsius']?.toString() ?? '3.8') ?? 3.8;

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
      slotTime: json['slot_time'] ?? (subDetail?.deliverySlot ?? '05:30 AM - 07:00 AM'),
      status: json['status'] ?? 'PENDING',
      proofImageUrl: json['proof_image_url'] ?? '',
      deliveredAt: json['delivered_at'],
      customerLatitude: parsedLat,
      customerLongitude: parsedLon,
      productName: json['product_name'] ?? (subDetail?.productDetail?.name ?? 'Farm Fresh Cow Milk'),
      productImage: json['product_image'] ?? (subDetail?.productDetail?.imageUrl ?? 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80'),
      quantity: json['quantity'] is int ? json['quantity'] : (int.tryParse(json['quantity']?.toString() ?? '1') ?? (subDetail?.quantity ?? 1)),
      packSize: json['pack_size'] ?? (subDetail?.packSize ?? '1 Litre'),
      pricePerUnit: parsedPrice,
      fatPercentage: parsedFat,
      snfPercentage: parsedSnf,
      waterPercentage: parsedWater,
      batchPricePerLitre: parsedBatchPrice,
      batchCode: parsedBatchCode,
      temperatureCelsius: parsedTemp,
    );
  }

  DeliveryTaskModel copyWith({
    String? status,
    String? proofImageUrl,
    String? deliveredAt,
    double? fatPercentage,
    double? snfPercentage,
    double? waterPercentage,
    double? batchPricePerLitre,
    String? batchCode,
    double? temperatureCelsius,
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
      productName: productName,
      productImage: productImage,
      quantity: quantity,
      packSize: packSize,
      pricePerUnit: pricePerUnit,
      fatPercentage: fatPercentage ?? this.fatPercentage,
      snfPercentage: snfPercentage ?? this.snfPercentage,
      waterPercentage: waterPercentage ?? this.waterPercentage,
      batchPricePerLitre: batchPricePerLitre ?? this.batchPricePerLitre,
      batchCode: batchCode ?? this.batchCode,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
    );
  }

  bool get isDelivered => status == 'DELIVERED';
}
