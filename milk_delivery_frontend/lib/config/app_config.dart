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
    switch (environment) {
      case AppEnvironment.production:
        return const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://milk-delivery-backend-production.up.railway.app/api',
        );
      case AppEnvironment.staging:
        return 'https://milk-delivery-backend-production.up.railway.app/api';
      case AppEnvironment.development:
        return 'http://127.0.0.1:8000/api';
    }
  }

  static const Duration requestTimeout = Duration(seconds: 12);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(milliseconds: 600);

  static const String appName = 'MilkDrop Express';
  static const String appVersion = '1.0.0+1';
  static const String supportPhone = '1800-6455-3767';
  static const String supportEmail = 'support@milkdrop.com';
}
