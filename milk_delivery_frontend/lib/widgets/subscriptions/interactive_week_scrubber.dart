import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class InteractiveWeekScrubber extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const InteractiveWeekScrubber({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<InteractiveWeekScrubber> createState() => _InteractiveWeekScrubberState();
}

class _InteractiveWeekScrubberState extends State<InteractiveWeekScrubber> {
  static const List<String> _weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🗓️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    '7-Day Doorstep Forecast',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryMint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Morning 05:30 AM',
                  style: TextStyle(color: AppTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final dayDate = startOfWeek.add(Duration(days: i));
              final isToday = dayDate.day == now.day && dayDate.month == now.month && dayDate.year == now.year;
              final isSelected = dayDate.day == widget.selectedDate.day &&
                  dayDate.month == widget.selectedDate.month &&
                  dayDate.year == widget.selectedDate.year;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    AppTheme.hapticLight();
                    widget.onDateSelected(dayDate);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryTeal
                          : (isToday ? AppTheme.primaryMint.withValues(alpha: 0.12) : AppTheme.bgSurfaceMuted),
                      borderRadius: BorderRadius.circular(14),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryMint, width: 1.2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekDays[i],
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white70
                                : (isToday ? AppTheme.primaryTeal : AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${dayDate.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? AppTheme.primaryTeal : AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryMint
                                : (dayDate.isBefore(now.subtract(const Duration(days: 1)))
                                    ? AppTheme.textMuted
                                    : AppTheme.primaryMint),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
