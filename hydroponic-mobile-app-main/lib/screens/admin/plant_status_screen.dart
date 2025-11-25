import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/plant_harvest_card.dart';
import 'package:hydroponics_app/widgets/plant_harvest_history_expansion.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class PlantStatusScreen extends StatefulWidget{
  const PlantStatusScreen({super.key});

  @override
  State<PlantStatusScreen> createState() => _PlantStatusScreenState();
}

class _PlantStatusScreenState extends State<PlantStatusScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Status Tanaman', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 1, 68, 33),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container tombol ekspor
                Container(
                  color: AppColors.primary,
                  width: double.infinity,
                  padding: EdgeInsets.all(15),
                  child: StyledElevatedButton(
                    text: 'Ekspor Data', 
                    onPressed: () {
                      
                    },
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white,
                  ),
                ),
                _buildReadyToHarvestSection(),
                _buildHistorySection(constraints.maxWidth),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildReadyToHarvestSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('tanaman').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tanaman Siap Panen:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final nama = (data['nama_tanaman'] ?? '') as String;
                    // hitung total tanam dan panen untuk tanaman ini
                    return FutureBuilder<Map<String, int>>(
                      future: _aggregateForPlant(doc.id),
                      builder: (context, aggSnap) {
                        final plantTotal =
                            aggSnap.data?['tanam'] ?? 0;
                        final harvestTotal =
                            aggSnap.data?['panen'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: PlantHarvestCard(
                            plantName: nama,
                            plantHarvestQty: harvestTotal,
                            plantTotalQty: plantTotal,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistorySection(double width) {
    // agregasi global per tanggal untuk 3 tanaman utama
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.only(top: 5, bottom: 15, left: 15, right: 15),
      child: Card(
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riwayat Tanam',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              // Pertama, ambil daftar tanaman untuk memetakan id_tanaman -> nama
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('tanaman')
                    .get(),
                builder: (context, plantSnap) {
                  if (plantSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final plantDocs = plantSnap.data?.docs ?? [];
                  final Map<String, String> plantNames = {
                    for (final doc in plantDocs)
                      doc.id:
                          (doc.data()['nama_tanaman'] ?? '') as String,
                  };

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('data_tanam')
                        .orderBy('tanggal_tanam', descending: true)
                        .snapshots(),
                    builder: (context, tanamSnap) {
                      if (tanamSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final tanamDocs = tanamSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot<
                          Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('data_panen')
                            .orderBy('tanggal_panen', descending: true)
                            .snapshots(),
                        builder: (context, panenSnap) {
                          if (panenSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final panenDocs = panenSnap.data?.docs ?? [];

                          // map tanggal -> (plantId -> tanam/panen)
                          final Map<String,
                                  Map<String, Map<String, int>>>
                              agg = {};

                          void addRecord(
                            QueryDocumentSnapshot<Map<String, dynamic>>
                                doc,
                            String dateField,
                            String qtyField,
                            String type,
                          ) {
                            final data = doc.data();
                            final ts = data[dateField] as Timestamp?;
                            final d = ts?.toDate();
                            if (d == null) return;
                            final dateKey =
                                DateTime(d.year, d.month, d.day)
                                    .toIso8601String();
                            final plantId =
                                (data['id_tanaman'] ?? '') as String;

                            agg.putIfAbsent(dateKey, () => {});
                            agg[dateKey]!.putIfAbsent(plantId,
                                () => {'tanam': 0, 'panen': 0});
                            agg[dateKey]![plantId]![type] =
                                (agg[dateKey]![plantId]![type] ?? 0) +
                                    (data[qtyField] as int? ?? 0);
                          }

                          for (final doc in tanamDocs) {
                            addRecord(doc, 'tanggal_tanam',
                                'jumlah_tanam', 'tanam');
                          }
                          for (final doc in panenDocs) {
                            addRecord(doc, 'tanggal_panen',
                                'jumlah_panen', 'panen');
                          }

                          final dates = agg.keys.toList()
                            ..sort((a, b) => b.compareTo(a));

                          return ListView(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            children: dates.map((dateKey) {
                              final d = DateTime.parse(dateKey);
                              final label = '${d.day} '
                                  '${d.month.toString().padLeft(2, '0')} '
                                  '${d.year}';

                              int seladaPlant = 0,
                                  seladaHarvest = 0,
                                  pakcoyPlant = 0,
                                  pakcoyHarvest = 0,
                                  kangkungPlant = 0,
                                  kangkungHarvest = 0;

                              final plantsMap = agg[dateKey]!;
                              plantsMap.forEach((plantId, value) {
                                final name = (plantNames[plantId] ??
                                        '')
                                    .toLowerCase();
                                if (name.contains('selada')) {
                                  seladaPlant +=
                                      value['tanam'] ?? 0;
                                  seladaHarvest +=
                                      value['panen'] ?? 0;
                                } else if (name.contains('pakcoy')) {
                                  pakcoyPlant +=
                                      value['tanam'] ?? 0;
                                  pakcoyHarvest +=
                                      value['panen'] ?? 0;
                                } else if (name.contains('kangkung')) {
                                  kangkungPlant +=
                                      value['tanam'] ?? 0;
                                  kangkungHarvest +=
                                      value['panen'] ?? 0;
                                }
                              });

                              return PlantHarvestHistoryExpansion(
                                date: label,
                                seladaPlantQty: seladaPlant,
                                seladaHarvestQty: seladaHarvest,
                                pakcoyPlantQty: pakcoyPlant,
                                pakcoyHarvestQty: pakcoyHarvest,
                                kangkungPlantQty: kangkungPlant,
                                kangkungHarvestQty: kangkungHarvest,
                                screenWidth: width,
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, int>> _aggregateForPlant(String plantId) async {
    int tanam = 0;
    int panen = 0;

    final tanamSnap = await FirebaseFirestore.instance
        .collection('data_tanam')
        .where('id_tanaman', isEqualTo: plantId)
        .get();
    for (final doc in tanamSnap.docs) {
      tanam += (doc.data()['jumlah_tanam'] as int? ?? 0);
    }

    final panenSnap = await FirebaseFirestore.instance
        .collection('data_panen')
        .where('id_tanaman', isEqualTo: plantId)
        .get();
    for (final doc in panenSnap.docs) {
      panen += (doc.data()['jumlah_panen'] as int? ?? 0);
    }

    return {'tanam': tanam, 'panen': panen};
  }
}

