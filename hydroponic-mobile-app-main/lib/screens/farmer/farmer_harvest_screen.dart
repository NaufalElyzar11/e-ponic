import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/harvest_assignment_model.dart';
import 'package:hydroponics_app/widgets/harvest_assignment_card.dart';

class FarmerHarvestScreen extends StatefulWidget {
  const FarmerHarvestScreen({super.key});

  @override
  State<FarmerHarvestScreen> createState() => _FarmerHarvestScreenState();
}

class _FarmerHarvestScreenState extends State<FarmerHarvestScreen> {
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
        child: _buildAssignments(),
      ),
    );
  }

  Widget _buildAssignments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
          child: Text('User tidak ditemukan, silakan login ulang'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transaksi')
          .where('is_harvest', isEqualTo: false)
          .orderBy('tanggal')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada tugas panen.'));
        }

        // Ambil id_tanaman petani
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: FirebaseFirestore.instance
              .collection('pengguna')
              .doc(user.uid)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final userData = userSnap.data?.data() ?? {};
            final petaniPlantId =
                (userData['id_tanaman'] ?? '') as String;

            final List<HarvestAssignmentModel> list = [];

            for (final doc in docs) {
              final data = doc.data();
              final items =
                  (data['items'] as List<dynamic>? ?? <dynamic>[]);

              for (final item in items) {
                final m = item as Map<String, dynamic>;
                if (m['id_tanaman'] != petaniPlantId) continue;

                final dt =
                    (data['tanggal'] as Timestamp?)?.toDate();
                final dateStr = dt != null
                    ? DateFormat('dd MMM yyyy').format(dt)
                    : '';
                final timeStr = dt != null
                    ? DateFormat('HH:mm').format(dt)
                    : '';

                list.add(
                  HarvestAssignmentModel(
                    customerName:
                        (data['nama_pelanggan'] ?? '') as String,
                    plantName:
                        (m['nama_tanaman'] ?? '') as String,
                    plantQty: (m['jumlah'] as int?) ?? 0,
                    address: (data['alamat'] ?? '') as String,
                    date: dateStr,
                    time: timeStr,
                  ),
                );
              }
            }

            if (list.isEmpty) {
              return const Center(child: Text('Belum ada tugas panen.'));
            }

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final assignment = list[index];
                return HarvestAssignmentCard(
                  assignment: assignment,
                  onMarkDone: () async {
                    // catat panen dan tandai transaksi
                    final tsDoc = docs[index];
                    await FirebaseFirestore.instance
                        .collection('data_panen')
                        .add({
                      'id_petani': user.uid,
                      'jumlah_panen': assignment.plantQty,
                      'tanggal_panen': tsDoc['tanggal'],
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance
                        .collection('transaksi')
                        .doc(tsDoc.id)
                        .update({'is_harvest': true});
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}