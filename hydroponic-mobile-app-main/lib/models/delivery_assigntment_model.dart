import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/models/user_model.dart';

class DeliveryAssigntmentModel {
  final TransactionModel transaction;
  final UserModel courier;
  final bool isDone;

  const DeliveryAssigntmentModel({
    required this.transaction,
    required this.courier,
    this.isDone = false
  });
}