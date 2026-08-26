import 'package:flutter/material.dart';

/// Unified per-category presentation metadata.
///
/// Replaces divergent inline maps across the home category grid
/// (`home_category_showcase.dart`) and the category products screen
/// (`category_products_screen.dart`).
class CategoryMeta {
  /// Uppercase category code, e.g. `MILK`, `WATER_CAN`.
  final String key;

  /// Short label for the home grid tile, e.g. `Fresh Milk`.
  final String shortTitle;

  /// Full title for the category screen header, e.g. `Fresh Milk & Dairy`.
  final String longTitle;

  /// Emoji used as the fallback glyph and badge.
  final String icon;

  /// Home grid tile realistic photo URL.
  final String? image;

  /// Home grid tile fallback background.
  final Color tileBg;

  /// Home grid tile accent (selected border + label colour).
  final Color tileFg;

  /// Category screen hero gradient (two stops).
  final List<Color> gradient;

  /// Category screen accent colour.
  final Color accent;

  /// Category screen hero banner copy.
  final String banner;

  /// Category screen quick-filter chips (first entry is always `ALL`).
  final List<String> subtags;

  const CategoryMeta({
    required this.key,
    required this.shortTitle,
    required this.longTitle,
    required this.icon,
    this.image,
    required this.tileBg,
    required this.tileFg,
    required this.gradient,
    required this.accent,
    required this.banner,
    required this.subtags,
  });
}

/// Ordered keys shown as tiles in the home category grid.
const List<String> kHomeCategoryKeys = [
  'MILK',
  'MEAT',
  'EGGS',
  'WATER_CAN',
  'PANEER',
  'GHEE',
  'CURD',
  'BAKERY',
];

/// All known categories, keyed by uppercase category code with ultra-realistic photography.
const Map<String, CategoryMeta> kCategoryCatalog = {
  'MILK': CategoryMeta(
    key: 'MILK',
    shortTitle: 'Fresh Milk',
    longTitle: 'Fresh Milk & Dairy',
    icon: '🥛',
    image:
        'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFE6F5F0),
    tileFg: Color(0xFF0D7C66),
    gradient: [Color(0xFF0369A1), Color(0xFF0284C7)],
    accent: Color(0xFF0284C7),
    banner: '🥛 Pure A2 Vedic Desi Cow & Buffalo Milk',
    subtags: ['ALL', 'COW MILK', 'BUFFALO', 'CURD / DAHI'],
  ),
  'MEAT': CategoryMeta(
    key: 'MEAT',
    shortTitle: 'Meat & Poultry',
    longTitle: 'Meat & Poultry',
    icon: '🥩',
    image:
        'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFFDE8E8),
    tileFg: Color(0xFFDC2626),
    gradient: [Color(0xFF991B1B), Color(0xFFDC2626)],
    accent: Color(0xFFDC2626),
    banner: '🥩 Fresh Tender Meat • 100% Antibiotic-Free',
    subtags: ['ALL', 'CHICKEN', 'MUTTON', 'FRESH CUT'],
  ),
  'EGGS': CategoryMeta(
    key: 'EGGS',
    shortTitle: 'Farm Eggs',
    longTitle: 'Farm Fresh Eggs',
    icon: '🥚',
    image:
        'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFFFF3E6),
    tileFg: Color(0xFFE67E22),
    gradient: [Color(0xFFB45309), Color(0xFFD97706)],
    accent: Color(0xFFD97706),
    banner: '🥚 Daily Dawn Harvested • Free-Range & Organic',
    subtags: ['ALL', 'DESI', 'BROWN', 'HIGH PROTEIN'],
  ),
  'WATER_CAN': CategoryMeta(
    key: 'WATER_CAN',
    shortTitle: 'Water Cans',
    longTitle: 'Pure Water Cans',
    icon: '💧',
    image:
        'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFE8F2FE),
    tileFg: Color(0xFF2563EB),
    gradient: [Color(0xFF0F766E), Color(0xFF0D9488)],
    accent: Color(0xFF0D9488),
    banner: '💧 8-Stage RO + UV Purified • Mineral Rich',
    subtags: ['ALL', '20L CAN', 'DISPENSER', 'MINERAL'],
  ),
  'PANEER': CategoryMeta(
    key: 'PANEER',
    shortTitle: 'Paneer & Curd',
    longTitle: 'Farm Fresh Paneer',
    icon: '🧀',
    image:
        'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFF0EAFC),
    tileFg: Color(0xFF7C3AED),
    gradient: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
    accent: Color(0xFF7C3AED),
    banner: '🧀 Soft Malai Paneer • Crafted Fresh Daily',
    subtags: ['ALL', 'MALAI', 'PANEER', 'VACUUM PACK'],
  ),
  'GHEE': CategoryMeta(
    key: 'GHEE',
    shortTitle: 'Desi Ghee',
    longTitle: 'Pure Desi Ghee & Butter',
    icon: '🧈',
    image:
        'https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFFEF3C7),
    tileFg: Color(0xFFD97706),
    gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
    accent: Color(0xFFD97706),
    banner: '🧈 Traditional Bilona Vedic Cow Ghee & White Butter',
    subtags: ['ALL', 'BILONA GHEE', 'BUTTER', 'A2 VEDIC'],
  ),
  'CURD': CategoryMeta(
    key: 'CURD',
    shortTitle: 'Set Curd',
    longTitle: 'Natural Set Curd (Dahi)',
    icon: '🥣',
    image:
        'https://images.unsplash.com/photo-1571212515416-fef01fc43637?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFE6F5F0),
    tileFg: Color(0xFF0D7C66),
    gradient: [Color(0xFF0D9488), Color(0xFF14B8A6)],
    accent: Color(0xFF0D7C66),
    banner: '🥣 Probiotic-Rich Natural Set Curd in Eco Tubs',
    subtags: ['ALL', 'MATKA DAHI', 'SET CURD', 'ORGANIC'],
  ),
  'BAKERY': CategoryMeta(
    key: 'BAKERY',
    shortTitle: 'Bakery',
    longTitle: 'Artisanal Breads & Bakery',
    icon: '🍞',
    image:
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=85',
    tileBg: Color(0xFFFEF3C7),
    tileFg: Color(0xFFB45309),
    gradient: [Color(0xFFB45309), Color(0xFFD97706)],
    accent: Color(0xFFB45309),
    banner: '🍞 Fresh Morning Multi-Grain & Sourdough Breads',
    subtags: ['ALL', 'MULTI-GRAIN', 'SOURDOUGH', 'WHOLE WHEAT'],
  ),
};

/// Metadata for [key], falling back to `MILK` for unknown keys.
CategoryMeta categoryMetaFor(String key) =>
    kCategoryCatalog[key.toUpperCase()] ?? kCategoryCatalog['MILK']!;
