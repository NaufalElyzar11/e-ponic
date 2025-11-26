import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/plant_history_model.dart';
import 'package:hydroponics_app/widgets/farmer_history_expansion_item.dart';
import 'package:hydroponics_app/screens/farmer/edit_plant_data_screen.dart';
import 'package:hydroponics_app/screens/farmer/edit_harvest_data_screen.dart';

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
                    map[key]!.tanamDocs.add({
                      'id': doc.id,
                      'jumlah_tanam': data['jumlah_tanam'] as int? ?? 0,
                      'tanggal_tanam': d,
                    });
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
                    map[key]!.panenDocs.add({
                      'id': doc.id,
                      'jumlah_panen': data['jumlah_panen'] as int? ?? 0,
                      'tanggal_panen': d,
                    });
                  }

                  final keys = map.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  final List<PlantHistoryModel> dataList = [];
                  for (final key in keys) {
                    final d = DateTime.parse(key);
                    final label =
                        DateFormat('dd MMM yyyy').format(d.toLocal());
                    final agg = map[key]!;
                    // Simpan reference ke docs untuk digunakan di callback
                    final tanamDocsCopy = List<Map<String, dynamic>>.from(agg.tanamDocs);
                    final panenDocsCopy = List<Map<String, dynamic>>.from(agg.panenDocs);
                    final tanamIdsCopy = List<String>.from(agg.tanamIds);
                    final panenIdsCopy = List<String>.from(agg.panenIds);
                    
                    print('📊 Creating history item for $label: tanam=${tanamDocsCopy.length}, panen=${panenDocsCopy.length}');
                    
                    dataList.add(PlantHistoryModel(
                      date: label,
                      plantQty: agg.tanam,
                      harvestQty: agg.panen,
                      onPlantEdit: () {
                        print('📝 onPlantEdit callback triggered for date: $label, docs: ${tanamDocsCopy.length}');
                        if (tanamDocsCopy.isEmpty) {
                          print('⚠️ tanamDocsCopy is empty!');
                        }
                        _handleEditPlant(tanamDocsCopy);
                      }, 
                      onPlantDelete: () {
                        _deleteDocs(
                          collection: 'data_tanam',
                          ids: tanamIdsCopy,
                        );
                      },
                      onHarvestEdit: () {
                        print('📝 onHarvestEdit callback triggered for date: $label, docs: ${panenDocsCopy.length}');
                        if (panenDocsCopy.isEmpty) {
                          print('⚠️ panenDocsCopy is empty!');
                        }
                        _handleEditHarvest(panenDocsCopy);
                      }, 
                      onHarvestDelete: () {
                        _deleteDocs(
                          collection: 'data_panen',
                          ids: panenIdsCopy,
                        );
                      },
                      onDeleteAll: () {
                        _deleteDocs(
                          collection: 'data_tanam',
                          ids: tanamIdsCopy,
                          alsoDeleteCollection2: 'data_panen',
                          ids2: panenIdsCopy,
                        );
                      },
                    ));
                  }

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

  Future<void> _handleEditPlant(
    List<Map<String, dynamic>> docs,
  ) async {
    print('🔧 _handleEditPlant called with ${docs.length} docs');
    if (!mounted) {
      print('❌ Widget not mounted');
      return;
    }
    
    if (docs.isEmpty) {
      print('⚠️ No docs to edit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data tanam untuk diedit')),
      );
      return;
    }

    // Jika hanya ada satu dokumen, langsung edit
    if (docs.length == 1) {
      try {
        final doc = docs.first;
        final documentId = doc['id'] as String?;
        final jumlah = doc['jumlah_tanam'] as int?;
        final tanggal = doc['tanggal_tanam'] as DateTime?;
        
        if (documentId == null || jumlah == null || tanggal == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data tidak valid untuk diedit')),
            );
          }
          return;
        }
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditPlantDataScreen(
              documentId: documentId,
              currentJumlah: jumlah,
              currentTanggal: tanggal,
            ),
          ),
        );
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil diperbarui')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
      return;
    }

    // Jika ada multiple dokumen, tampilkan dialog untuk memilih
    final selectedDoc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Data yang Akan Diedit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final date = DateFormat('dd MMM yyyy').format(doc['tanggal_tanam'] as DateTime);
              return ListTile(
                title: Text('${doc['jumlah_tanam']} bibit'),
                subtitle: Text('Tanggal: $date'),
                onTap: () => Navigator.pop(ctx, doc),
              );
            },
          ),
        ),
      ),
    );

    if (selectedDoc != null && mounted) {
      try {
        final documentId = selectedDoc['id'] as String?;
        final jumlah = selectedDoc['jumlah_tanam'] as int?;
        final tanggal = selectedDoc['tanggal_tanam'] as DateTime?;
        
        if (documentId == null || jumlah == null || tanggal == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data tidak valid untuk diedit')),
          );
          return;
        }
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditPlantDataScreen(
              documentId: documentId,
              currentJumlah: jumlah,
              currentTanggal: tanggal,
            ),
          ),
        );
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil diperbarui')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleEditHarvest(
    List<Map<String, dynamic>> docs,
  ) async {
    print('🔧 _handleEditHarvest called with ${docs.length} docs');
    if (!mounted) {
      print('❌ Widget not mounted');
      return;
    }
    
    if (docs.isEmpty) {
      print('⚠️ No docs to edit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data panen untuk diedit')),
      );
      return;
    }

    // Jika hanya ada satu dokumen, langsung edit
    if (docs.length == 1) {
      try {
        final doc = docs.first;
        final documentId = doc['id'] as String?;
        final jumlah = doc['jumlah_panen'] as int?;
        final tanggal = doc['tanggal_panen'] as DateTime?;
        
        if (documentId == null || jumlah == null || tanggal == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data tidak valid untuk diedit')),
            );
          }
          return;
        }
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditHarvestDataScreen(
              documentId: documentId,
              currentJumlah: jumlah,
              currentTanggal: tanggal,
            ),
          ),
        );
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil diperbarui')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
      return;
    }

    // Jika ada multiple dokumen, tampilkan dialog untuk memilih
    final selectedDoc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Data yang Akan Diedit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final date = DateFormat('dd MMM yyyy').format(doc['tanggal_panen'] as DateTime);
              return ListTile(
                title: Text('${doc['jumlah_panen']} panen'),
                subtitle: Text('Tanggal: $date'),
                onTap: () => Navigator.pop(ctx, doc),
              );
            },
          ),
        ),
      ),
    );

    if (selectedDoc != null && mounted) {
      try {
        final documentId = selectedDoc['id'] as String?;
        final jumlah = selectedDoc['jumlah_panen'] as int?;
        final tanggal = selectedDoc['tanggal_panen'] as DateTime?;
        
        if (documentId == null || jumlah == null || tanggal == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data tidak valid untuk diedit')),
          );
          return;
        }
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditHarvestDataScreen(
              documentId: documentId,
              currentJumlah: jumlah,
              currentTanggal: tanggal,
            ),
          ),
        );
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil diperbarui')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

class _HistoryAgg {
  int tanam = 0;
  int panen = 0;
  final List<String> tanamIds = [];
  final List<String> panenIds = [];
  final List<Map<String, dynamic>> tanamDocs = []; // Store full doc data for edit
  final List<Map<String, dynamic>> panenDocs = []; // Store full doc data for edit
}

