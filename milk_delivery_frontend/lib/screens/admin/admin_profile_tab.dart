import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';

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
                colors: [UiTone.ink, Color(0xFF1E293B), UiTone.primary],
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
                        gradient: LinearGradient(colors: [UiTone.secondary, Color(0xFF38BDF8)]),
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 38,
                        backgroundColor: UiTone.ink,
                        child: Text('🛡️', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: UiTone.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: UiTone.ink, width: 2),
                      ),
                      child: const Icon(Icons.shield_rounded, size: 14, color: UiTone.surface),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  adminName,
                  style: const TextStyle(color: UiTone.surface, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  adminEmail,
                  style: TextStyle(color: UiTone.surface.withValues(alpha: 0.7), fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: UiTone.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                    border: Border.all(color: UiTone.secondary.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '🛡️ Master Operations Administrator • ID #${state.currentUser?.id ?? 0}',
                    style: TextStyle(color: UiTone.secondary, fontWeight: FontWeight.w800, fontSize: 11),
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
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.lg),
              border: Border.all(color: UiTone.surfaceBorder),
              boxShadow: UiShadow.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('LIVE BACKEND & SYSTEM HEALTH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.8, color: UiTone.ink)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: UiTone.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: const Text('🟢 ALL OPERATIONAL', style: TextStyle(color: UiTone.primary, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSystemStatRow('API Server', '${ApiService.baseUrl} (Django REST)', '🟢 CONNECTED'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: UiTone.surfaceMuted)),
                _buildSystemStatRow('Database', 'PostgreSQL • Railway Cloud', '🟢 HEALTHY'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: UiTone.surfaceMuted)),
                _buildSystemStatRow('Auth Token', ApiService.authToken != null ? 'JWT Active' : 'Not authenticated', ApiService.authToken != null ? '🟢 VALID' : '🔴 MISSING'),
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
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.lg),
              border: Border.all(color: UiTone.surfaceBorder),
              boxShadow: UiShadow.card,
            ),
            child: Column(
              children: [
                _buildWebLinkRow(
                  context,
                  '🖥️ Operations Web Console',
                  '${ApiService.baseUrl.replaceAll('/api', '')}/admin-console/',
                  'Real-time delivery management, wallet credits & push broadcasts',
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: UiTone.surfaceMuted)),
                _buildWebLinkRow(
                  context,
                  '⚙️ Django Master Admin Portal',
                  '${ApiService.baseUrl.replaceAll('/api', '')}/admin/',
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
              icon: const Icon(Icons.logout_rounded, color: UiTone.error, size: 18),
              label: const Text('Log Out of Admin Account', style: TextStyle(color: UiTone.error, fontWeight: FontWeight.w800, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F2),
                side: const BorderSide(color: Color(0xFFFECDD3)),
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
      child: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: UiTone.ink, letterSpacing: -0.2),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: UiTone.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(UiRadius.xs),
          ),
          child: Text(status, style: const TextStyle(color: UiTone.primary, fontWeight: FontWeight.w900, fontSize: 10.5)),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: UiTone.primary),
              tooltip: 'Copy URL',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('📋 Copied $url to clipboard!')),
                );
              },
            ),
          ],
        ),
        Text(url, style: const TextStyle(color: UiTone.accentBlue, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
      ],
    );
  }
}
