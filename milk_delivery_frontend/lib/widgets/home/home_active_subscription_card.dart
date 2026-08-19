import 'package:flutter/material.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';

class HomeActiveSubscriptionCard extends StatelessWidget {
  final AppState state;
  final SubscriptionModel sub;

  const HomeActiveSubscriptionCard({
    super.key,
    required this.state,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final pName = sub.productDetail?.name ?? 'Daily Farm Fresh Milk';
    final pPrice = sub.productDetail?.pricePerUnit ?? 72.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.autorenew_rounded, color: Color(0xFF0D7C66), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Active Morning Subscription',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Next: Tomorrow 6:00 AM',
                      style: TextStyle(
                        color: Color(0xFF0D7C66),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(sub.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 1),
                        Text(
                          '${sub.quantity} Unit(s) • ₹${(pPrice * sub.quantity).toStringAsFixed(0)} / day • ${sub.scheduleType}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => state.setTab(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
