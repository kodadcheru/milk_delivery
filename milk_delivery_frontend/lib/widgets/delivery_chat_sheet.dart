import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

class DeliveryChatMessage {
  final String text;
  final bool isCustomer;
  final DateTime timestamp;

  DeliveryChatMessage({
    required this.text,
    required this.isCustomer,
    required this.timestamp,
  });
}

class DeliveryChatSheet extends StatefulWidget {
  final String driverName;
  final String driverPhone;
  final String orderTitle;
  final String deliveryAddress;

  const DeliveryChatSheet({
    super.key,
    required this.driverName,
    this.driverPhone = '',
    this.orderTitle = 'Morning Milk Delivery',
    this.deliveryAddress = 'Doorstep Delivery Address',
  });

  static void show(
    BuildContext context, {
    required String driverName,
    String driverPhone = '',
    String orderTitle = 'Morning Milk Delivery',
    String deliveryAddress = 'Doorstep Delivery Address',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DeliveryChatSheet(
          driverName: driverName,
          driverPhone: driverPhone,
          orderTitle: orderTitle,
          deliveryAddress: deliveryAddress,
        ),
      ),
    );
  }

  @override
  State<DeliveryChatSheet> createState() => _DeliveryChatSheetState();
}

class _DeliveryChatSheetState extends State<DeliveryChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<DeliveryChatMessage> _messages = [
    DeliveryChatMessage(
      text: 'Namaste! I am on the way with your chilled farm-fresh milk batch. Let me know if you have specific drop instructions.',
      isCustomer: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  static const List<String> _quickInstructions = [
    '🚪 Leave at doorstep milk bag',
    '🔔 Ring bell once',
    '🤫 Do not ring, baby sleeping',
    '🏢 Hand over to security gate',
    '❄️ Keep inside insulated chiller bag',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? customText]) {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;

    if (customText == null) _textController.clear();

    setState(() {
      _messages.add(DeliveryChatMessage(
        text: text,
        isCustomer: true,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();

    // Automated Partner Response Simulation
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      String response = 'Got it! Following your delivery instructions.';
      if (text.contains('ring')) {
        response = 'Understood! I will handle the bell accordingly.';
      } else if (text.contains('gate') || text.contains('security')) {
        response = 'Sure, handing over to the security gate upon arrival.';
      } else if (text.contains('bag') || text.contains('doorstep')) {
        response = 'Will neatly place the cold-chain packet inside your doorstep bag! 🥛';
      }

      setState(() {
        _messages.add(DeliveryChatMessage(
          text: response,
          isCustomer: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
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

  Future<void> _callDriver() async {
    if (widget.driverPhone.isEmpty) return;
    final uri = Uri.parse('tel:${widget.driverPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: UiTone.surfaceBorder,
              borderRadius: BorderRadius.circular(UiRadius.pill),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: UiTone.primarySoft,
                      child: const Text('👨‍🌾', style: TextStyle(fontSize: 20)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.driverName,
                              style: UiText.bodyStrong.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: UiTone.primarySoft,
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                            ),
                            child: Text('ON ROUTE', style: UiText.caption.copyWith(color: UiTone.primary, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Direct In-App Delivery Chat', style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11.5)),
                    ],
                  ),
                ),
                if (widget.driverPhone.isNotEmpty)
                  IconButton(
                    onPressed: _callDriver,
                    icon: const Icon(Icons.phone_in_talk_rounded, color: UiTone.primary, size: 22),
                    tooltip: 'Call Driver',
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: UiTone.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: UiTone.surfaceBorder),

          // Message Thread
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.isCustomer;
                final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: isMobile ? 280 : 400),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 13.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Preset Instruction Chips
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickInstructions.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final instruction = _quickInstructions[i];
                return ActionChip(
                  label: Text(instruction, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: () => _sendMessage(instruction),
                );
              },
            ),
          ),

          // Input Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      style: UiText.body.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type instructions for delivery boy...',
                        hintStyle: UiText.caption.copyWith(color: UiTone.softText),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                          borderSide: const BorderSide(color: Color(0xFF0D7C66), width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
