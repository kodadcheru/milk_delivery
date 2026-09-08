import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/next_gen_nav_bar.dart';
import '../customer/notifications_screen.dart';
import '../provider/provider_dashboard_screen.dart';
import '../provider/provider_earnings_screen.dart';
import '../provider/provider_profile_tab.dart';
import '../common/day_wise_orders_screen.dart';
import '../driver/morning_batch_screen.dart';

class ProviderShell extends StatefulWidget {
  final AppState state;
  final VoidCallback onLogout;

  const ProviderShell({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _providerTab = 0;

  @override
  Widget build(BuildContext context) {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubTitle = activeHub != null ? (activeHub['name'] ?? 'Central Dairy Depot') : 'Central Dairy Depot';
    final activeDeliveriesCount = widget.state.deliveries.length;

    final providerScreens = [
      ProviderDashboardScreen(state: widget.state),
      ProviderEarningsScreen(state: widget.state),
      DayWiseOrdersScreen(state: widget.state, role: 'PROVIDER'),
      MorningBatchScreen(
        state: widget.state,
        onReturnToDashboard: () {
          setState(() => _providerTab = 0);
          widget.state.syncProviderTab(0);
          widget.state.reloadAllData();
        },
      ),
      ProviderProfileTab(state: widget.state, onLogout: widget.onLogout),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_providerTab != 0) {
          setState(() {
            _providerTab = 0;
          });
          widget.state.syncProviderTab(0);
        }
      },
      child: Scaffold(
      extendBody: false,
      appBar: _providerTab == 3
          ? null
          : AppBar(
        backgroundColor: UiTone.ink,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: UiTone.accentBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              child: const Text('🏬', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Location Hub Portal', style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (widget.state.isRedisConnected ? UiTone.secondary : UiTone.warning).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                          border: Border.all(color: (widget.state.isRedisConnected ? UiTone.secondary : UiTone.warning).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: widget.state.isRedisConnected ? UiTone.secondary : UiTone.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.state.isRedisConnected ? 'Live Redis' : 'Auto-Sync',
                              style: UiText.caption.copyWith(
                                color: widget.state.isRedisConnected ? UiTone.secondary : UiTone.warning,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$hubTitle • $activeDeliveriesCount Active Deliveries',
                    overflow: TextOverflow.ellipsis,
                    style: UiText.label.copyWith(color: UiTone.accentBlue, fontSize: 11),
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
            tooltip: 'Refresh Hub Data',
            onPressed: () async {
              await widget.state.reloadAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: UiTone.primary,
                    content: Text('⚡ Hub Redis Stream & Data Refreshed!'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _providerTab.clamp(0, providerScreens.length - 1),
        children: providerScreens,
      ),
      bottomNavigationBar: NextGenBottomNavBar(
        selectedIndex: _providerTab.clamp(0, providerScreens.length - 1),
        onItemSelected: (idx) {
          setState(() => _providerTab = idx);
          widget.state.syncProviderTab(idx);
          widget.state.reloadAllData();
        },
        items: [
          NextGenNavItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: widget.state.isTelugu ? 'హబ్ కాక్‌పిట్' : 'Hub Cockpit',
          ),
          NextGenNavItem(
            icon: Icons.currency_rupee_rounded,
            activeIcon: Icons.account_balance_wallet_rounded,
            label: widget.state.isTelugu ? 'ఆదాయం' : 'Earnings',
            badgeText: widget.state.totalDailyRevenue > 0
                ? '₹${widget.state.totalDailyRevenue.toStringAsFixed(0)}'
                : null,
          ),
          NextGenNavItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            label: widget.state.isTelugu ? 'ఆర్డర్లు' : 'Day Orders',
            badgeText: activeDeliveriesCount > 0 ? '$activeDeliveriesCount' : null,
          ),
          NextGenNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: widget.state.isTelugu ? 'ప్యాకింగ్' : 'Batch Packing',
          ),
          NextGenNavItem(
            icon: Icons.business_center_outlined,
            activeIcon: Icons.business_center_rounded,
            label: widget.state.isTelugu ? 'ప్రొఫైల్' : 'Hub Profile',
          ),
        ],
      ),
    ),
  );
  }
}
