import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

/// Light teal focal card — the shared hero treatment used across the customer,
/// provider, and driver surfaces (replaces the old dark "command-center"
/// panels). Wraps arbitrary white-on-teal content in the on-brand
/// [UiGradient.hero] gradient with the [UiShadow.glowPrimary] glow.
///
/// Content is passed as [child] because hero layouts differ per screen. Use the
/// companion [UiHeroPill] (eyebrow / status pill) and [UiHeroGlass] (frosted
/// inner panel) for the repeated on-teal chrome so every hero stays consistent.
class UiHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const UiHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: UiGradient.hero,
        borderRadius: BorderRadius.circular(UiRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        boxShadow: UiShadow.glowPrimary,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Small translucent-white eyebrow/status pill for use on a [UiHeroCard]
/// (e.g. "LIVE HUB", "ON DUTY", "LIVE ORDER").
class UiHeroPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const UiHeroPill({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(UiRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted inner panel for content nested inside a [UiHeroCard] — the
/// white@0.15 fill + white@0.22 border treatment used for OTP boxes, info
/// strips, and stat rows on teal.
class UiHeroGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const UiHeroGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}
