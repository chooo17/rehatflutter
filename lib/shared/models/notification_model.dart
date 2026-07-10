/// Notifikasi pengguna (dari `GET /notifications`).
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type = '',
    this.isRead = false,
    this.sentAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? sentAt;

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        sentAt: sentAt,
      );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? json['message'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      isRead: (json['is_read'] ?? json['isRead'] ?? false) == true,
      sentAt: DateTime.tryParse((json['sent_at'] ?? json['created_at'] ?? '').toString()),
    );
  }
}
