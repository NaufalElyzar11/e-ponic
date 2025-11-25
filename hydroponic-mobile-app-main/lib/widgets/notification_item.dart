import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/notification_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;

  const NotificationItem({
    super.key,
    required this.notification,
  });

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'transaction':
        return Icons.shopping_cart;
      case 'account':
        return Icons.person_add;
      case 'maintenance':
        return Icons.eco;
      case 'harvest':
        return Icons.agriculture;
      case 'shipping':
        return Icons.local_shipping;
      case 'delivery':
        return Icons.delivery_dining;
      case 'delivery_status':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'transaction':
        return Colors.blue;
      case 'account':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'harvest':
        return Colors.brown;
      case 'shipping':
        return Colors.purple;
      case 'delivery':
        return Colors.teal;
      case 'delivery_status':
        return Colors.indigo;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: notification.isRead
          ? Colors.grey[100]
          : Colors.white,
      elevation: notification.isRead ? 1 : 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon berdasarkan type
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getColorForType(notification.type)?.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconForType(notification.type),
                color: _getColorForType(notification.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: notification.isRead
                                ? Colors.grey[600]
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        notification.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}