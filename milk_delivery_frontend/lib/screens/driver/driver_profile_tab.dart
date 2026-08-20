import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../providers/app_state.dart';

class DriverProfileTab extends StatelessWidget {
  final AppState state;
  final VoidCallback onLogout;

  const DriverProfileTab({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final driverUser = state.currentUser;
    final driverName = (driverUser != null && (driverUser.firstName.isNotEmpty || driverUser.username.isNotEmpty))
        ? '${driverUser.firstName} ${driverUser.lastName}'.trim()
        : (driverUser?.username.isNotEmpty == true ? driverUser!.username : 'Partner Delivery Boy');
    final driverPhone = driverUser?.phone.isNotEmpty == true ? driverUser!.phone : 'Verified Mobile Partner';
    final driverId = driverUser != null ? 'DRV-${driverUser.id}' : 'DRV-101';

    final activeHub = state.locationHubs.isNotEmpty ? state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';
    final managerPhone = activeHub != null && activeHub['manager_phone'] != null && activeHub['manager_phone'].toString().isNotEmpty
        ? 'Central Operations (${activeHub['manager_phone']})'
        : 'Central Operations (+91 8919548905)';

    final salaryText = (driverUser != null && driverUser.monthlySalary > 0)
        ? '₹${driverUser.monthlySalary.toStringAsFixed(0)}'
        : '₹15,000';
    final salaryDetailText = (driverUser != null && driverUser.monthlySalary > 0)
        ? '₹${driverUser.monthlySalary.toStringAsFixed(0)} / month (Paid directly by Hub Owner)'
        : '₹15,000 / month (Paid directly by Hub Owner)';

    final vehicleText = (driverUser != null && driverUser.vehicleNumber.isNotEmpty)
        ? driverUser.vehicleNumber
        : 'EV Scooter (Verified)';
    final licenseText = (driverUser != null && driverUser.drivingLicense.isNotEmpty)
        ? '${driverUser.drivingLicense} (Active)'
        : 'Commercial License (Active)';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Partner Profile Hero Card ──
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: UiTone.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 40,
                        backgroundColor: UiTone.primary,
                        child: Text('🛵', style: TextStyle(fontSize: 38)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: UiTone.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 14, color: UiTone.surface),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  driverName,
                  style: const TextStyle(color: UiTone.surface, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  driverPhone,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: UiTone.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: UiTone.secondary),
                  ),
                  child: Text(
                    '🛵 Verified Delivery Partner • ID #$driverId',
                    style: const TextStyle(color: UiTone.secondary, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Key Metrics Strip ──
          Row(
            children: [
              _buildMetricCard('4.9 ★', 'Customer Rating', Icons.star_rounded, Colors.amber),
              const SizedBox(width: 10),
              _buildMetricCard('99.2%', 'On-Time Rate', Icons.timer_rounded, UiTone.secondary),
              const SizedBox(width: 10),
              _buildMetricCard(salaryText, 'Monthly Salary', Icons.payments_rounded, UiTone.primary),
            ],
          ),
          const SizedBox(height: 20),

          // ── Shift & Route Information ──
          _buildSectionHeader('Route, Shift & Employment Details'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.payments_rounded, 'Monthly Salary', salaryDetailText),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.map_rounded, 'Assigned Route', 'Morning Route #1 • $hubName Zone'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.schedule_rounded, 'Morning Shift Hours', '05:00 AM – 08:30 AM Daily'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.two_wheeler_rounded, 'Registered Vehicle', vehicleText),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.badge_rounded, 'Driving License', licenseText),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Hub & Support Contact ──
          _buildSectionHeader('Dispatch Hub & Emergency Support'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.warehouse_rounded, 'Operating Hub', hubName),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.support_agent_rounded, 'Dispatch Operations', managerPhone),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Logout Action ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                state.setRole('CUSTOMER');
                onLogout();
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
              label: const Text('Log Out of Partner Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildMetricCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: UiTone.surface,
          borderRadius: BorderRadius.circular(UiRadius.md),
          boxShadow: UiShadow.card,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: UiTone.ink)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
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
