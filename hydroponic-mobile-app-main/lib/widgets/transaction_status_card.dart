import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/styled_dropdown_button_form_field.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:intl/intl.dart';

class TransactionStatusCard extends StatefulWidget {
  final TransactionModel transaction;
  final void Function(String value)? onPaymentStatusChanged;
  final VoidCallback? onAssign;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionStatusCard({
    super.key,
    required this.transaction,
    this.onPaymentStatusChanged,
    this.onAssign,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<TransactionStatusCard> createState() => _TransactionStatusCardState();
}

class _TransactionStatusCardState extends State<TransactionStatusCard> {
  
  String? _selectedPaymentStatus;
  final List<String> _paymentStatuses = [
    'Lunas',
    'Belum Lunas',
  ];

  @override
  void initState() {
    super.initState();
    // Inisialisasi state awal
    _selectedPaymentStatus = widget.transaction.isPaid ? _paymentStatuses[0] : _paymentStatuses[1];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(15), 
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nama Penerima:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Flexible(
                  child: Text(
                    widget.transaction.customerName,
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
            Divider(),

            // Jenis dan Kuantitas Sayur
            Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Column(
                children: widget.transaction.plantQuantity.map((plantQty) {
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
                          '${plantQty.quantity} pcs x ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', ).format(plantQty.plant.price)}', 
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
                Text('Total Harga:', style: TextStyle(color: Colors.white),),
                Text(
                  // 'Rp ${widget.transaction.totalPrice.toStringAsFixed(0)}', 
                  NumberFormat.currency(
                    locale: 'id_ID', 
                    symbol: 'Rp ', ).format(widget.transaction.totalPrice
                  ),
                  style: TextStyle(color: Colors.white),
                )
              ],
            ),

            Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status Panen', style: TextStyle(color: Colors.white),),
                      Text((widget.transaction.isHarvest) ? 'Sudah' : 'Belum', style: TextStyle(color: Colors.white),)
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status Pengiriman', style: TextStyle(color: Colors.white),),
                      Text((widget.transaction.isDeliver) ? 'Sudah' : 'Belum', style: TextStyle(color: Colors.white),)
                    ],
                  ),
                ],
              )
            ),

            Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.transaction.date, style: TextStyle(color: Colors.white),),
                  Text(widget.transaction.time, style: TextStyle(color: Colors.white),)
                ],
              ),
            ),

            Text(
              widget.transaction.address, 
              style: TextStyle(color: Colors.white), 
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15,),

            StyledDropdownButtonFormField(
              hintText: 'Pilih Status Pembayaran', 
              prefixIcon: Icons.payment,
              value: _selectedPaymentStatus, 
              items: _paymentStatuses.map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue == null) return;
                setState(() {
                  _selectedPaymentStatus = newValue;
                });
                widget.onPaymentStatusChanged?.call(newValue);
              },
              validator: (value) {
                if (value == null) {
                  return 'Silakan pilih status pembayaran';
                }
                return null;
              },
            ),
            SizedBox(height: 15,),

            // Tombol Tugaskan dihapus karena transaksi otomatis muncul ke petani
            // Staf logistik hanya menugaskan kurir setelah petani selesai panen
            SizedBox(height: 10,),

            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onEdit, 
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)
                      ),
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.yellow[700]
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('Edit'),
                    )
                  ),
                ),
                SizedBox(width: 5,),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onDelete, 
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)
                      ),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red
                    ),
                    child: Padding(
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