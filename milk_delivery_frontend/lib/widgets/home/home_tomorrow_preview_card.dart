import 'dart:ui';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

/// Glassmorphic card showing tomorrow's delivery preview.
/// Only visible when the user has active subscriptions.
class HomeTomorrowPreviewCard extends StatelessWidget {
  final AppState state;

  const HomeTomorrowPreviewCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // Get active subscriptions for tomorrow preview
    final activeSubs = state.subscriptions.where((s) => s.status == 'ACTIVE').toList();
    if (activeSubs.isEmpty) return const SizedBox.shrink();

    // Calculate tomorrow's delivery items
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final daysTe = ['సోమ', 'మంగళ', 'బుధ', 'గురు', 'శుక్ర', 'శని', 'ఆది'];
    final dayName = (state.isTelugu ? daysTe : daysEn)[tomorrow.weekday - 1];
    
    int totalItems = 0;
    double totalCost = 0;
    for (final sub in activeSubs) {
      totalItems += sub.quantity;
      final price = sub.displayPrice > 0 ? sub.displayPrice : (sub.productDetail?.pricePerUnit ?? 0);
      totalCost += price * sub.quantity;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  UiTone.primary.withValues(alpha: 0.08),
                  UiTone.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(UiRadius.lg),
              border: Border.all(
                color: UiTone.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Left: Calendar icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: UiTone.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: UiTone.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${tomorrow.day}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: UiTone.primary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Middle: Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isTelugu ? 'రేపటి డెలివరీ' : 'Tomorrow\'s Delivery',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: UiTone.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        state.isTelugu
                            ? '$totalItems వస్తువులు • సుమారు ₹${totalCost.toStringAsFixed(0)}'
                            : '$totalItems items • ₹${totalCost.toStringAsFixed(0)} estimated',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: UiTone.softText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        state.isTelugu ? 'షెడ్యూల్డ్' : 'Scheduled',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
