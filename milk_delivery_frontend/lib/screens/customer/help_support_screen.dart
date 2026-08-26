import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../models/support_chat_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/support_socket_service.dart';

class HelpSupportScreen extends StatefulWidget {
  final AppState state;
  final String? initialTopic;

  const HelpSupportScreen({super.key, required this.state, this.initialTopic});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupportSocketService _socketService = SupportSocketService();

  final List<SupportChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isOnline = true;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _statusSub;

  final List<SupportFaqTopic> _faqs = const [
    SupportFaqTopic(
      id: 'faq_1',
      title: 'What time is morning milk delivered?',
      icon: '⏰',
      accentColor: UiTone.primary,
      answer: 'All daily milk and dawn grocery subscriptions are guaranteed to reach your doorstep between 05:00 AM and 06:00 AM every morning without ringing the bell unless specified.',
      quickPromptSuggestions: ['Check tomorrow morning delivery', 'Add delivery instructions'],
    ),
    SupportFaqTopic(
      id: 'faq_2',
      title: 'How do I pause deliveries for vacation?',
      icon: '🏖️',
      accentColor: UiTone.accentBlue,
      answer: 'Go to the Subscriptions tab, tap your active subscription, and select "Pause Subscription". Choose your start and resume dates. No wallet balance is deducted during paused days.',
      quickPromptSuggestions: ['Pause my subscription', 'Resume my subscription'],
    ),
    SupportFaqTopic(
      id: 'faq_3',
      title: 'How do refunds & wallet balance work?',
      icon: '💳',
      accentColor: UiTone.secondary,
      answer: 'Any un-delivered or skipped items are automatically refunded to your in-app prepaid wallet in real time. Your wallet balance is used for future subscription days or instant orders.',
      quickPromptSuggestions: ['Show my wallet transactions', 'How to top up wallet?'],
    ),
    SupportFaqTopic(
      id: 'faq_4',
      title: 'Can I change my milk quantity for tomorrow?',
      icon: '🥛',
      accentColor: UiTone.warning,
      answer: 'Yes! You can increase or decrease your daily milk quantity (+ / -) from the Subscriptions tab until 10:00 PM the night before.',
      quickPromptSuggestions: ['Increase milk quantity', 'Change to Buffalo Milk'],
    ),
    SupportFaqTopic(
      id: 'faq_5',
      title: 'What is the quality assurance of Vedic A2 Milk?',
      icon: '🌿',
      accentColor: UiTone.success,
      answer: 'Our milk is 100% single-origin Vedic A2 Desi cow milk, pasteurized & chilled below 4°C within 60 minutes of milking, free of antibiotics and synthetic hormones.',
      quickPromptSuggestions: ['View lab test reports', 'Sample farm video'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initial greeting message from support specialist
    _messages.add(
      SupportChatMessage(
        id: 'init_welcome',
        senderType: MessageSenderType.agent,
        senderName: 'Priya (MilkDrop Care)',
        text: '👋 Hello ${widget.state.currentUser?.firstName ?? "there"}! Welcome to MilkDrop 24/7 Priority Support.\n\nHow can we help you with your morning delivery, subscriptions, or orders today?',
        timestamp: DateTime.now(),
        quickReplies: const [
          'Track Morning Delivery 🥛',
          'Vacation Pause Guide 🏖️',
          'Wallet & Refunds 💳',
          'Speak to Live Agent 👨‍💼',
        ],
      ),
    );

    // Connect WebSocket
    _socketService.connect(
      userPhone: widget.state.currentUser?.phone,
      userName: widget.state.currentUser?.fullName,
    );

    // Listen to real-time incoming messages
    _msgSub = _socketService.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
        _scrollToBottom();
      }
    });

    _typingSub = _socketService.typingStream.listen((typing) {
      if (mounted) {
        setState(() {
          _isTyping = typing;
        });
        if (typing) _scrollToBottom();
      }
    });

