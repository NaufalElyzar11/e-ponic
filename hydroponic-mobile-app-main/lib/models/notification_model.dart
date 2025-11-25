class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String date;
  final String time;
  final bool isRead;
  final String? type;
  final String? referenceId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.time,
    this.isRead = false,
    this.type,
    this.referenceId,
  });

  /// Factory constructor untuk membuat dari Map (dari Firestore)
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      date: map['date'] as String? ?? '',
      time: map['time'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      type: map['type'] as String?,
      referenceId: map['referenceId'] as String?,
    );
  }
}