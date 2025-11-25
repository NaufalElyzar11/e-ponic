import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class LogisticDeliveryDetailCard extends StatelessWidget{
  final DeliveryAssigntmentModel assignment;

  const LogisticDeliveryDetailCard({
    super.key, 
    required this.assignment
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 0.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        child: ListTile(
          textColor: Colors.white,
          title: Text(
            assignment.transaction.customerName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          subtitle: Column(children: [
            const Divider(),
            const SizedBox(height: 25,),
            
            Column(
              children: assignment.transaction.plantQuantity.map((transaction) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(transaction.plant.plantName),
                    Text('${transaction.quantity} pcs'),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 25,),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(assignment.transaction.date),
                Text(assignment.transaction.time),
              ],
            ),
            const SizedBox(height: 20,),

            Text(assignment.transaction.address, textAlign: TextAlign.justify,),
          ]),
        ),
      ),
    );
  }
}