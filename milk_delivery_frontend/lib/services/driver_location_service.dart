import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

/// Background and Foreground real-time location tracker for Pamba delivery drivers.
/// Uses native Foreground Services on Android and UIBackgroundModes: location on iOS
/// to ensure delivery tracking stays active even when the phone is locked or driver switches to Google Maps.
class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  bool _isRunning = false;
  DateTime? _lastApiSentTime;
  Position? _lastSentPosition;

  bool get isTracking => _isRunning;
  Stream<Position> get positionStream => _positionController.stream;
  Position? get currentPosition => _lastSentPosition;

  /// Starts background GPS tracking if permissions are granted.
  Future<bool> startTracking() async {
    if (_isRunning) return true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[DriverLocationService] Location service disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[DriverLocationService] Location permission denied: $permission');
        return false;
      }

      // Configure platform-specific background location settings
      late final LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Minimum 10 meters change
          forceLocationManager: false,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: 'Sharing live location for active deliveries',
            notificationTitle: 'Pamba Delivery Tracking Active',
            enableWakeLock: true,
            notificationIcon: AndroidResource(name: 'ic_launcher'),
            color: Color(0xFF0D7C66),
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 10,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        );
      }

      // Cancel any previous subscription
      await _positionSubscription?.cancel();

      // Start continuous stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handlePositionUpdate,
        onError: (error) {
          debugPrint('[DriverLocationService] Error in position stream: $error');
        },
      );

      _isRunning = true;
      debugPrint('[DriverLocationService] Background location tracking started successfully.');

      // Also grab an immediate single position to sync right away
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
        await _handlePositionUpdate(currentPos, force: true);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[DriverLocationService] Failed to start tracking: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stops tracking and marks the driver offline if needed
  Future<void> stopTracking({bool sendOffline = true}) async {
    if (!_isRunning && _positionSubscription == null) return;

    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _isRunning = false;
      debugPrint('[DriverLocationService] Background tracking stopped.');

      if (sendOffline && _lastSentPosition != null) {
        await ApiService.updateDriverLocation(
          latitude: _lastSentPosition!.latitude,
          longitude: _lastSentPosition!.longitude,
          status: 'OFFLINE',
        );
      }
    } catch (e) {
      debugPrint('[DriverLocationService] Error stopping tracking: $e');
    }
  }

  /// Handles incoming GPS position and updates the backend API with throttling
  Future<void> _handlePositionUpdate(Position position, {bool force = false}) async {
    final now = DateTime.now();

    // Throttling: send at most once every 5 seconds unless forced
    if (!force && _lastApiSentTime != null) {
      final elapsed = now.difference(_lastApiSentTime!);
      if (elapsed.inSeconds < 5) {
        return;
      }
    }

    _lastApiSentTime = now;
    _lastSentPosition = position;
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }

    try {
      await ApiService.updateDriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        status: 'ON_DUTY',
      );
    } catch (e) {
      debugPrint('[DriverLocationService] Failed to update location via API: $e');
    }
  }
}
