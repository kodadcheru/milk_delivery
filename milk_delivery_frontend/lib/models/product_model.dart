import '../l10n/app_translations.dart';

class ProductModel {
  final int id;
  final int? categoryId;
  final String name;
  final String category; // MILK, MEAT, EGGS, WATER_CAN
  final String description;
  final double pricePerUnit;
  final String unit;
  final String unitQuantity;
  final String imageUrl;
  final String badgeText;
  final String nutritionInfo;
  final String farmOrigin;
  final bool isAvailable;
  final int availableSlots;
  final int dailyCapacitySlots;
  final double rating;
  final String icon;

  ProductModel({
    required this.id,
    this.categoryId,
    required this.name,
    this.category = 'MILK',
    required this.description,
    required this.pricePerUnit,
    required this.unit,
    required this.unitQuantity,
    required this.imageUrl,
    this.badgeText = 'Bestseller',
    this.nutritionInfo = '100% Pure & Certified Quality',
    this.farmOrigin = 'Vedic Heritage Farm',
    this.isAvailable = true,
    this.availableSlots = 100,
    this.dailyCapacitySlots = 100,
    this.rating = 4.9,
    this.icon = '🥛',
  });

  bool get isOutOfStock => !isAvailable || availableSlots <= 0;

  String localizedName(String lang) {
    if (lang != 'te') return name;
    return AppTranslations.translateProduct(name, lang: lang);
  }

  String localizedDescription(String lang) {
    if (lang != 'te') return description;
    return AppTranslations.translateDescription(name, description, lang: lang);
  }

  String localizedCategory(String lang) {
    if (lang != 'te') return category;
    return AppTranslations.translateCategory(category, lang: lang);
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String nameStr = json['name'] ?? '';
    String cat = (json['category'] ?? 'MILK').toString();
    final catDetail = json['category_detail'] is Map<String, dynamic> ? json['category_detail'] as Map<String, dynamic> : null;

    final int? catId = json['category_id'] is int
        ? json['category_id']
        : (int.tryParse(json['category_id']?.toString() ?? '') ??
            (json['category_ref'] is int ? json['category_ref'] : int.tryParse(json['category_ref']?.toString() ?? '')) ??
            (catDetail != null ? catDetail['id'] as int? : null));

    String resolvedIcon = json['category_icon']?.toString() ??
        (catDetail != null && catDetail['icon'] != null && catDetail['icon'].toString().isNotEmpty ? catDetail['icon'].toString() : '');

    if (resolvedIcon.isEmpty) {
      final catUpper = cat.toUpperCase();
      if (catUpper == 'WATER_CAN' || nameStr.toLowerCase().contains('water') || nameStr.toLowerCase().contains('can')) {
        resolvedIcon = nameStr.toLowerCase().contains('dispenser') || nameStr.toLowerCase().contains('tap') ? '🚰' : '💧';
      } else if (catUpper == 'EGGS' || nameStr.toLowerCase().contains('egg')) {
        resolvedIcon = '🥚';
      } else if (catUpper == 'MEAT' || nameStr.toLowerCase().contains('mutton') || nameStr.toLowerCase().contains('meat') || nameStr.toLowerCase().contains('chicken')) {
        resolvedIcon = nameStr.toLowerCase().contains('mutton') || nameStr.toLowerCase().contains('meat') ? '🥩' : '🍗';
      } else if (catUpper == 'PANEER' || nameStr.toLowerCase().contains('paneer')) {
        resolvedIcon = '🧀';
      } else if (catUpper == 'GHEE' || nameStr.toLowerCase().contains('ghee') || nameStr.toLowerCase().contains('butter') || nameStr.toLowerCase().contains('makkhan')) {
        resolvedIcon = '🧈';
      } else if (catUpper == 'CURD' || nameStr.toLowerCase().contains('curd') || nameStr.toLowerCase().contains('dahi') || nameStr.toLowerCase().contains('yogurt')) {
        resolvedIcon = '🥣';
      } else if (catUpper == 'BAKERY' || nameStr.toLowerCase().contains('bread') || nameStr.toLowerCase().contains('bakery')) {
        resolvedIcon = '🍞';
      } else {
        resolvedIcon = '🥛';
      }
    }

    String imgUrl = json['image_url']?.toString() ?? '';
    if (imgUrl.isEmpty && catDetail != null && catDetail['image_url'] != null) {
      imgUrl = catDetail['image_url'].toString();
    }

    return ProductModel(
      id: json['id'] ?? 0,
      categoryId: catId,
      name: nameStr,
      category: cat,
      description: json['description'] ?? '',
      pricePerUnit: double.tryParse(json['price_per_unit']?.toString() ?? '0') ?? 0.0,
      unit: json['unit'] ?? 'PACKET',
      unitQuantity: json['unit_quantity'] ?? '1 L',
      imageUrl: imgUrl,
      badgeText: json['badge_text'] ?? 'Daily Essential',
      nutritionInfo: json['nutrition_info'] ?? '100% Pure & Certified Quality',
      farmOrigin: json['farm_origin'] ?? 'Heritage Source, Hyderabad',
      isAvailable: json['is_available'] ?? true,
      availableSlots: json['available_slots'] ?? 100,
      dailyCapacitySlots: json['daily_capacity_slots'] ?? 100,
      rating: double.tryParse(json['rating']?.toString() ?? '4.9') ?? 4.9,
      icon: resolvedIcon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (categoryId != null && categoryId! > 0) 'category_id': categoryId,
      'name': name,
      'category': category,
      'description': description,
      'price_per_unit': pricePerUnit.toStringAsFixed(2),
      'unit': unit,
      'unit_quantity': unitQuantity,
      'image_url': imageUrl,
      'badge_text': badgeText,
      'nutrition_info': nutritionInfo,
      'farm_origin': farmOrigin,
      'is_available': isAvailable,
      'available_slots': availableSlots,
      'daily_capacity_slots': dailyCapacitySlots,
      'rating': rating,
    };
  }

  /// Returns a copy with selected fields overridden. Used to build a
  /// pack-size-specific variant (price + `unitQuantity`) for the cart and
  /// subscription flows while preserving stock, rating, imagery, etc.
  ProductModel copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? category,
    String? description,
    double? pricePerUnit,
    String? unit,
    String? unitQuantity,
    String? imageUrl,
    String? badgeText,
    String? nutritionInfo,
    String? farmOrigin,
    bool? isAvailable,
    int? availableSlots,
    int? dailyCapacitySlots,
    double? rating,
    String? icon,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      unit: unit ?? this.unit,
      unitQuantity: unitQuantity ?? this.unitQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      badgeText: badgeText ?? this.badgeText,
      nutritionInfo: nutritionInfo ?? this.nutritionInfo,
      farmOrigin: farmOrigin ?? this.farmOrigin,
      isAvailable: isAvailable ?? this.isAvailable,
      availableSlots: availableSlots ?? this.availableSlots,
      dailyCapacitySlots: dailyCapacitySlots ?? this.dailyCapacitySlots,
      rating: rating ?? this.rating,
      icon: icon ?? this.icon,
    );
  }
}
