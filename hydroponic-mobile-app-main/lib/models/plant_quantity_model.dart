import 'package:hydroponics_app/models/plant_model.dart';

class PlantQuantityModel {
  final PlantModel plant;
  final int quantity;

  const PlantQuantityModel({
    required this.plant,
    required this.quantity
  });
}