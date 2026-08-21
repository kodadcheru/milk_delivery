class ProductModel {
  final int id;
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

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String nameStr = json['name'] ?? '';
    String cat = (json['category'] ?? 'MILK').toString().toUpperCase();
    String defaultIcon = '🥛';

    if (cat == 'WATER_CAN' || nameStr.toLowerCase().contains('water') || nameStr.toLowerCase().contains('can')) {
      defaultIcon = nameStr.toLowerCase().contains('dispenser') || nameStr.toLowerCase().contains('tap') ? '🚰' : '💧';
    } else if (cat == 'EGGS' || nameStr.toLowerCase().contains('egg')) {
      defaultIcon = '🥚';
    } else if (cat == 'MEAT' || nameStr.toLowerCase().contains('mutton') || nameStr.toLowerCase().contains('meat') || nameStr.toLowerCase().contains('chicken')) {
      defaultIcon = nameStr.toLowerCase().contains('mutton') || nameStr.toLowerCase().contains('meat') ? '🥩' : '🍗';
    } else if (cat == 'PANEER' || nameStr.toLowerCase().contains('paneer')) {
      defaultIcon = '🧀';
    } else if (cat == 'GHEE' || nameStr.toLowerCase().contains('ghee') || nameStr.toLowerCase().contains('butter') || nameStr.toLowerCase().contains('makkhan')) {
      defaultIcon = '🧈';
    } else if (cat == 'CURD' || nameStr.toLowerCase().contains('curd') || nameStr.toLowerCase().contains('dahi') || nameStr.toLowerCase().contains('yogurt')) {
      defaultIcon = '🥣';
    } else if (cat == 'BAKERY' || nameStr.toLowerCase().contains('bread') || nameStr.toLowerCase().contains('bakery')) {
      defaultIcon = '🍞';
    } else {
      defaultIcon = '🥛';
    }

    return ProductModel(
      id: json['id'] ?? 0,
      name: nameStr,
      category: cat,
      description: json['description'] ?? '',
      pricePerUnit: double.tryParse(json['price_per_unit']?.toString() ?? '0') ?? 0.0,
      unit: json['unit'] ?? 'PACKET',
      unitQuantity: json['unit_quantity'] ?? '1 L',
      imageUrl: json['image_url'] ?? '',
      badgeText: json['badge_text'] ?? 'Daily Essential',
      nutritionInfo: json['nutrition_info'] ?? '100% Pure & Certified Quality',
      farmOrigin: json['farm_origin'] ?? 'Heritage Source, Hyderabad',
      isAvailable: json['is_available'] ?? true,
      availableSlots: json['available_slots'] ?? 100,
      dailyCapacitySlots: json['daily_capacity_slots'] ?? 100,
      rating: double.tryParse(json['rating']?.toString() ?? '4.9') ?? 4.9,
      icon: defaultIcon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
}
