import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/in_app_chat_banner.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/splash/pamba_splash_screen.dart';
import 'screens/shells/customer_shell.dart';
import 'screens/shells/driver_shell.dart';
import 'screens/shells/provider_shell.dart';
import 'screens/shells/admin_shell.dart';

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
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
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

  void _handleLogout() {
    // 1. Instantly pop any modal dialogs, sheets, or pushed screens back to root
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // 2. Flip logged-in state to false synchronously — immediate redirect to login!
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
      });
    }

    // 3. Clear auth token, user cache, addresses, and state in background
    _appState.logout();
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
      navigatorKey: _navigatorKey,
      title: '${AppConfig.appName} 🥛',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: !_isLoggedIn
          ? PhoneLoginScreen(
              key: const ValueKey('phone_login_screen_root'),
              state: _appState,
              onLoginSuccess: () {
                if (mounted) {
                  setState(() => _isLoggedIn = true);
                }
              },
            )
          : MainAppShell(
              key: ValueKey('main_app_shell_${_appState.currentRole}_${_appState.currentUser?.id ?? "session"}'),
              state: _appState,
              onLogout: _handleLogout,
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
    // Real-time notification & in-app chat poller (every 30 seconds)
    _notifPollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollLiveNotifications());
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
    switch (widget.state.currentRole) {
      case 'DRIVER':
        return DriverShell(state: widget.state, onLogout: widget.onLogout);
      case 'HUB_MANAGER':
      case 'PROVIDER':
        return ProviderShell(state: widget.state, onLogout: widget.onLogout);
      case 'ADMIN':
        return AdminShell(state: widget.state, onLogout: widget.onLogout);
      default:
        return CustomerShell(state: widget.state, onLogout: widget.onLogout);
    }
  }
}
