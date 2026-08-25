import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

class DriverChatMessage {
  final String text;
  final bool isDriver;
  final DateTime timestamp;

  DriverChatMessage({
    required this.text,
    required this.isDriver,
    required this.timestamp,
  });
}

class DriverDeliveryChatSheet extends StatefulWidget {
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String orderSummary;
  final String slotTime;

  const DriverDeliveryChatSheet({
    super.key,
    required this.customerName,
    this.customerPhone = '',
    this.deliveryAddress = 'Doorstep Delivery Location',
    this.orderSummary = 'Morning Milk Delivery',
    this.slotTime = '05:30 AM - 07:00 AM',
  });

  static void show(
    BuildContext context, {
    required String customerName,
    String customerPhone = '',
    String deliveryAddress = 'Doorstep Delivery Location',
    String orderSummary = 'Morning Milk Delivery',
    String slotTime = '05:30 AM - 07:00 AM',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DriverDeliveryChatSheet(
          customerName: customerName,
          customerPhone: customerPhone,
          deliveryAddress: deliveryAddress,
          orderSummary: orderSummary,
          slotTime: slotTime,
        ),
      ),
    );
  }

  @override
  State<DriverDeliveryChatSheet> createState() => _DriverDeliveryChatSheetState();
}

class _DriverDeliveryChatSheetState extends State<DriverDeliveryChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<DriverChatMessage> _messages = [
    DriverChatMessage(
      text: 'Namaste! I am on the way with your morning milk delivery.',
      isDriver: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
    ),
    DriverChatMessage(
      text: 'Please leave the packet inside the milk bag at the door. Thank you!',
      isDriver: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
  ];

  static const List<String> _quickUpdates = [
    '🛵 Reached your building / gate',
    '🚪 Placed inside doorstep milk bag',
    '🔔 Rang doorbell once',
    '🔑 Please share 4-digit delivery OTP',
    '📦 Handed over to security guard',
    '❄️ Milk is chilled at 4°C',
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
      _messages.add(DriverChatMessage(
        text: text,
        isDriver: true,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();

    // Simulated Customer Response
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      String reply = 'Thank you! Received.';
      if (text.contains('OTP') || text.contains('otp')) {
        reply = 'My delivery OTP is 4821. Thank you!';
      } else if (text.contains('gate') || text.contains('building')) {
        reply = 'Opening the gate now! Door 302 on 3rd floor.';
      } else if (text.contains('doorstep') || text.contains('Placed') || text.contains('bag')) {
        reply = 'Got the milk packet from the doorstep bag! Much appreciated.';
      } else if (text.contains('security')) {
        reply = 'Perfect, I will collect it from the security gate.';
      }

      setState(() {
        _messages.add(DriverChatMessage(
          text: reply,
          isDriver: false,
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

  Future<void> _callCustomer() async {
    if (widget.customerPhone.isEmpty) return;
    final clean = widget.customerPhone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendWhatsApp() async {
    if (widget.customerPhone.isEmpty) return;
    var phone = widget.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!phone.startsWith('91') && phone.length == 10) {
      phone = '91$phone';
    }
    final message = Uri.encodeComponent(
      'Namaste ${widget.customerName}! I have arrived with your MilkDrop order at ${widget.deliveryAddress}. Please collect or provide OTP.',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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

          // Header: Customer Info & Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: UiTone.primarySoft,
                  child: const Text('🏡', style: TextStyle(fontSize: 20)),
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
                              widget.customerName,
                              style: UiText.bodyStrong.copyWith(fontSize: 15.5, fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: UiTone.successSoft,
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                            ),
                            child: Text('CUSTOMER', style: UiText.caption.copyWith(color: UiTone.success, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.orderSummary} • ${widget.slotTime}',
                        style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Call CTA
                if (widget.customerPhone.isNotEmpty)
                  IconButton.filledTonal(
                    onPressed: _callCustomer,
                    icon: const Icon(Icons.phone_rounded, size: 18, color: UiTone.primary),
                    tooltip: 'Call Customer',
                    style: IconButton.styleFrom(backgroundColor: UiTone.primarySoft),
                  ),
                const SizedBox(width: 4),
                // WhatsApp CTA
                if (widget.customerPhone.isNotEmpty)
                  IconButton.filledTonal(
                    onPressed: _sendWhatsApp,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF25D366)),
                    tooltip: 'WhatsApp',
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F8EE)),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: UiTone.ink),
                ),
              ],
            ),
          ),

          // Address Ribbon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: UiTone.surfaceMuted,
            child: Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: UiTone.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UiText.caption.copyWith(fontWeight: FontWeight.w700, color: UiTone.ink, fontSize: 11.5),
                  ),
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
                final isMe = msg.isDriver;
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

          // Quick 1-Tap Driver Updates
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickUpdates.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final update = _quickUpdates[i];
                return ActionChip(
                  label: Text(update, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: () => _sendMessage(update),
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
                        hintText: 'Message customer regarding drop...',
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
