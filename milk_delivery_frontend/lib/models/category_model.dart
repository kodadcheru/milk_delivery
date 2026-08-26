class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String icon;
  final String imageUrl;
  final String description;
  final int displayOrder;
  final bool isActive;
  final int itemsCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon = '🥛',
    this.imageUrl = '',
    this.description = '',
    this.displayOrder = 0,
    this.isActive = true,
    this.itemsCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Category',
      slug: (json['slug'] as String?)?.isNotEmpty == true ? json['slug'] as String : 'category',
      icon: (json['icon'] as String?)?.isNotEmpty == true ? json['icon'] as String : '🥛',
      imageUrl: json['image_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      itemsCount: json['items_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'icon': icon,
        'image_url': imageUrl,
        'description': description,
        'display_order': displayOrder,
        'is_active': isActive,
        'items_count': itemsCount,
      };
}
