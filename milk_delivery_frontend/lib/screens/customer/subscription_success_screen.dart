import 'package:flutter/material.dart';
import '../../providers/app_state.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  final String productName;
  final String packSize;
  final int quantity;
  final String schedule;
  final String slot;
  final String address;
  final double totalCost;
  final AppState state;

  const SubscriptionSuccessScreen({
    super.key,
    required this.productName,
    required this.packSize,
    required this.quantity,
    required this.schedule,
    required this.slot,
    required this.address,
    required this.totalCost,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D7C66),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 100),
                const SizedBox(height: 24),
                const Text(
                  'Subscription Confirmed!',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delivering to: $address\nSlot: $slot',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D7C66),
                  ),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
