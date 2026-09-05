import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui_tokens.dart';

/// Next-Gen Design Tokens, Color Palette, and Styling Utilities for Pamba
class AppTheme {
  // ── 🎨 Core Color Palette ──
  // Kept in lockstep with UiTone (lib/theme/ui_tokens.dart) so the Material
  // ColorScheme seed matches the teal painted on custom surfaces app-wide.
  static const Color primaryTeal = UiTone.primary;
  static const Color primaryMint = UiTone.secondary;
  static const Color primaryDark = Color(0xFF0D5C56); // Rich Forest Teal
  static const Color accentAmber = Color(0xFFF59E0B); // Solar Amber Glow
  static const Color accentCyan = Color(0xFF06B6D4);  // Pure Spring Cyan
  static const Color accentViolet = Color(0xFF8B5CF6); // Lavender Frost

  // Surface & Neutrals
  static const Color bgPorcelain = UiTone.shellBackground;
  static const Color bgSurface = UiTone.surface;
  static const Color bgSurfaceMuted = UiTone.surfaceMuted;
  static const Color darkSlate = UiTone.ink;
  static const Color darkCard = Color(0xFF1E293B);    // Premium Dark Container

  // Text Colors
  static const Color textPrimary = UiTone.ink;
  static const Color textSecondary = UiTone.softText;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = UiTone.surface;

  // Border & Divider
  static const Color borderSubtle = UiTone.surfaceBorder;
  static const Color borderGlow = Color(0xFFCBD5E1);

  // ── 🌈 Signature Gradients ──
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldenSunriseGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient holographicCardGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F766E), Color(0xFF064E3B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.4, 0.75, 1.0],
  );

  static const LinearGradient morningSkyGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F766E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassHighlightGradient = LinearGradient(
    colors: [Colors.white24, Colors.white10, Colors.transparent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── 🌫️ Glassmorphic Decorations ──
  static BoxDecoration glassCardDecoration({
    double borderRadius = 20,
    Color? borderColor,
    Color? fillColor,
  }) {
    return BoxDecoration(
      color: fillColor ?? Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.6),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration darkGlassDecoration({
    double borderRadius = 20,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ── 📳 Sensory Haptic Helpers ──
  static void hapticLight() {
    HapticFeedback.lightImpact();
  }

  static void hapticMedium() {
    HapticFeedback.mediumImpact();
  }

  static void hapticSuccess() {
    HapticFeedback.selectionClick();
  }

  // ── 🏷️ Global Flutter ThemeData ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: primaryMint,
        surface: bgPorcelain,
      ),
      scaffoldBackgroundColor: bgPorcelain,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSlate,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }
}
