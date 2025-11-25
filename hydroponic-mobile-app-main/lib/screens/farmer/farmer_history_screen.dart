import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/plant_history_model.dart';
import 'package:hydroponics_app/widgets/farmer_history_expansion_item.dart';

class FarmerHistoryScreen extends StatefulWidget {
  const FarmerHistoryScreen({super.key});

  @override
  State<FarmerHistoryScreen> createState() => _FarmerHistoryScreenState();
}

class _FarmerHistoryScreenState extends State<FarmerHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Riwayat Tanam', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 25,
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 1, 68, 33),
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return const Center(
                child: Text('User tidak ditemukan, silakan login ulang'));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('data_tanam')
                .where('id_petani', isEqualTo: user.uid)
                .orderBy('tanggal_tanam', descending: true)
                .snapshots(),
            builder: (context, tanamSnapshot) {
              if (tanamSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tanamDocs = tanamSnapshot.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('data_panen')
                    .where('id_petani', isEqualTo: user.uid)
                    .orderBy('tanggal_panen', descending: true)
                    .snapshots(),
                builder: (context, panenSnapshot) {
                  if (panenSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final panenDocs = panenSnapshot.data?.docs ?? [];

                  final Map<String, _HistoryAgg> map = {};

                  for (final doc in tanamDocs) {
                    final data = doc.data();
                    final ts = data['tanggal_tanam'] as Timestamp?;
                    final d = ts?.toDate();
                    if (d == null) continue;
                    final key =
                        DateFormat('yyyy-MM-dd').format(d.toLocal());
                    map.putIfAbsent(key, () => _HistoryAgg());
                    map[key]!.tanam += (data['jumlah_tanam'] as int? ?? 0);
                    map[key]!.tanamIds.add(doc.id);
                  }

                  for (final doc in panenDocs) {
                    final data = doc.data();
                    final ts = data['tanggal_panen'] as Timestamp?;
                    final d = ts?.toDate();
                    if (d == null) continue;
                    final key =
                        DateFormat('yyyy-MM-dd').format(d.toLocal());
                    map.putIfAbsent(key, () => _HistoryAgg());
                    map[key]!.panen += (data['jumlah_panen'] as int? ?? 0);
                    map[key]!.panenIds.add(doc.id);
                  }

                  final keys = map.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  final List<PlantHistoryModel> dataList = keys.map((key) {
                    final d = DateTime.parse(key);
                    final label =
                        DateFormat('dd MMM yyyy').format(d.toLocal());
                    final agg = map[key]!;
                    return PlantHistoryModel(
                      date: label,
                      plantQty: agg.tanam,
                      harvestQty: agg.panen,
                      onPlantEdit: () {}, 
                      onPlantDelete: () => _deleteDocs(
                        collection: 'data_tanam',
                        ids: agg.tanamIds,
                      ),
                      onHarvestEdit: () {}, 
                      onHarvestDelete: () => _deleteDocs(
                        collection: 'data_panen',
                        ids: agg.panenIds,
                      ),
                      onDeleteAll: () => _deleteDocs(
                        collection: 'data_tanam',
                        ids: agg.tanamIds,
                        alsoDeleteCollection2: 'data_panen',
                        ids2: agg.panenIds,
                      ),
                    );
                  }).toList();

                  return Container(
                    padding: const EdgeInsets.all(15),
                    child: ListView.builder(
                      itemCount: dataList.length,
                      itemBuilder: (BuildContext context, int index) {
                        return FarmerHistoryExpansionItem(
                          history: dataList[index],
                          screenWidth: constraints.maxWidth,
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        }
      )
      
    );
  }

  Future<void> _deleteDocs({
    required String collection,
    required List<String> ids,
    String? alsoDeleteCollection2,
    List<String>? ids2,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(
          FirebaseFirestore.instance.collection(collection).doc(id));
    }
    if (alsoDeleteCollection2 != null && ids2 != null) {
      for (final id in ids2) {
        batch.delete(FirebaseFirestore.instance
            .collection(alsoDeleteCollection2)
            .doc(id));
      }
    }
    await batch.commit();
  }
}

class _HistoryAgg {
  int tanam = 0;
  int panen = 0;
  final List<String> tanamIds = [];
  final List<String> panenIds = [];
}

