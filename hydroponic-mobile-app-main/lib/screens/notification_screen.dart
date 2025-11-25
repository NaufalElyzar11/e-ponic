import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/notification_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/notification_item.dart';

class NotificationScreen extends StatefulWidget{
  const NotificationScreen({super.key});
  
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationModel> _data = [
    NotificationModel(
      title: 'Penambahan Nutrisi', 
      date: '25 Juni 2025', 
      time: '08:00 AM',
      isRead: true
    ),
    NotificationModel(
      title: 'Penggantian Air', 
      date: '26 Juni 2025', 
      time: '09:00 AM',
    ),
    NotificationModel(
      title: 'Pemeriksaan pH Air', 
      date: '27 Juni 2025', 
      time: '10:00 AM',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: ListView.builder(
          itemCount: _data.length,
          itemBuilder: (BuildContext context, int index) {
            return NotificationItem(
              notification: _data[index],
            );
          },
        ),
      ),
    );
  }
}