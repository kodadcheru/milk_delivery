import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class HomeTopUpDialog {
  static void show(BuildContext context, AppState state) {
    final amtController = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.lg)),
        title: const Row(
          children: [
            Text('⚡', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Quick Wallet Top-Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter amount to recharge for daily deliveries:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Amount (INR)',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('+ ₹300', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => amtController.text = '300',
                ),
                ActionChip(
                  label: const Text('+ ₹500', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => amtController.text = '500',
                ),
                ActionChip(
                  label: const Text('+ ₹1000', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => amtController.text = '1000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amtController.text.trim()) ?? 500.0;
              state.topUpWallet(amt, 'UPI Express Top-Up');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: UiTone.primary,
                  content: Text('⚡ Successfully recharged ₹${amt.toStringAsFixed(0)} to your Milk Wallet!'),
                ),
              );
            },
            child: const Text('Pay & Top-Up ⚡'),
          ),
        ],
      ),
    );
  }
}
