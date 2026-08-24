import 'package:flutter/material.dart';

import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// Centered empty state — soft-primary circle + icon + title + message + an
/// optional CTA. The `delivery_tracker_tab._buildFilteredEmptyState` /
/// `home_tab` recipe, promoted for reuse.
class UiEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Optional call-to-action (e.g. an `OutlinedButton`/`ElevatedButton`).
  final Widget? action;

  /// Accent for the circle + icon. Defaults to [UiTone.primary].
  final Color accent;

  final double circleSize;
  final EdgeInsets padding;

  const UiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.accent = UiTone.primary,
    this.circleSize = 84,
    this.padding = const EdgeInsets.only(top: 48, bottom: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: circleSize * 0.45, color: accent),
            ),
            const SizedBox(height: 16),
            Text(title, style: UiText.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                style: UiText.label.copyWith(height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 22),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
