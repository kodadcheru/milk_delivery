import 'package:flutter/material.dart';

class HomeQuickChips extends StatelessWidget {
  const HomeQuickChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildChip(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D7C66), Color(0xFF14A38B)],
              ),
              icon: Icons.local_offer_rounded,
              label: '₹72/day\nmilk plan',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildChip(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
              ),
              icon: Icons.bolt_rounded,
              label: '06:00 AM\ndoorstep drop',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildChip(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
              ),
              icon: Icons.verified_user_rounded,
              label: '100% Vedic\npure milk',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required LinearGradient gradient,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
