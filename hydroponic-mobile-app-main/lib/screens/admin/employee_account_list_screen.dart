import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import package pdf dan printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal

import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/employee_list_card.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/screens/admin/edit_account_screen.dart';

class EmployeeAccountListScreen extends StatefulWidget{
  const EmployeeAccountListScreen({super.key});

  @override
  State<EmployeeAccountListScreen> createState() => _EmployeeAccountListScreenState();
}

class _EmployeeAccountListScreenState extends State<EmployeeAccountListScreen> {
  bool _isExporting = false; // State untuk loading saat ekspor

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Daftar Akun Karyawan', style: TextStyle(fontWeight: FontWeight.bold),),
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
              // Ubah teks jika sedang loading
              text: _isExporting ? 'Memproses...' : 'Ekspor Data (PDF)', 
              // Panggil fungsi _exportToPdf saat ditekan
              onPressed: _isExporting ? null : _exportToPdf,
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white,
              icon: _isExporting ? null : Icons.picture_as_pdf,
            ),
          ),
          Expanded(child: 
            SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(15),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('pengguna')
                      .orderBy('nama_pengguna')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Gagal memuat data karyawan: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Text(
                        'Belum ada akun karyawan. Tambahkan akun melalui menu "Tambah Akun".',
                      );
                    }

                    final farmers = <UserModel>[];
                    final couriers = <UserModel>[];
                    final logistics = <UserModel>[];

                    for (final doc in docs) {
                      final data = doc.data();
                      final user = UserModel(
                        username:
                            (data['nama_pengguna'] ?? '') as String,
                        role: (data['posisi'] ?? '') as String,
                        onNotificationTap: () {},
                        id: doc.id,
                      );
                      switch (user.role) {
                        case 'Petani':
                          farmers.add(user);
                          break;
                        case 'Kurir':
                          couriers.add(user);
                          break;
                        case 'Staf Logistik':
                          logistics.add(user);
                          break;
                        default:
                          break;
                      }
                    }

                    return Column(
                      // spacing: 7, // Perhatikan: properti spacing mungkin tidak ada di Column versi Flutter lama, gunakan SizedBox jika error
                      children: [
                        EmployeeListCard(
                          role: 'Petani',
                          userData: farmers,
                          onEdit: (user) => _editAccount(user),
                          onDelete: (user) =>
                              _deleteAccount(user, docs),
                        ),
                        const SizedBox(height: 7),
                        EmployeeListCard(
                          role: 'Kurir',
                          userData: couriers,
                          onEdit: (user) => _editAccount(user),
                          onDelete: (user) =>
                              _deleteAccount(user, docs),
                        ),
                        const SizedBox(height: 7),
                        EmployeeListCard(
                          role: 'Staf Logistik',
                          userData: logistics,
                          onEdit: (user) => _editAccount(user),
                          onDelete: (user) =>
                              _deleteAccount(user, docs),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          ),
        ],
      ),
    );
  }

  // Fungsi untuk edit akun
  void _editAccount(UserModel user) {
    if (user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID akun tidak ditemukan')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAccountScreen(userId: user.id!),
      ),
    );
  }

  // Fungsi untuk menghapus akun (sudah ada sebelumnya)
  void _deleteAccount(
    UserModel user,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content:
            Text('Yakin ingin menghapus akun ${user.username}? '
                'Ini hanya menghapus data di koleksi pengguna, '
                'bukan akun Firebase Auth.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('pengguna')
                  .doc(user.id)
                  .delete();
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
      // 1. Ambil data terbaru dari Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('pengguna')
          .orderBy('posisi') // Urutkan berdasarkan posisi
          .get();

      final docs = snapshot.docs;

      if (docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
          );
        }
        return;
      }

      // 2. Buat Dokumen PDF
      final pdf = pw.Document();
      
      // Load font (opsional, default font biasanya aman)
      // final font = await PdfGoogleFonts.nunitoExtraLight();

      // Tanggal laporan dibuat
      final String dateNow = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());

      // Siapkan data tabel
      // Header tabel
      final List<List<String>> tableData = [
        ['No', 'Nama Pengguna', 'Email', 'Posisi', 'Tanaman (Khusus Petani)'],
      ];

      // Isi tabel
      int i = 1;
      for (var doc in docs) {
        final data = doc.data();
        
        // Jika petani, ambil nama tanaman dari koleksi 'tanaman' (opsional, butuh fetch tambahan)
        // Untuk performa cepat, kita tampilkan ID atau string kosong dulu, 
        // atau fetch nama tanaman secara paralel jika perlu. 
        // Di sini kita ambil ID Tanaman saja atau logic sederhana.
        String infoTanaman = 'Tidak ada';
        if (data['posisi'] == 'Petani' && data['id_tanaman'] != null) {
           // Untuk laporan cepat, kita tulis "Ada ID Tanaman" atau fetch namanya
           // Kita biarkan ID-nya atau label generic agar tidak terlalu lama loading
           infoTanaman = 'Terhubung'; 
        }

        tableData.add([
          i.toString(),
          (data['nama_pengguna'] ?? 'Tidak ada nama').toString(),
          (data['email'] ?? 'Tidak ada email').toString(),
          (data['posisi'] ?? 'Tidak ada posisi').toString(),
          infoTanaman,
        ]);
        i++;
      }

      // 3. Desain Halaman PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Laporan Data Karyawan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('E-Ponic App', style: const pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 5),
                    pw.Text('Tanggal Cetak: $dateNow', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // Tabel Data
              pw.TableHelper.fromTextArray(
                context: context,
                data: tableData,
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF014421)), // Warna Hijau AppColors.primary
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center, // No rata tengah
                },
                headerHeight: 30,
                cellHeight: 30,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 20),
                child: pw.Text(
                  'Total Karyawan: ${docs.length}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ];
          },
        ),
      );

      // 4. Tampilkan Preview / Print Dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Karyawan_EPonic_$dateNow',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
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