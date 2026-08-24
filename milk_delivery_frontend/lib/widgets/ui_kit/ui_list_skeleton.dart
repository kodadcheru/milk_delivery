import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';
import '../shimmer_loading.dart';

/// A thin shimmer placeholder for list loading states — a column of rounded
/// skeleton cards pulsing via [ShimmerLoading]. Drop in while a `state.*` list
/// is still loading, in place of the empty state.
class UiListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const UiListSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 84,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(
            itemCount,
            (_) => Container(
              height: itemHeight,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.md),
                border: Border.all(color: UiTone.surfaceBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: UiTone.surfaceMuted,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 10,
                      decoration: BoxDecoration(
                        color: UiTone.surfaceMuted,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: UiTone.surfaceMuted,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
