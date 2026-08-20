import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class HomeWalletVacationCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onRechargeTap;

  const HomeWalletVacationCard({
    super.key,
    required this.state,
    required this.onRechargeTap,
  });

  @override
  Widget build(BuildContext context) {
    final bal = state.currentUser?.walletBalance ?? 500.00;
    int estDays = (bal / 72.0).floor();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: UiTone.ink,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UiTone.primary, UiTone.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiShadow.card,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PREPAID MILK WALLET',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AUTO-DEBIT 🟢',
                              style: TextStyle(
                                color: UiTone.surface,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${bal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: UiTone.surface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        estDays > 0
                            ? '✨ Covers approx. $estDays days of morning deliveries'
                            : '⚠️ Low balance! Recharge for uninterrupted milk',
                        style: TextStyle(
                          color: UiTone.surface.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onRechargeTap,
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: UiTone.surface,
                      borderRadius: BorderRadius.circular(UiRadius.sm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: UiTone.primary),
                        SizedBox(width: 4),
                        Text(
                          'Recharge',
                          style: TextStyle(
                            color: UiTone.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subscription Status Strip
          if (state.subscriptions.any((s) => s.status == 'ACTIVE')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: UiTone.surface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: UiTone.surface.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isVacationMode ? Icons.beach_access_rounded : Icons.schedule_rounded,
                    color: state.isVacationMode ? Colors.amber : UiTone.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.isVacationMode
                          ? '⏸ Vacation Pause Active (Deliveries on hold)'
                          : '🟢 Morning Deliveries Active: Tomorrow 06:00 AM',
                      style: const TextStyle(
                        color: UiTone.surface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      state.toggleVacationMode(!state.isVacationMode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: !state.isVacationMode ? Colors.amber[900] : UiTone.primary,
                          content: Text(!state.isVacationMode ? '⏸ Vacation Mode turned ON.' : '▶️ Vacation Mode turned OFF.'),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      state.isVacationMode ? 'Resume' : 'Pause',
                      style: TextStyle(
                        color: state.isVacationMode ? Colors.amber : UiTone.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: UiTone.surface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: UiTone.surface.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.explore_outlined, color: UiTone.secondary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🌱 No Active Subscriptions • Subscribe below for 6 AM milk',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
