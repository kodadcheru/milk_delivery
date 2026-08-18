import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/support_chat_model.dart';

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
  String _serverUrl = 'wss://milk-delivery-backend-production.up.railway.app/ws/support/';

  void connect({String? customUrl, String? userPhone, String? userName}) {
    if (customUrl != null) _serverUrl = customUrl;

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

    // 3. Intelligent Instant Support Agent / Assistant auto-response
    _dispatchAutomatedAgentReply(text, orderId: orderId);
  }

  void _dispatchAutomatedAgentReply(String userQuery, {String? orderId}) {
    _typingController.add(true);

    Future.delayed(const Duration(milliseconds: 1200), () {
      _typingController.add(false);

      final lower = userQuery.toLowerCase();
      String replyText;
      List<String>? quickReplies;

      if (lower.contains('where') || lower.contains('track') || lower.contains('order') || lower.contains('late') || lower.contains('delivery')) {
        replyText = '🥛 Your morning farm delivery is scheduled for guaranteed dispatch by 05:30 AM and doorstep delivery by 06:00 AM.\n\nOur driver will place the chilled insulated bag at your doorstep and notify you with a live delivery photo proof! 📸';
        quickReplies = ['Track live on Map', 'Contact Driver', 'I need immediate assistance'];
      } else if (lower.contains('vacation') || lower.contains('pause') || lower.contains('stop')) {
        replyText = '🏖️ Going on vacation? You can easily pause your daily subscription anytime with 1 tap from the Subscriptions Tab!\n\nNo charges will be deducted from your wallet for paused days.';
        quickReplies = ['Pause Subscription', 'Check Wallet Balance'];
      } else if (lower.contains('wallet') || lower.contains('refund') || lower.contains('money') || lower.contains('balance')) {
        replyText = '💳 All unused subscription days and skipped deliveries are automatically credited back to your prepaid wallet in real-time. You can top up anytime via UPI or Card in the Wallet tab.';
        quickReplies = ['Open Wallet', 'Top Up ₹500', 'Top Up ₹1000'];
      } else if (lower.contains('quantity') || lower.contains('change') || lower.contains('more milk') || lower.contains('extra')) {
        replyText = '🥛 Need extra milk tomorrow? Simply go to your Active Subscription and use the + / - steppers to adjust your daily liters before 10:00 PM!';
        quickReplies = ['Change Quantity', 'Add Water Cans', 'Add Fresh Eggs'];
      } else if (lower.contains('call') || lower.contains('human') || lower.contains('agent') || lower.contains('specialist')) {
        replyText = '👨‍💼 Routing you to our senior live support manager... You can also dial our 24/7 toll-free priority line at 1800-6455-3767 for instant telephone assistance!';
        quickReplies = ['📞 Call 1800-6455-3767', '💬 Continue Chat'];
      } else {
        replyText = '👋 Thank you for contacting MilkDrop Express Support! I am connected to your account. How can our team assist you with your delivery, subscriptions, or fresh orders today?';
        quickReplies = ['Delivery Timing ⏰', 'Vacation Pause 🏖️', 'Wallet & Refunds 💳', 'Speak to Agent 👨‍💼'];
      }

      final agentMsg = SupportChatMessage(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
        senderType: MessageSenderType.agent,
        senderName: 'Priya (MilkDrop Support)',
        text: replyText,
        timestamp: DateTime.now(),
        quickReplies: quickReplies,
        orderId: orderId,
      );

      _messageController.add(agentMsg);
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _typingController.close();
    _connectionStatusController.close();
  }
}
