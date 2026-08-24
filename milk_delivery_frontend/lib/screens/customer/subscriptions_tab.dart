import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'package:flutter/services.dart';
import '../../providers/app_state.dart';
import '../../models/subscription_model.dart';
import '../../widgets/delivery_calendar_view.dart';
import '../../widgets/subscriptions/interactive_week_scrubber.dart';

class SubscriptionsTab extends StatefulWidget {
  final AppState state;

  const SubscriptionsTab({super.key, required this.state});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  late Timer _timer;
  String _countdownStr = '';
  DateTime _selectedDate = DateTime.now();

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
    final subs = widget.state.subscriptions;
    final activeSubs = subs.where((s) => s.status != 'CANCELLED').toList();
    final cancelledSubs = subs.where((s) => s.status == 'CANCELLED').toList();
    final activeDailySubs = activeSubs.where((s) => s.status == 'ACTIVE').toList();

    double totalDailyCost = 0.0;
    int totalDailyUnits = 0;
    for (var s in activeDailySubs) {
      final pPrice = s.productDetail?.pricePerUnit ?? 72.0;
      totalDailyCost += (pPrice * s.quantity);
      totalDailyUnits += s.quantity;
    }

    return SafeArea(
      child: RefreshIndicator(
        color: UiTone.primary,
        onRefresh: () => widget.state.reloadAllData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY RECURRING SUBSCRIPTIONS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Morning Doorstep Drops 🥛',
                            style: TextStyle(
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
                        child: Text(
                          '${activeDailySubs.length} Active',
                          style: const TextStyle(
                            color: UiTone.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Countdown Pill Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_on_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Next Dispatch: $_countdownStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: UiTone.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(UiRadius.xs),
                          ),
                          child: const Text(
                            '06:00 AM Slot',
                            style: TextStyle(color: UiTone.secondary, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCol('Daily Units', '$totalDailyUnits Items', Icons.local_drink_rounded),
                      Container(height: 24, width: 1, color: Colors.white12),
                      _buildStatCol('Daily Total', '₹${totalDailyCost.toStringAsFixed(0)} / day', Icons.currency_rupee_rounded),
                      Container(height: 24, width: 1, color: Colors.white12),
                      _buildStatCol('Auto-Debit', 'Enabled 🟢', Icons.verified_user_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 2. Next-Gen Interactive Weekly Delivery Scrubber ──
            InteractiveWeekScrubber(
              selectedDate: _selectedDate,
              onDateSelected: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 12),

            // ── 3. Interactive Visual Monthly Calendar ──
            DeliveryCalendarView(state: widget.state),
            const SizedBox(height: 16),

            // ── 4. Subscriptions List Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Subscriptions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: UiTone.ink),
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.state.setTab(0);
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: UiTone.primary),
                  label: const Text(
                    'Add Items +',
                    style: TextStyle(color: UiTone.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── 5. Segmented Switcher: Active vs Cancelled ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: UiTone.shellBackground,
                borderRadius: BorderRadius.circular(UiRadius.pill),
                border: Border.all(color: UiTone.surfaceBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedSegment = 0);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 0 ? UiTone.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Active (${activeSubs.length})',
                          style: TextStyle(
                            color: _selectedSegment == 0 ? Colors.white : UiTone.softText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedSegment = 1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 1 ? Colors.redAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancelled (${cancelledSubs.length})',
                          style: TextStyle(
                            color: _selectedSegment == 1 ? Colors.white : UiTone.softText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 6. Active Subscriptions Section ──
            if (_selectedSegment == 0) ...[
              if (activeSubs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: UiTone.surface,
                        borderRadius: BorderRadius.circular(UiRadius.lg),
                        border: Border.all(color: UiTone.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          const Text('🥛', style: TextStyle(fontSize: 44)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Active Subscriptions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Set up daily deliveries for Milk, Meat, Eggs, or Water Cans.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => widget.state.setTab(0),
                            child: const Text('Explore Catalog ✨'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeSubs.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final sub = activeSubs[idx];
                    final isPaused = sub.status == 'PAUSED';
                    final pName = sub.productDetail?.name ?? 'Daily Farm Milk';
                    final pPrice = sub.displayPrice;
                    final pUnitQty = sub.packSize;
                    final itemDailyCost = pPrice * sub.quantity;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Top Row
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isPaused ? Colors.amber.withValues(alpha: 0.12) : UiTone.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(UiRadius.md),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${sub.quantity}x $pUnitQty • ₹${itemDailyCost.toStringAsFixed(0)} / delivery',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Schedule: ${sub.scheduleType == 'DAILY' ? 'Every Day ☀️' : (sub.scheduleType == 'ALTERNATE' ? 'Alternate Days 🔄' : 'Weekdays 📅')}',
                                        style: TextStyle(
                                          color: isPaused ? Colors.amber[900] : UiTone.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPaused ? Colors.amber.withValues(alpha: 0.2) : UiTone.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(UiRadius.sm),
                                    border: Border.all(color: isPaused ? Colors.amber : UiTone.secondary),
                                  ),
                                  child: Text(
                                    isPaused ? '⏸ PAUSED' : '✓ ACTIVE',
                                    style: TextStyle(
                                      color: isPaused ? Colors.amber[900] : UiTone.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Delivery Address & Slot Strip
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: UiTone.successSoft,
                                borderRadius: BorderRadius.circular(UiRadius.sm),
                                border: Border.all(color: UiTone.successSoft),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 16, color: UiTone.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Deliver to: ${sub.deliveryAddress.isNotEmpty ? sub.deliveryAddress : (widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.ink),
                                        ),
                                        Text(
                                          'Slot: ${sub.deliverySlot} ${sub.deliveryInstructions.isNotEmpty ? "• ${sub.deliveryInstructions}" : ""}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: UiTone.success, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Delivery timing note
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: UiTone.shellBackground,
                                borderRadius: BorderRadius.circular(UiRadius.sm),
                                border: Border.all(color: UiTone.surfaceBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 13, color: isPaused ? Colors.grey : UiTone.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isPaused
                                          ? 'Deliveries paused for vacation. Resume anytime below.'
                                          : 'Next Delivery: Tomorrow (${sub.deliverySlot})',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isPaused ? Colors.grey[700] : UiTone.ink,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 4),

                            // Action Buttons Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Pause / Resume Button
                                TextButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final wasPaused = isPaused;
                                    final ok = await widget.state.toggleSubscriptionStatus(sub.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: wasPaused ? UiTone.primary : Colors.amber[900],
                                          content: Text(ok
                                              ? (wasPaused ? '▶️ Subscription Resumed! Daily morning drops active.' : '⏸ Subscription Paused!')
                                              : 'Failed to update subscription status'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 16),
                                  label: Text(isPaused ? 'Resume' : 'Pause'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isPaused ? UiTone.primary : Colors.amber[900],
                                    padding: EdgeInsets.zero,
                                  ),
                                ),

                                // Address & Slot Edit Button
                                TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showChangeAddressAndSlotModal(context, sub);
                                  },
                                  icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                                  label: const Text('Address / Slot'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: UiTone.primary,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),

                                // Modify Qty Button
                                TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showModifySubscriptionDialog(context, sub);
                                  },
                                  icon: const Icon(Icons.tune_rounded, size: 15),
                                  label: const Text('Modify'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: UiTone.ink,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),

                                // Vacation Dates Button
                                TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showVacationDatePicker(context, sub);
                                  },
                                  icon: const Icon(Icons.calendar_month_rounded, size: 15),
                                  label: const Text('Vacation'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: UiTone.primary,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),

                                // Cancel Button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  tooltip: 'Cancel Subscription',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _confirmCancelSubscription(context, sub);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ] else ...[
              // ── 7. Cancelled Subscriptions Section ──
              if (cancelledSubs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: UiTone.surface,
                        borderRadius: BorderRadius.circular(UiRadius.lg),
                        border: Border.all(color: UiTone.surfaceBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 44, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No Cancelled Subscriptions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Any subscriptions you cancel will appear here and can be restarted anytime.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cancelledSubs.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final sub = cancelledSubs[idx];
                    return _buildCancelledSubscriptionCard(context, sub);
                  },
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildCancelledSubscriptionCard(BuildContext context, SubscriptionModel sub) {
    final pName = sub.productDetail?.name ?? 'Daily Farm Milk';
    final pPrice = sub.displayPrice;
    final pUnitQty = sub.packSize;
    final itemDailyCost = pPrice * sub.quantity;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.lg),
        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(UiRadius.md),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sub.quantity}x $pUnitQty • ₹${itemDailyCost.toStringAsFixed(0)} / delivery',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Schedule: ${sub.scheduleType}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    '🛑 CANCELLED',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Notice Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recurring deliveries stopped. Past delivery history is saved in your account.',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Reactivate Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final ok = await widget.state.reactivateSubscription(sub.id);
                  if (context.mounted) {
                    if (ok) {
                      setState(() => _selectedSegment = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: UiTone.primary,
                          content: Text('✅ Subscription for $pName reactivated! Deliveries will resume tomorrow.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('Failed to reactivate subscription'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Restart Subscription 🔄'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
      ],
    );
  }

  void _showModifySubscriptionDialog(BuildContext context, SubscriptionModel sub) {
    int qty = sub.quantity;
    String sched = sub.scheduleType;

    showModalBottomSheet(
      context: context,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Modify Subscription 🛠️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Daily Quantity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      if (qty > 1) {
                        setDialogState(() => qty--);
                        HapticFeedback.lightImpact();
                      }
                    },
                  ),
                  Text('$qty Unit(s)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setDialogState(() => qty++);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Delivery Frequency:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['DAILY', 'ALTERNATE', 'CUSTOM'].map((s) {
                  final isSel = sched == s;
                  return ChoiceChip(
                    label: Text(s == 'DAILY' ? 'Every Day' : (s == 'ALTERNATE' ? 'Alternate' : 'Custom')),
                    selected: isSel,
                    onSelected: (val) {
                      if (val) setDialogState(() => sched = s);
                      HapticFeedback.lightImpact();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final ok = await widget.state.updateSubscriptionDetails(
                      sub.id,
                      quantity: qty,
                      scheduleType: sched,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: UiTone.primary,
                          content: Text(ok
                              ? '✅ Subscription updated: $qty Unit(s) • ${sched == 'DAILY' ? 'Every Day' : (sched == 'ALTERNATE' ? 'Alternate' : 'Custom')}!'
                              : 'Failed to update subscription'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Changes ✨'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVacationDatePicker(BuildContext context, SubscriptionModel sub) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: UiTone.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final start = picked.start.toString().split(' ')[0];
      final end = picked.end.toString().split(' ')[0];
      final ok = await widget.state.pauseSubscriptionWithDates(sub.id, start, end, 'Vacation');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.primary,
            content: Text(ok ? '🌴 Paused deliveries from $start to $end' : 'Failed to set vacation dates'),
          ),
        );
      }
    }
  }

  void _confirmCancelSubscription(BuildContext context, SubscriptionModel sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.lg)),
        title: const Text('Cancel Subscription?'),
        content: Text('Are you sure you want to cancel daily morning deliveries for ${sub.productDetail?.name ?? "this subscription"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Active')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.state.cancelSubscription(sub.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🛑 Subscription for ${sub.productDetail?.name ?? "item"} cancelled'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showChangeAddressAndSlotModal(BuildContext context, SubscriptionModel sub) {
    String selectedSlot = sub.deliverySlot.isNotEmpty ? sub.deliverySlot : '05:30 AM - 07:00 AM';
    final slotCtrl = TextEditingController(text: selectedSlot);
    final instructionsCtrl = TextEditingController(text: sub.deliveryInstructions);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final savedAddrs = widget.state.savedAddresses;
          final activeAddrStr = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_location_alt_rounded, color: UiTone.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Update Subscription Address & Slot',
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: UiTone.ink),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 16),

                // Delivery Time Slot Preference (Typable + Presets)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery Time Slot ⏰', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
                    Text('Typable & Customizable', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.teal[700])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    '05:30 AM - 07:00 AM',
                    '07:00 AM - 08:30 AM',
                    '05:00 PM - 07:00 PM',
                  ].map((slot) {
                    final isSel = selectedSlot == slot;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedSlot = slot;
                              slotCtrl.text = slot;
                            });
                          },
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSel ? UiTone.primary : UiTone.shellBackground,
                              borderRadius: BorderRadius.circular(UiRadius.sm),
                              border: Border.all(color: isSel ? UiTone.primary : UiTone.surfaceBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              slot,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : UiTone.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: slotCtrl,
                  onChanged: (val) {
                    setModalState(() {
                      selectedSlot = val.trim().isNotEmpty ? val.trim() : '05:30 AM - 07:00 AM';
                    });
                  },
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: UiTone.ink),
                  decoration: InputDecoration(
                    labelText: 'Or type custom slot (e.g. 06:00 AM - 07:30 AM)',
                    labelStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                    prefixIcon: const Icon(Icons.edit_calendar_rounded, size: 16, color: UiTone.primary),
                    filled: true,
                    fillColor: UiTone.shellBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm), borderSide: const BorderSide(color: UiTone.surfaceBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm), borderSide: const BorderSide(color: UiTone.surfaceBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm), borderSide: const BorderSide(color: UiTone.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),

                // Saved Address Selector
                const Text('Select Doorstep Delivery Address 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
                const SizedBox(height: 8),
                if (savedAddrs.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: savedAddrs.map((a) {
                        final isSel = widget.state.activeAddress?.id == a.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              widget.state.selectActiveAddress(a);
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(UiRadius.sm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? UiTone.primary : UiTone.surfaceMuted,
                                borderRadius: BorderRadius.circular(UiRadius.sm),
                                border: Border.all(color: isSel ? UiTone.primary : UiTone.surfaceBorder),
                              ),
                              child: Row(
                                children: [
                                  Text(a.icon, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Text(
                                    a.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : UiTone.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: UiTone.successSoft,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: UiTone.successSoft),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: UiTone.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeAddrStr,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: UiTone.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Instructions input
                TextField(
                  controller: instructionsCtrl,
                  decoration: InputDecoration(
                    labelText: 'Doorstep Instructions (Optional)',
                    hintText: 'e.g. Ring bell twice, leave in box',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 18),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final chosenAddr = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;
                      final chosenLat = widget.state.activeAddress?.latitude ?? widget.state.currentLat;
                      final chosenLon = widget.state.activeAddress?.longitude ?? widget.state.currentLon;

                      await widget.state.updateSubscriptionAddressAndSlot(
                        sub.id,
                        deliveryAddress: chosenAddr,
                        deliverySlot: selectedSlot,
                        deliveryLatitude: chosenLat,
                        deliveryLongitude: chosenLon,
                        deliveryInstructions: instructionsCtrl.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: UiTone.primary,
                            content: Text('✅ Subscription updated to deliver at $chosenAddr ($selectedSlot)!'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Save Address & Slot Preference 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
