import 'package:flutter/material.dart';

class UserModel{
  final String username;
  final String role;
  final VoidCallback onNotificationTap;
  final String? id; // optional Firestore document ID

  UserModel({
    required this.username,
    required this.role,
    required this.onNotificationTap,
    this.id,
  });
}