import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pengiriman')
          .doc(shippingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shippingData = snapshot.data?.data();
        final statusPengiriman = (shippingData?['status_pengiriman'] ?? 'Belum Dikirim') as String;
        final catatan = (shippingData?['catatan_pengiriman'] ?? '') as String;
        final isSelesai = statusPengiriman.toLowerCase().contains('selesai') ||
                          statusPengiriman.toLowerCase().contains('terkirim');

        return _buildCard(context, statusPengiriman, catatan, isSelesai);
      },
    );
  }

  Widget _buildCard(BuildContext context, String statusPengiriman, String catatan, bool isSelesai) {
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

            // Status Pengiriman
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelesai ? Colors.green[700] : Colors.orange[700],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelesai ? Icons.check_circle : Icons.local_shipping,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Status: $statusPengiriman',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15,),

            // Catatan jika ada
            if (catatan.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      catatan,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 15,),
            ],

            // Tombol hanya muncul jika belum selesai
            if (!isSelesai) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final controller = TextEditingController();
                      final formKey = GlobalKey<FormState>();
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tandai Selesai'),
                          content: Form(
                            key: formKey,
                            child: TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'Catatan (opsional, maksimal 30 kata)',
                              ),
                              maxLines: 3,
                              inputFormatters: [
                                // Hanya simbol penting: huruf, angka, spasi, titik, koma, dash, slash, @
                                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s.,\-/@]")),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return null; // Opsional, jadi boleh kosong
                                }
                                // Validasi: maksimal 30 kata
                                final words = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
                                if (words.length > 30) {
                                  return 'Catatan maksimal 30 kata (saat ini: ${words.length} kata)';
                                }
                                return null;
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (formKey.currentState?.validate() ?? true) {
                                  await ShippingService.instance
                                      .updateDeliveryStatus(
                                    shippingId: shippingId,
                                    statusPengiriman: 'Selesai',
                                    catatan: controller.text.trim(),
                                  );
                                  // ignore: use_build_context_synchronously
                                  Navigator.pop(ctx);
                                }
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
              ),
            ]
          ]),
        ),
      ),
    );
  }
}