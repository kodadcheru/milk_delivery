import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

/// Timeline dot + connector + white card chrome with a 4px status-accent left
/// border. The `delivery_tracker_tab._timelineCard` recipe, promoted for reuse
/// across order / stop / subscription lists. The connector fills the card via
/// `IntrinsicHeight`; set [isLast] to hide it on the final row.
class UiTimelineCard extends StatelessWidget {
  final Color accent;
  final VoidCallback? onTap;
  final Widget child;
  final bool isLast;

  const UiTimelineCard({
    super.key,
    required this.accent,
    required this.child,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 24),
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: UiTone.surfaceBorder),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.lg),
                border: Border.all(color: UiTone.surfaceMuted),
                boxShadow: UiShadow.card,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(UiRadius.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(width: 4, color: accent)),
                      borderRadius: BorderRadius.circular(UiRadius.lg),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
