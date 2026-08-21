import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import 'driver_route_map_screen.dart';
import 'morning_batch_screen.dart';

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
    final driverPhone = driverUser?.phone.isNotEmpty == true ? driverUser!.phone : '+91 8919548905';
    final driverId = driverUser != null ? 'DRV-${driverUser.id}' : 'DRV-101';

    final activeHub = state.locationHubs.isNotEmpty ? state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';
    final managerPhone = activeHub != null && activeHub['manager_phone'] != null && activeHub['manager_phone'].toString().isNotEmpty
        ? activeHub['manager_phone'].toString()
        : '+91 8919548905';

    final salaryText = (driverUser != null && driverUser.monthlySalary > 0)
        ? '₹${driverUser.monthlySalary.toStringAsFixed(0)}'
        : '₹15,000';

    final vehicleText = (driverUser != null && driverUser.vehicleNumber.isNotEmpty)
        ? driverUser.vehicleNumber
        : 'EV Scooter (Verified)';
    final licenseText = (driverUser != null && driverUser.drivingLicense.isNotEmpty)
        ? '${driverUser.drivingLicense} (Active)'
        : 'Commercial License (Active)';

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Part 1: Hero Header ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF0D7C66), Color(0xFF044E3A)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Color(0x250D7C66), blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    const Text(
                      'Driver Profile',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF34D399)),
                          SizedBox(width: 5),
                          Text('On Duty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Avatar stack
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.40)],
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x30000000), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: const Center(
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: Color(0xFF0D7C66),
                            child: Text('🛵', style: TextStyle(fontSize: 36)),
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.verified, size: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Name row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: Color(0xFF38BDF8)),
                  ],
                ),
                const SizedBox(height: 6),

                // Phone & ID pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          'Verified Delivery Partner • ID #$driverId',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Part 2: Scrollable Content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                // Quick Metrics Strip
                Row(
                  children: [
                    _buildQuickStatCard('4.9 ★', 'Driver Rating', Icons.star_rounded, const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
                    const SizedBox(width: 10),
                    _buildQuickStatCard('99.2%', 'On-Time Drops', Icons.timer_rounded, const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(salaryText, 'Monthly Salary', Icons.payments_rounded, const Color(0xFF0D7C66), const Color(0xFFE6F5F0)),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 1: Route & Shift Details
                _buildSectionHeader('Route & Shift Assignment'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.map_rounded,
                    iconBg: const Color(0xFFE8F2FE),
                    iconFg: const Color(0xFF2563EB),
                    label: 'Morning Route #1 • $hubName',
                    subtitle: 'Assigned Urban Zone & Street Path',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverRouteMapScreen(state: state, tasks: state.deliveries))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.schedule_rounded,
                    iconBg: const Color(0xFFE0F7F3),
                    iconFg: const Color(0xFF0D9488),
                    label: 'Shift: 05:00 AM – 08:30 AM Daily',
                    subtitle: 'Morning delivery window',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.two_wheeler_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Vehicle: $vehicleText',
                    subtitle: 'License: $licenseText',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 2: Operations & Hub Dispatch
                _buildSectionHeader('Operations & Hub Dispatch'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.warehouse_rounded,
                    iconBg: const Color(0xFFE6F5F0),
                    iconFg: const Color(0xFF0D7C66),
                    label: 'Dispatch Depot: $hubName',
                    subtitle: 'Central Hub Operations',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.inventory_2_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconFg: const Color(0xFF4F46E5),
                    label: 'Morning Batch Packing Crates',
                    subtitle: 'View crate breakdown & pack counts',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MorningBatchScreen(state: state))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.support_agent_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconFg: const Color(0xFFEF4444),
                    label: 'Hub Manager Contact',
                    subtitle: managerPhone,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling Hub Manager: $managerPhone'))),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 3: Safety & Partner Support
                _buildSectionHeader('Support & Partner Safety'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.headset_mic_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Emergency Delivery Support',
                    subtitle: '24x7 Driver helpline & assistance',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to Emergency Partner Support...'))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.shield_outlined,
                    iconBg: const Color(0xFFF1F5F9),
                    iconFg: const Color(0xFF475569),
                    label: 'Driver Safety Guidelines & Terms',
                    subtitle: 'Zero spillage & cold chain standards',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safety Guidelines displayed'))),
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Action
                GestureDetector(
                  onTap: () => _confirmDriverLogout(context, state, onLogout),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x28E11D48), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Log out of Partner Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Version Footer
                const Center(
                  child: Text(
                    'MilkDrop Express Partner v1.0.0 • Dedicated Delivery Heroes 🛵',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(String value, String label, IconData icon, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: -0.2),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE8), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x081A2B23), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x051A2B23), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 68);
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1A2B23))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC0C8C4)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDriverLogout(BuildContext context, AppState state, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Log Out Partner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your driver partner account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              state.setRole('CUSTOMER');
              Navigator.pop(ctx);
              onLogout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
