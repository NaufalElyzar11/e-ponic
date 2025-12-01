import 'package:flutter/material.dart';

class PlantHistoryModel {
  final String date;
  final int plantQty;      // Total bibit
  final int harvestQty;    // Total panen
  final int plantDocCount; // Jumlah data tanam (dokumen)
  final int harvestDocCount; // Jumlah data panen (dokumen)
  
  final VoidCallback onPlantEdit;
  final VoidCallback onHarvestEdit;
  final VoidCallback onDeletePlant;   // Hapus kategori Tanam
  final VoidCallback onDeleteHarvest; // Hapus kategori Panen
  final VoidCallback onDeleteAll;     // Hapus Semua

  PlantHistoryModel({
    required this.date,
    required this.plantQty,
    required this.harvestQty,
    required this.plantDocCount,   // Baru
    required this.harvestDocCount, // Baru
    required this.onPlantEdit,
    required this.onHarvestEdit,
    required this.onDeletePlant,   // Baru
    required this.onDeleteHarvest, // Baru
    required this.onDeleteAll,
  });
}