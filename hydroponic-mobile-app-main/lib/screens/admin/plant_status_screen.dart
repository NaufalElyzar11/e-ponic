import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/plant_harvest_card.dart';
import 'package:hydroponics_app/widgets/plant_harvest_history_expansion.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class PlantStatusScreen extends StatefulWidget {
  const PlantStatusScreen({super.key});

  @override
  State<PlantStatusScreen> createState() => _PlantStatusScreenState();
}

class _PlantStatusScreenState extends State<PlantStatusScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Status Tanaman',
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
      body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container tombol ekspor
              Container(
                color: AppColors.primary,
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                child: StyledElevatedButton(
                  text: _isExporting ? 'Memproses...' : 'Ekspor Laporan (PDF)',
                  onPressed: _isExporting ? null : _exportToPdf,
                  foregroundColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  icon: _isExporting ? null : Icons.picture_as_pdf,
                ),
              ),
              _buildReadyToHarvestSection(),
              _buildHistorySection(constraints.maxWidth),
            ],
          ),
        );
      }),
    );
  }

  // --- BAGIAN 1: KARTU STOCK & SIAP PANEN ---
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
                    
                    // Parsing masa tanam
                    final masaTanamRaw = (data['masa_tanam'] ?? '30').toString();
                    final int masaTanam = int.tryParse(masaTanamRaw
                            .split('-')[0]
                            .replaceAll(RegExp(r'[^0-9]'), '')) ??
                        30;

                    return FutureBuilder<Map<String, int>>(
                      future: _aggregateForPlant(doc.id, masaTanam),
                      builder: (context, aggSnap) {
                        final stokSaatIni = aggSnap.data?['stock'] ?? 0;
                        final siapPanen = aggSnap.data?['ready'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: PlantHarvestCard(
                            plantName: nama,
                            plantHarvestQty: siapPanen,
                            plantTotalQty: stokSaatIni,
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

  // Helper: Menghitung Stok & Siap Panen
  Future<Map<String, int>> _aggregateForPlant(
      String plantId, int masaTanam) async {
    int totalTanamSemua = 0;
    int totalTanamMatang = 0;
    int totalPanen = 0;

    final now = DateTime.now();

    // 1. Ambil Data Tanam
    final tanamSnap = await FirebaseFirestore.instance
        .collection('data_tanam')
        .where('id_tanaman', isEqualTo: plantId)
        .get();

    for (final doc in tanamSnap.docs) {
      final jumlah = (doc.data()['jumlah_tanam'] as int? ?? 0);
      final Timestamp? ts = doc.data()['tanggal_tanam'] as Timestamp?;

      totalTanamSemua += jumlah;

      if (ts != null) {
        final tanggalTanam = ts.toDate();
        final selisihHari = now.difference(tanggalTanam).inDays;
        if (selisihHari >= masaTanam) {
          totalTanamMatang += jumlah;
        }
      }
    }

    // 2. Ambil Data Panen (Mencari via Petani)
    final farmersSnap = await FirebaseFirestore.instance
        .collection('pengguna')
        .where('id_tanaman', isEqualTo: plantId)
        .get();

    final List<String> farmerIds = farmersSnap.docs.map((d) => d.id).toList();

    if (farmerIds.isNotEmpty) {
      final panenSnap =
          await FirebaseFirestore.instance.collection('data_panen').get();

      for (final doc in panenSnap.docs) {
        final idPetaniPanen = doc.data()['id_petani'] as String?;
        if (idPetaniPanen != null && farmerIds.contains(idPetaniPanen)) {
          totalPanen += (doc.data()['jumlah_panen'] as int? ?? 0);
        }
      }
    }

    // 3. Hitung Hasil Akhir
    int sisaTanaman = totalTanamSemua - totalPanen;
    if (sisaTanaman < 0) sisaTanaman = 0;

    int sisaSiapPanen = totalTanamMatang - totalPanen;
    if (sisaSiapPanen < 0) sisaSiapPanen = 0;
    
    if (sisaSiapPanen > sisaTanaman) sisaSiapPanen = sisaTanaman;

    return {'stock': sisaTanaman, 'ready': sisaSiapPanen};
  }

  // --- BAGIAN 2: RIWAYAT AKTIVITAS ---
  Widget _buildHistorySection(double width) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 5, bottom: 15, left: 15, right: 15),
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

              // Ambil Data Master (Tanaman & Pengguna)
              FutureBuilder<List<QuerySnapshot>>(
                future: Future.wait([
                  FirebaseFirestore.instance.collection('tanaman').get(),
                  FirebaseFirestore.instance.collection('pengguna').get(),
                ]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Map 1: ID Tanaman -> Nama Tanaman
                  final plantDocs = snapshot.data?[0].docs ?? [];
                  final Map<String, String> plantNames = {
                    for (final doc in plantDocs)
                      doc.id: (doc.data() as Map<String, dynamic>)['nama_tanaman'] ?? '',
                  };

                  // Map 2: ID Petani -> ID Tanaman
                  final userDocs = snapshot.data?[1].docs ?? [];
                  final Map<String, String> farmerToPlant = {};
                  for (final doc in userDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final val = data['id_tanaman'];
                    if (val != null && val is String) {
                      farmerToPlant[doc.id] = val;
                    }
                  }

                  // Stream Realtime Data Tanam
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('data_tanam')
                        .orderBy('tanggal_tanam', descending: true)
                        .snapshots(),
                    builder: (context, tanamSnap) {
                      final tanamDocs = tanamSnap.data?.docs ?? [];

                      // Stream Realtime Data Panen
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('data_panen')
                            .orderBy('tanggal_panen', descending: true)
                            .snapshots(),
                        builder: (context, panenSnap) {
                          final panenDocs = panenSnap.data?.docs ?? [];

                          // Agregasi Data
                          final Map<String, Map<String, Map<String, int>>> agg = {};

                          void addRecord(
                            QueryDocumentSnapshot<Map<String, dynamic>> doc,
                            String dateField,
                            String qtyField,
                            String type,
                          ) {
                            final data = doc.data();
                            final ts = data[dateField] as Timestamp?;
                            final d = ts?.toDate();
                            if (d == null) return;

                            final dateKey = DateTime(d.year, d.month, d.day).toIso8601String();

                            String plantId = '';
                            if (type == 'tanam') {
                              plantId = (data['id_tanaman'] ?? '') as String;
                            } else {
                              final idPetani = (data['id_petani'] ?? '') as String;
                              plantId = farmerToPlant[idPetani] ?? '';
                            }

                            if (plantId.isEmpty) return;

                            agg.putIfAbsent(dateKey, () => {});
                            agg[dateKey]!.putIfAbsent(plantId, () => {'tanam': 0, 'panen': 0});
                            
                            final currentVal = agg[dateKey]![plantId]![type] ?? 0;
                            final additionalVal = (data[qtyField] as int? ?? 0);
                            
                            agg[dateKey]![plantId]![type] = currentVal + additionalVal;
                          }

                          for (final doc in tanamDocs) {
                            addRecord(doc, 'tanggal_tanam', 'jumlah_tanam', 'tanam');
                          }
                          for (final doc in panenDocs) {
                            addRecord(doc, 'tanggal_panen', 'jumlah_panen', 'panen');
                          }

                          final dates = agg.keys.toList()..sort((a, b) => b.compareTo(a));

                          return ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: dates.map((dateKey) {
                              final d = DateTime.parse(dateKey);
                              final label = DateFormat('dd MMMM yyyy', 'id_ID').format(d);

                              int seladaPlant = 0, seladaHarvest = 0;
                              int pakcoyPlant = 0, pakcoyHarvest = 0;
                              int kangkungPlant = 0, kangkungHarvest = 0;

                              final plantsMap = agg[dateKey]!;
                              plantsMap.forEach((plantId, value) {
                                final name = (plantNames[plantId] ?? '').toLowerCase();

                                if (name.contains('selada')) {
                                  seladaPlant += value['tanam'] ?? 0;
                                  seladaHarvest += value['panen'] ?? 0;
                                } else if (name.contains('pakcoy')) {
                                  pakcoyPlant += value['tanam'] ?? 0;
                                  pakcoyHarvest += value['panen'] ?? 0;
                                } else if (name.contains('kangkung')) {
                                  kangkungPlant += value['tanam'] ?? 0;
                                  kangkungHarvest += value['panen'] ?? 0;
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

  // --- BAGIAN 3: EKSPOR PDF (DIPERBAIKI) ---
  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);

    try {
      final now = DateTime.now();

      // 1. Fetch Semua Data
      final tanamanSnap = await FirebaseFirestore.instance.collection('tanaman').get();
      final tanamSnap = await FirebaseFirestore.instance.collection('data_tanam').get();
      final panenSnap = await FirebaseFirestore.instance.collection('data_panen').get();
      final penggunaSnap = await FirebaseFirestore.instance.collection('pengguna').get();

      if (tanamanSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data tanaman kosong')));
        }
        return;
      }

      // 2. Map & Data Helper
      final Map<String, String> plantNames = {};
      final Map<String, int> plantMasaTanam = {}; // Map ID -> Masa Tanam (int)

      for (var doc in tanamanSnap.docs) {
        final data = doc.data();
        plantNames[doc.id] = (data['nama_tanaman'] ?? 'Tanaman') as String;
        
        // Parse Masa Tanam
        final raw = (data['masa_tanam'] ?? '30').toString();
        final days = int.tryParse(raw.split('-')[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 30;
        plantMasaTanam[doc.id] = days;
      }

      // Map Petani -> Tanaman
      final Map<String, String> farmerToPlant = {};
      for (var doc in penggunaSnap.docs) {
        final data = doc.data();
        final val = data['id_tanaman'];
        if (val != null && val is String) {
          farmerToPlant[doc.id] = val;
        }
      }

      // 3. Hitung Ringkasan (Sinkron dengan Logika Kartu)
      // Structure: { plantId: { 'tanam': X, 'matang': Y, 'panen': Z } }
      final Map<String, Map<String, int>> summaryData = {};
      
      for (var id in plantNames.keys) {
        summaryData[id] = {'tanam': 0, 'matang': 0, 'panen': 0};
      }

      // Hitung Tanam & Matang
      for (var doc in tanamSnap.docs) {
        final pid = doc.data()['id_tanaman'] as String?;
        final qty = doc.data()['jumlah_tanam'] as int? ?? 0;
        final ts = doc.data()['tanggal_tanam'] as Timestamp?;

        if (pid != null && summaryData.containsKey(pid)) {
          // Tambah Total Tanam
          summaryData[pid]!['tanam'] = (summaryData[pid]!['tanam'] ?? 0) + qty;

          // Cek Kematangan
          if (ts != null) {
            final tanggalTanam = ts.toDate();
            final masaTanam = plantMasaTanam[pid] ?? 30;
            final selisihHari = now.difference(tanggalTanam).inDays;
            
            if (selisihHari >= masaTanam) {
              summaryData[pid]!['matang'] = (summaryData[pid]!['matang'] ?? 0) + qty;
            }
          }
        }
      }

      // Hitung Panen
      for (var doc in panenSnap.docs) {
        final idPetani = doc.data()['id_petani'] as String?;
        final qty = doc.data()['jumlah_panen'] as int? ?? 0;
        
        if (idPetani != null && farmerToPlant.containsKey(idPetani)) {
          final pid = farmerToPlant[idPetani];
          if (pid != null && summaryData.containsKey(pid)) {
            summaryData[pid]!['panen'] = (summaryData[pid]!['panen'] ?? 0) + qty;
          }
        }
      }

      // Buat Tabel Summary PDF
      // Kolom: Nama, Total Tanam (Fisik), Total Panen, Stok Siap Panen (Matang - Panen)
      final List<List<String>> summaryTable = [
        ['Tanaman', 'Total Tanam', 'Total Panen', 'Siap Panen']
      ];
      
      summaryData.forEach((id, val) {
        final name = plantNames[id] ?? 'Tanaman tidak diketahui';
        final t = val['tanam']!; // Total Fisik
        final m = val['matang']!; // Total Matang
        final p = val['panen']!; // Total Panen
        
        // Stok Fisik = Tanam - Panen
        int stockFisik = t - p;
        if (stockFisik < 0) stockFisik = 0;

        // Siap Panen = Matang - Panen
        int siapPanen = m - p;
        if (siapPanen < 0) siapPanen = 0;
        if (siapPanen > stockFisik) siapPanen = stockFisik; // Safety cap

        summaryTable.add([name, '$stockFisik', '$p', '$siapPanen']);
      });

      // 4. Riwayat (Logika sama, hanya untuk display list)
      final List<Map<String, dynamic>> historyList = [];

      for (var doc in tanamSnap.docs) {
        final ts = doc.data()['tanggal_tanam'] as Timestamp?;
        if (ts != null) {
          historyList.add({
            'date': ts.toDate(),
            'type': 'Tanam',
            'plant': plantNames[doc.data()['id_tanaman']] ?? 'Tanaman tidak diketahui',
            'qty': doc.data()['jumlah_tanam'] ?? 0,
          });
        }
      }

      for (var doc in panenSnap.docs) {
        final ts = doc.data()['tanggal_panen'] as Timestamp?;
        final idPetani = doc.data()['id_petani'] as String?;
        
        String plantName = 'Panen (Umum)';
        if (idPetani != null && farmerToPlant.containsKey(idPetani)) {
          final pid = farmerToPlant[idPetani];
          plantName = plantNames[pid] ?? 'Tanaman tidak diketahui';
        }

        if (ts != null) {
          historyList.add({
            'date': ts.toDate(),
            'type': 'Panen',
            'plant': plantName,
            'qty': doc.data()['jumlah_panen'] ?? 0,
          });
        }
      }

      historyList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      final List<List<String>> historyTable = [
        ['Tanggal', 'Aktivitas', 'Tanaman', 'Jumlah']
      ];
      for (var item in historyList) {
        final dt = DateFormat('dd MMM yyyy', 'id_ID').format(item['date']);
        historyTable.add([
          dt,
          item['type'],
          item['plant'],
          '${item['qty']}',
        ]);
      }

      // 5. Generate PDF Document
      final pdf = pw.Document();
      final dateNow = DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                  level: 0,
                  child: pw.Text('Laporan Status Tanaman',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.Text('Dicetak pada: $dateNow',
                  style: const pw.TextStyle(color: PdfColors.grey)),
              pw.SizedBox(height: 20),
              
              pw.Text('Ringkasan Stok (Siap Panen)',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('(Total Tanam adalah sisa stok fisik di kebun)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.SizedBox(height: 5),
              
              pw.TableHelper.fromTextArray(
                context: context,
                data: summaryTable,
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFF014421)),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignment: pw.Alignment.center,
              ),
              
              pw.SizedBox(height: 20),
              pw.Text('Riwayat Aktivitas (Tanam & Panen)',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              
              pw.TableHelper.fromTextArray(
                  context: context,
                  data: historyTable,
                  headerDecoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF014421)),
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                  }),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Tanaman_$dateNow',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}