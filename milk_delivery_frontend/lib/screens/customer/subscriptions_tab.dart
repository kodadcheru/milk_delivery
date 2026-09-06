import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/subscriptions/interactive_week_scrubber.dart';
import '../../widgets/subscriptions/subscription_card.dart';
import '../../widgets/delivery_calendar_view.dart';
import '../../services/api_service.dart';

class SubscriptionsTab extends StatefulWidget {
  final AppState state;

  const SubscriptionsTab({super.key, required this.state});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  int _selectedSegment = 0; // 0 = Active, 1 = Cancelled
  DateTime _selectedForecastDate = DateTime.now().add(const Duration(days: 1));
  bool _showFullCalendar = false;

  @override
  Widget build(BuildContext context) {
    final isTelugu = widget.state.isTelugu;
    final subs = widget.state.subscriptions;
    final activeSubs = subs.where((s) => s.status != 'CANCELLED').toList();
    final cancelledSubs = subs.where((s) => s.status == 'CANCELLED').toList();
    final displayedSubs = _selectedSegment == 0 ? activeSubs : cancelledSubs;

    double totalDailyCost = 0.0;
    int totalDailyUnits = 0;
    double totalMonthlySavings = 0.0;
    for (var s in activeSubs.where((s) => s.status == 'ACTIVE')) {
      final pPrice = s.displayPrice > 0 ? s.displayPrice : (s.productDetail?.pricePerUnit ?? 0.0);
      totalDailyCost += (pPrice * s.quantity);
      totalDailyUnits += s.quantity;
      
      final mrp = s.productDetail?.pricePerUnit ?? 0.0;
      final effective = s.effectiveUnitPrice > 0 ? s.effectiveUnitPrice : pPrice;
      if (mrp > effective) {
        totalMonthlySavings += (mrp - effective) * s.quantity * 30;
      }
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          color: UiTone.primary,
          onRefresh: () => widget.state.reloadAllData(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                sliver: SliverToBoxAdapter(
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
                                _DeliveryCountdownWidget(isTelugu: isTelugu),
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
                                Container(width: 1, height: 32, color: Colors.white24),
                                Expanded(
                                  child: _summaryStat(
                                    isTelugu ? 'సేవ్ చేయబడింది' : 'Saved',
                                    '₹${totalMonthlySavings.toInt()}',
                                    Icons.savings_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── 2. Next-Gen 7-Day Doorstep Forecast Scrubber ──
                      InteractiveWeekScrubber(
                        selectedDate: _selectedForecastDate,
                        onDateSelected: (date) {
                          setState(() => _selectedForecastDate = date);
                        },
                      ),
                      const SizedBox(height: 10),

                      // ── 2b. Day Schedule Summary & Vacation Mode Action Bar ──
                      _buildForecastActionCard(context, isTelugu, activeSubs),

                      if (_showFullCalendar) ...[
                        const SizedBox(height: 14),
                        DeliveryCalendarView(state: widget.state),
                      ],
                    ],
                  ),
                ),
              ),

              // ── 3. Active vs Cancelled Segmented Filter (Sticky) ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(UiRadius.lg),
                            border: Border.all(color: UiTone.surfaceBorder),
                          ),
                          child: Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                left: _selectedSegment == 0 ? 0 : (constraints.maxWidth - 8) / 2,
                                width: (constraints.maxWidth - 8) / 2,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: UiTone.primary,
                                    borderRadius: BorderRadius.circular(UiRadius.md - 2),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedSegment = 0);
                                      },
                                      child: Center(
                                        child: Text(
                                          isTelugu ? 'యాక్టివ్ సభ్యత్వాలు (${activeSubs.length})' : 'Active Subscriptions (${activeSubs.length})',
                                          style: TextStyle(
                                            color: _selectedSegment == 0 ? Colors.white : Colors.grey.shade700,
                                            fontSize: 12,
                                            fontWeight: _selectedSegment == 0 ? FontWeight.w800 : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedSegment = 1);
                                      },
                                      child: Center(
                                        child: Text(
                                          isTelugu ? 'రద్దు చేయబడినవి (${cancelledSubs.length})' : 'Cancelled (${cancelledSubs.length})',
                                          style: TextStyle(
                                            color: _selectedSegment == 1 ? Colors.white : Colors.grey.shade700,
                                            fontSize: 12,
                                            fontWeight: _selectedSegment == 1 ? FontWeight.w800 : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                ),
              ),

              // ── Subscriptions List ──
              if (displayedSubs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: UiTone.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.local_florist, size: 64, color: UiTone.primary.withValues(alpha: 0.2)),
                              const Text('🥛', style: TextStyle(fontSize: 48)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isTelugu ? 'మీ మొదటి సభ్యత్వాన్ని ప్రారంభించండి' : 'Start your first subscription',
                          style: UiText.h2.copyWith(fontSize: 20, color: UiTone.ink),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTelugu
                              ? 'ప్రతిరోజూ ఉదయం తాజా పాలు మీ గుమ్మానికి పంపిణీ చేయబడతాయి'
                              : 'Fresh milk delivered to your doorstep every morning',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => widget.state.setTab(0),
                          icon: const Icon(Icons.storefront_rounded, size: 20),
                          label: Text(
                            isTelugu ? 'ఉత్పత్తులను బ్రౌజ్ చేయండి' : 'Browse Products',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UiTone.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  sliver: SliverList.builder(
                    itemCount: displayedSubs.length,
                    itemBuilder: (context, index) {
                      return SubscriptionCard(
                        state: widget.state,
                        sub: displayedSubs[index],
                        isTelugu: isTelugu,
                        onDeleteRequested: _confirmDeleteSubscription,
                      );
                    },
                  ),
                ),
            ],
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

  Widget _buildForecastActionCard(BuildContext context, bool isTelugu, List<SubscriptionModel> activeSubs) {
    final now = DateTime.now();
    final isToday = _selectedForecastDate.year == now.year &&
        _selectedForecastDate.month == now.month &&
        _selectedForecastDate.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = _selectedForecastDate.year == tomorrow.year &&
        _selectedForecastDate.month == tomorrow.month &&
        _selectedForecastDate.day == tomorrow.day;

    String dayLabel;
    if (isToday) {
      dayLabel = isTelugu ? 'ఈరోజు డ్రాప్స్' : "Today's Scheduled Drops";
    } else if (isTomorrow) {
      dayLabel = isTelugu ? 'రేపటి డ్రాప్స్ (06:00 AM)' : "Tomorrow's Scheduled Drops (06:00 AM)";
    } else {
      dayLabel = isTelugu
          ? '${_selectedForecastDate.day}/${_selectedForecastDate.month} డ్రాప్స్'
          : "Drops on ${_selectedForecastDate.day} ${_getMonthName(_selectedForecastDate.month)}";
    }

    final scheduledSubs = activeSubs.where((s) {
      if (s.status != 'ACTIVE') return false;
      if (s.scheduleType == 'ALTERNATE_DAYS') {
        try {
          final diff = _selectedForecastDate.difference(DateTime.parse(s.startDate)).inDays;
          return diff >= 0 && diff % 2 == 0;
        } catch (_) {
          return true;
        }
      }
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🥛', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    dayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheduledSubs.isNotEmpty
                      ? UiTone.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scheduledSubs.isNotEmpty
                      ? '${scheduledSubs.length} ${scheduledSubs.length == 1 ? "Item" : "Items"}'
                      : 'No drops',
                  style: TextStyle(
                    color: scheduledSubs.isNotEmpty ? UiTone.primary : Colors.grey.shade600,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (scheduledSubs.isNotEmpty) ...[
            ...scheduledSubs.map((s) {
              final pName = s.productDetail?.name ?? 'Fresh Milk';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(s.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.state.translateProduct(pName)} (${s.packSize})',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'Qty: ${s.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: UiTone.primary),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            Text(
              isTelugu
                  ? 'ఈ రోజున డెలివరీలు ఏవీ లేవు.'
                  : 'No milk deliveries scheduled for this day (off-day or paused).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showVacationModePicker(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: UiTone.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: UiTone.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🏖️', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          isTelugu ? 'సెలవు మోడ్' : 'Vacation Mode',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showFullCalendar = !_showFullCalendar);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: UiTone.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: UiTone.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_showFullCalendar ? Icons.expand_less_rounded : Icons.calendar_month_rounded, size: 14, color: UiTone.primary),
                        const SizedBox(width: 6),
                        Text(
                          _showFullCalendar
                              ? (isTelugu ? 'క్యాలెండర్ దాచు' : 'Hide Calendar')
                              : (isTelugu ? 'నెల క్యాలెండర్' : 'Monthly View'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: UiTone.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVacationModePicker(BuildContext context) async {
    final now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: UiTone.primary,
              onPrimary: Colors.white,
              onSurface: UiTone.ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final activeSubs = widget.state.subscriptions.where((s) => s.status == 'ACTIVE').toList();
      for (var i = 0; i <= picked.end.difference(picked.start).inDays; i++) {
        final date = picked.start.add(Duration(days: i));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        for (var s in activeSubs) {
          await ApiService.pauseSubscription(s.id, dateStr, dateStr);
        }
      }
      await widget.state.reloadAllData(silent: true);
      if (context.mounted) {
        final startStr = '${picked.start.day} ${_getMonthName(picked.start.month)}';
        final endStr = '${picked.end.day} ${_getMonthName(picked.end.month)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.warning,
            content: Text('⏸️ Deliveries paused from $startStr to $endStr.'),
          ),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? names[month] : '';
  }

  Future<void> _confirmDeleteSubscription(BuildContext context, SubscriptionModel sub, bool isTelugu) async {
    HapticFeedback.mediumImpact();
    final pName = sub.productDetail?.name ?? 'Subscription';

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTelugu ? 'మీరు ఎందుకు రద్దు చేయాలనుకుంటున్నారు?' : 'Why are you cancelling?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ...['Too expensive', 'Quality issues', 'Going out of town', 'Switched to another brand', 'Other'].map(
                (r) => ListTile(
                  title: Text(r, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reason == null) return;
    if (!context.mounted) return;

    if (reason == 'Going out of town') {
      final pause = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isTelugu ? 'బదులుగా పాజ్ చేయాలా?' : 'Pause Instead?'),
          content: Text(isTelugu ? 'మీరు విరామం తీసుకోవచ్చు. మీ ప్రణాళికను అలాగే ఉంచండి.' : 'You can pause your subscription while you are away instead of deleting it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isTelugu ? 'తొలగించు' : 'No, Delete', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white, elevation: 0),
              child: Text(isTelugu ? 'పాజ్ చేయి' : 'Pause Plan'),
            ),
          ],
        ),
      );

      if (pause == true) {
        HapticFeedback.mediumImpact();
        await widget.state.toggleSubscriptionStatus(sub.id);
        return;
      } else if (pause == null) {
        return;
      }
    }

    if (!context.mounted) return;

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

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyFilterDelegate({required this.child});

  @override
  double get minExtent => 60.0;
  
  @override
  double get maxExtent => 60.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class _DeliveryCountdownWidget extends StatefulWidget {
  final bool isTelugu;
  const _DeliveryCountdownWidget({required this.isTelugu});

  @override
  State<_DeliveryCountdownWidget> createState() => _DeliveryCountdownWidgetState();
}

class _DeliveryCountdownWidgetState extends State<_DeliveryCountdownWidget> {
  late Timer _timer;
  String _countdownStr = '';

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCountdown());
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
    return Container(
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
            widget.isTelugu ? 'తదుపరి: $_countdownStr' : 'Next in $_countdownStr',
            style: const TextStyle(
              color: UiTone.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
