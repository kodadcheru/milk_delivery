import 'package:flutter/material.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

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
    final pName = sub.productDetail != null
        ? sub.productDetail!.localizedName(state.currentLanguage)
        : state.translateProduct('Daily Farm Fresh Milk');
    final pPrice = sub.displayPrice;

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
                        Icon(Icons.autorenew_rounded, color: UiTone.primary, size: 16),
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
                      color: UiTone.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: const Text(
                      'Next: Tomorrow 6:00 AM',
                      style: TextStyle(
                        color: UiTone.primary,
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
                      color: UiTone.surfaceMuted,
                      borderRadius: BorderRadius.circular(UiRadius.sm),
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
                          '${sub.packSize} • ₹${(pPrice * sub.quantity).toStringAsFixed(0)} / day • ${sub.scheduleType}',
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
              const SizedBox(height: 10),
              const Divider(height: 1, color: UiTone.surfaceBorder),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await state.toggleSubscriptionStatus(sub.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: UiTone.primary,
                              content: Text(sub.status == 'ACTIVE' ? '⏸️ Tomorrow\'s delivery paused!' : '▶️ Subscription resumed!'),
                            ),
                          );
                        }
                      },
                      icon: Icon(sub.status == 'ACTIVE' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 14),
                      label: Text(sub.status == 'ACTIVE' ? 'Pause Tomorrow' : 'Resume Delivery', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        foregroundColor: sub.status == 'ACTIVE' ? UiTone.warning : UiTone.primary,
                        side: BorderSide(color: sub.status == 'ACTIVE' ? UiTone.warning.withValues(alpha: 0.5) : UiTone.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => state.setTab(1),
                      icon: const Icon(Icons.calendar_month_rounded, size: 14),
                      label: const Text('Visual Calendar 📅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        backgroundColor: UiTone.primary,
                        foregroundColor: UiTone.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
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
