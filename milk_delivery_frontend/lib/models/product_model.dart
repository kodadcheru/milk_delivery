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
  final String subtitle;
  final String qualityBadgeTitle;
  final Map<String, String> qualitySpecs;
  final List<Map<String, String>> trackingBadges;

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
    this.subtitle = '',
    this.qualityBadgeTitle = '',
    this.qualitySpecs = const {},
    this.trackingBadges = const [],
  });

  bool get isOutOfStock => !isAvailable || availableSlots <= 0;

  bool get isMeat {
    final c = category.toUpperCase();
    final n = name.toLowerCase();
    return c.contains('MEAT') || c.contains('POULTRY') ||
        n.contains('chicken') || n.contains('mutton') || n.contains('meat') ||
        n.contains('fish') || n.contains('prawn');
  }

  bool get isEggs {
    final c = category.toUpperCase();
    final n = name.toLowerCase();
    return c.contains('EGG') || n.contains('egg');
  }

  bool get isWater {
    final c = category.toUpperCase();
    final n = name.toLowerCase();
    return c.contains('WATER') || n.contains('water') || n.contains('can') || n.contains('dispenser');
  }

  bool get isDairy {
    if (isMeat || isEggs || isWater) return false;
    final c = category.toUpperCase();
    final n = name.toLowerCase();
    return c.contains('MILK') || c.contains('DAIRY') || c.contains('GHEE') ||
        c.contains('PANEER') || c.contains('CURD') ||
        n.contains('milk') || n.contains('ghee') || n.contains('paneer') ||
        n.contains('curd') || n.contains('butter') || n.contains('dahi');
  }

  String get categorySubtitle {
    if (isMeat) return 'Fresh & Tender • 100% Antibiotic-Free';
    if (isEggs) return 'Free-Range & Healthy • Daily Farm Sourced';
    if (isWater) return '100% RO Purified • Sealed Hygienic Can';
    if (isDairy) {
      if (name.toLowerCase().contains('buffalo')) return 'Pure Buffalo Dairy • 05:30 AM Farm Fresh';
      return 'Pure Cow Dairy • 05:30 AM Farm Fresh';
    }
    return 'Fresh & Verified • Daily Doorstep Delivery';
  }

  String get displaySubtitle => subtitle.isNotEmpty ? subtitle : categorySubtitle;

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

    final String sub = json['resolved_subtitle']?.toString() ??
        json['subtitle']?.toString() ??
        (catDetail != null ? catDetail['subtitle']?.toString() ?? '' : '');

    final String badgeTitle = json['resolved_quality_badge_title']?.toString() ??
        json['quality_badge_title']?.toString() ??
        (catDetail != null ? catDetail['quality_badge_title']?.toString() ?? '' : '');

    final Map<String, String> specs = {};
    final rawSpecs = json['resolved_quality_specs'] ??
        json['quality_specs'] ??
        (catDetail != null ? catDetail['quality_specs'] : null);
    if (rawSpecs is Map) {
      rawSpecs.forEach((k, v) {
        if (k != null && v != null) {
          specs[k.toString()] = v.toString();
        }
      });
    }

    final List<Map<String, String>> trackingList = [];
    final rawTracking = json['resolved_tracking_badges'] ??
        json['tracking_badges'] ??
        (catDetail != null ? catDetail['tracking_badges'] : null);
    if (rawTracking is List) {
      for (final item in rawTracking) {
        if (item is Map) {
          final l = item['label']?.toString() ?? '';
          final val = item['value']?.toString() ?? '';
          if (l.isNotEmpty && val.isNotEmpty) {
            trackingList.add({'label': l, 'value': val});
          }
        }
      }
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
      subtitle: sub,
      qualityBadgeTitle: badgeTitle,
      qualitySpecs: specs,
      trackingBadges: trackingList,
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
