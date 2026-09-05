import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

enum UiButtonVariant { primary, secondary, destructive, outline }

class UiButton extends StatelessWidget {
  final UiButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final VoidCallback? onPressed;
  final String label;

  const UiButton({
    super.key,
    this.variant = UiButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case UiButtonVariant.primary:
        backgroundColor = UiTone.primary;
        foregroundColor = UiTone.surface;
        break;
      case UiButtonVariant.secondary:
        backgroundColor = UiTone.secondary;
        foregroundColor = UiTone.surface;
        break;
      case UiButtonVariant.destructive:
        backgroundColor = UiTone.error;
        foregroundColor = UiTone.surface;
        break;
      case UiButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = UiTone.primary;
        borderSide = const BorderSide(color: UiTone.primary, width: 1.2);
        break;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      side: borderSide,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.xs),
      ),
      padding: const EdgeInsets.symmetric(horizontal: UiSpace.lg, vertical: UiSpace.md),
      elevation: variant == UiButtonVariant.outline ? 0 : 1,
    );

    Widget content = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w800),
    );

    if (isLoading) {
      content = SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foregroundColor,
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          content,
        ],
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: content,
    );
  }
}
