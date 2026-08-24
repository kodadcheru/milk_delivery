import 'package:flutter/material.dart';

import '../../theme/ui_status.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// Tinted status pill: `color.withValues(alpha: .1)` fill + bold caption in the
/// status accent. Color is derived from [uiStatusColor] unless [color] is given.
class UiStatusPill extends StatelessWidget {
  final String status;

  /// Overrides the display text (defaults to [status] verbatim).
  final String? label;

  /// Overrides the derived accent color.
  final Color? color;

  /// Slightly smaller variant for dense list rows.
  final bool dense;

  const UiStatusPill({
    super.key,
    required this.status,
    this.label,
    this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? uiStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UiRadius.xs),
      ),
      child: Text(
        label ?? status,
        style: UiText.caption.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: dense ? 10 : null,
        ),
      ),
    );
  }
}
