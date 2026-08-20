import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Next-Gen Design Tokens, Color Palette, and Styling Utilities for MilkDrop
class AppTheme {
  // ── 🎨 Core Color Palette ──
  static const Color primaryTeal = Color(0xFF0F766E); // Nordic Deep Teal
  static const Color primaryMint = Color(0xFF10B981); // Radiant Farm Mint
  static const Color primaryDark = Color(0xFF0D5C56); // Rich Forest Teal
  static const Color accentAmber = Color(0xFFF59E0B); // Solar Amber Glow
  static const Color accentCyan = Color(0xFF06B6D4);  // Pure Spring Cyan
  static const Color accentViolet = Color(0xFF8B5CF6); // Lavender Frost

  // Surface & Neutrals
  static const Color bgPorcelain = Color(0xFFF8FAFC); // Clean Canvas Background
  static const Color bgSurface = Color(0xFFFFFFFF);   // Card Background
  static const Color bgSurfaceMuted = Color(0xFFF1F5F9); // Muted Pill Background
  static const Color darkSlate = Color(0xFF0F172A);   // Deep Contrast Slate
  static const Color darkCard = Color(0xFF1E293B);    // Premium Dark Container

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFFFFFFFF);

  // Border & Divider
  static const Color borderSubtle = Color(0xFFE2E8F0);
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
