import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_tokens.dart';

class SubscriptionCard extends StatelessWidget {
  final AppState state;
  final SubscriptionModel sub;
  final bool isTelugu;
  final Future<void> Function(BuildContext context, SubscriptionModel sub, bool isTelugu)? onDeleteRequested;

  const SubscriptionCard({
    super.key,
    required this.state,
    required this.sub,
    required this.isTelugu,
    this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final prod = sub.productDetail;
    final pName = prod?.name ?? 'Farm Fresh Milk';
    final isPaused = sub.status == 'PAUSED';
    final isCancelled = sub.status == 'CANCELLED';

    final streakDays = sub.streakDays;

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: UiTone.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(prod?.icon ?? '🥛', style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.translateProduct(pName),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sub.packSize} • ${sub.scheduleType}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (!isCancelled && !isPaused && streakDays > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥 ', style: TextStyle(fontSize: 10)),
                      Text(
                        isTelugu ? '$streakDays రోజులు' : '$streakDays days',
                        style: const TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? Colors.red.withValues(alpha: 0.1)
                      : isPaused
                          ? Colors.orange.withValues(alpha: 0.1)
                          : const Color(0xFF0D7C66).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCancelled
                      ? (isTelugu ? 'రద్దు చేయబడింది' : 'CANCELLED')
                      : isPaused
                          ? (isTelugu ? 'విరామం' : 'PAUSED')
                          : (isTelugu ? 'యాక్టివ్' : 'ACTIVE'),
                  style: TextStyle(
                    color: isCancelled
                        ? Colors.red
                        : isPaused
                            ? Colors.orange
                            : const Color(0xFF0D7C66),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    sub.deliverySlot,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                isTelugu
                    ? '${sub.quantity} × ${sub.packSize} • ${UiFormat.price(sub.displayPrice * sub.quantity)} / రోజు'
                    : '${sub.quantity} × ${sub.packSize} • ${UiFormat.price(sub.displayPrice * sub.quantity)} / day',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
          if (!isCancelled && !isPaused) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        isTelugu ? 'రేపటి పరిమాణం:' : "Tomorrow's Quantity:",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: sub.quantity > 1
                            ? () async {
                                HapticFeedback.lightImpact();
                                await state.updateSubscriptionQuantity(sub.id, sub.quantity - 1);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sub.quantity > 1 ? Colors.white : Colors.grey.shade200,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 14,
                            color: sub.quantity > 1 ? const Color(0xFF1E293B) : Colors.grey,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${sub.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                        ),
                      ),
                      InkWell(
                        onTap: sub.quantity < 10
                            ? () async {
                                HapticFeedback.lightImpact();
                                await state.updateSubscriptionQuantity(sub.id, sub.quantity + 1);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (isCancelled) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final ok = await state.reactivateSubscription(sub.id);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF0D7C66),
                        content: Text(isTelugu ? 'సభ్యత్వం మళ్లీ ప్రారంభించబడింది' : 'Subscription reactivated!'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: Text(isTelugu ? 'సభ్యత్వాన్ని పునఃప్రారంభించండి' : 'Reactivate Subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (isCancelled) return cardContent;

    return Dismissible(
      key: ValueKey(sub.id),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          if (onDeleteRequested != null) {
            await onDeleteRequested!(context, sub, isTelugu);
          }
          return false;
        } else {
          HapticFeedback.mediumImpact();
          await state.toggleSubscriptionStatus(sub.id);
          return false;
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
      child: cardContent,
    );
  }
}
