import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/plant_model.dart';
import 'package:hydroponics_app/models/plant_quantity_model.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/widgets/transaction_status_card.dart';
import 'package:hydroponics_app/services/transaction_service.dart';

class TransactionStatusScreen extends StatefulWidget {
  const TransactionStatusScreen({super.key});

  @override
  State<TransactionStatusScreen> createState() =>
      _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Status Transaksi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 1, 68, 33),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            child: StyledElevatedButton(
              text: 'Ekspor Data',
              onPressed: () {
                // TODO: Implementasi ekspor data (misalnya ke CSV)
              },
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('transaksi')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('Belum ada transaksi.'),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final doc = docs[index];
                      final data = doc.data();

                      final ts = data['tanggal'] as Timestamp?;
                      final dt = ts?.toDate();
                      final dateStr = dt != null
                          ? DateFormat('dd MMM yyyy').format(dt)
                          : '-';
                      final timeStr =
                          dt != null ? DateFormat('HH:mm').format(dt) : '';

                      final items =
                          (data['items'] as List<dynamic>? ?? <dynamic>[]);

                      final plantQuantity = items.map((item) {
                        final m = item as Map<String, dynamic>;
                        final plant = PlantModel(
                          plantName: (m['nama_tanaman'] ?? '') as String,
                          price:
                              (m['harga'] as num?)?.toDouble() ?? 0.0,
                        );
                        return PlantQuantityModel(
                          plant: plant,
                          quantity: (m['jumlah'] as int?) ?? 0,
                        );
                      }).toList();

                      final model = TransactionModel(
                        id: doc.id,
                        customerName:
                            (data['nama_pelanggan'] ?? '') as String,
                        plantQuantity: plantQuantity,
                        address: (data['alamat'] ?? '') as String,
                        date: dateStr,
                        time: timeStr,
                        isPaid: (data['is_paid'] ?? false) as bool,
                        isAssigned:
                            (data['is_assigned'] ?? false) as bool,
                        isHarvest:
                            (data['is_harvest'] ?? false) as bool,
                        isDeliver:
                            (data['is_deliver'] ?? false) as bool,
                      );

                      return TransactionStatusCard(
                        transaction: model,
                        onPaymentStatusChanged: (value) {
                          final isPaid = value == 'Lunas';
                          if (model.id != null) {
                            TransactionService.instance
                                .updatePaymentStatus(
                              transactionId: model.id!,
                              isPaid: isPaid,
                            );
                          }
                        },
                        onDelete: () {
                          if (model.id != null) {
                            _confirmDelete(context, model.id!);
                          }
                        },
                        onAssign: () {
                          if (model.id != null) {
                            Navigator.pushNamed(
                              context,
                              '/logistic_assignment_detail',
                              arguments: model.id!,
                            );
                          }
                        },
                        // onAssign dan onEdit akan diisi ketika fitur
                        // penugasan & edit transaksi sudah diimplementasi.
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return const SizedBox(
                        height: 10,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text(
            'Apakah Anda yakin ingin menghapus transaksi ini beserta detailnya?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TransactionService.instance
                  .deleteTransactionWithDetails(transactionId);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
