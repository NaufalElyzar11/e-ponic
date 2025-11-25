import 'package:flutter/material.dart';

class PlantHistoryModel {
  final String date;
  final int plantQty;
  final int harvestQty;
  final VoidCallback onPlantEdit;
  final VoidCallback onPlantDelete;
  final VoidCallback onHarvestEdit;
  final VoidCallback onHarvestDelete;
  final VoidCallback onDeleteAll;

  const PlantHistoryModel({
    required this.date, 
    required this.plantQty, 
    required this.harvestQty, 
    required this.onPlantEdit, 
    required this.onPlantDelete, 
    required this.onHarvestEdit, 
    required this.onHarvestDelete,
    required this.onDeleteAll
  });
}