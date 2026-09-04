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
                Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final isEvening = slot.toUpperCase().contains('PM') || slot.contains('17:') || slot.contains('18:') || slot.contains('19:');
                    final startsToday = isEvening && (now.hour < 12);
                    final firstDropInfo = startsToday
                        ? (state.isTelugu ? '⚡ మొదటి డెలివరీ: ఈరోజు సాయంత్రం' : '⚡ First Delivery: Today Evening')
                        : (state.isTelugu
                            ? (isEvening ? '🗓️ మొదటి డెలివరీ: రేపు సాయంత్రం' : '🗓️ మొదటి డెలివరీ: రేపు ఉదయం')
                            : (isEvening ? '🗓️ First Delivery: Tomorrow Evening' : '🗓️ First Delivery: Tomorrow Morning'));

                    return Column(
                      children: [
                        Text(
                          'Delivering to: $address\nSlot: $slot',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            firstDropInfo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 36),
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
