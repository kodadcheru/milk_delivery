import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/app_state.dart';
import '../../models/subscription_model.dart';
import '../../widgets/delivery_calendar_view.dart';

class SubscriptionsTab extends StatefulWidget {
  final AppState state;

  const SubscriptionsTab({super.key, required this.state});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  late Timer _timer;
  String _countdownStr = '';

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
    final activeSubs = subs.where((s) => s.status == 'ACTIVE').toList();

    double totalDailyCost = 0.0;
    int totalDailyUnits = 0;
    for (var s in activeSubs) {
      final pPrice = s.productDetail?.pricePerUnit ?? 72.0;
      totalDailyCost += (pPrice * s.quantity);
      totalDailyUnits += s.quantity;
    }

    return RefreshIndicator(
      color: const Color(0xFF0D7C66),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D7C66).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Text(
                          '${activeSubs.length} Active',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.alarm_on_rounded, color: Colors.amber, size: 15),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Next Dispatch: $_countdownStr',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '06:00 AM Slot',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 18),

            // ── 2. Interactive Visual Monthly Calendar ──
            DeliveryCalendarView(state: widget.state),
            const SizedBox(height: 18),

            // ── 3. Subscriptions List ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Active Subscriptions (${subs.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.state.setTab(0);
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF0D7C66)),
                  label: const Text(
                    'Add Items +',
                    style: TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (subs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('🥛', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('No Active Subscriptions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                itemCount: subs.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final sub = subs[idx];
                  final isPaused = sub.status == 'PAUSED';
                  final pName = sub.productDetail?.name ?? 'Daily Farm Milk';
                  final pPrice = sub.productDetail?.pricePerUnit ?? 72.0;
                  final pUnitQty = sub.productDetail?.unitQuantity ?? '1 L';
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
                                  color: isPaused ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFF0D7C66).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
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
                                        color: isPaused ? Colors.amber[900] : const Color(0xFF0D7C66),
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
                                  color: isPaused ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isPaused ? Colors.amber : const Color(0xFF10B981)),
                                ),
                                child: Text(
                                  isPaused ? '⏸ PAUSED' : '✓ ACTIVE',
                                  style: TextStyle(
                                    color: isPaused ? Colors.amber[900] : const Color(0xFF0D7C66),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Delivery timing note
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: isPaused ? Colors.grey : const Color(0xFF0D7C66)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isPaused
                                        ? 'Deliveries paused for vacation. Resume anytime below.'
                                        : 'Next Delivery: Tomorrow morning at 06:00 AM',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isPaused ? Colors.grey[700] : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 6),

                          // Action Buttons Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Pause / Resume Button
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  widget.state.toggleSubscriptionStatus(sub.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isPaused ? '▶️ Subscription Resumed!' : '⏸ Subscription Paused!')),
                                  );
                                },
                                icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                                label: Text(isPaused ? 'Resume' : 'Pause'),
                                style: TextButton.styleFrom(
                                  foregroundColor: isPaused ? const Color(0xFF0D7C66) : Colors.amber[900],
                                  padding: EdgeInsets.zero,
                                ),
                              ),

                              // Modify Qty & Schedule Button
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showModifySubscriptionDialog(context, sub);
                                },
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('Modify'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: EdgeInsets.zero,
                                ),
                              ),

                              // Vacation Date Range Button
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showVacationDatePicker(context, sub);
                                },
                                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                                label: const Text('Vacation Dates'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D7C66),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  onPressed: () {
                    widget.state.updateSubscriptionQuantity(sub.id, qty);
                    widget.state.updateSubscriptionSchedule(sub.id, sched);
                    Navigator.pop(ctx);
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF0D7C66)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final start = picked.start.toString().split(' ')[0];
      final end = picked.end.toString().split(' ')[0];
      widget.state.pauseSubscriptionWithDates(sub.id, start, end, 'Vacation');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D7C66),
            content: Text('🌴 Paused deliveries from $start to $end'),
          ),
        );
      }
    }
  }

  void _confirmCancelSubscription(BuildContext context, SubscriptionModel sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Subscription?'),
        content: const Text('Are you sure you want to stop daily morning deliveries for this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Active')),
          ElevatedButton(
            onPressed: () {
              widget.state.cancelSubscription(sub.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }
}
