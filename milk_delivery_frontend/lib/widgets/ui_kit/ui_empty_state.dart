import 'package:flutter/material.dart';

import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// Centered empty state — soft-primary circle + icon/emoji + title + message + an
/// optional CTA.
class UiEmptyState extends StatefulWidget {
  final IconData? icon;
  final String? emoji;
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
    this.icon,
    this.emoji,
    required this.title,
    required this.message,
    this.action,
    this.accent = UiTone.primary,
    this.circleSize = 84,
    this.padding = const EdgeInsets.only(top: 48, bottom: 20),
  }) : assert(icon != null || emoji != null, 'Must provide either icon or emoji');

  @override
  State<UiEmptyState> createState() => _UiEmptyStateState();
}

class _UiEmptyStateState extends State<UiEmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: widget.circleSize,
                  height: widget.circleSize,
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: widget.emoji != null
                        ? Text(
                            widget.emoji!,
                            style: TextStyle(fontSize: widget.circleSize * 0.45),
                          )
                        : Icon(widget.icon, size: widget.circleSize * 0.45, color: widget.accent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.title, style: UiText.title, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.message,
                    style: UiText.label.copyWith(height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (widget.action != null) ...[
                  const SizedBox(height: 22),
                  widget.action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
