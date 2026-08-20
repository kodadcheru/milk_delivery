import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
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
    final activeHub = state.locationHubs.isNotEmpty ? state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Central Dairy Depot') : 'Central Dairy Depot';
    final hubAddress = activeHub != null ? (activeHub['address'] ?? 'Central Depot Operations') : 'Central Depot Operations';
    final fssai = activeHub != null ? (activeHub['fssai_license'] ?? '13621014000342') : '13621014000342';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UiTone.ink, Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(UiRadius.xl),
              boxShadow: UiShadow.card,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: UiTone.secondary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🏬', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 14),
                Text(
                  hubName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: UiTone.surface, fontSize: 18, fontWeight: FontWeight.bold),
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
                    color: UiTone.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: UiTone.secondary),
                  ),
                  child: Text(
                    '🛡️ Verified FSSAI License #$fssai',
                    style: const TextStyle(color: UiTone.secondary, fontWeight: FontWeight.bold, fontSize: 11),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.place_rounded, 'Depot Address', hubAddress),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.radar_rounded, 'Delivery Service Radius', '5.0 km Urban Micro-Cluster Coverage'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.schedule_rounded, 'Morning Dispatch Window', '04:30 AM (Cold Storage) – 07:00 AM Complete'),
                  const Divider(height: 20),
                  _buildDetailRow(
                    Icons.account_balance_rounded,
                    'Settlement Bank',
                    activeHub != null && activeHub['bank_account'] != null
                        ? '${activeHub['bank_account']}'
                        : 'Primary Settlement Bank • Daily Auto-Payout',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20), const SizedBox(height: 20),

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: UiTone.ink),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: UiTone.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
            ],
          ),
        ),
      ],
    );
  }
}
