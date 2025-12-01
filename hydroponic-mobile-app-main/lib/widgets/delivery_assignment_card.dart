import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class DeliveryAssignmentCard extends StatelessWidget{
  final DeliveryAssigntmentModel assignment;
  final VoidCallback onTap;

  const DeliveryAssignmentCard({
    super.key, 
    required this.assignment,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = assignment.isDone;

    return Card(
      color: isDone ? const Color.fromARGB(255, 46, 125, 50) : AppColors.primary,
      margin: EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(vertical: 15, horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      assignment.transaction.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis, // Menambahkan tanda ... jika terlalu panjang
                      maxLines: 1, // Membatasi hanya 1 baris
                    ),
                  ),
                  // Menambahkan sedikit jarak agar teks tidak menempel langsung dengan tanggal
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Text(
                        assignment.transaction.date,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text(
                            'Selesai',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              SizedBox(height: 5,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(assignment.transaction.address, style: TextStyle(color: Colors.white),),
                  Text(assignment.transaction.time, style: TextStyle(color: Colors.white),)
                ],
              ),
            ],
          ),
        ),
      )                     
    );
  }
}