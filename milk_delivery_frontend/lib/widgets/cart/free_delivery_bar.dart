import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class FreeDeliveryBar extends StatelessWidget {
  final double cartTotal;
  final double threshold;

  const FreeDeliveryBar({
    super.key,
    required this.cartTotal,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    if (threshold <= 0) return const SizedBox.shrink();

    final isFree = cartTotal >= threshold;
    final progress = (cartTotal / threshold).clamp(0.0, 1.0);
    final deficit = threshold - cartTotal;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  isFree ? '✓ 🎉' : '🚚',
                  style: TextStyle(
                    fontSize: 18,
                    color: isFree ? UiTone.success : Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFree 
                        ? 'Yay! FREE Delivery unlocked!' 
                        : 'Add ₹${deficit.toStringAsFixed(0)} more for FREE Delivery',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isFree ? UiTone.success : UiTone.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 6,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    color: isFree ? UiTone.success : Colors.amber.shade500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
