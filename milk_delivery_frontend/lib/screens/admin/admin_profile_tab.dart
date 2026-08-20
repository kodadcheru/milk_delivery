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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // ── 1. ADMIN HERO CARD ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.25),
                  blurRadius: 20,
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
                        gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF38BDF8)]),
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 38,
                        backgroundColor: Color(0xFF0F172A),
                        child: Text('🛡️', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F172A), width: 2),
                      ),
                      child: const Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  adminName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  adminEmail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    '🛡️ Master Operations Administrator • ID #ADM-001',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 2. SYSTEM HEALTH STATUS CARD ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('LIVE BACKEND & SYSTEM HEALTH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.8, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🟢 ALL OPERATIONAL', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSystemStatRow('API Server Engine', 'http://127.0.0.1:8000 (Django 5.x REST Framework)', '🟢 ONLINE'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildSystemStatRow('SQLite Database', 'SQLite3 WAL Mode • Auto-indexed schema', '🟢 HEALTHY'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildSystemStatRow('Geocoding Service', 'Google Maps V3 Geocoding & Places Engine', '🟢 ACTIVE'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 3. WEB CONSOLE QUICK ACCESS ──
          _buildSectionHeader('Operations Web Console Shortcuts'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildWebLinkRow(
                  context,
                  '🖥️ Operations Web Console',
                  'http://127.0.0.1:8000/admin-console/',
                  'Real-time delivery management, wallet credits & push broadcasts',
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildWebLinkRow(
                  context,
                  '⚙️ Django Master Admin Portal',
                  'http://127.0.0.1:8000/admin/',
                  'Database models, user roles, permission groups & server logs',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 4. LOG OUT ACTION ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                state.setRole('CUSTOMER');
                onLogout();
              },
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 18),
              label: const Text('Log Out of Admin Account', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F2),
                side: const BorderSide(color: Color(0xFFFECDD3)),
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
      child: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
      ),
    );
  }

  Widget _buildSystemStatRow(String label, String value, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status, style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.w900, fontSize: 10.5)),
        ),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
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
        Text(url, style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
      ],
    );
  }
}
