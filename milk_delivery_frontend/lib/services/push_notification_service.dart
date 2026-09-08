import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification_model.dart';
import '../providers/app_state.dart';
import 'api_service.dart';
import 'notification_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Message received: ${message.messageId} | ${message.notification?.title}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? _lastToken;

  /// Real project credentials for pamba-delivery
  static const FirebaseOptions _androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyDc1A9xybmj5I0P0yesX8j4wfRsuepfzsk',
    appId: '1:7416380046:android:ff89ece9d8598e997c67df',
    messagingSenderId: '7416380046',
    projectId: 'pamba-delivery',
    storageBucket: 'pamba-delivery.firebasestorage.app',
  );

  static const FirebaseOptions _iosOptions = FirebaseOptions(
    apiKey: 'AIzaSyDc1A9xybmj5I0P0yesX8j4wfRsuepfzsk',
    appId: '1:7416380046:ios:ff89ece9d8598e997c67df',
    messagingSenderId: '7416380046',
    projectId: 'pamba-delivery',
    storageBucket: 'pamba-delivery.firebasestorage.app',
    iosBundleId: 'com.example.milkDeliveryFrontend',
  );

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Core safely
      try {
        await Firebase.initializeApp();
        debugPrint('[FCM] Firebase initialized with native configuration');
      } catch (e) {
        debugPrint('[FCM] Initializing with platform FirebaseOptions: $e');
        final options = Platform.isAndroid ? _androidOptions : _iosOptions;
        await Firebase.initializeApp(options: options);
      }

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Initialize Local Notifications for Foreground display
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              _handleDataPayload(data);
            } catch (err) {
              debugPrint('[FCM] Error decoding local notification payload: $err');
            }
          }
        },
      );

      // 4. Create High-Importance Notification Channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'pamba_milk_delivery',
        'Pamba Delivery Alerts',
        description: 'Real-time updates for morning milk delivery, orders, and wallet.',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 5. Configure Foreground presentation on iOS
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Received: ${message.notification?.title ?? message.data['title']}');
        _showForegroundNotification(message);
      });

      // 7. Listen to notification click when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM Click] Opened from background: ${message.data}');
        _handleRemoteMessage(message);
      });

      // 8. Check if opened from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM Launch] Opened from terminated state: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleRemoteMessage(initialMessage);
        });
      }

      _isInitialized = true;
      debugPrint('[FCM] PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('[FCM] PushNotificationService initialization skipped/failed: $e');
    }
  }

  /// Request permissions and register FCM device token with Django backend
  Future<void> registerDeviceToken(AppState state) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Request user permission for notifications
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Notification permissions denied by user');
        return;
      }

      // On iOS, ensure APNs token is ready
      if (Platform.isIOS) {
        final apnsToken = await messaging.getAPNSToken();
        debugPrint('[FCM] APNs Token: ${apnsToken != null ? "Acquired (${apnsToken.length} chars)" : "Awaiting registration"}');
      }

      // Retrieve FCM registration token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _lastToken = token;
        final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
        final deviceName = Platform.isIOS ? 'iPhone' : 'Android Device';

        final success = await ApiService.registerDeviceToken(
          token: token,
          platform: platform,
          deviceName: deviceName,
        );

        if (success) {
          debugPrint('[FCM] Device token registered with server successfully: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        } else {
          debugPrint('[FCM] Failed to register device token with server: ${ApiService.lastError}');
        }
      }

      // Listen for token rotation
      messaging.onTokenRefresh.listen((newToken) async {
        _lastToken = newToken;
        final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
        await ApiService.registerDeviceToken(
          token: newToken,
          platform: platform,
          deviceName: Platform.isIOS ? 'iPhone' : 'Android Device',
        );
        debugPrint('[FCM] Refreshed device token synced to server');
      });
    } catch (e) {
      debugPrint('[FCM] Error registering device token: $e');
    }
  }

  /// Unregister device token upon user logout
  Future<void> unregisterDeviceToken() async {
    try {
      if (_lastToken != null && _lastToken!.isNotEmpty) {
        await ApiService.unregisterDeviceToken(token: _lastToken);
      } else {
        await ApiService.unregisterDeviceToken();
      }
      debugPrint('[FCM] Device token unregistered upon logout');
    } catch (e) {
      debugPrint('[FCM] Error unregistering device token: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Pamba Milk Delivery';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

    const androidDetails = AndroidNotificationDetails(
      'pamba_milk_delivery',
      'Pamba Delivery Alerts',
      channelDescription: 'Real-time updates for morning milk delivery, orders, and wallet.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    final payloadStr = jsonEncode(message.data);
    _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payloadStr,
    );
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (message.notification != null) {
      data.putIfAbsent('title', () => message.notification!.title ?? '');
      data.putIfAbsent('body', () => message.notification!.body ?? '');
    }
    _handleDataPayload(data);
  }

  void _handleDataPayload(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final appState = AppState();
      final targetScreen = (data['target_screen'] ?? data['screen'] ?? '').toString();
      final targetParam = (data['target_param'] ?? data['order_id'] ?? data['param'] ?? '').toString();
      final title = (data['title'] ?? 'Notification').toString();
      final message = (data['body'] ?? data['message'] ?? '').toString();
      final type = (data['notification_type'] ?? data['type'] ?? 'DELIVERY').toString();

      final notif = NotificationModel(
        id: int.tryParse(data['notification_id']?.toString() ?? '') ?? 0,
        title: title,
        message: message,
        notificationType: type,
        targetScreen: targetScreen,
        targetParam: targetParam,
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      );

      NotificationRouter.navigate(context, notif, appState);
    } catch (e) {
      debugPrint('[FCM] Error routing notification payload: $e');
    }
  }
}