    _statusSub = _socketService.connectionStatusStream.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    });

    _loadHistory();
    _historyPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _syncIncomingMessages());

    if (widget.initialTopic != null) {
      _sendMessage(widget.initialTopic!);
    }
  }

  Timer? _historyPollTimer;

  Future<void> _loadHistory() async {
    final phone = widget.state.currentUser?.phone ?? '+917794893990';
    final history = await ApiService.fetchSupportChatHistory(phone);
    if (history.isNotEmpty && mounted) {
      final serverMsgs = history.map((h) {
        return SupportChatMessage(
          id: h['id']?.toString() ?? 'hist_${h.hashCode}',
          senderType: h['sender_type'] == 'agent' ? MessageSenderType.agent : MessageSenderType.user,
          senderName: h['sender_name']?.toString() ?? (h['sender_type'] == 'agent' ? 'Support Executive' : 'You'),
          text: h['text']?.toString() ?? '',
          timestamp: h['timestamp'] != null ? (DateTime.tryParse(h['timestamp'].toString()) ?? DateTime.now()) : DateTime.now(),
          orderId: h['order_id']?.toString(),
        );
      }).toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(serverMsgs);
      });
      _scrollToBottom();
    }
  }

  Future<void> _syncIncomingMessages() async {
    final phone = widget.state.currentUser?.phone ?? '+917794893990';
    final history = await ApiService.fetchSupportChatHistory(phone);
    if (history.isNotEmpty && mounted) {
      final serverMsgs = history.map((h) {
        return SupportChatMessage(
          id: h['id']?.toString() ?? 'hist_${h.hashCode}',
          senderType: h['sender_type'] == 'agent' ? MessageSenderType.agent : MessageSenderType.user,
          senderName: h['sender_name']?.toString() ?? (h['sender_type'] == 'agent' ? 'Support Executive' : 'You'),
          text: h['text']?.toString() ?? '',
          timestamp: h['timestamp'] != null ? (DateTime.tryParse(h['timestamp'].toString()) ?? DateTime.now()) : DateTime.now(),
          orderId: h['order_id']?.toString(),
        );
      }).toList();

      // Only update if server list count is different or content changed
      if (serverMsgs.length != _messages.length) {
        setState(() {
          _messages
            ..clear()
            ..addAll(serverMsgs);
        });
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _historyPollTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _statusSub?.cancel();
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final trimmed = text.trim();
    _messageController.clear();

    // 1. Instantly show user message in UI
    final tempMsg = SupportChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderType: MessageSenderType.user,
      senderName: widget.state.currentUser?.firstName ?? 'You',
      text: trimmed,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    // 2. Transmit to backend
    final phone = widget.state.currentUser?.phone ?? '+917794893990';
    ApiService.sendSupportChatMessage(
      phone: phone,
      text: trimmed,
      senderType: 'user',
      senderName: widget.state.currentUser?.fullName ?? 'Customer',
    ).then((_) {
      _syncIncomingMessages();
    });
  }

  Future<void> _callSupportHotline() async {
    final uri = Uri.parse('tel:${AppConfig.adminPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse('https://wa.me/${AppConfig.adminWhatsApp}?text=Hello%20Pamba%20Support,%20I%20need%20help%20with%20my%20delivery.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        backgroundColor: UiTone.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UiTone.surface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: UiTone.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎧', style: TextStyle(fontSize: 18)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isOnline ? UiTone.secondary : Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: UiTone.ink, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help & Live Support',
                  style: TextStyle(color: UiTone.surface, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isOnline ? '🟢 Live WebSocket Active • 2 min response' : '🟡 Offline Bot Assistant Ready',
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call Support 24/7',
            icon: const Icon(Icons.call_rounded, color: UiTone.secondary, size: 22),
            onPressed: _callSupportHotline,
          ),
          IconButton(
            tooltip: 'WhatsApp Help',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 20),
            onPressed: _openWhatsAppSupport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: UiTone.secondary,
          indicatorWeight: 3,
          labelColor: UiTone.secondary,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.forum_rounded, size: 18), text: 'Live Chat (WebSocket)'),
            Tab(icon: Icon(Icons.help_outline_rounded, size: 18), text: 'Quick FAQs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Real-Time Live Chat Room
          _buildLiveChatTab(context),

          // Tab 2: FAQ Accordion
          _buildFaqTab(context),
        ],
      ),
    );
  }

  // ── Tab 1: Live Chat Interface ──
  Widget _buildLiveChatTab(BuildContext context) {
    return Column(
      children: [
        // Live Call-Out Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: UiTone.primary.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: UiTone.primary, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Connected to MilkDrop Priority Care Desk',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: UiTone.primary),
                ),
              ),
              InkWell(
                onTap: _callSupportHotline,
                child: const Text('📞 1800-6455-3767', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: UiTone.primary)),
              ),
            ],
          ),
        ),

        // Chat Messages List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (ctx, idx) {
              if (idx == _messages.length && _isTyping) {
                return _buildTypingBubble();
              }
              final msg = _messages[idx];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        // Message Composer
        _buildMessageComposer(),
      ],
    );
  }

  Widget _buildMessageBubble(SupportChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: UiTone.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, size: 16, color: UiTone.surface),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? UiTone.primary : UiTone.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(UiRadius.md),
                      topRight: const Radius.circular(UiRadius.md),
                      bottomLeft: isUser ? const Radius.circular(UiRadius.md) : const Radius.circular(UiRadius.xs),
                      bottomRight: isUser ? const Radius.circular(UiRadius.xs) : const Radius.circular(UiRadius.md),
                    ),
                    boxShadow: UiShadow.card,
                    border: isUser ? null : Border.all(color: UiTone.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            msg.senderName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: UiTone.primary),
                          ),
                        ),
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : UiTone.ink,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey[500],
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Quick Replies Chips
          if (msg.quickReplies != null && msg.quickReplies!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: msg.quickReplies!.map((reply) {
                  return InkWell(
                    onTap: () => _sendMessage(reply),
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: UiTone.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(UiRadius.lg),
                        border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        reply,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: UiTone.primary),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(color: UiTone.primary, shape: BoxShape.circle),
            child: const Icon(Icons.support_agent_rounded, size: 16, color: UiTone.surface),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.md),
              border: Border.all(color: UiTone.surfaceBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary)),
                SizedBox(width: 8),
                Text('Support Agent is typing...', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UiTone.surface,
        boxShadow: UiShadow.card,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: UiTone.surfaceMuted,
                  borderRadius: BorderRadius.circular(UiRadius.lg),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type your question here...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _sendMessage(_messageController.text),
              borderRadius: BorderRadius.circular(UiRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: UiTone.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: UiTone.surface, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: FAQs ──
  Widget _buildFaqTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Direct Call Assistance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [UiTone.primary, Color(0xFF042F2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(UiRadius.md),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: UiTone.surface.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.headset_mic_rounded, color: UiTone.surface, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Need Instant Phone Help?', style: TextStyle(color: UiTone.surface, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    const Text('Toll-Free 24/7 Priority Hotline', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _callSupportHotline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: UiTone.surface, borderRadius: BorderRadius.circular(UiRadius.xs)),
                        child: const Text('📞 Dial 1800-6455-3767', style: TextStyle(color: UiTone.primary, fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Frequently Asked Questions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: UiTone.ink),
        ),
        const SizedBox(height: 12),

        ..._faqs.map((faq) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md), side: const BorderSide(color: UiTone.surfaceBorder)),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: faq.accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(UiRadius.sm)),
                child: Text(faq.icon, style: const TextStyle(fontSize: 20)),
              ),
              title: Text(faq.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(faq.answer, style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: faq.quickPromptSuggestions.map((prompt) {
                          return ActionChip(
                            label: Text(prompt, style: const TextStyle(fontSize: 11, color: UiTone.primary, fontWeight: FontWeight.w600)),
                            backgroundColor: UiTone.primary.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            onPressed: () {
                              _tabController.animateTo(0);
                              _sendMessage(prompt);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
