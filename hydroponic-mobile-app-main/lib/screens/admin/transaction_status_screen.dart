import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Tambahkan import package pdf & printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:hydroponics_app/models/plant_model.dart';
import 'package:hydroponics_app/models/plant_quantity_model.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/widgets/transaction_status_card.dart';
import 'package:hydroponics_app/services/transaction_service.dart';
import 'package:hydroponics_app/screens/admin/add_edit_transaction_screen.dart';

class TransactionStatusScreen extends StatefulWidget {
  const TransactionStatusScreen({super.key});

  @override
  State<TransactionStatusScreen> createState() =>
      _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen> {
  bool _isExporting = false; // State loading untuk tombol ekspor

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
              // Update logika tombol
              text: _isExporting ? 'Memproses...' : 'Ekspor Data (PDF)',
              onPressed: _isExporting ? null : _exportToPdf,
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white,
              icon: _isExporting ? null : Icons.picture_as_pdf,
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
                          : 'Tanggal tidak tersedia';
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
                        onEdit: () {
                          if (model.id != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditTransactionScreen(
                                  transactionId: model.id!,
                                ),
                              ),
                            );
                          }
                        },
                        // onAssign dihapus karena transaksi otomatis muncul ke petani
                        onAssign: null,
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

  // --- FUNGSI EKSPOR PDF ---
  Future<void> _exportToPdf() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // 1. Ambil data transaksi
      final snapshot = await FirebaseFirestore.instance
          .collection('transaksi')
          .orderBy('tanggal', descending: true)
          .get();

      final docs = snapshot.docs;

      if (docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data transaksi untuk diekspor.')),
          );
        }
        return;
      }

      // 2. Buat PDF
      final pdf = pw.Document();
      final String dateNow = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());

      // Header Tabel
      final List<List<String>> tableData = [
        ['Tgl', 'Pelanggan', 'Alamat', 'Pesanan', 'Total', 'Bayar', 'Kirim'],
      ];

      // Isi Tabel
      for (var doc in docs) {
        final data = doc.data();
        
        // Format Tanggal
        final ts = data['tanggal'] as Timestamp?;
        final dateStr = ts != null ? DateFormat('dd/MM/yy').format(ts.toDate()) : 'Tanggal tidak tersedia';

        // Format Item (Misal: Selada(2), Pakcoy(1))
        final items = (data['items'] as List<dynamic>? ?? []);
        String itemsStr = items.isEmpty 
            ? 'Tidak ada item' 
            : items.map((i) {
                return "${i['nama_tanaman'] ?? 'Tanaman'}(${i['jumlah'] ?? 0})";
              }).join(', ');

        // Format Status
        final isPaid = (data['is_paid'] ?? false) ? 'Lunas' : 'Belum';
        final isDeliver = (data['is_deliver'] ?? false) ? 'Dikirim' : 'Proses';
        final total = (data['total_harga'] as num?)?.toStringAsFixed(0) ?? '0';

        tableData.add([
          dateStr,
          (data['nama_pelanggan'] ?? 'Tidak ada nama').toString(),
          (data['alamat'] ?? 'Tidak ada alamat').toString(),
          itemsStr,
          'Rp $total',
          isPaid,
          isDeliver,
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, // Landscape agar muat banyak kolom
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Laporan Transaksi', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(dateNow, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: tableData,
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9), // Font lebih kecil untuk tabel padat
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF014421)),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  4: pw.Alignment.centerRight, // Total rata kanan
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Transaksi_$dateNow',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}