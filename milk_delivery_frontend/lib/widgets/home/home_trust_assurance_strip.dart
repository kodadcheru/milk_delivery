import 'package:flutter/material.dart';

class HomeTrustAssuranceStrip extends StatelessWidget {
  const HomeTrustAssuranceStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTrustBadge('🌿 100% Vedic Pure', 'Zero Adulteration'),
            Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
            _buildTrustBadge('❄️ Chilled < 4°C', 'Direct Cold Chain'),
            Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
            _buildTrustBadge('⚡ 06:00 AM Slot', 'Doorstep Guaranteed'),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10.5,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
