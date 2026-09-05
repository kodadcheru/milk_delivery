import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../widgets/next_gen_nav_bar.dart';
import '../customer/home_tab.dart';
import '../customer/subscriptions_tab.dart';
import '../customer/wallet_tab.dart';
import '../customer/delivery_tracker_tab.dart';
import '../customer/profile_tab.dart';

class CustomerShell extends StatelessWidget {
  final AppState state;
  final VoidCallback onLogout;

  const CustomerShell({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(state: state),
      SubscriptionsTab(state: state),
      WalletTab(state: state),
      DeliveryTrackerTab(state: state),
      ProfileTab(state: state, onLogout: onLogout),
    ];

    return PopScope(
      canPop: state.currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          state.setTab(0);
        }
      },
      child: Scaffold(
        extendBody: false,
        body: screens[state.currentTabIndex],
        bottomNavigationBar: NextGenBottomNavBar(
          selectedIndex: state.currentTabIndex,
          onItemSelected: (idx) => state.setTab(idx),
          items: [
            NextGenNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: state.tr('home'),
            ),
            NextGenNavItem(
              icon: Icons.autorenew_outlined,
              activeIcon: Icons.autorenew_rounded,
              label: state.isTelugu ? 'సబ్స్' : 'Subs',
              badgeText: state.subscriptions.isNotEmpty
                  ? '${state.subscriptions.length}'
                  : null,
            ),
            NextGenNavItem(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: state.tr('wallet'),
              badgeText: (state.currentUser?.walletBalance ?? 0) > 0
                  ? '₹${(state.currentUser?.walletBalance ?? 0).toStringAsFixed(0)}'
                  : null,
            ),
            NextGenNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: state.isTelugu ? 'ఆర్డర్లు' : 'Orders',
            ),
            NextGenNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: state.tr('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
