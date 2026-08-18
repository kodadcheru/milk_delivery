import 'dart:ui';
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
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
import 'screens/provider/provider_profile_tab.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_profile_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Production Global Crash & Error Boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [MilkDrop FlutterError]: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🚨 [MilkDrop UncaughtAsyncError]: $error');
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
    final token = await ApiService.initAuthToken();
    if (token != null && mounted) {
      setState(() {
        _isLoggedIn = true;
        _isInitializing = false;
      });
    } else if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF0F172A)),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🥛', style: TextStyle(fontSize: 48)),
                SizedBox(height: 16),
                CircularProgressIndicator(color: Color(0xFF10B981)),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: '${AppConfig.appName} 🥛',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D7C66),
          primary: const Color(0xFF0D7C66),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFFF8FAFC),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF0D7C66).withValues(alpha: 0.12),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF0D7C66), size: 24);
            }
            return const IconThemeData(color: Color(0xFF64748B), size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF0D7C66),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              );
            }
            return const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF0D7C66),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      builder: (context, child) {
        // Global Error Boundary
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🥛', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('We recovered safely. Tap below to reload the screen.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _appState.reloadAllData(),
                      child: const Text('Reload App'),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child!;
      },
      home: !_isLoggedIn
          ? PhoneLoginScreen(
              state: _appState,
              onLoginSuccess: () => setState(() => _isLoggedIn = true),
            )
          : MainAppShell(
              state: _appState,
              onLogout: () async {
                await ApiService.clearAuthToken();
                _appState.currentUser = null;
                _appState.currentRole = 'CUSTOMER';
                setState(() => _isLoggedIn = false);
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

class _MainAppShellState extends State<MainAppShell> {
  int _driverTab = 0;
  int _providerTab = 0;
  int _adminTab = 0;

  @override
  Widget build(BuildContext context) {
    // ── 1. DRIVER ROLE APP SHELL ──
    if (widget.state.currentRole == 'DRIVER') {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🛵', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Driver Partner App', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    '${widget.state.deliveries.where((d) => d.status == "PENDING").length} Deliveries Pending Today',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          actions: [
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
        body: _driverTab == 0
            ? DriverDashboardScreen(state: widget.state)
            : DriverProfileTab(state: widget.state, onLogout: widget.onLogout),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _driverTab,
          onDestinationSelected: (idx) => setState(() => _driverTab = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping_rounded),
              label: 'Route Deliveries',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Driver Profile',
            ),
          ],
        ),
      );
    }

    // ── 2. PROVIDER / LOCATION HUB ROLE APP SHELL ──
    if (widget.state.currentRole == 'PROVIDER' || widget.state.currentRole == 'HUB_MANAGER') {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🏬', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location Hub Portal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    'Jubilee Hills Central Depot #1 • 128 Subscribers',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh Hub Data',
              onPressed: () async {
                await widget.state.reloadAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hub orders and stats refreshed!')),
                  );
                }
              },
            ),
          ],
        ),
        body: _providerTab == 0
            ? ProviderDashboardScreen(state: widget.state)
            : ProviderProfileTab(state: widget.state, onLogout: widget.onLogout),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _providerTab,
          onDestinationSelected: (idx) => setState(() => _providerTab = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Hub Command',
            ),
            NavigationDestination(
              icon: Icon(Icons.business_center_outlined),
              selectedIcon: Icon(Icons.business_center_rounded),
              label: 'Hub Profile',
            ),
          ],
        ),
      );
    }

    // ── 3. ADMIN ROLE APP SHELL ──
    if (widget.state.currentRole == 'ADMIN') {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🛡️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Operations Hub', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    '${widget.state.totalDailyMilkVolume.toStringAsFixed(1)}L Total • ₹${widget.state.totalDailyRevenue.toStringAsFixed(0)} Daily Rev',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          actions: [
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
        body: _adminTab == 0
            ? AdminDashboardScreen(state: widget.state)
            : AdminProfileTab(state: widget.state, onLogout: widget.onLogout),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _adminTab,
          onDestinationSelected: (idx) => setState(() => _adminTab = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Command Center',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🥛', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MilkDrop Express', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 11),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          widget.state.currentDeliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Notification Bell with Unread Badge
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
                      decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${widget.state.unreadNotificationCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
          const SizedBox(width: 4),
        ],
      ),
      body: screens[widget.state.currentTabIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: widget.state.currentTabIndex,
          onDestinationSelected: (idx) => widget.state.setTab(idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Store',
            ),
            NavigationDestination(
              icon: Icon(Icons.autorenew_outlined),
              selectedIcon: Icon(Icons.autorenew_rounded),
              label: 'Subscriptions',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
