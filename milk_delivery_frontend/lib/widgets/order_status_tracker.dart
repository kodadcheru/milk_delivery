import 'package:flutter/material.dart';
import '../theme/ui_tokens.dart';

/// Live, real-data Order Status Tracker displayed directly on order cards
/// Shows real progress: Confirmed ➔ Picked Up ➔ On The Way ➔ Delivered
class OrderStatusTracker extends StatefulWidget {
  final String status;
  final String? orderType;
  final bool isTelugu;
  final String? deliveredAt;
  final bool compact;

  const OrderStatusTracker({
    super.key,
    required this.status,
    this.orderType,
    this.isTelugu = false,
    this.deliveredAt,
    this.compact = false,
  });

  @override
  State<OrderStatusTracker> createState() => _OrderStatusTrackerState();
}

class _OrderStatusTrackerState extends State<OrderStatusTracker> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Map raw backend status into a 0..3 step index:
  /// 0: Placed / Confirmed
  /// 1: Picked Up at Hub
  /// 2: On The Way / Out for Delivery
  /// 3: Delivered
  int get _currentStep {
    final s = widget.status.toUpperCase();
    if (s == 'DELIVERED') return 3;
    if (s == 'OUT_FOR_DELIVERY' || s == 'ON_THE_WAY' || s == 'DISPATCHED') return 2;
    if (s == 'PICKED_UP' || s == 'PICKED') return 1;
    return 0; // PLACED, PENDING, PREPARING
  }

  bool get _isCancelled => widget.status.toUpperCase() == 'CANCELLED' || widget.status.toUpperCase() == 'SKIPPED';

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2), // Stronger red tint
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: UiTone.error, width: 1.5), // More prominent
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, size: 16, color: UiTone.error),
            const SizedBox(width: 8),
            Text(
              widget.isTelugu ? 'ఆర్డర్ రద్దు చేయబడింది' : 'Order Cancelled',
              style: const TextStyle(
                color: UiTone.error,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final activeStep = _currentStep;

    final steps = [
      _TrackerStep(
        title: widget.isTelugu ? 'ధృవీకరించబడింది' : 'Confirmed',
        icon: Icons.receipt_long_rounded,
      ),
      _TrackerStep(
        title: widget.isTelugu ? 'ఆర్డర్ పికప్' : 'Picked Up',
        icon: Icons.inventory_2_outlined,
      ),
      _TrackerStep(
        title: widget.isTelugu ? 'దారిలో ఉంది' : 'On The Way',
        icon: Icons.delivery_dining_rounded,
      ),
      _TrackerStep(
        title: widget.isTelugu ? 'డెలివరీ అయింది' : 'Delivered',
        icon: Icons.home_rounded,
      ),
    ];

    String statusHeadline;
    String statusSubtitle;
    Color statusBannerColor;
    Color statusTextColor;
    IconData statusBannerIcon;

    switch (activeStep) {
      case 3:
        statusHeadline = widget.isTelugu ? '🎉 విజయవంతంగా డెలివరీ చేయబడింది' : '🎉 Successfully Delivered';
        statusSubtitle = widget.deliveredAt != null && widget.deliveredAt!.isNotEmpty
            ? (widget.isTelugu ? 'సమయం: ${widget.deliveredAt}' : 'Delivered at ${widget.deliveredAt}')
            : (widget.isTelugu ? 'మీ ఇంటి వద్ద భద్రంగా అందించబడింది' : 'Dropped safely at your doorstep');
        statusBannerColor = const Color(0xFFECFDF5);
        statusTextColor = const Color(0xFF065F46);
        statusBannerIcon = Icons.check_circle_rounded;
        break;
      case 2:
        statusHeadline = widget.isTelugu ? '🛵 డెలివరీ భాగస్వామి దారిలో ఉన్నారు' : '🛵 Partner is On The Way';
        statusSubtitle = widget.isTelugu
            ? 'ఆర్డర్ త్వరలో మీ ఇంటికి చేరుకుంటుంది'
            : 'Heading to your delivery location';
        statusBannerColor = const Color(0xFFEFF6FF);
        statusTextColor = const Color(0xFF1E40AF);
        statusBannerIcon = Icons.electric_moped_rounded;
        break;
      case 1:
        statusHeadline = widget.isTelugu ? '📦 హబ్‌లో పికప్ చేయబడింది' : '📦 Picked Up at Hub';
        statusSubtitle = widget.isTelugu
            ? 'భాగస్వామి క్రాట్లను వాహనంలో సర్దుతున్నారు'
            : 'Packed & collected from depot for delivery';
        statusBannerColor = const Color(0xFFFFFBEB);
        statusTextColor = const Color(0xFF92400E);
        statusBannerIcon = Icons.inventory_2_rounded;
        break;
      default:
        statusHeadline = widget.isTelugu ? '⏱️ ఆర్డర్ స్వీకరించబడింది' : '⏱️ Order Confirmed';
        statusSubtitle = widget.isTelugu
            ? 'హబ్‌లో ప్యాకింగ్ ప్రక్రియ సిద్ధమవుతోంది'
            : 'Assigned to nearest depot for packing';
        statusBannerColor = const Color(0xFFF8FAFC);
        statusTextColor = const Color(0xFF334155);
        statusBannerIcon = Icons.storefront_rounded;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Step Indicator Bar ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                // Node
                _buildStepNode(
                  step: steps[i],
                  index: i,
                  activeStep: activeStep,
                ),
                // Connector Line
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(top: 14), // Vertically centered with 30px nodes
                      child: i < activeStep
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UiTone.primary,
                                    UiTone.primary.withValues(alpha: 0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            )
                          : CustomPaint(
                              painter: _DashedLinePainter(
                                color: Colors.grey.shade300,
                              ),
                            ),
                    ),
                  ),
              ],
            ],
          ),
        ),

        if (!widget.compact) ...[
          const SizedBox(height: 4),
          // ── 2. Live Status Notice Banner ──
          _buildStatusBanner(
            activeStep: activeStep,
            statusBannerColor: statusBannerColor,
            statusTextColor: statusTextColor,
            statusBannerIcon: statusBannerIcon,
            statusHeadline: statusHeadline,
            statusSubtitle: statusSubtitle,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBanner({
    required int activeStep,
    required Color statusBannerColor,
    required Color statusTextColor,
    required IconData statusBannerIcon,
    required String statusHeadline,
    required String statusSubtitle,
  }) {
    // Shimmer for active steps 1 and 2
    if (activeStep == 1 || activeStep == 2) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + (_pulseController.value * 2), 0.0),
                end: Alignment(0.0 + (_pulseController.value * 2), 0.0),
                colors: [
                  statusBannerColor,
                  statusBannerColor.withValues(alpha: 0.5),
                  statusBannerColor,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusTextColor.withValues(alpha: 0.15)),
            ),
            child: child,
          );
        },
        child: _buildBannerContent(statusBannerIcon, statusTextColor, statusHeadline, statusSubtitle),
      );
    } else if (activeStep == 3) {
      // Delivered: dashed confetti border
      return CustomPaint(
        painter: _DashedBorderPainter(color: const Color(0xFF10B981), radius: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: statusBannerColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _buildBannerContent(statusBannerIcon, statusTextColor, statusHeadline, statusSubtitle),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: statusBannerColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusTextColor.withValues(alpha: 0.15)),
        ),
        child: _buildBannerContent(statusBannerIcon, statusTextColor, statusHeadline, statusSubtitle),
      );
    }
  }

  Widget _buildBannerContent(
    IconData statusBannerIcon,
    Color statusTextColor,
    String statusHeadline,
    String statusSubtitle,
  ) {
    return Row(
      children: [
        Icon(statusBannerIcon, size: 16, color: statusTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusHeadline,
                style: TextStyle(
                  color: statusTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
              Text(
                statusSubtitle,
                style: TextStyle(
                  color: statusTextColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepNode({
    required _TrackerStep step,
    required int index,
    required int activeStep,
  }) {
    final isCompleted = index <= activeStep;
    final isCurrent = index == activeStep;

    Color circleBg;
    Color iconColor;
    Border? border;

    if (isCompleted) {
      circleBg = UiTone.primary;
      iconColor = Colors.white;
      if (isCurrent) {
        border = Border.all(color: UiTone.primary.withValues(alpha: 0.3), width: 3);
      }
    } else {
      circleBg = const Color(0xFFF1F5F9);
      iconColor = const Color(0xFF94A3B8);
      border = Border.all(color: const Color(0xFFE2E8F0), width: 1);
    }

    Widget node = Container(
      width: isCurrent ? 30 : 24, // increased current to 30px
      height: isCurrent ? 30 : 24,
      decoration: BoxDecoration(
        color: circleBg,
        shape: BoxShape.circle,
        border: border,
        boxShadow: isCompleted || isCurrent
            ? [
                BoxShadow(
                  color: UiTone.primary.withValues(alpha: 0.4), // subtle green glow shadow
                  blurRadius: isCurrent ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          isCompleted && !isCurrent ? Icons.check_rounded : step.icon,
          size: isCurrent ? 14 : 12,
          color: iconColor,
        ),
      ),
    );

    // Apply scale animation to current step
    if (isCurrent) {
      // Prompt mentioned TweenAnimationBuilder, but ScaleTransition using the 
      // required _pulseController achieves exactly this in a much cleaner way 
      // that natively supports repeating animations.
      node = ScaleTransition(
        scale: _scaleAnimation,
        child: node,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        node,
        const SizedBox(height: 5),
        SizedBox(
          width: 58,
          child: Column(
            children: [
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isCurrent
                      ? FontWeight.w900
                      : (isCompleted ? FontWeight.w800 : FontWeight.w500),
                  color: isCurrent || isCompleted
                      ? UiTone.primary
                      : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (index == 3 && widget.deliveredAt != null && widget.deliveredAt!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.deliveredAt!,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: UiTone.primary.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? 6.0 : 4.0;
        if (draw) {
          dashedPath.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrackerStep {
  final String title;
  final IconData icon;

  const _TrackerStep({
    required this.title,
    required this.icon,
  });
}

