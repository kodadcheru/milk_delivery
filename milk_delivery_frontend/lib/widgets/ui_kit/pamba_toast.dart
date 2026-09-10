import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

enum ToastType { success, error, warning, info }

class PambaToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() async {
    _timer?.cancel();
    if (mounted) {
      await _controller.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case ToastType.success:
        return UiTone.success;
      case ToastType.error:
        return UiTone.error;
      case ToastType.warning:
        return UiTone.warning;
      case ToastType.info:
        return UiTone.accentBlue;
    }
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case ToastType.success:
        return UiTone.successSoft;
      case ToastType.error:
        return UiTone.errorSoft;
      case ToastType.warning:
        return UiTone.warningSoft;
      case ToastType.info:
        return UiTone.infoSoft;
    }
  }

  IconData get _iconData {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.cancel;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + UiSpace.md,
      left: UiSpace.md,
      right: UiSpace.md,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _timer?.cancel();
              widget.onDismiss();
            },
            child: Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(UiRadius.sm),
                boxShadow: UiShadow.floating,
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: _accentColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.md,
                          vertical: UiSpace.md,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _iconData,
                              color: _accentColor,
                            ),
                            const SizedBox(width: UiSpace.sm),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: const TextStyle(
                                  color: UiTone.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.actionLabel != null && widget.onAction != null)
                              TextButton(
                                onPressed: () {
                                  widget.onAction!();
                                  _dismiss();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _accentColor,
                                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.sm),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
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
