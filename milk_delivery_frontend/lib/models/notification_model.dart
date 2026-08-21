class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String notificationType; // DELIVERY, WALLET, VACATION, OFFER, SUBSCRIPTION, SUPPORT, BATCH
  final String targetScreen; // DELIVERIES, WALLET, SUBSCRIPTIONS, CATEGORY, OFFERS, SUPPORT, ADDRESS, BATCH, DRIVER_ROUTE
  final String targetParam; // category key, product ID, order ID, etc.
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    this.targetScreen = '',
    this.targetParam = '',
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      notificationType: json['notification_type'] ?? 'DELIVERY',
      targetScreen: json['target_screen'] ?? '',
      targetParam: json['target_param'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }

  NotificationModel copyWith({
    bool? isRead,
    String? targetScreen,
    String? targetParam,
  }) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      targetScreen: targetScreen ?? this.targetScreen,
      targetParam: targetParam ?? this.targetParam,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
