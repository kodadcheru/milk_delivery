import 'package:flutter/foundation.dart';

enum AppEnvironment { development, staging, production }

class AppConfig {
  static const AppEnvironment environment = kReleaseMode
      ? AppEnvironment.production
      : AppEnvironment.development;

  /// Base URL configuration
  /// In iOS simulator: 127.0.0.1:8000
  /// In Android emulator: 10.0.2.2:8000
  /// In production cloud: https://api.milkdrop.com
  static String get apiBaseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://milk-delivery-backend-production.up.railway.app/api',
    );
  }

  static String get baseUrl {
    final base = apiBaseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  /// Google Maps API Key — override via --dart-define=GOOGLE_MAPS_API_KEY=...
  static String get googleMapsApiKey {
    return const String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: '', // Must be provided via --dart-define
    );
  }

  static const Duration requestTimeout = Duration(seconds: 12);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(milliseconds: 600);

  static const String appName = 'Pamba';
  static const String appVersion = '1.0.0+1';
  static const String supportPhone = '+91 8919548905';
  static const String adminPhone = '+91 8919548905';
  static const String adminWhatsApp = '918919548905';
  static const String supportEmail = 'support@pamba.in';

  // Geographic & Hub Fallbacks
  static const double defaultLatitude = 17.001734;
  static const double defaultLongitude = 79.962500;
  static const String defaultCity = 'Kodad';
  static const String defaultHubName = 'Central Operational Hub';
  static const String defaultHubAddress = 'Kodad, Telangana 508206, India';
  static const String defaultFssai = '13621014000342';

  static String getWhatsAppUrl(String phone, {String text = ''}) {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) clean = '91$clean';
    if (clean.length == 12 && clean.startsWith('91')) { /* ok */ }
    final encoded = Uri.encodeComponent(text);
    return 'https://wa.me/$clean?text=$encoded';
  }
}
