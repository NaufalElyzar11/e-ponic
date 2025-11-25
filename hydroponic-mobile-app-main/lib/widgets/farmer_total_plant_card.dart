import 'package:flutter/material.dart';

class FarmerTotalPlantCard extends StatelessWidget {
  final String header;
  final int plantCount;
  final IconData? plantIcon;

  const FarmerTotalPlantCard({
    super.key,
    required this.header,
    required this.plantCount,
    this.plantIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 7,
      child: Container(
        alignment: Alignment.topLeft,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),  
        ),
        child: Padding(padding: const EdgeInsets.all(20.0),
          child: 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(header, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                  const SizedBox(height: 13),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$plantCount', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      SizedBox(width: 5),
                      const Text('bibit', style: TextStyle(fontSize: 18),),
                    ],
                  ),
                ],
              ),
              Icon(plantIcon ?? Icons.grass, size: 60, color: Color.fromARGB(255, 1, 68, 33)),
            ],
          ),
        ),
      ),
    );
  }
}