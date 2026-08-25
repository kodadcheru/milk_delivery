import 'package:flutter/material.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

class DeliveryRatingDialog extends StatefulWidget {
  final String productName;
  final String driverName;
  final String deliveryDate;

  const DeliveryRatingDialog({
    super.key,
    required this.productName,
    required this.driverName,
    required this.deliveryDate,
  });

  static void show(BuildContext context, {
    required String productName,
    required String driverName,
    required String deliveryDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DeliveryRatingDialog(
          productName: productName,
          driverName: driverName,
          deliveryDate: deliveryDate,
        ),
      ),
    );
  }

  @override
  State<DeliveryRatingDialog> createState() => _DeliveryRatingDialogState();
}

class _DeliveryRatingDialogState extends State<DeliveryRatingDialog> {
  int _rating = 5;
  final TextEditingController _feedbackController = TextEditingController();
  final Set<String> _selectedTags = {'❄️ Chilled at 4°C', '⏰ On-Time 5:30 AM'};

  static const List<String> _ratingTags = [
    '❄️ Chilled at 4°C',
    '⏰ On-Time 5:30 AM',
    '🤝 Polite Partner',
    '🚪 Neat Doorstep Drop',
    '🛡️ Tamper-Proof Seal',
    '🥛 Fresh & Thick',
  ];

  static const List<String> _ratingSentiments = [
    'Tap a star to rate',
    'Poor 😞',
    'Fair 😐',
    'Good 🙂',
    'Very Good 😊',
    'Superb Experience! 🌟',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentiment = _ratingSentiments[_rating.clamp(0, 5)];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: UiTone.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Center(
              child: Text('⭐', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Rate Your Delivery', style: UiText.h2.copyWith(fontSize: 19)),
          const SizedBox(height: 4),
          Text(
            '${widget.productName} • Delivered by ${widget.driverName}\nDate: ${widget.deliveryDate}',
            textAlign: TextAlign.center,
            style: UiText.caption.copyWith(color: UiTone.softText, height: 1.3),
          ),
          const SizedBox(height: 16),

          // 5-Star Interactive Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              final isFilled = star <= _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: isFilled ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                      size: 42,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            sentiment,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _rating >= 4 ? const Color(0xFF0D7C66) : const Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Feedback Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _ratingTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag, style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? UiTone.primary : UiTone.ink,
                )),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
                selectedColor: UiTone.primarySoft,
                backgroundColor: UiTone.surfaceMuted,
                checkmarkColor: UiTone.primary,
                side: BorderSide(
                  color: isSelected ? UiTone.primary : Colors.transparent,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Optional comment field
          TextField(
            controller: _feedbackController,
            maxLines: 2,
            style: UiText.body.copyWith(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Share any additional thoughts with our quality team...',
              hintStyle: UiText.caption.copyWith(color: UiTone.softText),
              filled: true,
              fillColor: UiTone.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UiRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Submit CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Rated $_rating★! Thank you for helping us keep milk pure.',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    backgroundColor: const Color(0xFF0D7C66),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                elevation: 0,
              ),
              child: const Text('Submit Review ⭐', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later', style: TextStyle(color: UiTone.softText, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
