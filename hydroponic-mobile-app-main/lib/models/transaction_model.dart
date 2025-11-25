import 'package:hydroponics_app/models/plant_quantity_model.dart';

class TransactionModel {
  final String? id;
  final String customerName;
  final List<PlantQuantityModel> plantQuantity;
  final String address;
  final String date;
  final String time;
  final bool isPaid;
  final bool isAssigned;
  final bool isHarvest;
  final bool isDeliver;

  const TransactionModel({
    this.id,
    required this.customerName,
    required this.plantQuantity,
    required this.address,
    required this.date,
    required this.time,
    this.isPaid = false,
    this.isAssigned = false,
    this.isHarvest = false,
    this.isDeliver = false,
  });

  double get totalPrice {
    // Menggunakan fold untuk menjumlahkan total harga dari setiap item di list
    // 0.0 adalah nilai awal (initial sum)
    return plantQuantity.fold(0.0, (sum, item) {
      // 'sum' adalah total sementara
      // 'item' adalah setiap PlantQuantityModel dalam list
      double itemTotal = item.plant.price * item.quantity;
      return sum + itemTotal;
    });
  }
}