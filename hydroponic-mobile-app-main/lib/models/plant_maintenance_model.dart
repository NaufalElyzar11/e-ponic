import 'package:flutter/material.dart';

class PlantMaintenanceModel {
  final String maintenanceName;
  final String description;
  final String date;
  final String time;
  final VoidCallback onTap;
  final bool isDone;

  PlantMaintenanceModel({
    required this.maintenanceName,
    required this.description,
    required this.date,
    required this.time,
    required this.onTap,
    this.isDone = false
  });
}