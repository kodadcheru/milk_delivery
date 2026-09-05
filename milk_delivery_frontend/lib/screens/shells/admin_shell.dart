import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/next_gen_nav_bar.dart';
import '../customer/notifications_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_profile_tab.dart';
import '../common/day_wise_orders_screen.dart';
import '../driver/morning_batch_screen.dart';

class AdminShell extends StatefulWidget {
  final AppState state;
  final VoidCallback onLogout;

  const AdminShell({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _adminTab = 0;

  @override
  Widget build(BuildContext context) {
    final adminScreens = [
      AdminDashboardScreen(state: widget.state),
      DayWiseOrdersScreen(state: widget.state, role: 'ADMIN'),
      MorningBatchScreen(
        state: widget.state,
        onReturnToDashboard: () {
          setState(() => _adminTab = 0);
          widget.state.reloadAllData();
        },
      ),
      AdminProfileTab(state: widget.state, onLogout: widget.onLogout),
    ];

    return Scaffold(
      extendBody: false,
      appBar: _adminTab == 3
          ? null
          : AppBar(
        backgroundColor: UiTone.ink,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: UiTone.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: const Text('🛡️', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Operations Hub', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(
                    '${widget.state.totalDailyMilkVolume.toStringAsFixed(1)}L Total • ₹${widget.state.totalDailyRevenue.toStringAsFixed(0)} Daily Rev',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                if (widget.state.unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: UiTone.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${widget.state.unreadNotificationCount}',
                        textAlign: TextAlign.center,
                        style: UiText.caption.copyWith(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => NotificationsScreen(state: widget.state),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Operations Data',
            onPressed: () async {
              await widget.state.reloadAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Operations dashboard refreshed!')),
                );
              }
            },
          ),
        ],
      ),
      body: adminScreens[_adminTab.clamp(0, adminScreens.length - 1)],
      bottomNavigationBar: NextGenBottomNavBar(
        selectedIndex: _adminTab.clamp(0, adminScreens.length - 1),
        onItemSelected: (idx) {
          setState(() => _adminTab = idx);
          widget.state.reloadAllData();
        },
        items: [
          const NextGenNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'Command',
          ),
          const NextGenNavItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            label: 'Day Orders',
          ),
          const NextGenNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: 'Batch Packing',
          ),
          const NextGenNavItem(
            icon: Icons.admin_panel_settings_outlined,
            activeIcon: Icons.admin_panel_settings_rounded,
            label: 'Admin Profile',
          ),
        ],
      ),
    );
  }
}
