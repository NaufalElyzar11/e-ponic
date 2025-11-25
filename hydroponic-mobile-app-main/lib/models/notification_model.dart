class NotificationModel {
  final String title;
  final String date;
  final String time;
  final bool isRead;

  NotificationModel({
    required this.title,
    required this.date,
    required this.time,
    this.isRead = false
  });
}