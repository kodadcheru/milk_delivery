import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request Location Permission (Foreground / When In Use)
  static Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled on device
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }
  }

  /// Request Push Notification Permission
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Check whether Location permission is granted
  static Future<bool> hasLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Check whether Notification permission is granted
  static Future<bool> hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Get real-time Device GPS Coordinates with Instant Fallback
  static Future<Position?> getDeviceCoordinates() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return await Geolocator.getLastKnownPosition();
      }

      LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.otherNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: false,
          timeLimit: const Duration(seconds: 4),
        );
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          forceLocationManager: true,
          intervalDuration: const Duration(milliseconds: 500),
          timeLimit: const Duration(seconds: 4),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 4),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      return position;
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}
