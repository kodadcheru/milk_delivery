import 'package:flutter/material.dart';
import '../../providers/app_state.dart';

class ProviderProfileTab extends StatelessWidget {
  final AppState state;
  final VoidCallback onLogout;

  const ProviderProfileTab({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Provider Hub Hero Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🏬', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Jubilee Hills Central Dairy Depot #1',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Licensed Farm Milk Provider & Micro-Fulfillment Center',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text(
                    '🛡️ Verified FSSAI License #13621014000342',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Hub Operating Specs ──
          _buildSectionHeader('Hub Operational Parameters'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.place_rounded, 'Depot Address', 'Plot 42, Road #36, Jubilee Hills, Hyderabad'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.radar_rounded, 'Delivery Service Radius', '5.0 km Urban Micro-Cluster Coverage'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.schedule_rounded, 'Morning Dispatch Window', '04:30 AM (Cold Storage) – 07:00 AM Complete'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.account_balance_rounded, 'Settlement Bank', 'HDFC Bank (A/C **4892) • Daily Auto-Payout'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Switch to Customer / Logout ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                state.setRole('CUSTOMER');
                onLogout();
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
              label: const Text('Log Out of Provider Portal', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0D7C66), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            ],
          ),
        ),
      ],
    );
  }
}
