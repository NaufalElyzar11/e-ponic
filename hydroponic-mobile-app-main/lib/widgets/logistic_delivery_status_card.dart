import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class LogisticDeliveryStatusCard extends StatefulWidget {
  final DeliveryAssigntmentModel assignment;

  const LogisticDeliveryStatusCard({
    super.key, 
    required this.assignment
  });

  @override
  State<LogisticDeliveryStatusCard> createState() => _LogisticDeliveryStatusCardState();
}

class _LogisticDeliveryStatusCardState extends State<LogisticDeliveryStatusCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 0.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.assignment.isDone ? const Color.fromARGB(255, 69, 219, 74) : Colors.red[400],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10)
              )
            ),
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                widget.assignment.isDone ? 'Sudah dikirim' : 'Belum Dikirim',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: ListTile(
              textColor: Colors.white,
              title: Text(
                widget.assignment.transaction.customerName,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              subtitle: Column(children: [
                Divider(),
                SizedBox(height: 25,),
                
                Column(
                  children: widget.assignment.transaction.plantQuantity.map((transaction) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(transaction.plant.plantName),
                        Text('${transaction.quantity} pcs'),
                      ],
                    );
                  }).toList(),
                ),
                SizedBox(height: 25,),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.assignment.transaction.date),
                    Text(widget.assignment.transaction.time),
                  ],
                ),
                SizedBox(height: 20,),

                Text(widget.assignment.transaction.address, textAlign: TextAlign.justify,),
              ]),
            ),
          )
        ],
      ),
    );
  }

}