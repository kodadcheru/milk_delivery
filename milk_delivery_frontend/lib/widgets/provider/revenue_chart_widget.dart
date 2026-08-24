import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';

class RevenueChartWidget extends StatelessWidget {
  final List<MapEntry<String, double>> data;

  const RevenueChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Light green bg
        borderRadius: BorderRadius.circular(UiRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-Day Revenue Trend', style: UiText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _BarChartPainter(data),
              size: const Size(double.infinity, 150),
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
    final double maxBarHeight = size.height - 30; // Leave space for labels
    final double barWidth = (size.width / data.length) * 0.5;
    final double spacing = (size.width - (barWidth * data.length)) / (data.length + 1);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4CAF50) // Green
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    double startX = spacing;

    for (var entry in data) {
      final double barHeight = maxVal == 0 ? 0 : (entry.value / maxVal) * maxBarHeight;
      final Rect barRect = Rect.fromLTWH(
        startX,
        size.height - 20 - barHeight,
        barWidth,
        barHeight,
      );

      // Draw bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        barPaint,
      );

      // Draw value text
      textPainter.text = TextSpan(
        text: entry.value.toInt().toString(),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(startX + (barWidth / 2) - (textPainter.width / 2), size.height - 20 - barHeight - 14),
      );

      // Draw day label
      textPainter.text = TextSpan(
        text: entry.key,
        style: const TextStyle(color: Colors.black87, fontSize: 10),
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
