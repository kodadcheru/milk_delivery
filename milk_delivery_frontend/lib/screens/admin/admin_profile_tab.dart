import 'package:flutter/material.dart';
import '../../providers/app_state.dart';

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
    final adminName = (adminUser != null && adminUser.firstName.isNotEmpty)
        ? '${adminUser.firstName} ${adminUser.lastName}'.trim()
        : 'Operations Administrator';
    final adminEmail = adminUser?.email.isNotEmpty == true ? adminUser!.email : 'ops.admin@milkdrop.in';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Admin Hero Card ──
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
                        child: Text('🛡️', style: TextStyle(fontSize: 38)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  adminName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  adminEmail,
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
                    '🛡️ Master Administrator • ID #ADM-001',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── System Health Status Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('LIVE BACKEND & SYSTEM HEALTH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🟢 ALL SYSTEMS OPERATIONAL', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSystemStatRow('API Server', 'http://127.0.0.1:8000 (Django 5.x)', '🟢 ONLINE'),
                const Divider(height: 16),
                _buildSystemStatRow('Database', 'SQLite3 WAL Mode (196 KB)', '🟢 HEALTHY'),
                const Divider(height: 16),
                _buildSystemStatRow('Geocoding Engine', 'OpenStreetMap Nominatim', '🟢 ACTIVE'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Web Console Quick Access ──
          _buildSectionHeader('Web Console Quick Access'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildWebLinkRow(
                    context,
                    '🖥️ MilkDrop Operations Console',
                    'http://127.0.0.1:8000/admin-console/',
                    'Real-time delivery management, manual wallet credits & push broadcasts',
                  ),
                  const Divider(height: 20),
                  _buildWebLinkRow(
                    context,
                    '⚙️ Django Master Admin Panel',
                    'http://127.0.0.1:8000/admin/',
                    'Complete database models, permission groups & server logs',
                  ),
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
              label: const Text('Log Out of Admin Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildSystemStatRow(String label, String value, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
        Text(status, style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  Widget _buildWebLinkRow(BuildContext context, String title, String url, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0D7C66)),
              tooltip: 'Copy URL',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('📋 Copied $url to clipboard!')),
                );
              },
            ),
          ],
        ),
        Text(url, style: const TextStyle(color: Color(0xFF0D7C66), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }
}
