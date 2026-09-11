import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

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
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    if (url.isNotEmpty) return url;
    return kReleaseMode
        ? 'https://milk-delivery-backend-production.up.railway.app/api'
        : 'http://127.0.0.1:8000/api';
  }

  static String get baseUrl {
    final base = apiBaseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  /// Google Maps API Key — dynamically fetched or fallback to --dart-define
  static String _googleMapsApiKey = '';

  static String get googleMapsApiKey {
    if (_googleMapsApiKey.isNotEmpty) return _googleMapsApiKey;
    return const String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: '', // Must be provided via --dart-define
    );
  }

  static Future<void> loadRemoteConfig() async {
    try {
      final config = await ApiService.fetchAppConfig();
      if (config != null) {
        if (config['google_maps_api_key'] != null) {
          final String key = config['google_maps_api_key'];
          if (key.isNotEmpty) {
            _googleMapsApiKey = key;
          }
        }
        
        final res = config;
        if (res['support_phone'] != null && (res['support_phone'] as String).isNotEmpty) {
          _supportPhone = res['support_phone'];
          _adminPhone = res['support_phone'];
        }
        if (res['support_whatsapp'] != null && (res['support_whatsapp'] as String).isNotEmpty) {
          _adminWhatsApp = res['support_whatsapp'];
        }
        if (res['support_email'] != null && (res['support_email'] as String).isNotEmpty) {
          _supportEmail = res['support_email'];
        }
        if (res['default_city'] != null && (res['default_city'] as String).isNotEmpty) {
          _defaultCity = res['default_city'];
        }
      }
    } catch (e) {
      debugPrint('Failed to load remote config: $e');
    }
  }

  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration imageUploadTimeout = Duration(seconds: 45);

  /// Normalizes image URLs to absolute HTTPS URLs if relative or HTTP
  static String normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.startsWith('http://')) {
      return trimmed.replaceFirst('http://', 'https://');
    }
    if (trimmed.startsWith('/')) {
      final base = baseUrl;
      return '$base$trimmed';
    }
    return trimmed;
  }

  // Delivery Slot Constants — should eventually be fetched from backend DeliverySlot model
  static const String defaultMorningSlot = '05:30 AM - 07:00 AM';
  static const String defaultEveningSlot = '07:00 AM - 08:30 AM';
  static const String defaultCutoffDisplay = '06:00 AM';

  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(milliseconds: 600);

  static const String appName = 'Pamba';
  static const String appVersion = '1.0.0+1';
  static String _supportPhone = '+91 8919548905';
  static String _adminPhone = '+91 8919548905';
  static String _adminWhatsApp = '918919548905';
  static String _supportEmail = 'support@pamba.in';

  static String get supportPhone => _supportPhone;
  static String get adminPhone => _adminPhone;
  static String get adminWhatsApp => _adminWhatsApp;
  static String get supportEmail => _supportEmail;

  // Geographic & Hub Fallbacks
  static const double defaultLatitude = 17.001734;
  static const double defaultLongitude = 79.962500;
  static String _defaultCity = 'Kodad';
  static String get defaultCity => _defaultCity;
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
