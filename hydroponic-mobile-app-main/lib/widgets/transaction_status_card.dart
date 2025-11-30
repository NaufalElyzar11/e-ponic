import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:intl/intl.dart';

class TransactionStatusCard extends StatelessWidget {
  final TransactionModel transaction;
  // Callback onPaymentStatusChanged DIHAPUS karena sudah tidak dipakai di card ini
  final VoidCallback? onAssign;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionStatusCard({
    super.key,
    required this.transaction,
    this.onAssign,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15), 
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nama Pelanggan:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Flexible(
                  child: Text(
                    transaction.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                  ),
                )
              ],
            ),
            const Divider(),

            // Jenis dan Kuantitas Sayur
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Column(
                children: transaction.plantQuantity.map((plantQty) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          plantQty.plant.plantName, 
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${plantQty.quantity} pcs x ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(plantQty.plant.price)}', 
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Harga:', style: TextStyle(color: Colors.white),),
                Text(
                  NumberFormat.currency(
                    locale: 'id_ID', 
                    symbol: 'Rp ', 
                    decimalDigits: 0
                  ).format(transaction.totalPrice),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Column(
                children: [
                  // Status Panen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status Panen', style: TextStyle(color: Colors.white),),
                      // Text((transaction.isHarvest) ? 'Sudah' : 'Belum', style: const TextStyle(color: Colors.white),),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: transaction.isHarvest ? Colors.green.shade600 : Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.isHarvest ? 'Selesai' : 'Belum Dipanen',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Status Pengiriman
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status Pengiriman', style: TextStyle(color: Colors.white),),
                      // Text((transaction.isDeliver) ? 'Sudah' : 'Belum', style: const TextStyle(color: Colors.white),),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: transaction.isDeliver ? Colors.green.shade600 : Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.isDeliver ? 'Selesai' : 'Belum Dikirim',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // REVISI: Status Pembayaran (Tampilan Biasa)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status Pembayaran', style: TextStyle(color: Colors.white),),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: transaction.isPaid ? Colors.green.shade600 : Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.isPaid ? 'Lunas' : 'Belum Lunas',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(transaction.date, style: const TextStyle(color: Colors.white),),
                  Text(transaction.time, style: const TextStyle(color: Colors.white),)
                ],
              ),
            ),

            Text(
              transaction.address, 
              style: const TextStyle(color: Colors.white), 
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15,),

            // Tombol Aksi (Edit & Delete)
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(
                    onPressed: onEdit, 
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)
                      ),
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.yellow[700]
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('Edit'),
                    )
                  ),
                ),
                const SizedBox(width: 5,),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDelete, 
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)
                      ),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('Delete'),
                    )
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}