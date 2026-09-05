import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../theme/ui_tokens.dart';


class DeliveryCalendarView extends StatefulWidget {
  final AppState state;

  const DeliveryCalendarView({super.key, required this.state});

  @override
  State<DeliveryCalendarView> createState() => _DeliveryCalendarViewState();
}

class _DeliveryCalendarViewState extends State<DeliveryCalendarView> {
  final Set<int> _customPausedDays = {};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1 = Mon, 7 = Sun
    final monthName = _getMonthName(now.month);
    final hasActiveSub = widget.state.subscriptions.any((s) => s.status == 'ACTIVE');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
                      color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vacation Mode Banner
          InkWell(
            onTap: () async {
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
                
                // Iterate through days
                for (var i = 0; i <= picked.end.difference(picked.start).inDays; i++) {
                  final date = picked.start.add(Duration(days: i));
                  final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  
                  for (var s in activeSubs) {
                    await ApiService.pauseSubscription(s.id, dateStr, dateStr);
                  }
                  
                  if (date.month == now.month && date.year == now.year) {
                    setState(() {
                      _customPausedDays.add(date.day);
                    });
                  }
                }
                
                await widget.state.reloadAllData(silent: true);
                if (mounted) {
                  final startStr = '${picked.start.day} ${_getMonthName(picked.start.month)}';
                  final endStr = '${picked.end.day} ${_getMonthName(picked.end.month)}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 3),
                      backgroundColor: UiTone.warning,
                      content: Text('⏸️ Deliveries paused from $startStr to $endStr.', style: const TextStyle(color: Colors.white)),
                    ),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(UiRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: UiTone.warningSoft,
                borderRadius: BorderRadius.circular(UiRadius.md),
                border: Border.all(color: UiTone.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🏖️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Going on vacation?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.warning),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to pause deliveries for a date range',
                          style: TextStyle(fontSize: 11, color: UiTone.warning),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: UiTone.warning),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Month Header & Hold Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: UiTone.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: UiTone.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$monthName ${now.year} Schedule',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UiTone.ink),
                  ),
                ],
              ),
              Text(
                'Tap day to pause',
                style: TextStyle(color: Colors.grey[600], fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Weekday Labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
              _WeekdayLabel('S', isWeekend: true),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: UiTone.surfaceMuted),
          const SizedBox(height: 8),

          // Monthly Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (firstWeekday - 1) + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink(); // Empty offset
              }

              final day = index - (firstWeekday - 1) + 1;
              final isToday = day == now.day;
              final isPast = day < now.day;
              final isPaused = _customPausedDays.contains(day) || (widget.state.isVacationMode && widget.state.subscriptions.any((s) => s.status == 'PAUSED'));

              final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final tasksForDay = widget.state.deliveries.where((d) => d.deliveryDate.startsWith(dateStr)).toList();
              
              bool hasDelivered = false;
              bool hasFailed = false;
              bool hasPhoto = false;
              
              if (tasksForDay.isNotEmpty) {
                hasDelivered = tasksForDay.any((d) => d.status == 'DELIVERED');
                hasFailed = tasksForDay.any((d) => d.status == 'FAILED' || d.status == 'SKIPPED');
                hasPhoto = tasksForDay.any((d) => d.proofImageUrl.isNotEmpty);
              }

              Color bgColor = Colors.transparent;
              Color textColor = UiTone.ink;
              Color dotColor = hasActiveSub ? UiTone.secondary : Colors.grey[300]!;
              Widget? indicator;

              if (isToday) {
                bgColor = UiTone.primary.withValues(alpha: 0.12);
                textColor = UiTone.primary;
              }

              if (isPast) {
                textColor = Colors.grey[400]!;
                if (isPaused) {
                   indicator = Container(
                     width: 14,
                     height: 14,
                     decoration: const BoxDecoration(color: UiTone.warning, shape: BoxShape.circle),
                     child: const Icon(Icons.pause, size: 10, color: Colors.white),
                   );
                   bgColor = UiTone.warningSoft.withValues(alpha: 0.5);
                } else if (hasFailed) {
                   indicator = Container(
                     width: 14,
                     height: 14,
                     decoration: const BoxDecoration(color: UiTone.error, shape: BoxShape.circle),
                     child: const Icon(Icons.close, size: 10, color: Colors.white),
                   );
                } else {
                   // Defaults to green checkmark for past non-paused days
                   indicator = Stack(
                     clipBehavior: Clip.none,
                     children: [
                       Container(
                         width: 14,
                         height: 14,
                         decoration: const BoxDecoration(color: UiTone.secondary, shape: BoxShape.circle),
                         child: const Icon(Icons.check, size: 10, color: Colors.white),
                       ),
                       if (hasPhoto)
                         Positioned(
                           right: -4,
                           bottom: -4,
                           child: Container(
                             padding: const EdgeInsets.all(2),
                             decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                             child: const Icon(Icons.camera_alt, size: 8, color: UiTone.primary),
                           ),
                         ),
                     ],
                   );
                }
              } else if (isPaused) {
                indicator = Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: UiTone.warning,
                    shape: BoxShape.circle,
                  ),
                );
                bgColor = UiTone.warningSoft;
                textColor = UiTone.warning;
              } else {
                indicator = Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                );
              }

              return InkWell(
                onTap: isPast
                    ? null
                    : () async {
                        final activeSubs = widget.state.subscriptions.where((s) => s.status == 'ACTIVE').toList();
                        final pausedSubs = widget.state.subscriptions.where((s) => s.status == 'PAUSED').toList();
                        
                        if (isPaused) {
                          // Resume delivery for this day
                          for (var s in pausedSubs) {
                            await ApiService.resumeSubscription(s.id);
                          }
                          setState(() {
                            _customPausedDays.remove(day);
                          });
                          await widget.state.reloadAllData(silent: true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                backgroundColor: UiTone.primary,
                                content: Text('🟢 Delivery resumed for $day $monthName!'),
                              ),
                            );
                          }
                        } else {
                          // Pause delivery for this day
                          for (var s in activeSubs) {
                            await ApiService.pauseSubscription(s.id, dateStr, dateStr);
                          }
                          setState(() {
                            _customPausedDays.add(day);
                          });
                          await widget.state.reloadAllData(silent: true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                backgroundColor: UiTone.warning,
                                content: Text('⏸️ Delivery paused for $day $monthName.', style: const TextStyle(color: Colors.white)),
                              ),
                            );
                          }
                        }
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday ? Border.all(color: UiTone.primary, width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (indicator != null) indicator,
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: UiTone.surfaceMuted),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend(UiTone.secondary, 'Scheduled 06:00 AM'),
              _buildLegend(UiTone.warning, 'Paused / Hold'),
              _buildLegend(const Color(0xFF94A3B8), 'Delivered'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  final bool isWeekend;

  const _WeekdayLabel(this.text, {this.isWeekend = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isWeekend ? UiTone.error : const Color(0xFF64748B),
      ),
    );
  }
}
