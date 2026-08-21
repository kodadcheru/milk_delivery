import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../driver/morning_batch_screen.dart';

class AdminProfileTab extends StatelessWidget {
  final AppState state;
  final VoidCallback onLogout;

  const AdminProfileTab({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final adminUser = state.currentUser;
    final adminName = (adminUser != null && (adminUser.firstName.isNotEmpty || adminUser.username.isNotEmpty))
        ? '${adminUser.firstName} ${adminUser.lastName}'.trim()
        : 'Operations Administrator';
    final adminEmail = adminUser?.email.isNotEmpty == true ? adminUser!.email : 'ops.admin@milkdrop.in';
    final adminId = adminUser != null ? '${adminUser.id}' : '1';

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
                colors: [Color(0xFF022C22), Color(0xFF0F172A), Color(0xFF064E3B)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Color(0x25064E3B), blurRadius: 20, offset: Offset(0, 10)),
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
                      'Admin Profile',
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
                          Icon(Icons.shield_rounded, size: 13, color: Color(0xFF38BDF8)),
                          SizedBox(width: 5),
                          Text('Super Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
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
                            backgroundColor: Color(0xFF0F172A),
                            child: Text('🛡️', style: TextStyle(fontSize: 36)),
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

                // Admin Name row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      adminName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: Color(0xFF38BDF8)),
                  ],
                ),
                const SizedBox(height: 6),

                // Email & ID pill
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
                        const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          'Master Ops Admin • ID #$adminId • $adminEmail',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
                    _buildQuickStatCard('Active', 'Django REST', Icons.dns_rounded, const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                    const SizedBox(width: 10),
                    _buildQuickStatCard('Healthy', 'Postgres DB', Icons.storage_rounded, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                    const SizedBox(width: 10),
                    _buildQuickStatCard('Valid', 'JWT Session', Icons.lock_clock_rounded, const Color(0xFF0D7C66), const Color(0xFFE6F5F0)),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 1: System Health & Infrastructure
                _buildSectionHeader('Live Backend & Infrastructure'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.dns_rounded,
                    iconBg: const Color(0xFFE8F2FE),
                    iconFg: const Color(0xFF2563EB),
                    label: 'API Server: Django REST Framework',
                    subtitle: ApiService.baseUrl,
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.storage_rounded,
                    iconBg: const Color(0xFFE0F7F3),
                    iconFg: const Color(0xFF0D9488),
                    label: 'Database: PostgreSQL Cloud Cluster',
                    subtitle: 'Railway Cloud Deployment • Connected',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.key_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'JWT Session Token',
                    subtitle: ApiService.authToken != null ? 'Active & Validated' : 'Unauthenticated',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 2: Operations Web Consoles
                _buildSectionHeader('Operations Web Consoles & Shortcuts'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.dashboard_customize_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconFg: const Color(0xFF4F46E5),
                    label: 'Operations Web Console',
                    subtitle: 'Real-time order dispatch, wallet credits & broadcasts',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Console: ${ApiService.baseUrl.replaceAll('/api', '')}/admin-console/'))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.admin_panel_settings_rounded,
                    iconBg: const Color(0xFFE6F5F0),
                    iconFg: const Color(0xFF0D7C66),
                    label: 'Django Master Admin Portal',
                    subtitle: 'Database tables, user roles & server audit logs',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Master Admin: ${ApiService.baseUrl.replaceAll('/api', '')}/admin/'))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.inventory_2_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Morning Batch Packing System',
                    subtitle: 'Inspect daily crate breakdowns & hub packs',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MorningBatchScreen(state: state))),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 3: Communications & Security
                _buildSectionHeader('System Audit & Communications'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.campaign_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Broadcast Notification Engine',
                    subtitle: 'Targeted customer & driver push messaging',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast Engine active in Web Console'))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.security_rounded,
                    iconBg: const Color(0xFFF1F5F9),
                    iconFg: const Color(0xFF475569),
                    label: 'Security & Access Control',
                    subtitle: 'Multi-Role Access: Customer, Driver, Hub, Admin',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RBAC Security matrix is fully enforced'))),
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Action
                GestureDetector(
                  onTap: () => _confirmAdminLogout(context, state, onLogout),
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
                        Text('Log out of Admin Portal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Version Footer
                const Center(
                  child: Text(
                    'MilkDrop Master Admin Console v1.0.0 • Operations Command 🛡️',
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

  void _confirmAdminLogout(BuildContext context, AppState state, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Log Out Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of the Master Admin Operations portal?'),
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
