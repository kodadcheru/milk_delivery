import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Branded pull-to-refresh wrapper with Pamba theming.
/// 
/// Usage:
/// ```dart
/// PambaRefreshIndicator(
///   onRefresh: () => state.reloadAllData(),
///   child: CustomScrollView(...),
/// )
/// ```
class PambaRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;
  final Color? color;
  final Color? backgroundColor;

  const PambaRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? UiTone.primary,
      backgroundColor: backgroundColor ?? Colors.white,
      displacement: displacement,
      strokeWidth: 2.5,
      child: child,
    );
  }
}
