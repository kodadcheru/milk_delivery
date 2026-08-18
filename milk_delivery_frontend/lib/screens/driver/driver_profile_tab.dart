import 'package:flutter/material.dart';
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
    final driverName = (driverUser != null && driverUser.firstName.isNotEmpty)
        ? '${driverUser.firstName} ${driverUser.lastName}'.trim()
        : 'Suresh Rao';
    final driverPhone = driverUser?.phone.isNotEmpty == true ? driverUser!.phone : '+91 9123456789';

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
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 40,
                        backgroundColor: Color(0xFF0D7C66),
                        child: Text('🛵', style: TextStyle(fontSize: 38)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  driverName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text(
                    '🛵 Verified Delivery Partner • ID #DRV-802',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
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
              _buildMetricCard('99.2%', 'On-Time Rate', Icons.timer_rounded, const Color(0xFF10B981)),
              const SizedBox(width: 10),
              _buildMetricCard('₹15,000', 'Monthly Salary', Icons.payments_rounded, const Color(0xFF0D7C66)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Shift & Route Information ──
          _buildSectionHeader('Route, Shift & Employment Details'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.payments_rounded, 'Monthly Salary', '₹15,000 / month (Paid directly by Hub Owner)'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.map_rounded, 'Assigned Route', 'Route #4 • Jubilee Hills Hub (Sector A & B)'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.schedule_rounded, 'Morning Shift Hours', '05:00 AM – 08:30 AM Daily'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.two_wheeler_rounded, 'Registered Vehicle', 'Honda Activa 6G (TS 09 AB 1234)'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.badge_rounded, 'Driving License', 'DL-042019003849 (Active)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Hub & Support Contact ──
          _buildSectionHeader('Dispatch Hub & Emergency Support'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.warehouse_rounded, 'Operating Hub', 'Jubilee Hills Central Depot #1'),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.support_agent_rounded, 'Dispatch Manager', 'Rajesh V. (+91 98888 77777)'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
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
