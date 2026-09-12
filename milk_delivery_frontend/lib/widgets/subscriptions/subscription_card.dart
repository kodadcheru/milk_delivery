import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_tokens.dart';

class SubscriptionCard extends StatefulWidget {
  final AppState state;
  final SubscriptionModel sub;
  final bool isTelugu;
  final Future<void> Function(BuildContext context, SubscriptionModel sub, bool isTelugu)? onDeleteRequested;
  final Future<void> Function(BuildContext context, SubscriptionModel sub, bool isTelugu)? onTogglePauseRequested;

  const SubscriptionCard({
    super.key,
    required this.state,
    required this.sub,
    required this.isTelugu,
    this.onDeleteRequested,
    this.onTogglePauseRequested,
  });

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _isToggling = false;

  Future<void> _handlePauseResumeClick(BuildContext context) async {
    if (widget.onTogglePauseRequested != null) {
      await widget.onTogglePauseRequested!(context, widget.sub, widget.isTelugu);
      return;
    }

    final isPaused = widget.sub.status == 'PAUSED';
    final isTelugu = widget.isTelugu;

    final titleText = isTelugu
        ? (isPaused ? 'సభ్యత్వాన్ని పునఃప్రారంభించాలా?' : 'సభ్యత్వాన్ని పాజ్ చేయాలా?')
        : (isPaused ? 'Resume Subscription?' : 'Pause Subscription?');

    final contentText = isTelugu
        ? (isPaused
            ? 'రేపటి నుండి ఉదయం 06:00 AM గంటలకు మీ రోజువారీ డెలివరీలు మళ్లీ ప్రారంభమవుతాయి.'
            : 'రేపటి నుండి మీ రోజువారీ డెలివరీలు ఆగిపోతాయి. మీరు ఎప్పుడైనా ఒక్క ట్యాప్‌తో పునఃప్రారంభించవచ్చు.')
        : (isPaused
            ? 'Your daily morning milk deliveries will resume starting tomorrow at 06:00 AM.'
            : 'Your daily morning deliveries will be paused starting tomorrow. You can resume anytime with one tap.');

    final confirmBtnText = isTelugu
        ? (isPaused ? 'డెలివరీలు పునఃప్రారంభించు' : 'డెలివరీ పాజ్ చేయండి')
        : (isPaused ? 'Resume Deliveries' : 'Pause Delivery');

    final cancelBtnText = isTelugu
        ? (isPaused ? 'పాజ్ అలాగే ఉంచండి' : 'యాక్టివ్‌గా ఉంచండి')
        : (isPaused ? 'Keep Paused' : 'Keep Active');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPaused
                    ? const Color(0xFF0D7C66).withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: isPaused ? const Color(0xFF0D7C66) : const Color(0xFFD97706),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titleText,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          contentText,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            child: Text(cancelBtnText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPaused ? const Color(0xFF0D7C66) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              confirmBtnText,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isToggling = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await widget.state.toggleSubscriptionStatus(widget.sub.id);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isPaused ? const Color(0xFF0D7C66) : const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Icon(
                  isPaused ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPaused
                        ? (isTelugu ? '🎉 సభ్యత్వం పునఃప్రారంభించబడింది! రేపు ఉదయం డెలివరీ అవుతుంది.' : '🎉 Subscription resumed! Deliveries restart tomorrow 06:00 AM.')
                        : (isTelugu ? '⏸️ సభ్యత్వం పాజ్ చేయబడింది. ఎప్పుడైనా పునఃప్రారంభించవచ్చు.' : '⏸️ Subscription paused starting tomorrow.'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    final state = widget.state;
    final isTelugu = widget.isTelugu;
    final prod = sub.productDetail;
    final pName = prod?.name ?? 'Farm Fresh Milk';
    final isPaused = sub.status == 'PAUSED';
    final isCancelled = sub.status == 'CANCELLED';
    final streakDays = sub.streakDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaused
              ? const Color(0xFFFCD34D)
              : (isCancelled ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
          width: isPaused ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPaused
                ? Colors.amber.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Header Row: Icon, Title, Status Badge ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPaused
                      ? Colors.amber.withValues(alpha: 0.12)
                      : (isCancelled ? Colors.red.withValues(alpha: 0.08) : UiTone.primary.withValues(alpha: 0.08)),
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
                      '${sub.packSize} • ${sub.localizedScheduleType(isTelugu)}',
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
                          ? Colors.amber.withValues(alpha: 0.15)
                          : const Color(0xFF0D7C66).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: isPaused ? Border.all(color: const Color(0xFFF59E0B), width: 1.0) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPaused) ...[
                      const Icon(Icons.pause_circle_filled_rounded, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                    ] else if (!isCancelled) ...[
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF0D7C66)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isCancelled
                          ? (isTelugu ? 'రద్దు చేయబడింది' : 'CANCELLED')
                          : isPaused
                              ? (isTelugu ? 'విరామం' : 'PAUSED')
                              : (isTelugu ? 'యాక్టివ్' : 'ACTIVE'),
                      style: TextStyle(
                        color: isCancelled
                            ? Colors.red
                            : isPaused
                                ? const Color(0xFFB45309)
                                : const Color(0xFF0D7C66),
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),

          // ── 2. Delivery Slot & Daily Price ──
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
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: isPaused ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  decoration: isPaused ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),

          // ── 3. Tomorrow's Quantity Stepper (Active Only) ──
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

          // ── 4. Primary Interactive Pause / Resume Action Bar ──
          const SizedBox(height: 14),
          if (isCancelled) ...[
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                // Pause or Resume Button
                Expanded(
                  child: _isToggling
                      ? Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0D7C66)),
                          ),
                        )
                      : (isPaused
                          // ── RESUME BUTTON (When Paused) ──
                          ? ElevatedButton.icon(
                            onPressed: () => _handlePauseResumeClick(context),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text(
                              isTelugu ? 'డెలివరీ పునఃప్రారంభించండి' : 'Resume Delivery',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                          // ── PAUSE BUTTON (When Active) ──
                          : OutlinedButton.icon(
                              onPressed: () => _handlePauseResumeClick(context),
                              icon: const Icon(Icons.pause_rounded, size: 16),
                              label: Text(
                                isTelugu ? 'డెలివరీ పాజ్ చేయండి' : 'Pause Delivery',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                backgroundColor: const Color(0xFFFFFBEB),
                                side: const BorderSide(color: Color(0xFFFCD34D), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )),
                ),
                const SizedBox(width: 8),

                // Delete / Cancel Option Icon Button
                if (widget.onDeleteRequested != null) ...[
                  IconButton(
                    onPressed: () => widget.onDeleteRequested!(context, sub, isTelugu),
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                    tooltip: isTelugu ? 'రద్దు చేయండి' : 'Cancel Plan',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
