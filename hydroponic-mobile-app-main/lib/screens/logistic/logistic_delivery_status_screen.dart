import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/models/plant_model.dart';
import 'package:hydroponics_app/models/plant_quantity_model.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/widgets/logistic_delivery_status_card.dart';
import 'package:hydroponics_app/services/shipping_service.dart';

class LogisticDeliveryStatusScreen extends StatefulWidget {
  const LogisticDeliveryStatusScreen({super.key});

  @override
  State<LogisticDeliveryStatusScreen> createState() => _LogisticDeliveryStatusScreenState();
}

class _LogisticDeliveryStatusScreenState extends State<LogisticDeliveryStatusScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tugas Panen', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 25,
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 1, 68, 33),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        padding: EdgeInsets.only(top: 15, right: 20, left: 20),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ShippingService.instance.allShipmentsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Belum ada data pengiriman.'));
            }

            final shipDocs = snapshot.data!.docs;

            return ListView.separated(
              itemCount: shipDocs.length,
              itemBuilder: (context, index) {
                final shipDoc = shipDocs[index];
                final shipData = shipDoc.data();
                final transaksiId =
                    (shipData['id_transaksi'] ?? '') as String;
                final courierId =
                    (shipData['id_kurir'] ?? '') as String;
                final status =
                    (shipData['status_pengiriman'] ?? '') as String;

                return FutureBuilder<
                    Map<String, dynamic>?>(
                  future: _buildAssignmentData(transaksiId, courierId),
                  builder: (context, dataSnapshot) {
                    if (dataSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        height: 80,
                        child: Center(
                            child: CircularProgressIndicator()),
                      );
                    }
                    final map = dataSnapshot.data;
                    if (map == null) return const SizedBox();

                    final tx = map['transaction'] as TransactionModel;
                    final courier = map['courier'] as UserModel;

                    final assignment = DeliveryAssigntmentModel(
                      transaction: tx,
                      courier: courier,
                      isDone: status == 'Selesai',
                    );

                    return LogisticDeliveryStatusCard(assignment: assignment);
                  },
                );
              },
              separatorBuilder: (context, index) {
                return const SizedBox(height: 10);
              },
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _buildAssignmentData(
      String transaksiId, String courierId) async {
    final txSnap = await FirebaseFirestore.instance
        .collection('transaksi')
        .doc(transaksiId)
        .get();
    if (!txSnap.exists) return null;

    final txData = txSnap.data()!;
    final items =
        (txData['items'] as List<dynamic>? ?? <dynamic>[]);

    final plantQuantity = items.map((item) {
      final m = item as Map<String, dynamic>;
      final plant = PlantModel(
        plantName: (m['nama_tanaman'] ?? '') as String,
        price: (m['harga'] as num?)?.toDouble() ?? 0.0,
      );
      return PlantQuantityModel(
        plant: plant,
        quantity: (m['jumlah'] as int?) ?? 0,
      );
    }).toList();

    final dt = (txData['tanggal'] as Timestamp?)?.toDate();
    final dateStr =
        dt != null ? DateFormat('dd MMM yyyy').format(dt) : '';
    final timeStr =
        dt != null ? DateFormat('HH:mm').format(dt) : '';

    final tx = TransactionModel(
      id: transaksiId,
      customerName: (txData['nama_pelanggan'] ?? '') as String,
      plantQuantity: plantQuantity,
      address: (txData['alamat'] ?? '') as String,
      date: dateStr,
      time: timeStr,
      isPaid: (txData['is_paid'] ?? false) as bool,
      isAssigned: (txData['is_assigned'] ?? false) as bool,
      isHarvest: (txData['is_harvest'] ?? false) as bool,
      isDeliver: (txData['is_deliver'] ?? false) as bool,
    );

    final courierSnap = await FirebaseFirestore.instance
        .collection('pengguna')
        .doc(courierId)
        .get();

    final namaKurir =
        (courierSnap.data()?['nama_pengguna'] ?? 'Kurir') as String;
    final courier = UserModel(
      username: namaKurir,
      role: 'Kurir',
      onNotificationTap: () {},
    );

    return {
      'transaction': tx,
      'courier': courier,
    };
  }
}