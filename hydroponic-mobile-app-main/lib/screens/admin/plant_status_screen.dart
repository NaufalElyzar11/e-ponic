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

class PlantStatusScreen extends StatefulWidget{
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
        title: const Text('Status Tanaman', style: TextStyle(fontWeight: FontWeight.bold),),
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
      body: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
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
        }
      ),
    );
  }

  // --- PERBAIKAN 1: Mengambil masa_tanam dari dokumen ---
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
                    
                    // Ambil masa tanam (default 0 jika tidak ada)
                    final int masaTanam = (data['masa_tanam'] ?? 0) as int;

                    return FutureBuilder<Map<String, int>>(
                      // Kirim masaTanam ke fungsi helper
                      future: _aggregateForPlant(doc.id, masaTanam),
                      builder: (context, aggSnap) {
                        // Data default
                        final stokSaatIni = aggSnap.data?['stock'] ?? 0;
                        final siapPanen = aggSnap.data?['ready'] ?? 0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: PlantHarvestCard(
                            plantName: nama,
                            // plantHarvestQty: Total yang SUDAH MATANG (siap panen)
                            plantHarvestQty: siapPanen,
                            // plantTotalQty: Sisa tanaman yang ada di kebun (hidup)
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

  // --- PERBAIKAN 2: Logika Perhitungan ---
  Future<Map<String, int>> _aggregateForPlant(String plantId, int masaTanam) async {
    int totalTanamSemua = 0;
    int totalTanamMatang = 0; // Yang usianya >= masa_tanam
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
      
      // Hitung Total Seluruh Tanam
      totalTanamSemua += jumlah;

      // Cek apakah batch ini sudah matang
      if (ts != null) {
        final tanggalTanam = ts.toDate();
        final selisihHari = now.difference(tanggalTanam).inDays;

        if (selisihHari >= masaTanam) {
          totalTanamMatang += jumlah;
        }
      }
    }

    // 2. Ambil Data Panen
    final panenSnap = await FirebaseFirestore.instance
        .collection('data_panen')
        .where('id_tanaman', isEqualTo: plantId)
        .get();
    
    for (final doc in panenSnap.docs) {
      totalPanen += (doc.data()['jumlah_panen'] as int? ?? 0);
    }

    // 3. Hitung Hasil Akhir
    
    // Sisa Tanaman (Stock) = Total Masuk - Total Keluar
    int sisaTanaman = totalTanamSemua - totalPanen;
    if (sisaTanaman < 0) sisaTanaman = 0; // Safety check

    // Siap Panen (Ready) = (Total Tanam yang Sudah Matang) - (Yang Sudah Dipanen)
    // Asumsinya kita memanen yang matang duluan.
    int sisaSiapPanen = totalTanamMatang - totalPanen;
    
    // Validasi Logika: Siap panen tidak boleh minus
    if (sisaSiapPanen < 0) sisaSiapPanen = 0;
    
    // Validasi Logika: Siap panen tidak boleh lebih besar dari sisa tanaman fisik
    if (sisaSiapPanen > sisaTanaman) sisaSiapPanen = sisaTanaman;

    return {
      'stock': sisaTanaman, // Untuk plantTotalQty
      'ready': sisaSiapPanen // Untuk plantHarvestQty
    };
  }

  // ... Widget _buildHistorySection TETAP SAMA seperti kode awal Anda ...
  Widget _buildHistorySection(double width) {
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
                              final label = DateFormat('dd MMMM yyyy', 'id_ID').format(d);

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

  // ... _exportToPdf TETAP SAMA ... (Anda bisa paste fungsi export Anda yang sebelumnya di sini)
  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);

    try {
      // 1. Fetch semua data yang dibutuhkan
      final tanamanSnap = await FirebaseFirestore.instance.collection('tanaman').get();
      final tanamSnap = await FirebaseFirestore.instance.collection('data_tanam').get();
      final panenSnap = await FirebaseFirestore.instance.collection('data_panen').get();

      if (tanamanSnap.docs.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data tanaman kosong')));
        return;
      }

      // 2. Proses Data: Map ID Tanaman -> Nama
      final Map<String, String> plantNames = {
        for (var doc in tanamanSnap.docs) doc.id: (doc.data()['nama_tanaman'] ?? 'Tanaman')
      };

      // 3. Proses Data: Ringkasan Siap Panen (Total Tanam - Total Panen)
      final Map<String, Map<String, int>> summaryData = {};
      // Inisialisasi
      for(var id in plantNames.keys) {
        summaryData[id] = {'tanam': 0, 'panen': 0};
      }
      // Hitung Total Tanam
      for (var doc in tanamSnap.docs) {
        final pid = doc.data()['id_tanaman'] as String?;
        final qty = doc.data()['jumlah_tanam'] as int? ?? 0;
        if(pid != null && summaryData.containsKey(pid)) {
          summaryData[pid]!['tanam'] = (summaryData[pid]!['tanam'] ?? 0) + qty;
        }
      }
      // Hitung Total Panen
      for (var doc in panenSnap.docs) {
        final pid = doc.data()['id_tanaman'] as String?; 
        final qty = doc.data()['jumlah_panen'] as int? ?? 0;
        
        if(pid != null && summaryData.containsKey(pid)) {
          summaryData[pid]!['panen'] = (summaryData[pid]!['panen'] ?? 0) + qty;
        }
      }

      // Siapkan Tabel Ringkasan untuk PDF
      final List<List<String>> summaryTable = [['Tanaman', 'Total Tanam', 'Total Panen', 'Siap Panen (Sisa)']];
      summaryData.forEach((id, val) {
        final name = plantNames[id] ?? 'Tanaman tidak diketahui';
        final t = val['tanam']!;
        final p = val['panen']!;
        final sisa = t - p;
        summaryTable.add([name, '$t', '$p', '$sisa']);
      });

      // 4. Proses Data: Riwayat Aktivitas Kronologis
      // Kita gabungkan data tanam dan panen jadi satu list event
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
        final pid = doc.data()['id_tanaman'];
        if (ts != null) {
          historyList.add({
            'date': ts.toDate(),
            'type': 'Panen',
            'plant': pid != null ? (plantNames[pid] ?? 'Tanaman tidak diketahui') : 'Panen (Umum)',
            'qty': doc.data()['jumlah_panen'] ?? 0,
          });
        }
      }

      // Sort descending (terbaru diatas)
      historyList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      final List<List<String>> historyTable = [['Tanggal', 'Aktivitas', 'Tanaman', 'Jumlah']];
      for (var item in historyList) {
        final dt = DateFormat('dd MMM yyyy').format(item['date']);
        historyTable.add([
          dt,
          item['type'],
          item['plant'],
          '${item['qty']}',
        ]);
      }

      // 5. Generate PDF
      final pdf = pw.Document();
      final dateNow = DateFormat('dd MMMM yyyy').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Laporan Status Tanaman', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.Text('Dicetak pada: $dateNow', style: const pw.TextStyle(color: PdfColors.grey)),
              pw.SizedBox(height: 20),
              
              pw.Text('Ringkasan Stok (Siap Panen)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                context: context,
                data: summaryTable,
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF014421)),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignment: pw.Alignment.center,
              ),

              pw.SizedBox(height: 20),
              pw.Text('Riwayat Aktivitas (Tanam & Panen)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                context: context,
                data: historyTable,
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF014421)),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                }
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Tanaman_$dateNow',
      );

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error PDF: $e')));
      }
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }
}