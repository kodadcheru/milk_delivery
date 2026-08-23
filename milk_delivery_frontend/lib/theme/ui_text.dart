import 'package:flutter/material.dart';

import 'ui_tokens.dart';

/// Shared typography scale for the customer surface.
///
/// The app historically declared text styles inline at every call site, so
/// weights and letter-spacing drifted between widgets. These `static const`
/// styles are the single source of truth — adopt them incrementally by
/// replacing inline `TextStyle(...)` with `UiText.*` (optionally `.copyWith`
/// for one-off color/size tweaks).
///
/// A helper (not a `ThemeData.textTheme`) is used deliberately: widgets don't
/// read `Theme.of(context).textTheme` today, so a TextTheme wouldn't apply.
class UiText {
  UiText._();

  /// Muted caption grey (matches the `0xFF94A3B8` used across the shop).
  static const Color muted = Color(0xFF94A3B8);

  // ── Headings ──
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.1,
    color: UiTone.ink,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.15,
    color: UiTone.ink,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
    color: UiTone.ink,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
    color: UiTone.ink,
  );

  // ── Body & labels ──
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: UiTone.softText,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: UiTone.ink,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: UiTone.softText,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: muted,
  );

  // ── Pricing ──
  static const TextStyle price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: UiTone.ink,
  );

  static const TextStyle priceStrike = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: muted,
    decoration: TextDecoration.lineThrough,
    decorationColor: muted,
  );
}
