import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';

class RevenueChartWidget extends StatelessWidget {
  final List<MapEntry<String, double>> data;

  const RevenueChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final double totalWeekRevenue = data.fold(0.0, (sum, e) => sum + e.value);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: UiTone.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: UiTone.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('7-Day Revenue Velocity', style: UiText.h2.copyWith(fontSize: 14)),
                      Text(
                        'Completed morning & evening drops',
                        style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalWeekRevenue > 0
                      ? UiTone.primary.withValues(alpha: 0.12)
                      : UiTone.surfaceMuted,
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                  border: Border.all(
                    color: totalWeekRevenue > 0
                        ? UiTone.primary.withValues(alpha: 0.3)
                        : UiTone.surfaceBorder,
                  ),
                ),
                child: Text(
                  UiFormat.price(totalWeekRevenue),
                  style: UiText.caption.copyWith(
                    fontWeight: FontWeight.w900,
                    color: totalWeekRevenue > 0 ? UiTone.primary : UiTone.softText,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _BarChartPainter(data),
              size: const Size(double.infinity, 140),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  _BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final double maxBarHeight = size.height - 36;
    final double barWidth = (size.width / data.length) * 0.44;
    final double spacing = (size.width - (barWidth * data.length)) / (data.length + 1);

    // Draw baseline
    final Paint linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height - 20),
      Offset(size.width, size.height - 20),
      linePaint,
    );

    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    double startX = spacing;

    for (var entry in data) {
      final double barHeight = maxVal <= 0 ? 4 : ((entry.value / maxVal) * maxBarHeight).clamp(4.0, maxBarHeight);
      final Rect barRect = Rect.fromLTWH(
        startX,
        size.height - 20 - barHeight,
        barWidth,
        barHeight,
      );

      final hasRevenue = entry.value > 0;

      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hasRevenue
              ? [const Color(0xFF0D7C66), const Color(0xFF10B981)]
              : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
        ).createShader(barRect)
        ..style = PaintingStyle.fill;

      // Draw rounded bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(6)),
        barPaint,
      );

      // Draw value text if positive
      if (hasRevenue) {
        textPainter.text = TextSpan(
          text: entry.value >= 1000
              ? '₹${(entry.value / 1000).toStringAsFixed(1)}k'
              : '₹${entry.value.toInt()}',
          style: const TextStyle(
            color: Color(0xFF0D7C66),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(startX + (barWidth / 2) - (textPainter.width / 2), size.height - 20 - barHeight - 13),
        );
      }

      // Draw day label
      textPainter.text = TextSpan(
        text: entry.key,
        style: TextStyle(
          color: hasRevenue ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: hasRevenue ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(startX + (barWidth / 2) - (textPainter.width / 2), size.height - 15),
      );

      startX += barWidth + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
