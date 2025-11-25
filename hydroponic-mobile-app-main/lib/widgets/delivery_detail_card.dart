import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/services/shipping_service.dart';

class DeliveryDetailCard extends StatelessWidget {
  final DeliveryAssigntmentModel assignment;
  final String shippingId;

  const DeliveryDetailCard({
    super.key,
    required this.assignment,
    required this.shippingId,
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
            assignment.transaction.customerName,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          subtitle: Column(children: [
            Divider(),
            SizedBox(height: 25,),
            
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
            SizedBox(height: 25,),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(assignment.transaction.date),
                Text(assignment.transaction.time),
              ],
            ),
            SizedBox(height: 20,),

            Text(assignment.transaction.address, textAlign: TextAlign.justify,),
            SizedBox(height: 20,),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () async {
                    final controller = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Catatan Pengiriman'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Tulis catatan (opsional)',
                          ),
                          maxLines: 3,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ShippingService.instance
                                  .updateDeliveryStatus(
                                shippingId: shippingId,
                                statusPengiriman: 'Dalam Perjalanan',
                                catatan: controller.text.trim(),
                              );
                              // ignore: use_build_context_synchronously
                              Navigator.pop(ctx);
                            },
                            child: const Text('Simpan'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Icons.camera_enhance, color: Colors.white,)
                ),
                ElevatedButton(
                  onPressed: () async {
                    final controller = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Tandai Selesai'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Catatan (opsional)',
                          ),
                          maxLines: 3,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ShippingService.instance
                                  .updateDeliveryStatus(
                                shippingId: shippingId,
                                statusPengiriman: 'Selesai',
                                catatan: controller.text.trim(),
                              );
                              // ignore: use_build_context_synchronously
                              Navigator.pop(ctx);
                            },
                            child: const Text('Simpan'),
                          ),
                        ],
                      ),
                    );
                  },
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