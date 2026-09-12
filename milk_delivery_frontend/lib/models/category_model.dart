import 'package:flutter/material.dart';

class CategoryModel {
  final int id;
  final String name;
  final String nameTe;
  final String slug;
  final String icon;
  final String imageUrl;
  final String description;
  final String subtitle;
  final String subtitleTe;
  final String bannerEn;
  final String bannerTe;
  final List<String> subtags;
  final String tileBgColor;
  final String tileFgColor;
  final List<String> gradientColors;
  final String qualityBadgeTitle;
  final Map<String, dynamic> qualitySpecs;
  final List<dynamic> trackingBadges;
  final int displayOrder;
  final bool isActive;
  final int itemsCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.nameTe = '',
    required this.slug,
    this.icon = '🥛',
    this.imageUrl = '',
    this.description = '',
    this.subtitle = '',
    this.subtitleTe = '',
    this.bannerEn = '',
    this.bannerTe = '',
    this.subtags = const [],
    this.tileBgColor = '',
    this.tileFgColor = '',
    this.gradientColors = const [],
    this.qualityBadgeTitle = '',
    this.qualitySpecs = const {},
    this.trackingBadges = const [],
    this.displayOrder = 0,
    this.isActive = true,
    this.itemsCount = 0,
  });

  String localizedName(String lang) {
    if (lang == 'te' && nameTe.trim().isNotEmpty) {
      return nameTe.trim();
    }
    return name;
  }

  String localizedSubtitle(String lang) {
    if (lang == 'te' && subtitleTe.trim().isNotEmpty) {
      return subtitleTe.trim();
    }
    return subtitle;
  }

  String localizedBanner(String lang) {
    if (lang == 'te' && bannerTe.trim().isNotEmpty) {
      return bannerTe.trim();
    }
    return bannerEn;
  }

  Color? get parsedTileBgColor => _parseHexColor(tileBgColor);
  Color? get parsedTileFgColor => _parseHexColor(tileFgColor);

  List<Color> get parsedGradientColors {
    if (gradientColors.isEmpty) return const [];
    final list = <Color>[];
    for (final hex in gradientColors) {
      final c = _parseHexColor(hex);
      if (c != null) list.add(c);
    }
    return list;
  }

  static Color? _parseHexColor(String hex) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      return val != null ? Color(val) : null;
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      return val != null ? Color(val) : null;
    }
    return null;
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    return CategoryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Category',
      nameTe: json['name_te'] as String? ?? '',
      slug: (json['slug'] as String?)?.isNotEmpty == true ? json['slug'] as String : 'category',
      icon: (json['icon'] as String?)?.isNotEmpty == true ? json['icon'] as String : '🥛',
      imageUrl: json['image_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      subtitleTe: json['subtitle_te'] as String? ?? '',
      bannerEn: json['banner_en'] as String? ?? '',
      bannerTe: json['banner_te'] as String? ?? '',
      subtags: parseStringList(json['subtags']),
      tileBgColor: json['tile_bg_color'] as String? ?? '',
      tileFgColor: json['tile_fg_color'] as String? ?? '',
      gradientColors: parseStringList(json['gradient_colors']),
      qualityBadgeTitle: json['quality_badge_title'] as String? ?? '',
      qualitySpecs: json['quality_specs'] is Map<String, dynamic>
          ? json['quality_specs'] as Map<String, dynamic>
          : {},
      trackingBadges: json['tracking_badges'] is List ? json['tracking_badges'] as List : [],
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      itemsCount: json['items_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_te': nameTe,
        'slug': slug,
        'icon': icon,
        'image_url': imageUrl,
        'description': description,
        'subtitle': subtitle,
        'subtitle_te': subtitleTe,
        'banner_en': bannerEn,
        'banner_te': bannerTe,
        'subtags': subtags,
        'tile_bg_color': tileBgColor,
        'tile_fg_color': tileFgColor,
        'gradient_colors': gradientColors,
        'quality_badge_title': qualityBadgeTitle,
        'quality_specs': qualitySpecs,
        'tracking_badges': trackingBadges,
        'display_order': displayOrder,
        'is_active': isActive,
        'items_count': itemsCount,
      };
}
