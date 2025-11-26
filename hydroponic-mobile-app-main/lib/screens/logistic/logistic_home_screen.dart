import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/models/plant_model.dart';
import 'package:hydroponics_app/models/plant_quantity_model.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/widgets/delivery_assignment_card.dart';
import 'package:hydroponics_app/widgets/home_app_bar.dart';

class LogisticHomeScreen extends StatefulWidget {
  const LogisticHomeScreen({super.key});

  @override
  State<LogisticHomeScreen> createState() => _LogisticHomeScreenState();
}

class _LogisticHomeScreenState extends State<LogisticHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('pengguna')
          .doc(authUser?.uid)
          .get(),
      builder: (context, userSnap) {
        final uData = userSnap.data?.data() ?? {};
        final name = (uData['nama_pengguna'] ?? authUser?.email ??
            'Staf Logistik') as String;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: HomeAppBar(
          user: UserModel(
            username: name, 
            role: 'Staf Logistik',
            onNotificationTap: () {
              Navigator.pushNamed(context, '/notification');
            },
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 25, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Daftar Penugasan',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 25,),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('transaksi')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Gagal memuat transaksi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  // Tampilkan hanya transaksi yang sudah di-panen dan belum ditugaskan ke kurir
                  final docs = allDocs
                      .where((d) => 
                          (d.data()['is_harvest'] ?? false) == true &&
                          !(d.data()['is_assigned'] ?? false))
                      .toList();

                  if (docs.isEmpty) {
                    return const Text('Belum ada transaksi yang perlu ditugaskan.');
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final items =
                          (data['items'] as List<dynamic>? ?? <dynamic>[]);

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

                      // --- PERBAIKAN DI SINI ---
                      final dt = (data['tanggal'] as Timestamp?)?.toDate();
                      final createdAt = (data['created_at'] as Timestamp?)?.toDate(); // Ambil created_at

                      final dateStr = dt != null
                          ? DateFormat('dd MMM yyyy').format(dt)
                          : '';
                      
                      // Gunakan createdAt untuk jam, jika ada. Jika tidak, fallback ke dt atau string kosong.
                      final timeStr = createdAt != null 
                          ? DateFormat('HH:mm').format(createdAt) 
                          : (dt != null ? DateFormat('HH:mm').format(dt) : '');
                      // -------------------------

                      final tx = TransactionModel(
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

                      final assignment = DeliveryAssigntmentModel(
                        transaction: tx,
                        courier: UserModel(
                          username: '-',
                          role: 'Kurir',
                          onNotificationTap: () {},
                        ),
                      );

                      return DeliveryAssignmentCard(
                        assignment: assignment,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/logistic_assignment_detail',
                            arguments: doc.id,
                          );
                        },
                      );
                    },
                    separatorBuilder:
                        (BuildContext context, int index) {
                      return const SizedBox(height: 7);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}