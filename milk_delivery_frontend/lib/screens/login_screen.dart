import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.state,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _handleLogin(String role, String username, String pass) {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.state.setRole(role);
      setState(() => _isLoading = false);
      widget.onLoginSuccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── App Brand Logo ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7C66),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text('🥛', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MilkDrop Express',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '⚡ Daily Farm Fresh Doorstep Milk Delivery',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 36),

                // ── Quick Role Selector Cards ──
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT EXPERIENCE DEMO ROLE:',
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 12),

                // Customer Option
                _buildRoleCard(
                  title: 'Customer Experience',
                  subtitle: 'Prepaid Wallet, Daily Subscriptions & Tracker',
                  icon: '🏡',
                  badgeColor: const Color(0xFF0D7C66),
                  onTap: () => _handleLogin('CUSTOMER', 'customer', 'pass123'),
                ),
                const SizedBox(height: 12),

                // Delivery Partner Option
                _buildRoleCard(
                  title: 'Delivery Partner (Driver)',
                  subtitle: 'Morning Route Task List & Photo Proof Upload',
                  icon: '🛵',
                  badgeColor: Colors.amber.shade800,
                  onTap: () => _handleLogin('DRIVER', 'driver', 'pass123'),
                ),
                const SizedBox(height: 12),

                // Admin Option
                _buildRoleCard(
                  title: 'Admin / Operations Console',
                  subtitle: 'Milk Volume Demand Forecast & Catalog Manager',
                  icon: '📊',
                  badgeColor: Colors.purple.shade700,
                  onTap: () => _handleLogin('ADMIN', 'admin', 'admin123'),
                ),

                const SizedBox(height: 30),

                if (_isLoading)
                  const CircularProgressIndicator(color: Color(0xFF10B981))
                else
                  const Text(
                    'Connected to Django REST Backend & Live SQLite DB',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required String icon,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
