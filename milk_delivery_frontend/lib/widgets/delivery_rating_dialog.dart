import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/app_state.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

class DeliveryRatingDialog extends StatefulWidget {
  final AppState state;
  final String productName;
  final String driverName;
  final String deliveryDate;
  final String? orderId;
  final int? taskId;
  final Function(int rating)? onRated;

  const DeliveryRatingDialog({
    super.key,
    required this.state,
    required this.productName,
    required this.driverName,
    required this.deliveryDate,
    this.orderId,
    this.taskId,
    this.onRated,
  });

  static void show(
    BuildContext context, {
    required AppState state,
    required String productName,
    required String driverName,
    required String deliveryDate,
    String? orderId,
    int? taskId,
    Function(int rating)? onRated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DeliveryRatingDialog(
          state: state,
          productName: productName,
          driverName: driverName,
          deliveryDate: deliveryDate,
          orderId: orderId,
          taskId: taskId,
          onRated: onRated,
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
  bool _isSubmitting = false;

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

  void _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    await widget.state.submitDeliveryRating(
      orderId: widget.orderId,
      taskId: widget.taskId,
      rating: _rating,
      feedback: _feedbackController.text,
      tags: _selectedTags.toList(),
    );

    widget.onRated?.call(_rating);

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rated $_rating★! Thank you for rating ${widget.driverName.isNotEmpty ? widget.driverName : "delivery"}.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D7C66),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
      ),
    );
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
              child: Text('🥛', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 12),
          Text('How was your delivery?', style: UiText.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '${widget.productName} • Delivered on ${widget.deliveryDate}',
            style: UiText.caption.copyWith(color: UiTone.softText),
            textAlign: TextAlign.center,
          ),
          if (widget.driverName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Delivered by ${widget.driverName}',
              style: UiText.caption.copyWith(color: const Color(0xFF0D7C66), fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 18),

          // 5-Star Interactive Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              final isFilled = star <= _rating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = star);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 38,
                    color: isFilled ? const Color(0xFFF59E0B) : UiTone.surfaceBorder,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            sentiment,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _rating >= 4 ? const Color(0xFF0D7C66) : const Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 16),

          // Delivery Compliment Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _ratingTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0D7C66) : UiTone.ink,
                  ),
                ),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
                selectedColor: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                backgroundColor: UiTone.surfaceMuted,
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder,
                  width: isSelected ? 1.4 : 1.0,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                showCheckmark: false,
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
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Review ⭐', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
