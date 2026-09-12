import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class FreeDeliveryBar extends StatelessWidget {
  final double cartTotal;
  final double threshold;
  final bool isTelugu;

  const FreeDeliveryBar({
    super.key,
    required this.cartTotal,
    required this.threshold,
    this.isTelugu = false,
  });

  @override
  Widget build(BuildContext context) {
    if (threshold <= 0) return const SizedBox.shrink();

    final isFree = cartTotal >= threshold;
    final progress = (cartTotal / threshold).clamp(0.0, 1.0);
    final deficit = threshold - cartTotal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isFree ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(
          color: isFree ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isFree ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isFree ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
                    size: 16,
                    color: isFree ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFree
                      ? (isTelugu ? 'ఈ ఆర్డర్‌పై ఉచిత డెలివరీ లభించింది!' : 'FREE Delivery unlocked on this order!')
                      : (isTelugu
                          ? 'ఉచిత డెలివరీ కోసం ఇంకో ₹${deficit.toStringAsFixed(0)} జోడించండి'
                          : 'Add ₹${deficit.toStringAsFixed(0)} more for FREE Delivery'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isFree ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
              if (!isFree)
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              width: double.infinity,
              color: isFree ? const Color(0xFFDCFCE7) : const Color(0xFFFDE68A).withValues(alpha: 0.6),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isFree ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
