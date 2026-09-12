import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class CartEmptyState extends StatelessWidget {
  final VoidCallback onBrowse;
  final bool isTelugu;

  const CartEmptyState({
    super.key,
    required this.onBrowse,
    this.isTelugu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isTelugu ? 'మీ కార్ట్ ఖాళీగా ఉంది' : 'Your cart is empty',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: UiTone.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTelugu
                ? 'తాజా పాలు, గుడ్లు మరియు నిత్యావసరాలను ఎంచుకోండి'
                : 'Browse our fresh dairy, eggs & groceries',
            style: const TextStyle(
              fontSize: 14,
              color: UiTone.softText,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onBrowse,
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTone.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              isTelugu ? 'షాపింగ్ ప్రారంభించండి' : 'Start Shopping',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
