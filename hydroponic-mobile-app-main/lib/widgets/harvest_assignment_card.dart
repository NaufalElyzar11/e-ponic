import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/harvest_assignment_model.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class HarvestAssignmentCard extends StatelessWidget{
  final HarvestAssignmentModel assignment;
  final VoidCallback? onMarkDone;

  const HarvestAssignmentCard({
    super.key, 
    required this.assignment,
    this.onMarkDone,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0.0),
      color: const Color.fromARGB(255, 1, 68, 33),
      
      child: Padding(padding: EdgeInsetsGeometry.only(top: 10, bottom: 10),
        child: 
          ListTile(
            textColor: Colors.white,
            title: Text(assignment.customerName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
            subtitle: Column(
              spacing: 15,
              children: [
                SizedBox(height: 7,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(assignment.plantName, style: TextStyle(fontSize: 18),),
                    Text('${assignment.plantQty} pcs', style: TextStyle(fontSize: 18),)
                  ],
                ),
                Text(assignment.address, 
                  style: TextStyle(fontSize: 16), 
                  textAlign: TextAlign.justify,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(assignment.date, style: TextStyle(fontSize: 16),),
                    Text(assignment.time, style: TextStyle(fontSize: 16),)
                  ],
                ),
                StyledElevatedButton(
                  text: 'Tandai Sudah Dipanen', 
                  foregroundColor: Color.fromARGB(255, 1, 68, 33),
                  onPressed: onMarkDone,
                )
              ],
            )
          ),
      ),
    );
  }
}