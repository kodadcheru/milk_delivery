import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

class SubscriptionsTab extends StatefulWidget {
  final AppState state;

  const SubscriptionsTab({super.key, required this.state});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  late Timer _timer;
  String _countdownStr = '';

  int _selectedSegment = 0; // 0 = Active, 1 = Cancelled

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now();
    var nextDelivery = DateTime(now.year, now.month, now.day, 6, 0);
    if (now.isAfter(nextDelivery)) {
      nextDelivery = nextDelivery.add(const Duration(days: 1));
    }
    final diff = nextDelivery.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (mounted) {
      setState(() {
        _countdownStr = '${hours}h ${minutes}m';
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTelugu = widget.state.isTelugu;
    final subs = widget.state.subscriptions;
    final activeSubs = subs.where((s) => s.status != 'CANCELLED').toList();
    final cancelledSubs = subs.where((s) => s.status == 'CANCELLED').toList();
    final displayedSubs = _selectedSegment == 0 ? activeSubs : cancelledSubs;

    double totalDailyCost = 0.0;
    int totalDailyUnits = 0;
    for (var s in activeSubs.where((s) => s.status == 'ACTIVE')) {
      final pPrice = s.displayPrice > 0 ? s.displayPrice : (s.productDetail?.pricePerUnit ?? 0.0);
      totalDailyCost += (pPrice * s.quantity);
      totalDailyUnits += s.quantity;
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          color: UiTone.primary,
          onRefresh: () => widget.state.reloadAllData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Title ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTelugu ? 'డైలీ సభ్యత్వాలు' : 'Daily Subscriptions',
                          style: UiText.h1.copyWith(fontSize: 22, color: UiTone.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTelugu ? 'ప్రతిరోజూ ఉదయం 06:00 AM డోర్‌స్టెప్ డెలివరీ' : 'Guaranteed 06:00 AM morning doorstep deliveries',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: UiTone.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🥛', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            'Pamba Daily',
                            style: TextStyle(color: UiTone.primary, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 1. Header Summary Card with Live Dispatch Countdown ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: UiGradient.primary,
                    borderRadius: BorderRadius.circular(UiRadius.xl),
                    boxShadow: UiShadow.elevated,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTelugu ? 'డైలీ రికరింగ్ సబ్‌స్క్రిప్షన్‌లు' : 'DAILY RECURRING SUBSCRIPTIONS',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isTelugu ? 'ఉదయం డోర్‌స్టెప్ డ్రాప్‌లు 🥛' : 'Morning Doorstep Drops 🥛',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: UiTone.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(UiRadius.sm),
                              border: Border.all(color: UiTone.secondary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⚡ ', style: TextStyle(fontSize: 10)),
                                Text(
                                  isTelugu ? 'తదుపరి: $_countdownStr' : 'Next in $_countdownStr',
                                  style: TextStyle(
                                    color: UiTone.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryStat(
                              isTelugu ? 'యాక్టివ్ ప్లాన్‌లు' : 'Active Plans',
                              '${activeSubs.length}',
                              Icons.calendar_today_rounded,
                            ),
                          ),
                          Container(width: 1, height: 32, color: Colors.white24),
                          Expanded(
                            child: _summaryStat(
                              isTelugu ? 'డైలీ వాల్యూమ్' : 'Daily Volume',
                              '$totalDailyUnits Units',
                              Icons.local_shipping_outlined,
                            ),
                          ),
                          Container(width: 1, height: 32, color: Colors.white24),
                          Expanded(
                            child: _summaryStat(
                              isTelugu ? 'డైలీ డెబిట్' : 'Daily Spend',
                              UiFormat.price(totalDailyCost),
                              Icons.currency_rupee_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),



                // ── 3. Active vs Cancelled Segmented Filter ──
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                    border: Border.all(color: UiTone.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _segmentButton(
                          0,
                          isTelugu ? 'యాక్టివ్ సభ్యత్వాలు (${activeSubs.length})' : 'Active Subscriptions (${activeSubs.length})',
                        ),
                      ),
                      Expanded(
                        child: _segmentButton(
                          1,
                          isTelugu ? 'రద్దు చేయబడినవి (${cancelledSubs.length})' : 'Cancelled (${cancelledSubs.length})',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (displayedSubs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('🥛', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          isTelugu ? 'సభ్యత్వాలు లేవు' : 'No Subscriptions Found',
                          style: UiText.h2.copyWith(fontSize: 16, color: UiTone.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isTelugu
                              ? 'మీ ఇష్టమైన పాలు మరియు డైరీ ఉత్పత్తులను ప్రతిరోజూ పొందడానికి సబ్‌స్క్రయిబ్ చేసుకోండి.'
                              : 'Subscribe to farm-fresh milk and dairy for guaranteed 06:00 AM delivery.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => widget.state.setTab(0),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                          label: Text(isTelugu ? 'సబ్‌స్క్రిప్షన్‌ను ప్రారంభించండి' : 'Start a Subscription'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UiTone.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...displayedSubs.map((sub) => _buildSubscriptionCard(context, sub, isTelugu)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _segmentButton(int index, String label) {
    final isSelected = _selectedSegment == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSegment = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(UiRadius.md),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionModel sub, bool isTelugu) {
    final prod = sub.productDetail;
    final pName = prod?.name ?? 'Farm Fresh Milk';
    final isPaused = sub.status == 'PAUSED';
    final isCancelled = sub.status == 'CANCELLED';

    return Container(
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
                      widget.state.translateProduct(pName),
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
              if (!isCancelled) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: isTelugu ? 'సభ్యత్వాన్ని తొలగించండి' : 'Delete Subscription',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () => _confirmDeleteSubscription(context, sub, isTelugu),
                ),
              ],
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
          if (!isCancelled) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await widget.state.toggleSubscriptionStatus(sub.id);
                    },
                    icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 16),
                    label: Text(
                      isPaused
                          ? (isTelugu ? 'పునఃప్రారంభించండి' : 'Resume Plan ▶')
                          : (isTelugu ? 'విరామం ఇవ్వండి' : 'Pause Plan ⏸'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isPaused ? UiTone.primary : Colors.orange.shade800,
                      side: BorderSide(color: isPaused ? UiTone.primary : Colors.orange.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteSubscription(context, sub, isTelugu),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                    label: Text(
                      isTelugu ? 'తొలగించు' : 'Delete',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      backgroundColor: Colors.red.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final ok = await widget.state.reactivateSubscription(sub.id);
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
  }

  Future<void> _confirmDeleteSubscription(BuildContext context, SubscriptionModel sub, bool isTelugu) async {
    HapticFeedback.mediumImpact();
    final pName = sub.productDetail?.name ?? 'Subscription';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                isTelugu ? 'సభ్యత్వాన్ని తొలగించాలా?' : 'Delete Subscription?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isTelugu
                    ? '${widget.state.translateProduct(pName)} సభ్యత్వాన్ని ఖచ్చితంగా తొలగించాలనుకుంటున్నారా?'
                    : 'Are you sure you want to delete your recurring subscription for ${widget.state.translateProduct(pName)}?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTelugu
                            ? 'రేపటి నుండి ఉదయం డెలివరీలు మరియు రోజువారీ ఛార్జీలు వెంటనే ఆగిపోతాయి.'
                            : 'Morning doorstep deliveries and daily charges will be stopped immediately.',
                        style: TextStyle(color: Colors.brown.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isTelugu ? 'ఉంచండి' : 'Keep My Plan',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isTelugu ? 'అవును, తొలగించు' : 'Yes, Cancel Subscription',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      final ok = await widget.state.cancelSubscription(sub.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? Colors.red.shade700 : Colors.orange.shade800,
            content: Text(ok
                ? (isTelugu ? 'సభ్యత్వం విజయవంతంగా తొలగించబడింది.' : 'Subscription deleted successfully.')
                : (isTelugu ? 'లోపం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.' : 'Failed to delete subscription.')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
