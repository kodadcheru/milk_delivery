import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

/// A light inset card — white surface, `UiRadius.md`, `surfaceBorder` outline —
/// the base container for list rows and sheet sections. Becomes tappable (with
/// ink ripple) when [onTap] is provided.
class UiInsetCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? shadow;

  const UiInsetCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.radius = UiRadius.md,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? UiTone.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? UiTone.surfaceBorder),
        boxShadow: shadow,
      ),
      child: child,
    );

    final content = onTap == null
        ? decorated
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: decorated,
            ),
          );

    return margin == EdgeInsets.zero
        ? content
        : Padding(padding: margin, child: content);
  }
}
