import 'package:flutter/material.dart';

import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// Section title + optional count badge + optional trailing action — the
/// `delivery_tracker_tab._buildSectionHeader` recipe, promoted for reuse.
class UiSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? action;
  final EdgeInsets padding;

  const UiSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.action,
    this.padding = const EdgeInsets.only(top: 20, bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: UiText.h2.copyWith(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: UiTone.surfaceMuted,
                borderRadius: BorderRadius.circular(UiRadius.xs),
              ),
              child: Text(
                '$count',
                style: UiText.caption
                    .copyWith(fontWeight: FontWeight.w700, color: UiTone.softText),
              ),
            ),
          ],
          if (action != null) ...[
            const Spacer(),
            action!,
          ],
        ],
      ),
    );
  }
}
