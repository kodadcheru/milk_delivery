import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class CartEmptyState extends StatelessWidget {
  final VoidCallback onBrowse;

  const CartEmptyState({
    super.key,
    required this.onBrowse,
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
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: UiTone.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse our fresh dairy, eggs & groceries',
            style: TextStyle(
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
            child: const Text(
              'Start Shopping',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
