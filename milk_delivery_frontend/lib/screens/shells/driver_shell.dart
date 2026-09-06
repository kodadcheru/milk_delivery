import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/next_gen_nav_bar.dart';
import '../customer/notifications_screen.dart';
import '../driver/driver_dashboard_screen.dart';
import '../driver/driver_profile_tab.dart';
import '../driver/driver_route_map_screen.dart';
import '../driver/morning_batch_screen.dart';

class DriverShell extends StatefulWidget {
  final AppState state;
  final VoidCallback onLogout;

  const DriverShell({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _driverTab = 0;

  void _showDriverLocationZoneSheet(BuildContext context, AppState state) {
    final activeHub = state.driverAssignedHub;
    final hubName = state.driverHubName;
    final hubCode = activeHub != null ? (activeHub['hub_code'] ?? 'HUB-DEFAULT') : 'HUB-DEFAULT';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.lg))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: UiTone.secondary, size: 22),
                const SizedBox(width: 8),
                const Text('Driver Operating Zone & Hub', style: UiText.title),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: UiTone.ink,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: UiTone.secondary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🏬', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hubName, style: UiText.bodyStrong.copyWith(color: Colors.white)),
                        Text('Assigned Hub • $hubCode', style: UiText.caption.copyWith(color: UiTone.secondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: UiTone.secondary, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: UiTone.primary,
                      content: Text('🟢 GPS Location Synced to $hubName!'),
                    ),
                  );
                },
                icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                label: Text('Detect & Sync Device GPS Location 📍', style: UiText.bodyStrong.copyWith(fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hubName = widget.state.driverHubName;
    final pendingDeliveries = widget.state.deliveries.where((d) => d.status == "PENDING").length;
    final pendingExpress = widget.state.liveOrders.where((o) => o.status != 'DELIVERED' && o.status != 'CANCELLED').length;
    final pendingCount = pendingDeliveries + pendingExpress;

    final driverScreens = [
      DriverDashboardScreen(state: widget.state),
      DriverRouteMapScreen(state: widget.state, tasks: widget.state.deliveries),
      MorningBatchScreen(
        state: widget.state,
        onReturnToDashboard: () {
          setState(() => _driverTab = 0);
          widget.state.reloadAllData();
        },
      ),
      DriverProfileTab(state: widget.state, onLogout: widget.onLogout),
    ];

    return Scaffold(
      extendBody: false,
      appBar: _driverTab == 0
          ? AppBar(
        backgroundColor: UiTone.ink,
        elevation: 0,
        title: InkWell(
          onTap: () => _showDriverLocationZoneSheet(context, widget.state),
          borderRadius: BorderRadius.circular(UiRadius.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: UiTone.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                ),
                child: const Text('🛵', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '📍 $hubName',
                            overflow: TextOverflow.ellipsis,
                            style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: UiTone.secondary, size: 18),
                      ],
                    ),
                    Text(
                      'Operating Zone • $pendingCount Pending Drops',
                      overflow: TextOverflow.ellipsis,
                      style: UiText.label.copyWith(color: UiTone.secondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            tooltip: 'Refresh Deliveries',
            onPressed: () async {
              await widget.state.reloadAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deliveries list refreshed!')),
                );
              }
            },
          ),
        ],
      )
    : null,
      body: IndexedStack(
        index: _driverTab.clamp(0, driverScreens.length - 1),
        children: driverScreens,
      ),
      bottomNavigationBar: NextGenBottomNavBar(
        selectedIndex: _driverTab.clamp(0, driverScreens.length - 1),
        onItemSelected: (idx) {
          setState(() => _driverTab = idx);
          widget.state.reloadAllData();
        },
        items: [
          NextGenNavItem(
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping_rounded,
            label: 'Route Drops',
            badgeText: pendingCount > 0 ? '$pendingCount' : null,
          ),
          const NextGenNavItem(
            icon: Icons.map_outlined,
            activeIcon: Icons.map_rounded,
            label: 'Route Map',
          ),
          const NextGenNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: 'Crates',
          ),
          const NextGenNavItem(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
            label: 'Account & Cash',
          ),
        ],
      ),
    );
  }
}
