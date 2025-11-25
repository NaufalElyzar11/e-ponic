import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/notification_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class NotificationItem extends StatelessWidget{
  final NotificationModel notification;

  const NotificationItem({
    super.key, 
    required this.notification
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color.fromARGB(255, 236, 236, 236),
      child: Padding(
        padding: EdgeInsetsGeometry.symmetric(vertical: 10),
        child: ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                notification.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                ),
              ),
              Icon(
                Icons.circle, 
                size: 10,
                color: notification.isRead ? AppColors.primary : Color.fromARGB(255, 236, 236, 236),
              )
            ],
          ),
          subtitle: Padding(
            padding: EdgeInsetsGeometry.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(notification.date),
                Text(notification.time),
              ],
            ),
          )
        ),
      )
    );
  }
}