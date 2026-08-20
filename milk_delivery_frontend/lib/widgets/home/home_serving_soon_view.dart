import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class HomeServingSoonView extends StatelessWidget {
  final AppState state;
  final VoidCallback onSelectZoneTap;

  const HomeServingSoonView({
    super.key,
    required this.state,
    required this.onSelectZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final areaName = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Text('🚚', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          const Text(
            'We are Serving Soon in Your Area!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: UiTone.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We haven\'t expanded doorstep 06:00 AM delivery to "$areaName" yet. Our active hubs currently serve a 5.0 km radius.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 20),

          // Operational Hub Badges
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: UiTone.shellBackground,
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: UiTone.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📍 Active Operational Delivery Hubs:',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                if (state.locationHubs.isNotEmpty)
                  ...state.locationHubs.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: UiTone.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${h['name']} (${(h['coverage_radius_km'] as num?)?.toDouble() ?? 5.0} km Radius)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: UiTone.softText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: UiTone.secondary),
                      SizedBox(width: 6),
                      Text(
                        'Central Operations Hub (5.0 km Radius)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: UiTone.softText),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          InkWell(
            key: const ValueKey('select_zone_btn'),
            onTap: onSelectZoneTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: UiTone.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_rounded, size: 18, color: UiTone.surface),
                  SizedBox(width: 8),
                  Text(
                    '📍 Select Active Service Zone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.surface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            key: const ValueKey('notify_me_btn'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: UiTone.primary,
                  content: Text('🔔 Thanks! We recorded your pincode interest and will notify you when MilkDrop launches here.'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: UiTone.primary),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active_rounded, size: 16, color: UiTone.primary),
                  SizedBox(width: 8),
                  Text(
                    'Notify Me When MilkDrop Launches',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: UiTone.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
