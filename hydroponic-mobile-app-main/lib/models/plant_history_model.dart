import 'package:flutter/material.dart';

class PlantHistoryModel {
  final String date;
  final int plantQty;
  final int harvestQty;
  final int plantDocCount;
  final int harvestDocCount;
  
  final VoidCallback onPlantEdit;
  final VoidCallback onHarvestEdit;
  final VoidCallback onDeletePlant;
  final VoidCallback onDeleteHarvest;
  final VoidCallback onDeleteAll;

  PlantHistoryModel({
    required this.date,
    required this.plantQty,
    required this.harvestQty,
    required this.plantDocCount,
    required this.harvestDocCount,
    required this.onPlantEdit,
    required this.onHarvestEdit,
    required this.onDeletePlant,  
    required this.onDeleteHarvest,
    required this.onDeleteAll,
  });
}