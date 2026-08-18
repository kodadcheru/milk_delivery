import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/subscription_model.dart';
import '../../widgets/delivery_calendar_view.dart';

class SubscriptionsTab extends StatelessWidget {
  final AppState state;

  const SubscriptionsTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final subs = state.subscriptions;
    final activeSubs = subs.where((s) => s.status == 'ACTIVE').toList();

    double totalDailyCost = 0.0;
    int totalDailyUnits = 0;
    for (var s in activeSubs) {
      final pPrice = s.productDetail?.pricePerUnit ?? 72.0;
      totalDailyCost += (pPrice * s.quantity);
      totalDailyUnits += s.quantity;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Summary Card ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
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
                        Text('DAILY SUBSCRIPTION OVERVIEW', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        SizedBox(height: 4),
                        Text('Morning Doorstep Schedule', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
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
                    _buildStatCol('Delivery Slot', '06:00 AM', Icons.alarm_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Interactive Visual Monthly Calendar ──
          DeliveryCalendarView(state: state),
          const SizedBox(height: 18),

          // ── Subscriptions List ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Active Subscriptions (${subs.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              TextButton.icon(
                onPressed: () => state.setTab(0),
                icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF0D7C66)),
                label: const Text('Add Items +', style: TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 12)),
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
                      const Text('Set up daily deliveries for Milk, Meat, Eggs, or Water Cans.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => state.setTab(0),
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isPaused ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFF0D7C66).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(sub.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${sub.quantity}x $pUnitQty • ₹${itemDailyCost.toStringAsFixed(0)} / delivery',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Schedule: ${sub.scheduleType == 'DAILY' ? 'Every Day' : (sub.scheduleType == 'ALTERNATE' ? 'Alternate Days' : 'Weekdays')}',
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
                                state.toggleSubscriptionStatus(sub.id);
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
                              onPressed: () => _showModifySubscriptionDialog(context, sub),
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('Modify'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                padding: EdgeInsets.zero,
                              ),
                            ),

                            // Vacation Date Range Button
                            TextButton.icon(
                              onPressed: () => _showVacationDatePicker(context, sub),
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
                              onPressed: () => _confirmCancelSubscription(context, sub),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }

  void _showModifySubscriptionDialog(BuildContext context, SubscriptionModel sub) {
    int qty = sub.quantity;
    String schedule = sub.scheduleType;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modify ${sub.productDetail?.name ?? "Subscription"}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Quantity Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily Quantity:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: qty > 1 ? () => setModalState(() => qty--) : null,
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0D7C66)),
                      ),
                      Text('$qty Units', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setModalState(() => qty++),
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0D7C66)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Schedule Selector
              const Text('Delivery Schedule:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildScheduleChoice('DAILY', 'Everyday', schedule, (val) => setModalState(() => schedule = val)),
                  const SizedBox(width: 8),
                  _buildScheduleChoice('ALTERNATE', 'Alternate', schedule, (val) => setModalState(() => schedule = val)),
                  const SizedBox(width: 8),
                  _buildScheduleChoice('WEEKDAYS', 'Weekdays', schedule, (val) => setModalState(() => schedule = val)),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    state.updateSubscriptionQuantity(sub.id, qty);
                    state.updateSubscriptionSchedule(sub.id, schedule);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updated subscription: $qty units ($schedule)!')),
                    );
                  },
                  child: const Text('Save Modifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleChoice(String val, String label, String selectedVal, Function(String) onSelect) {
    final isSelected = selectedVal == val;
    return Expanded(
      child: ChoiceChip(
        label: FittedBox(child: Text(label)),
        selected: isSelected,
        selectedColor: const Color(0xFF0D7C66),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        onSelected: (sel) {
          if (sel) onSelect(val);
        },
      ),
    );
  }

  void _showVacationDatePicker(BuildContext context, SubscriptionModel sub) async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'SELECT VACATION PAUSE DATES',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D7C66),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      final startStr = range.start.toString().split(' ')[0];
      final endStr = range.end.toString().split(' ')[0];
      await state.pauseSubscriptionWithDates(sub.id, startStr, endStr, 'Out of town vacation');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✈️ Vacation pause active from $startStr to $endStr! Deliveries safely paused.'),
          ),
        );
      }
    }
  }

  void _confirmCancelSubscription(BuildContext context, SubscriptionModel sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Subscription?'),
        content: Text('Are you sure you want to cancel your daily delivery of "${sub.productDetail?.name}"? You can re-subscribe anytime from the catalog.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Active')),
          ElevatedButton(
            onPressed: () {
              state.cancelSubscription(sub.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription cancelled.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }
}
