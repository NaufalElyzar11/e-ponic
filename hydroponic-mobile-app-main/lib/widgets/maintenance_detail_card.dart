import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/plant_maintenance_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class MaintenanceDetailCard extends StatelessWidget{
  final PlantMaintenanceModel maintenance;
  final VoidCallback? onMarkDone;

  const MaintenanceDetailCard({
    super.key, 
    required this.maintenance,
    this.onMarkDone,
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
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        child: ListTile(
          textColor: Colors.white,
          title: Text(
            maintenance.maintenanceName,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          subtitle: Column(children: [
            Divider(),
            SizedBox(height: 25,),
            Text(
              maintenance.description, 
              textAlign: TextAlign.justify, 
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 25,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(maintenance.date),
                Text(maintenance.time),
              ],
            ),
            SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    // actions
                  }, 
                  icon: Icon(Icons.camera_enhance, color: Colors.white,)
                ),
                ElevatedButton(
                  onPressed: onMarkDone,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white
                  ), 
                  child: Text('Tandai Selesai', style: TextStyle(fontWeight: FontWeight.bold),),
                ),
              ],
            )
          ]),
        ),
      ),
    );
  }
}