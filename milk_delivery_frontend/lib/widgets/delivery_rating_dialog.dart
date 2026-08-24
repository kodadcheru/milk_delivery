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
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: UiTone.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Rate your delivery', style: UiText.h2),
          const SizedBox(height: 8),
          Text(
            '${widget.productName} by ${widget.driverName}\nDate: ${widget.deliveryDate}',
            textAlign: TextAlign.center,
            style: UiText.body.copyWith(color: UiTone.softText),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: index < _rating ? const Color(0xFFFFC107) : UiTone.softText,
                  size: 40,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _feedbackController,
            maxLines: 3,
            style: UiText.body,
            decoration: InputDecoration(
              hintText: 'Any feedback? (Optional)',
              hintStyle: UiText.body.copyWith(color: UiTone.softText),
              filled: true,
              fillColor: UiTone.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UiRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your feedback! ⭐'),
                    backgroundColor: Color(0xFF0D7C66),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip', style: TextStyle(color: UiTone.softText)),
          ),
        ],
      ),
    );
  }
}
