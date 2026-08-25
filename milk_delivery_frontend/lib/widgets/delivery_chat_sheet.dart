import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

class DeliveryChatMessage {
  final String text;
  final bool isCustomer;
  final DateTime timestamp;
  final String senderName;

  DeliveryChatMessage({
    required this.text,
    required this.isCustomer,
    required this.timestamp,
    this.senderName = '',
  });
}

class DeliveryChatSheet extends StatefulWidget {
  final int? taskId;
  final String? orderId;
  final String driverName;
  final String driverPhone;
  final String customerName;
  final String customerPhone;
  final String orderTitle;
  final String deliveryAddress;

  const DeliveryChatSheet({
    super.key,
    this.taskId,
    this.orderId,
    required this.driverName,
    this.driverPhone = '',
    this.customerName = 'Customer',
    this.customerPhone = '',
    this.orderTitle = 'Morning Milk Delivery',
    this.deliveryAddress = 'Doorstep Delivery Address',
  });

  static void show(
    BuildContext context, {
    int? taskId,
    String? orderId,
    required String driverName,
    String driverPhone = '',
    String customerName = 'Customer',
    String customerPhone = '',
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
          taskId: taskId,
          orderId: orderId,
          driverName: driverName,
          driverPhone: driverPhone,
          customerName: customerName,
          customerPhone: customerPhone,
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
  Timer? _pollTimer;
  bool _isLoading = true;

  String get _channelKey {
    if (widget.taskId != null && widget.taskId! > 0) {
      return 'delivery_task_${widget.taskId}';
    }
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      return 'delivery_order_${widget.orderId}';
    }
    final cleanPhone = widget.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'delivery_cust_${cleanPhone.isNotEmpty ? cleanPhone : widget.customerName.toLowerCase().replaceAll(' ', '_')}';
  }

  final List<DeliveryChatMessage> _messages = [];

  static const List<String> _quickInstructions = [
    '🚪 Leave at doorstep milk bag',
    '🔔 Ring bell once',
    '🤫 Do not ring, baby sleeping',
    '🏢 Hand over to security gate',
    '❄️ Keep inside insulated chiller bag',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLiveMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveMessages({bool silent = false}) async {
    final rawMessages = await ApiService.fetchDeliveryChatHistory(
      channelKey: _channelKey,
      taskId: widget.taskId,
      orderId: widget.orderId,
    );

    if (!mounted) return;

    if (rawMessages.isNotEmpty) {
      final parsed = rawMessages.map<DeliveryChatMessage>((m) {
        final role = (m['sender_role'] ?? 'CUSTOMER').toString().toUpperCase();
        final isCust = role == 'CUSTOMER' || m['is_driver'] == false;
        final tsStr = m['timestamp']?.toString();
        final ts = tsStr != null ? (DateTime.tryParse(tsStr) ?? DateTime.now()) : DateTime.now();

        return DeliveryChatMessage(
          text: m['text']?.toString() ?? '',
          isCustomer: isCust,
          timestamp: ts,
          senderName: m['sender_name']?.toString() ?? (isCust ? 'You' : widget.driverName),
        );
      }).toList();

      final previousCount = _messages.length;
      setState(() {
        _messages.clear();
        _messages.addAll(parsed);
        _isLoading = false;
      });

      if (parsed.length > previousCount) {
        _scrollToBottom();
      }
    } else {
      if (_messages.isEmpty) {
        setState(() {
          _messages.add(
            DeliveryChatMessage(
              text: 'Namaste! I am on the way with your chilled milk delivery. Please let me know any doorstep instructions.',
              isCustomer: false,
              timestamp: DateTime.now(),
              senderName: widget.driverName,
            ),
          );
          _isLoading = false;
        });
      }
    }
  }

  void _sendMessage([String? customText]) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;

    if (customText == null) _textController.clear();

    final localMsg = DeliveryChatMessage(
      text: text,
      isCustomer: true,
      timestamp: DateTime.now(),
      senderName: widget.customerName,
    );

    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    await ApiService.sendDeliveryChatMessage(
      channelKey: _channelKey,
      taskId: widget.taskId,
      orderId: widget.orderId,
      senderRole: 'CUSTOMER',
      senderName: widget.customerName,
      senderPhone: widget.customerPhone,
      text: text,
    );

    _fetchLiveMessages(silent: true);
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
    final phone = widget.driverPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver contact number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
      ),
      child: Column(
        children: [
          // ── Drag Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: UiTone.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: UiTone.accentBlue.withValues(alpha: 0.12),
                  child: const Icon(Icons.two_wheeler_rounded, color: UiTone.accentBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.driverName,
                              style: UiText.h2.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: UiTone.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: UiTone.success, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(
                                  'Delivery Live',
                                  style: UiText.caption.copyWith(color: UiTone.success, fontWeight: FontWeight.w800, fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assigned Partner • ${widget.orderTitle}',
                        style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Call Driver
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: UiTone.primary, size: 22),
                  onPressed: _callDriver,
                  tooltip: 'Call Partner',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Quick Instruction Chips ──
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickInstructions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final instruction = _quickInstructions[idx];
                return ActionChip(
                  label: Text(
                    instruction,
                    style: UiText.caption.copyWith(color: UiTone.ink, fontWeight: FontWeight.w600, fontSize: 11.5),
                  ),
                  backgroundColor: UiTone.surfaceMuted,
                  side: const BorderSide(color: UiTone.surfaceBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _sendMessage(instruction),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // ── Chat Messages ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: UiTone.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = _messages[idx];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // ── Input Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: UiTone.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: UiTone.surfaceMuted,
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                      border: Border.all(color: UiTone.surfaceBorder),
                    ),
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      style: UiText.body.copyWith(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.driverName.split(" ").first}...',
                        hintStyle: UiText.body.copyWith(color: UiText.muted, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: UiTone.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DeliveryChatMessage msg) {
    final isCustomer = msg.isCustomer;
    final timeStr = '${msg.timestamp.hour.toString().padLeft(2, "0")}:${msg.timestamp.minute.toString().padLeft(2, "0")}';

    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCustomer ? UiTone.primary : UiTone.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(UiRadius.md),
            topRight: const Radius.circular(UiRadius.md),
            bottomLeft: Radius.circular(isCustomer ? UiRadius.md : 2),
            bottomRight: Radius.circular(isCustomer ? 2 : UiRadius.md),
          ),
          border: isCustomer ? null : Border.all(color: UiTone.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: UiText.body.copyWith(
                color: isCustomer ? Colors.white : UiTone.ink,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: UiText.caption.copyWith(
                    color: isCustomer ? Colors.white.withValues(alpha: 0.7) : UiTone.softText,
                    fontSize: 10,
                  ),
                ),
                if (isCustomer) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
