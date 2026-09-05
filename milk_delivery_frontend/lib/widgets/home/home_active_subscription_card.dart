import 'package:flutter/material.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class HomeActiveSubscriptionCard extends StatelessWidget {
  final AppState state;
  final SubscriptionModel sub;

  const HomeActiveSubscriptionCard({
    super.key,
    required this.state,
    required this.sub,
  });

  String _calculateCountdown() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 5, 30);
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    final diff = target.difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final pName = sub.productDetail != null
        ? sub.productDetail!.localizedName(state.currentLanguage)
        : state.translateProduct('Daily Farm Fresh Milk');
    final pPrice = sub.displayPrice;
    final countdown = _calculateCountdown();
    final isPaused = sub.status != 'ACTIVE';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPaused
                ? [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]
                : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(UiRadius.lg),
          border: Border.all(
            color: isPaused
                ? const Color(0xFFFCD34D)
                : const Color(0xFF86EFAC).withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPaused ? const Color(0xFFD97706) : const Color(0xFF0D7C66)).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Title & Dynamic Live Countdown ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isPaused
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : UiTone.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPaused ? Icons.pause_circle_rounded : Icons.autorenew_rounded,
                          color: isPaused ? const Color(0xFFD97706) : UiTone.primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPaused ? 'Subscription Paused' : 'Daily Morning Drop',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: isPaused ? const Color(0xFFB45309) : const Color(0xFF064E3B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isPaused
                          ? const LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)])
                          : const LinearGradient(colors: [Color(0xFF0D7C66), Color(0xFF0A5C4C)]),
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaused ? Icons.schedule : Icons.bolt_rounded,
                          size: 11,
                          color: isPaused ? const Color(0xFFB45309) : const Color(0xFF34D399),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPaused ? 'On Hold' : 'Next in $countdown',
                          style: TextStyle(
                            color: isPaused ? const Color(0xFF92400E) : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Product Info Row ──
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(sub.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: UiTone.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sub.packSize,
                                style: const TextStyle(
                                  color: UiTone.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${(pPrice * sub.quantity).toStringAsFixed(0)} / drop • ${sub.scheduleType}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => state.setTab(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      side: const BorderSide(color: UiTone.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: UiTone.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
              const SizedBox(height: 11),

              // ── Quick Actions ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (sub.status == 'ACTIVE') {
                          await state.pauseTomorrow(sub.id);
                        } else {
                          await state.toggleSubscriptionStatus(sub.id);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: UiTone.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              content: Text(
                                sub.status == 'ACTIVE' ? '⏸️ Delivery paused for tomorrow!' : '▶️ Subscription resumed!',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        sub.status == 'ACTIVE' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                        size: 15,
                      ),
                      label: Text(
                        sub.status == 'ACTIVE' ? 'Pause Tomorrow' : 'Resume Drop',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        foregroundColor: sub.status == 'ACTIVE' ? const Color(0xFFD97706) : UiTone.primary,
                        side: BorderSide(
                          color: sub.status == 'ACTIVE' ? const Color(0xFFF59E0B) : UiTone.primary,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => state.setTab(1),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text(
                        'Edit Plan & Drop',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
