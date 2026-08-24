import 'package:flutter/material.dart';

import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// Horizontal pill-chip carousel — selected = primary/white, unselected =
/// `surfaceMuted` + `surfaceBorder`. The `delivery_tracker_tab._buildFilterChips`
/// recipe, promoted for reuse. The caller owns [selectedIndex] and rebuilds on
/// [onSelected].
///
/// Pass [counts] (same length as [labels]) to render a live count badge after
/// each label — a positive count shows a pill (white-on-selected, muted
/// otherwise); zero or a missing entry hides it.
class UiFilterChipBar extends StatelessWidget {
  final List<String> labels;
  final List<int>? counts;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;
  final double height;

  const UiFilterChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
    this.padding = EdgeInsets.zero,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          final count =
              (counts != null && index < counts!.length) ? counts![index] : 0;
          return Center(
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(UiRadius.pill),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                  border: Border.all(
                    color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[index],
                      style: UiText.label.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : UiTone.softText,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : UiTone.surface,
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                        ),
                        child: Text(
                          '$count',
                          style: UiText.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : UiTone.softText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
