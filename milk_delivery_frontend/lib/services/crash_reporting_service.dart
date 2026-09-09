import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashReportingService {
  static const String _crashLogKey = 'pamba_crash_logs';

  /// Records a crash locally. In a real production app, this would send
  /// the error to Firebase Crashlytics or Sentry.
  static Future<void> reportCrash(dynamic error, StackTrace? stackTrace) async {
    if (kDebugMode) {
      // In debug mode, just use debugPrint (the default behaviour).
      debugPrint('🚨 [CrashReportingService]: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
      return;
    }

    // In release mode, log locally to SharedPreferences for now.
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final List<String> existingLogs = prefs.getStringList(_crashLogKey) ?? [];
      
      final crashReport = {
        'timestamp': DateTime.now().toIso8601String(),
        'error': error.toString(),
        'stackTrace': stackTrace?.toString(),
        // App version and other info would typically be added here
      };

      existingLogs.add(jsonEncode(crashReport));
      
      // Keep only the last 10 crash reports to avoid filling up storage
      if (existingLogs.length > 10) {
        existingLogs.removeAt(0);
      }

      await prefs.setStringList(_crashLogKey, existingLogs);
    } catch (e) {
      // If we fail to log the crash, print to console as a last resort
      debugPrint('Failed to save crash log: $e');
    }
  }

  /// Retrieves stored crash logs (can be used to send to a server on next launch)
  static Future<List<Map<String, dynamic>>> getCrashLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_crashLogKey) ?? [];
      return logs.map((log) => jsonDecode(log) as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clears stored crash logs
  static Future<void> clearCrashLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashLogKey);
    } catch (_) {}
  }
}
