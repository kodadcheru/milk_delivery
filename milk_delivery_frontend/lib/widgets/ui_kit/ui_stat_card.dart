import 'package:flutter/material.dart';

import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// A bare KPI element — icon/emoji + value + label — with no surface of its
/// own. Use inside a hero stat row ([onDark] = true, white text) or any parent
/// that already provides a container. For a self-contained bordered card, use
/// [UiStatCard].
class UiStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final String? emoji;

  /// White text for placement on a teal [UiHeroCard]; ink/soft text otherwise.
  final bool onDark;

  /// Accent for the icon (light mode only). Defaults to [UiTone.primary].
  final Color? accent;

  final CrossAxisAlignment align;

  const UiStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.emoji,
    this.onDark = false,
    this.accent,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final Color valueColor = onDark ? Colors.white : UiTone.ink;
    final Color labelColor =
        onDark ? Colors.white.withValues(alpha: 0.82) : UiTone.softText;
    final Color iconColor = onDark ? Colors.white : (accent ?? UiTone.primary);

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emoji != null)
          Text(emoji!, style: const TextStyle(fontSize: 18))
        else if (icon != null)
          Icon(icon, size: 18, color: iconColor),
        if (emoji != null || icon != null) const SizedBox(height: 6),
        Text(
          value,
          style: UiText.h2.copyWith(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: UiText.caption.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A self-contained bordered KPI card for light surfaces: an accent-tinted icon
/// chip, a bold value, and a label. Used in metric grids (fuel/CO₂/litres,
/// families/fleet/crates, rating/on-time/salary).
class UiStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final String? emoji;
  final Color accent;
  final VoidCallback? onTap;

  const UiStatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.emoji,
    this.accent = UiTone.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null || icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              alignment: Alignment.center,
              child: emoji != null
                  ? Text(emoji!, style: const TextStyle(fontSize: 16))
                  : Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 10),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: UiText.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: UiText.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UiRadius.md),
        child: card,
      ),
    );
  }
}
