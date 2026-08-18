import 'package:flutter/material.dart';
import '../providers/app_state.dart';

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header & Hold Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D7C66), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$monthName ${now.year} Schedule',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
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
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
              final isPaused = widget.state.isVacationMode || _customPausedDays.contains(day);

              Color bgColor = Colors.transparent;
              Color textColor = const Color(0xFF0F172A);
              Color dotColor = hasActiveSub ? const Color(0xFF10B981) : Colors.grey[300]!;

              if (isToday) {
                bgColor = const Color(0xFF0D7C66).withValues(alpha: 0.12);
                textColor = const Color(0xFF0D7C66);
              }

              if (isPast) {
                textColor = Colors.grey[400]!;
                dotColor = const Color(0xFF94A3B8);
              } else if (isPaused) {
                dotColor = const Color(0xFFE11D48);
                bgColor = const Color(0xFFFFF1F2);
                textColor = const Color(0xFFE11D48);
              }

              return InkWell(
                onTap: isPast
                    ? null
                    : () {
                        setState(() {
                          if (_customPausedDays.contains(day)) {
                            _customPausedDays.remove(day);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF0D7C66),
                                content: Text('🟢 Delivery resumed for $day $monthName!'),
                              ),
                            );
                          } else {
                            _customPausedDays.add(day);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFFE11D48),
                                content: Text('⏸️ Delivery paused for $day $monthName.'),
                              ),
                            );
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday ? Border.all(color: const Color(0xFF0D7C66), width: 1.5) : null,
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
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend(const Color(0xFF10B981), 'Scheduled 06:00 AM'),
              _buildLegend(const Color(0xFFE11D48), 'Paused / Hold'),
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
        color: isWeekend ? const Color(0xFFE11D48) : const Color(0xFF64748B),
      ),
    );
  }
}
