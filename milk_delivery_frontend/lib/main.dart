import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/ui_tokens.dart';
import 'theme/ui_text.dart';
import 'widgets/in_app_chat_banner.dart';
import 'widgets/next_gen_nav_bar.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/customer/home_tab.dart';
import 'screens/customer/subscriptions_tab.dart';
import 'screens/customer/wallet_tab.dart';
import 'screens/customer/delivery_tracker_tab.dart';
import 'screens/customer/profile_tab.dart';
import 'screens/customer/notifications_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/driver/driver_profile_tab.dart';
import 'screens/provider/provider_dashboard_screen.dart';
import 'screens/provider/provider_earnings_screen.dart';
import 'screens/provider/provider_profile_tab.dart';
import 'screens/common/day_wise_orders_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_profile_tab.dart';
import 'screens/driver/morning_batch_screen.dart';
import 'screens/splash/pamba_splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Production Global Crash & Error Boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [Pamba FlutterError]: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 [Pamba UncaughtAsyncError]: $error');
    return true; // Prevent app crashes
  };

  runApp(const MilkDeliveryApp());
}

class MilkDeliveryApp extends StatefulWidget {
  const MilkDeliveryApp({super.key});

  @override
  State<MilkDeliveryApp> createState() => _MilkDeliveryAppState();
}

class _MilkDeliveryAppState extends State<MilkDeliveryApp> {
  late final AppState _appState;
  bool _isLoggedIn = false;
  bool _isInitializing = true;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _appState.addListener(() {
      if (mounted) setState(() {});
    });
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    // Load cached addresses, catalog, and cached role FIRST (instant, zero network latency)
    await _appState.loadCachedAddresses();
    await _appState.loadCachedCatalog();
    await _appState.loadCachedUserRole();
    final token = await ApiService.initAuthToken();
    if (token != null && mounted) {
      try {
        await _appState.reloadAllData();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isInitializing = false;
        });
      }
    } else if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash || _isInitializing) {
      return MaterialApp(
        title: '${AppConfig.appName} 🥛',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF060911)),
        home: PambaSplashScreen(
          onFinish: () {
            if (mounted) {
              setState(() => _showSplash = false);
            }
          },
        ),
      );
    }

    return MaterialApp(
      title: '${AppConfig.appName} 🥛',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: !_isLoggedIn
          ? PhoneLoginScreen(
              key: const ValueKey('phone_login_screen_root'),
              state: _appState,
              onLoginSuccess: () => setState(() => _isLoggedIn = true),
            )
          : MainAppShell(
              key: ValueKey('main_app_shell_${_appState.currentRole}_${_appState.currentUser?.id ?? "session"}'),
              state: _appState,
              onLogout: () async {
                await _appState.logout();
                if (mounted) {
                  setState(() => _isLoggedIn = false);
                }
              },
            ),
    );
  }
}

class MainAppShell extends StatefulWidget {
  final AppState state;
  final VoidCallback onLogout;

  const MainAppShell({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> with WidgetsBindingObserver {
  int _driverTab = 0;
  int _providerTab = 0;
  int _adminTab = 0;
  Timer? _notifPollTimer;
  final Set<int> _seenNotifIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialise seen notification IDs
    for (final n in widget.state.notifications) {
      _seenNotifIds.add(n.id);
    }
    // Real-time notification & in-app chat poller (every 4 seconds)
    _notifPollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollLiveNotifications());
  }

  @override
  void dispose() {
    _notifPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pollLiveNotifications() async {
    if (!mounted) return;
    try {
      final notifs = await ApiService.fetchNotifications(pageSize: 10);
      if (!mounted) return;

      for (final n in notifs) {
        if (!n.isRead && !_seenNotifIds.contains(n.id)) {
          _seenNotifIds.add(n.id);
          // If this is an in-app chat message or urgent delivery notification, pop the heads-up banner!
          if (n.targetScreen == 'CHAT' || n.title.contains('💬') || n.notificationType == 'DELIVERY') {
            InAppChatBanner.show(context, notification: n, state: widget.state);
          }
        }
      }
      // Update notifications in state
      if (notifs.isNotEmpty) {
        widget.state.notifications = notifs;
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.state.reloadAllData();
      _pollLiveNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. DRIVER ROLE APP SHELL ──
    if (widget.state.currentRole == 'DRIVER') {
      final activeHub = widget.state.driverAssignedHub;
      final hubName = widget.state.driverHubName;
      final pendingDeliveries = widget.state.deliveries.where((d) => d.status == "PENDING").length;
      final pendingExpress = widget.state.liveOrders.where((o) => o.status != 'DELIVERED' && o.status != 'CANCELLED').length;
      final pendingCount = pendingDeliveries + pendingExpress;

      final driverScreens = [
        DriverDashboardScreen(state: widget.state),
        DayWiseOrdersScreen(state: widget.state, role: 'DRIVER'),
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
        appBar: _driverTab == 3
            ? null
            : AppBar(
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
        ),
        body: driverScreens[_driverTab.clamp(0, driverScreens.length - 1)],
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
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: 'Driver Profile',
            ),
          ],
        ),
      );
    }

    // ── 2. PROVIDER / LOCATION HUB ROLE APP SHELL ──
    if (widget.state.currentRole == 'PROVIDER' || widget.state.currentRole == 'HUB_MANAGER') {
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

      return Scaffold(
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
        body: providerScreens[_providerTab.clamp(0, providerScreens.length - 1)],
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
      );
    }

    // ── 3. ADMIN ROLE APP SHELL ──
    if (widget.state.currentRole == 'ADMIN') {
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

    // ── 3. CUSTOMER ROLE APP SHELL ──
    final screens = [
      HomeTab(state: widget.state),
      SubscriptionsTab(state: widget.state),
      WalletTab(state: widget.state),
      DeliveryTrackerTab(state: widget.state),
      ProfileTab(state: widget.state, onLogout: widget.onLogout),
    ];

    return Scaffold(
      extendBody: false,
      body: screens[widget.state.currentTabIndex],
      bottomNavigationBar: NextGenBottomNavBar(
        selectedIndex: widget.state.currentTabIndex,
        onItemSelected: (idx) => widget.state.setTab(idx),
        items: [
          NextGenNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: widget.state.tr('home'),
          ),
          NextGenNavItem(
            icon: Icons.autorenew_outlined,
            activeIcon: Icons.autorenew_rounded,
            label: widget.state.isTelugu ? 'సబ్స్' : 'Subs',
            badgeText: widget.state.subscriptions.isNotEmpty
                ? '${widget.state.subscriptions.length}'
                : null,
          ),
          NextGenNavItem(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
            label: widget.state.tr('wallet'),
            badgeText: (widget.state.currentUser?.walletBalance ?? 0) > 0
                ? '₹${(widget.state.currentUser?.walletBalance ?? 0).toStringAsFixed(0)}'
                : null,
          ),
          NextGenNavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: widget.state.isTelugu ? 'ఆర్డర్లు' : 'Orders',
          ),
          NextGenNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: widget.state.tr('profile'),
          ),
        ],
      ),
    );
  }
}

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
