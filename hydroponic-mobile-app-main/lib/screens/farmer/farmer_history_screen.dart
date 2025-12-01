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
        title: const Text(
          'Riwayat Tanam',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 25,
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 1, 68, 33),
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
              if (tanamSnapshot.connectionState == ConnectionState.waiting) {
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  final panenDocs = panenSnapshot.data?.docs ?? [];

                  final Map<String, _HistoryAgg> map = {};

                  // --- PROSES DATA TANAM ---
                  for (final doc in tanamDocs) {
                    final data = doc.data();
                    final ts = data['tanggal_tanam'] as Timestamp?;
                    final d = ts?.toDate();
                    if (d == null) continue;
                    final key = DateFormat('yyyy-MM-dd').format(d.toLocal());
                    map.putIfAbsent(key, () => _HistoryAgg());
                    map[key]!.tanam += (data['jumlah_tanam'] as int? ?? 0);
                    map[key]!.tanamIds.add(doc.id);
                    map[key]!.tanamDocs.add({
                      'id': doc.id,
                      'jumlah_tanam': data['jumlah_tanam'] as int? ?? 0,
                      'tanggal_tanam': d,
                    });
                  }

                  // --- PROSES DATA PANEN ---
                  for (final doc in panenDocs) {
                    final data = doc.data();
                    final ts = data['tanggal_panen'] as Timestamp?;
                    final d = ts?.toDate();
                    if (d == null) continue;
                    final key = DateFormat('yyyy-MM-dd').format(d.toLocal());
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
                    final label = DateFormat('dd MMM yyyy').format(d.toLocal());
                    final agg = map[key]!;
                    
                    // Copy list agar aman digunakan dalam callback (closure)
                    final tanamDocsCopy = List<Map<String, dynamic>>.from(agg.tanamDocs);
                    final panenDocsCopy = List<Map<String, dynamic>>.from(agg.panenDocs);
                    final tanamIdsCopy = List<String>.from(agg.tanamIds);
                    final panenIdsCopy = List<String>.from(agg.panenIds);

                    dataList.add(PlantHistoryModel(
                      date: label,
                      plantQty: agg.tanam,
                      harvestQty: agg.panen,
                      
                      // Masukkan jumlah dokumen untuk logika UI
                      plantDocCount: tanamDocsCopy.length,
                      harvestDocCount: panenDocsCopy.length,

                      // --- EDIT CALLBACKS ---
                      onPlantEdit: () {
                        _handleEditPlant(tanamDocsCopy);
                      },
                      onHarvestEdit: () {
                        _handleEditHarvest(panenDocsCopy);
                      },

                      // --- DELETE PER KATEGORI (CERDAS) ---
                      onDeletePlant: () {
                        _handleDeleteDocs(
                          docs: tanamDocsCopy,
                          collectionName: 'data_tanam',
                          title: 'Tanam',
                          unit: 'bibit',
                          qtyKey: 'jumlah_tanam',
                          dateKey: 'tanggal_tanam',
                        );
                      },
                      onDeleteHarvest: () {
                        _handleDeleteDocs(
                          docs: panenDocsCopy,
                          collectionName: 'data_panen',
                          title: 'Panen',
                          unit: 'panen',
                          qtyKey: 'jumlah_panen',
                          dateKey: 'tanggal_panen',
                        );
                      },

                      // --- DELETE ALL (HAPUS TANGGAL INI) ---
                      onDeleteAll: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Semua Data?'),
                            content: Text(
                                'Anda yakin ingin menghapus semua data pada tanggal $label?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteDocs(
                                    collection: 'data_tanam',
                                    ids: tanamIdsCopy,
                                    alsoDeleteCollection2: 'data_panen',
                                    ids2: panenIdsCopy,
                                  );
                                },
                                child: const Text('Hapus',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ));
                  }

                  if (dataList.isEmpty) {
                    return const Center(child: Text('Belum ada riwayat.'));
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
        },
      ),
    );
  }

  /// Fungsi penghapusan dokumen secara batch
  Future<void> _deleteDocs({
    required String collection,
    required List<String> ids,
    String? alsoDeleteCollection2,
    List<String>? ids2,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(FirebaseFirestore.instance.collection(collection).doc(id));
    }
    if (alsoDeleteCollection2 != null && ids2 != null) {
      for (final id in ids2) {
        batch.delete(
            FirebaseFirestore.instance.collection(alsoDeleteCollection2).doc(id));
      }
    }
    await batch.commit();
    
    if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dihapus')),
      );
    }
  }

  /// Logika hapus cerdas: Konfirmasi langsung jika 1 data, Pilih list jika > 1 data
  Future<void> _handleDeleteDocs({
    required List<Map<String, dynamic>> docs,
    required String collectionName,
    required String title,
    required String unit,
    required String qtyKey,
    required String dateKey,
  }) async {
    if (!mounted || docs.isEmpty) return;

    // KASUS 1: Hanya ada satu data -> Konfirmasi langsung
    if (docs.length == 1) {
      final doc = docs.first;
      final qty = doc[qtyKey];
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Hapus Data $title'),
          content: Text('Hapus data $qty $unit ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteDocs(collection: collectionName, ids: [doc['id']]);
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }

    // KASUS 2: Ada banyak data -> Pilih mana yang dihapus
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pilih Data $title yang Dihapus'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final date = DateFormat('HH:mm').format(doc[dateKey] as DateTime);
              final qty = doc[qtyKey];

              return ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('$qty $unit'),
                subtitle: Text('Jam Input: $date'),
                onTap: () {
                  // Tutup dialog list dulu
                  Navigator.pop(ctx);
                  
                  // Tampilkan konfirmasi untuk item spesifik ini
                  showDialog(
                    context: context,
                    builder: (confirmCtx) => AlertDialog(
                      title: const Text('Konfirmasi Hapus'),
                      content: Text('Yakin hapus data $qty $unit ini?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmCtx),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(confirmCtx);
                            _deleteDocs(collection: collectionName, ids: [doc['id']]);
                          },
                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  // --- LOGIKA EDIT DATA TANAM ---
  Future<void> _handleEditPlant(List<Map<String, dynamic>> docs) async {
    if (!mounted || docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data tanam untuk diedit')),
      );
      return;
    }

    // Single Doc
    if (docs.length == 1) {
      await _navigateToEditPlant(docs.first);
      return;
    }

    // Multiple Docs
    final selectedDoc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Data Tanam'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final date = DateFormat('HH:mm').format(doc['tanggal_tanam'] as DateTime);
              return ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text('${doc['jumlah_tanam']} bibit'),
                subtitle: Text('Jam Input: $date'),
                onTap: () => Navigator.pop(ctx, doc),
              );
            },
          ),
        ),
      ),
    );

    if (selectedDoc != null && mounted) {
      await _navigateToEditPlant(selectedDoc);
    }
  }

  Future<void> _navigateToEditPlant(Map<String, dynamic> doc) async {
    try {
      final documentId = doc['id'] as String?;
      final jumlah = doc['jumlah_tanam'] as int?;
      final tanggal = doc['tanggal_tanam'] as DateTime?;

      if (documentId == null || jumlah == null || tanggal == null) return;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- LOGIKA EDIT DATA PANEN ---
  Future<void> _handleEditHarvest(List<Map<String, dynamic>> docs) async {
    if (!mounted || docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data panen untuk diedit')),
      );
      return;
    }

    // Single Doc
    if (docs.length == 1) {
      await _navigateToEditHarvest(docs.first);
      return;
    }

    // Multiple Docs
    final selectedDoc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Data Panen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final date = DateFormat('HH:mm').format(doc['tanggal_panen'] as DateTime);
              return ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text('${doc['jumlah_panen']} panen'),
                subtitle: Text('Jam Input: $date'),
                onTap: () => Navigator.pop(ctx, doc),
              );
            },
          ),
        ),
      ),
    );

    if (selectedDoc != null && mounted) {
      await _navigateToEditHarvest(selectedDoc);
    }
  }

  Future<void> _navigateToEditHarvest(Map<String, dynamic> doc) async {
    try {
      final documentId = doc['id'] as String?;
      final jumlah = doc['jumlah_panen'] as int?;
      final tanggal = doc['tanggal_panen'] as DateTime?;

      if (documentId == null || jumlah == null || tanggal == null) return;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// Class Helper untuk Agregasi Data
class _HistoryAgg {
  int tanam = 0;
  int panen = 0;
  final List<String> tanamIds = [];
  final List<String> panenIds = [];
  final List<Map<String, dynamic>> tanamDocs = []; 
  final List<Map<String, dynamic>> panenDocs = []; 
}