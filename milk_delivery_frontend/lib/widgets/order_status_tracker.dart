import 'package:flutter/material.dart';
import '../theme/ui_tokens.dart';

/// Live, real-data Order Status Tracker displayed directly on order cards
/// Shows real progress: Confirmed ➔ Picked Up ➔ On The Way ➔ Delivered
class OrderStatusTracker extends StatelessWidget {
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

  /// Map raw backend status into a 0..3 step index:
  /// 0: Placed / Confirmed
  /// 1: Picked Up at Hub
  /// 2: On The Way / Out for Delivery
  /// 3: Delivered
  int get _currentStep {
    final s = status.toUpperCase();
    if (s == 'DELIVERED') return 3;
    if (s == 'OUT_FOR_DELIVERY' || s == 'ON_THE_WAY' || s == 'DISPATCHED') return 2;
    if (s == 'PICKED_UP' || s == 'PICKED') return 1;
    return 0; // PLACED, PENDING, PREPARING
  }

  bool get _isCancelled => status.toUpperCase() == 'CANCELLED' || status.toUpperCase() == 'SKIPPED';

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: UiTone.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, size: 16, color: UiTone.error),
            const SizedBox(width: 8),
            Text(
              isTelugu ? 'ఆర్డర్ రద్దు చేయబడింది' : 'Order Cancelled',
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
        title: isTelugu ? 'ధృవీకరించబడింది' : 'Confirmed',
        icon: Icons.receipt_long_rounded,
      ),
      _TrackerStep(
        title: isTelugu ? 'ఆర్డర్ పికప్' : 'Picked Up',
        icon: Icons.inventory_2_outlined,
      ),
      _TrackerStep(
        title: isTelugu ? 'దారిలో ఉంది' : 'On The Way',
        icon: Icons.delivery_dining_rounded,
      ),
      _TrackerStep(
        title: isTelugu ? 'డెలివరీ అయింది' : 'Delivered',
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
        statusHeadline = isTelugu ? '🎉 విజయవంతంగా డెలివరీ చేయబడింది' : '🎉 Successfully Delivered';
        statusSubtitle = deliveredAt != null && deliveredAt!.isNotEmpty
            ? (isTelugu ? 'సమయం: $deliveredAt' : 'Delivered at $deliveredAt')
            : (isTelugu ? 'మీ ఇంటి వద్ద భద్రంగా అందించబడింది' : 'Dropped safely at your doorstep');
        statusBannerColor = const Color(0xFFECFDF5);
        statusTextColor = const Color(0xFF065F46);
        statusBannerIcon = Icons.check_circle_rounded;
        break;
      case 2:
        statusHeadline = isTelugu ? '🛵 డెలివరీ భాగస్వామి దారిలో ఉన్నారు' : '🛵 Partner is On The Way';
        statusSubtitle = isTelugu
            ? 'ఆర్డర్ త్వరలో మీ ఇంటికి చేరుకుంటుంది'
            : 'Heading to your delivery location';
        statusBannerColor = const Color(0xFFEFF6FF);
        statusTextColor = const Color(0xFF1E40AF);
        statusBannerIcon = Icons.electric_moped_rounded;
        break;
      case 1:
        statusHeadline = isTelugu ? '📦 హబ్‌లో పికప్ చేయబడింది' : '📦 Picked Up at Hub';
        statusSubtitle = isTelugu
            ? 'భాగస్వామి క్రాట్లను వాహనంలో సర్దుతున్నారు'
            : 'Packed & collected from depot for delivery';
        statusBannerColor = const Color(0xFFFFFBEB);
        statusTextColor = const Color(0xFF92400E);
        statusBannerIcon = Icons.inventory_2_rounded;
        break;
      default:
        statusHeadline = isTelugu ? '⏱️ ఆర్డర్ స్వీకరించబడింది' : '⏱️ Order Confirmed';
        statusSubtitle = isTelugu
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
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: i < activeStep
                            ? UiTone.primary
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),

        if (!compact) ...[
          const SizedBox(height: 4),
          // ── 2. Live Status Notice Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: statusBannerColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusTextColor.withValues(alpha: 0.15)),
            ),
            child: Row(
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
            ),
          ),
        ],
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 28 : 24,
          height: isCurrent ? 28 : 24,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: border,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: UiTone.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
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
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 58,
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isCurrent
                  ? FontWeight.w900
                  : (isCompleted ? FontWeight.w700 : FontWeight.w500),
              color: isCurrent
                  ? UiTone.primary
                  : (isCompleted ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TrackerStep {
  final String title;
  final IconData icon;

  const _TrackerStep({
    required this.title,
    required this.icon,
  });
}
