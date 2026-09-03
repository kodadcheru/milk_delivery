import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/support_chat_model.dart';
import 'api_service.dart';

class SupportSocketService {
  static final SupportSocketService _instance = SupportSocketService._internal();
  factory SupportSocketService() => _instance;
  SupportSocketService._internal();

  WebSocketChannel? _channel;
  final _messageController = StreamController<SupportChatMessage>.broadcast();
  final _typingController = StreamController<bool>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  Stream<SupportChatMessage> get messageStream => _messageController.stream;
  Stream<bool> get typingStream => _typingController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _reconnectTimer;
  String _serverUrl = '';

  String get _defaultServerUrl {
    // Derive WebSocket URL from the API base URL
    final base = AppConfig.apiBaseUrl
        .replaceFirst(RegExp(r'/api/?$'), '')  // Remove trailing /api
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/support/';
  }

  void connect({String? customUrl, String? userPhone, String? userName}) {
    if (customUrl != null) _serverUrl = customUrl;
    if (_serverUrl.isEmpty) _serverUrl = _defaultServerUrl;

    try {
      final uri = Uri.parse('$_serverUrl?phone=${userPhone ?? ""}&name=${userName ?? ""}');
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _connectionStatusController.add(true);

      _channel?.stream.listen(
        (dynamic data) {
          try {
            final parsed = jsonDecode(data.toString());
            if (parsed is Map<String, dynamic>) {
              if (parsed['type'] == 'typing') {
                _typingController.add(parsed['is_typing'] == true);
              } else {
                final msg = SupportChatMessage.fromJson(parsed);
                _messageController.add(msg);
              }
            }
          } catch (_) {}
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _reconnectTimer?.cancel();
    // Auto-reconnect attempts every 8 seconds
    _reconnectTimer = Timer(const Duration(seconds: 8), () {
      connect();
    });
  }

  void sendMessage({
    required String text,
    String senderName = 'You',
    String? orderId,
    String? userPhone,
  }) {
    final userMsg = SupportChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderType: MessageSenderType.user,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
      orderId: orderId,
    );

    // 1. Locally emit user message for instant UI responsiveness
    _messageController.add(userMsg);

    // 2. Transmit over WebSocket channel if connected
    if (_isConnected && _channel != null) {
      try {
        _channel?.sink.add(jsonEncode(userMsg.toJson()));
      } catch (_) {}
    }

    // 3. Transmit via HTTP POST to backend DB & Redis so Web Admin Console receives it
    final phone = (userPhone != null && userPhone.isNotEmpty) ? userPhone : AppConfig.supportPhone;
    ApiService.sendSupportChatMessage(
      phone: phone,
      text: text,
      senderType: 'user',
      senderName: senderName,
      orderId: orderId,
    ).then((res) {
      if (res != null && res['auto_reply'] is Map<String, dynamic>) {
        final autoReply = res['auto_reply'] as Map<String, dynamic>;
        final agentMsg = SupportChatMessage(
          id: autoReply['id']?.toString() ?? 'rep_${DateTime.now().millisecondsSinceEpoch}',
          senderType: MessageSenderType.agent,
          senderName: autoReply['sender_name']?.toString() ?? 'Priya (Pamba Care)',
          text: autoReply['text']?.toString() ?? '',
          timestamp: DateTime.now(),
          orderId: orderId,
        );
        _messageController.add(agentMsg);
      }
    }).catchError((_) {});
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _typingController.close();
    _connectionStatusController.close();
  }
}

