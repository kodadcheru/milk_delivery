import 'product_model.dart';
import '../config/app_config.dart';
import '../services/pack_pricing.dart';

class SubscriptionModel {
  final int id;
  final int customerId;
  final int productId;
  final ProductModel? productDetail;
  final int quantity;
  final String scheduleType; // DAILY, ALTERNATE, CUSTOM, ONCE
  final String startDate;
  final String? endDate;
  final String status; // ACTIVE, PAUSED, CANCELLED
  final String deliveryAddress;
  final String deliverySlot;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String deliveryInstructions;
  final String packSize;
  final double effectiveUnitPrice;

  SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.productId,
    this.productDetail,
    required this.quantity,
    required this.scheduleType,
    required this.startDate,
    this.endDate,
    required this.status,
    this.deliveryAddress = 'Doorstep Drop',
    this.deliverySlot = AppConfig.defaultMorningSlot,
    this.deliveryLatitude = 17.4319,
    this.deliveryLongitude = 78.4073,
    this.deliveryInstructions = '',
    this.packSize = '1 Litre',
    this.effectiveUnitPrice = 0.0,
  });

  double get displayPrice {
    if (effectiveUnitPrice > 0) return effectiveUnitPrice;
    final basePrice = productDetail?.pricePerUnit ?? 0;
    return PackPricing.effectiveUnitPrice(basePrice.toDouble(), packSize);
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    ProductModel? pDetail;
    if (json['product_detail'] != null && json['product_detail'] is Map<String, dynamic>) {
      pDetail = ProductModel.fromJson(json['product_detail']);
    }

    return SubscriptionModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      customerId: json['customer'] is int ? json['customer'] : (int.tryParse(json['customer']?.toString() ?? '0') ?? 0),
      productId: json['product'] is int ? json['product'] : (int.tryParse(json['product']?.toString() ?? '0') ?? 0),
      productDetail: pDetail,
      quantity: json['quantity'] is int ? json['quantity'] : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      scheduleType: json['schedule_type']?.toString() ?? 'DAILY',
      startDate: json['start_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      deliveryAddress: json['delivery_address']?.toString() ?? 'Doorstep Drop',
      deliverySlot: json['delivery_slot']?.toString() ?? AppConfig.defaultMorningSlot,
      deliveryLatitude: double.tryParse(json['delivery_latitude']?.toString() ?? '17.4319') ?? 17.4319,
      deliveryLongitude: double.tryParse(json['delivery_longitude']?.toString() ?? '78.4073') ?? 78.4073,
      deliveryInstructions: json['delivery_instructions']?.toString() ?? '',
      packSize: json['pack_size']?.toString() ?? '1 Litre',
      effectiveUnitPrice: double.tryParse(json['effective_unit_price']?.toString() ?? '0') ?? 0.0,
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
      'effective_unit_price': effectiveUnitPrice,
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
    double? effectiveUnitPrice,
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
      effectiveUnitPrice: effectiveUnitPrice ?? this.effectiveUnitPrice,
    );
  }

  int get streakDays {
    try {
      final start = DateTime.parse(startDate);
      final diff = DateTime.now().difference(start).inDays;
      return diff >= 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  double get monthlySavings {
    // Only calculate savings based on the cosmetic markup (12%)
    // Not from pack-size price differences
    final displayP = displayPrice;
    if (displayP > 0) {
      final cosmeticMrp = displayP * 1.12;  // Matches UiFormat._strikeMarkup
      return (cosmeticMrp - displayP) * quantity * 30.0;
    }
    return 0.0;
  }

  bool get isDeliveryDay {
    if (scheduleType.toUpperCase() == 'DAILY') return true;
    if (scheduleType.toUpperCase() == 'ALTERNATE') {
      try {
        final start = DateTime.parse(startDate);
        final diff = DateTime.now().difference(start).inDays;
        return diff % 2 == 0;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  String localizedScheduleType(bool isTelugu) {
    final s = scheduleType.toUpperCase();
    if (s.contains('DAILY')) {
      return isTelugu ? 'ప్రతిరోజూ' : 'Daily';
    } else if (s.contains('ALTERNATE')) {
      return isTelugu ? 'రోజు విడిచి రోజు' : 'Alternate Days';
    } else if (s.contains('CUSTOM')) {
      return isTelugu ? 'కస్టమ్' : 'Custom';
    }
    return scheduleType;
  }
}
