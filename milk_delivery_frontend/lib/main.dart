import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'config/app_config.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/in_app_chat_banner.dart';
import 'services/crash_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash/pamba_splash_screen.dart';
import 'screens/shells/customer_shell.dart';
import 'screens/shells/driver_shell.dart';
import 'screens/shells/provider_shell.dart';
import 'screens/shells/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress debug logs in release mode
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Pre-cache fonts for offline use
  GoogleFonts.config.allowRuntimeFetching = true;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase safely
  try {
    await Firebase.initializeApp();
  } catch (e) {
    try {
      await PushNotificationService.instance.initialize();
    } catch (_) {}
  }

  // Production Global Crash & Error Boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    } catch (_) {}
    CrashReportingService.reportCrash(details.exception, details.stack);
    debugPrint('🚨 [Pamba FlutterError]: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    } catch (_) {}
    CrashReportingService.reportCrash(error, stack);
    debugPrint('🚨 [Pamba UncaughtAsyncError]: $error');
    return true; // Prevent app crashes
  };

  try {
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[PushNotificationService] Failed to initialize at startup: $e');
  }

  // Show friendly error widget instead of grey screen in release mode
  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again or restart the app.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    };
  }

  runApp(const MilkDeliveryApp());
}

class MilkDeliveryApp extends StatefulWidget {
  const MilkDeliveryApp({super.key});

  @override
  State<MilkDeliveryApp> createState() => _MilkDeliveryAppState();
}

class _MilkDeliveryAppState extends State<MilkDeliveryApp> {
  static final GlobalKey<NavigatorState> _navigatorKey = PushNotificationService.navigatorKey;
  late final AppState _appState;
  bool _isLoggedIn = false;
  bool _isInitializing = true;
  bool _showSplash = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (!hasSeenOnboarding) {
      _showOnboarding = true;
    }

    // Load cached addresses, catalog, and cached role FIRST (instant, zero network latency)
    await _appState.loadCachedAddresses();
    await _appState.loadCachedCatalog();
    await _appState.loadCachedUserRole();
    final token = await ApiService.initAuthToken();
    if (token != null && mounted) {
      try {
        await AppConfig.loadRemoteConfig();
        await _appState.reloadAllData();
        PushNotificationService.instance.registerDeviceToken(_appState);
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

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      setState(() {
        _showOnboarding = false;
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
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [
        if (Firebase.apps.isNotEmpty)
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      title: '${AppConfig.appName} 🥛',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: ListenableBuilder(
        listenable: _appState,
        builder: (context, child) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 550),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            // For the incoming screen (new child), just fade in
            // For the outgoing screen (splash), slide up slightly + fade out
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          child: (_showSplash || _isInitializing)
              ? PambaSplashScreen(
                  key: const ValueKey('pamba_splash_screen'),
                  onFinish: () {
                    if (mounted) {
                      setState(() => _showSplash = false);
                    }
                  },
                )
              : (_showOnboarding
                  ? OnboardingScreen(
                      key: const ValueKey('onboarding_screen'),
                      onComplete: _markOnboardingComplete,
                    )
                  : (!_isLoggedIn
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
                        ))),
        ),
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
