import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  const MaintenanceDetailScreen({super.key});

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Menerima data dari Home Screen
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String idPetani = args['id_petani'];
    final String idTanaman = args['id_tanaman'];
    
    // MENERIMA ID DATA TANAM (BATCH)
    final String tanamId = args['tanam_id'] ?? '';
    
    // MENERIMA ID DOKUMEN (KUNCI UTAMA)
    final String docId = args['doc_id'] ?? '';

    // Field ini menjadi kunci untuk menentukan jenis perawatan
    final String field = args['field'];
    final DateTime tanggal = args['tanggal'];
    final String title = args['title'];
    final String description = args['description'];
    final bool isDone = args['is_done'] ?? false;

    final dateStr = DateFormat('dd MMMM yyyy').format(tanggal);
    const timeStr = '09:00';

    final bool isButtonDisabled = isDone || _isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Perawatan', style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 230, 245, 230),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.spa,
                    color: Color.fromARGB(255, 1, 68, 33),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Deskripsi
            const Text(
              'Deskripsi',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 25),

            // Info Tanggal & Waktu
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 5),
                            Text(
                              'Tanggal',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          dateStr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 5),
                            Text(
                              'Waktu',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          timeStr,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('tanaman')
                  .doc(idTanaman)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final plantData = snapshot.data!.data() as Map<String, dynamic>;
                
                String intervalColumn = '';
                
                // Logika pemetaan field ke nama kolom database
                // Menggunakan .toLowerCase() untuk pencocokan yang lebih aman
                final fieldKey = field.toLowerCase();
                final titleKey = title.toLowerCase();

                if (fieldKey.contains('air') || fieldKey.contains('nutrisi') || titleKey.contains('air')) {
                  intervalColumn = 'jadwal_pengecekan_air_dan_nutrisi';
                } else if (fieldKey.contains('pembersihan') || titleKey.contains('pembersihan')) {
                  intervalColumn = 'jadwal_pembersihan_instalasi';
                } else if (fieldKey.contains('tanaman') || titleKey.contains('tanaman')) {
                  // Cek tanaman ditaruh terakhir karena 'air_dan_nutrisi' mungkin mengandung kata tanaman
                  intervalColumn = 'jadwal_pengecekan_tanaman';
                }

                // Ambil nilai interval, default '-' jika kolom tidak ditemukan
                final interval = (intervalColumn.isNotEmpty) 
                    ? (plantData[intervalColumn] ?? '-') 
                    : '-';

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, color: Colors.blue.shade700),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interval Jadwal',
                              style: TextStyle(
                                fontSize: 14, 
                                color: Colors.blue.shade700
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$interval Hari Sekali',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Tombol Aksi
            SizedBox(
              width: double.infinity,
              height: 50,
              child: isButtonDisabled
                  ? ElevatedButton.icon(
                      onPressed: null, 
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        isDone ? 'Perawatan Selesai' : 'Sedang Memproses...',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor:
                            isDone ? Colors.green : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  : StyledElevatedButton(
                      text: 'Tandai Selesai',
                      onPressed: () => _markAsDone(
                          docId, idPetani, idTanaman, field, tanggal, tanamId),
                      backgroundColor: const Color.fromARGB(255, 1, 68, 33),
                      foregroundColor: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsDone(String docId, String idPetani, String idTanaman, String field,
      DateTime tanggal, String tanamId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Pastikan docId tidak kosong
      if (docId.isEmpty) {
        throw Exception("ID Dokumen tidak valid. Tidak bisa menyimpan status.");
      }

      await FirebaseFirestore.instance
          .collection('jadwal_perawatan')
          .doc(docId) // Gunakan ID yang dikirim dari Home Screen
          .set({
        'id_petani': idPetani,
        'id_tanaman': idTanaman,
        'id_data_tanam': tanamId,
        'field': field,
        'tanggal': Timestamp.fromDate(tanggal),
        'is_done': true,
        'completed_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal berhasil ditandai selesai!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}