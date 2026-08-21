import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class HubRealtimeService {
  static WebSocketChannel? _channel;
  static Timer? _pingTimer;
  static Timer? _reconnectTimer;
  static bool _isConnected = false;
  static String? _currentHubCode;
  static Function(Map<String, dynamic>)? _onEventCallback;
  static Function(bool)? _onStatusCallback;
  static int _reconnectAttempts = 0;

  static bool get isConnected => _isConnected;

  static void connect({
    required String hubCode,
    required Function(Map<String, dynamic> event) onEvent,
    Function(bool isConnected)? onStatusChange,
  }) {
    _currentHubCode = hubCode;
    _onEventCallback = onEvent;
    _onStatusCallback = onStatusChange;
    _reconnectAttempts = 0;
    _initWebSocket();
  }

  static void _initWebSocket() {
    _cleanup();

    if (_currentHubCode == null) return;

    try {
      final base = ApiService.baseUrl;
      final wsScheme = base.startsWith('https://') ? 'wss://' : 'ws://';
      final host = base.replaceFirst(RegExp(r'^https?:\/\/'), '').replaceFirst(RegExp(r'\/api\/?$'), '');
      final wsUrl = Uri.parse('$wsScheme$host/ws/hub/$_currentHubCode/');

      debugPrint('🔌 [Redis Hub WebSocket] Connecting to $wsUrl');
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message.toString());
            debugPrint('⚡ [Redis Hub Event] ${data['type']} / ${data['event_type']}');

            if (data['type'] == 'connection_established') {
              _isConnected = true;
              _reconnectAttempts = 0;
              _onStatusCallback?.call(true);
              _startPingTimer();
            }

            _onEventCallback?.call(data);
          } catch (e) {
            debugPrint('⚠️ [Redis Hub Parse Error] $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [Redis Hub WebSocket Error] $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('🔌 [Redis Hub WebSocket Closed]');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Optimistically mark as active once connected
      _isConnected = true;
      _onStatusCallback?.call(true);
      _startPingTimer();
    } catch (e) {
      debugPrint('❌ [Redis Hub Connection Exception] $e');
      _handleDisconnect();
    }
  }

  static void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'action': 'ping'}));
        } catch (_) {}
      }
    });
  }

  static void _handleDisconnect() {
    _isConnected = false;
    _onStatusCallback?.call(false);
    _cleanup();

    // Reconnect with exponential backoff
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts > 5 ? 10 : 2 * _reconnectAttempts).clamp(2, 15));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentHubCode != null) {
        debugPrint('🔄 [Redis Hub WebSocket] Attempting reconnect...');
        _initWebSocket();
      }
    });
  }

  static void sendBroadcast(String message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          'action': 'broadcast_alert',
          'message': message,
        }));
      } catch (_) {}
    }
  }

  static void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  static void disconnect() {
    _currentHubCode = null;
    _onEventCallback = null;
    _onStatusCallback = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    _cleanup();
  }
}
