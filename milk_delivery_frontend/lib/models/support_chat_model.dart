import 'package:flutter/material.dart';

enum MessageSenderType { user, agent, bot, system }

class SupportChatMessage {
  final String id;
  final MessageSenderType senderType;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final List<String>? quickReplies;
  final String? orderId;
  final bool isRead;
  final String? attachmentUrl;

  const SupportChatMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.quickReplies,
    this.orderId,
    this.isRead = true,
    this.attachmentUrl,
  });

  bool get isUser => senderType == MessageSenderType.user;

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    MessageSenderType type;
    switch (json['sender_type']?.toString().toLowerCase()) {
      case 'user':
        type = MessageSenderType.user;
        break;
      case 'agent':
        type = MessageSenderType.agent;
        break;
      case 'bot':
        type = MessageSenderType.bot;
        break;
      default:
        type = MessageSenderType.system;
    }

    return SupportChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderType: type,
      senderName: json['sender_name'] as String? ?? (type == MessageSenderType.user ? 'You' : 'MilkDrop Support'),
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      quickReplies: (json['quick_replies'] as List?)?.map((e) => e.toString()).toList(),
      orderId: json['order_id']?.toString(),
      isRead: json['is_read'] as bool? ?? true,
      attachmentUrl: json['attachment_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_type': senderType.name,
      'sender_name': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (quickReplies != null) 'quick_replies': quickReplies,
      if (orderId != null) 'order_id': orderId,
      'is_read': isRead,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
    };
  }
}

class SupportFaqTopic {
  final String id;
  final String title;
  final String icon;
  final Color accentColor;
  final String answer;
  final List<String> quickPromptSuggestions;

  const SupportFaqTopic({
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.answer,
    required this.quickPromptSuggestions,
  });
}
