class HarvestAssignmentModel {
  final String customerName;
  final String plantName;
  final int plantQty;
  final String address;
  final String date;
  final String time;
  final bool isDone;

  HarvestAssignmentModel({
    required this.customerName,
    required this.plantName,
    required this.plantQty,
    required this.address,
    required this.date,
    required this.time,
    this.isDone = false
  });
}