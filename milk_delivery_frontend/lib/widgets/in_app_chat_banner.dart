import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notification_model.dart';
import '../providers/app_state.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';
import 'delivery_chat_sheet.dart';
import 'driver_delivery_chat_sheet.dart';

class InAppChatBanner {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required NotificationModel notification,
    required AppState state,
  }) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    HapticFeedback.mediumImpact();

    final overlayState = Overlay.of(context, rootOverlay: true);

    _currentEntry = OverlayEntry(
      builder: (ctx) => _InAppChatBannerWidget(
        notification: notification,
        state: state,
        onDismiss: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    _dismissTimer = Timer(const Duration(seconds: 5), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _InAppChatBannerWidget extends StatefulWidget {
  final NotificationModel notification;
  final AppState state;
  final VoidCallback onDismiss;

  const _InAppChatBannerWidget({
    required this.notification,
    required this.state,
    required this.onDismiss,
  });

  @override
  State<_InAppChatBannerWidget> createState() => _InAppChatBannerWidgetState();
}

class _InAppChatBannerWidgetState extends State<_InAppChatBannerWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleOpenChat() {
    widget.onDismiss();
    final userRole = (widget.state.currentUser?.role ?? 'CUSTOMER').toUpperCase();
    final notif = widget.notification;

    if (userRole == 'DRIVER' || userRole == 'DELIVERY_PARTNER') {
      DriverDeliveryChatSheet.show(
        context,
        customerName: notif.title.replaceAll('💬', '').replaceAll('(Customer)', '').trim(),
        driverName: widget.state.currentUser?.name ?? 'Delivery Partner',
        orderSummary: 'Active Milk Delivery',
      );
    } else {
      DeliveryChatSheet.show(
        context,
        driverName: notif.title.replaceAll('💬', '').replaceAll('(Delivery Partner)', '').trim(),
        customerName: widget.state.currentUser?.name ?? 'Customer',
        orderTitle: 'Live Milk Delivery',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 6,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -5) {
              widget.onDismiss();
            }
          },
          onTap: _handleOpenChat,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(UiRadius.lg),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x220D7C66),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D7C66), Color(0xFF10A37F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(UiRadius.md),
                    ),
                    child: const Center(
                      child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.notification.title,
                                style: UiText.bodyStrong.copyWith(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: UiTone.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NOW',
                                style: UiText.caption.copyWith(
                                  color: UiTone.success,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.notification.message,
                          style: UiText.caption.copyWith(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66),
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                    ),
                    child: Text(
                      'Reply',
                      style: UiText.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
