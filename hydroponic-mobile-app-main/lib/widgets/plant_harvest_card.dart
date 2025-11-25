import 'package:flutter/material.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class PlantHarvestCard extends StatelessWidget{
  final String plantName;
  final int plantHarvestQty;
  final int plantTotalQty;

  const PlantHarvestCard({
    super.key, 
    required this.plantName, 
    required this.plantHarvestQty, 
    required this.plantTotalQty
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: EdgeInsets.only(top: 15, bottom: 15, left: 20, right: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plantName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: 10,),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$plantHarvestQty',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold
                  ),
                ),
                SizedBox(width: 3,),
                Text(
                  'bibit',
                  style: TextStyle(
                    color: Colors.white
                  ),
                ),
              ],
            ),
            Text(
              'dari $plantTotalQty bibit',
              style: TextStyle(
                color: Colors.white
              ),
            )
          ],
        ),
      ),
    );
  }
}