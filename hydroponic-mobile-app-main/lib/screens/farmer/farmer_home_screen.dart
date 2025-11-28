import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/plant_maintenance_model.dart';
import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/widgets/farmer_total_plant_card.dart';
import 'package:hydroponics_app/widgets/home_app_bar.dart';
import 'package:hydroponics_app/widgets/maintenance_schedule_card.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/services/auth_service.dart';
import 'package:hydroponics_app/services/alarm_service.dart';
import 'package:hydroponics_app/services/notification_service.dart';

class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  late final Future<_FarmerInfo> _farmerInfoFuture;

  @override
  void initState() {
    super.initState();
    _farmerInfoFuture = _loadFarmerInfo();
  }

  Future<_FarmerInfo> _loadFarmerInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User belum login');
    }

    final userDoc = await AuthService.instance.getCurrentUserDoc();
    final data = userDoc?.data() ?? {};
    final nama = (data['nama_pengguna'] ?? 'Petani') as String;
    String posisi = (data['posisi'] ?? 'Petani') as String;
    final plantId = data['id_tanaman'] as String?;

    if (posisi == 'Petani' && plantId != null) {
      final plantSnap = await FirebaseFirestore.instance
          .collection('tanaman')
          .doc(plantId)
          .get();
      final plantName =
          (plantSnap.data()?['nama_tanaman'] ?? '') as String;
      if (plantName.isNotEmpty) {
        posisi = 'Petani $plantName';
      }
    }

    return _FarmerInfo(
      uid: user.uid,
      name: nama,
      role: posisi,
      plantId: plantId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FarmerInfo>(
      future: _farmerInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text('Gagal memuat data petani: ${snapshot.error}'),
            ),
          );
        }

        final info = snapshot.data!;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: HomeAppBar(
              user: UserModel(
                username: info.name,
                role: info.role,
                onNotificationTap: () {
                  Navigator.pushNamed(context, '/notification');
                },
              ),
            ),
          ),
          body: _FarmerHomeContent(info: info),
        );
      },
    );
  }
}

class _FarmerHomeContent extends StatelessWidget {
  final _FarmerInfo info;

  const _FarmerHomeContent({required this.info});

  @override
  Widget build(BuildContext context) {
    // STREAM 1: Mengambil Data Tanam (Bibit Masuk)
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('data_tanam')
          .where('id_petani', isEqualTo: info.uid)
          .where('id_tanaman', isEqualTo: info.plantId)
          .snapshots(),
      builder: (context, snapshotTanam) {
        if (snapshotTanam.hasError) {
          return Center(child: Text('Error data tanam: ${snapshotTanam.error}'));
        }

        // --- LOGIKA HITUNG TOTAL BIBIT (INPUT) ---
        int totalBibitDitanam = 0;
        bool isDateMissing = false;
        
        List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs = [];

        if (snapshotTanam.hasData && snapshotTanam.data!.docs.isNotEmpty) {
          var docs = snapshotTanam.data!.docs.toList();

          // Sorting Client-side (Terlama ke Terbaru)
          docs.sort((a, b) {
            DateTime? getOb(dynamic data) {
              if (data == null) return null;
              if (data is Timestamp) return data.toDate();
              if (data is String) return DateTime.tryParse(data);
              return null;
            }
            final dateA = getOb(a.data()['tanggal_tanam']) ?? DateTime(2100);
            final dateB = getOb(b.data()['tanggal_tanam']) ?? DateTime(2100);
            return dateA.compareTo(dateB);
          });
          
          sortedDocs = docs;

          // Hitung akumulasi bibit masuk
          totalBibitDitanam = docs.fold<int>(
            0,
            (prev, doc) => prev + (doc.data()['jumlah_tanam'] as int? ?? 0),
          );
        }

        // STREAM 2: Mengambil Data Panen (Pengurang)
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('data_panen')
              .where('id_petani', isEqualTo: info.uid)
              .snapshots(),
          builder: (context, snapshotPanen) {
            
            int totalSudahPanen = 0;
            if (snapshotPanen.hasData) {
              final panenDocs = snapshotPanen.data!.docs;
              totalSudahPanen = panenDocs.fold<int>(
                0,
                (prev, doc) => prev + (doc.data()['jumlah_panen'] as int? ?? 0),
              );
            }

            int stokSaatIni = totalBibitDitanam - totalSudahPanen;
            if (stokSaatIni < 0) stokSaatIni = 0;

            bool isLoading = snapshotTanam.connectionState == ConnectionState.waiting || 
                             snapshotPanen.connectionState == ConnectionState.waiting;

            // STREAM 3: Mengambil Data Tanaman (Interval & Masa Tanam)
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: info.plantId != null 
                  ? FirebaseFirestore.instance.collection('tanaman').doc(info.plantId).snapshots()
                  : null,
              builder: (context, snapshotTanaman) {
                
                final tanamanData = snapshotTanaman.data?.data() ?? {};
                int getInterval(String field) {
                  final val = tanamanData[field];
                  if (val is int) return val;
                  if (val is String) return int.tryParse(val) ?? 1;
                  return 1;
                }
                final masaTanam = getInterval('masa_tanam');

                // --- LOGIKA HITUNG SIAP PANEN ---
                int totalSiapPanenRaw = 0; 
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                for (var doc in sortedDocs) {
                  final data = doc.data();
                  final jumlah = (data['jumlah_tanam'] as int? ?? 0);
                  
                  DateTime? tglTanam;
                  final raw = data['tanggal_tanam'];
                  if (raw is Timestamp) tglTanam = raw.toDate();
                  else if (raw is String) tglTanam = DateTime.tryParse(raw);

                  if (tglTanam != null) {
                    final estimasiPanen = tglTanam.add(Duration(days: masaTanam));
                    final estimasiDate = DateTime(estimasiPanen.year, estimasiPanen.month, estimasiPanen.day);
                    
                    if (estimasiDate.compareTo(today) <= 0) {
                      totalSiapPanenRaw += jumlah;
                    }
                  }
                }

                int stokSiapPanen = totalSiapPanenRaw - totalSudahPanen;
                if (stokSiapPanen < 0) stokSiapPanen = 0;
                if (stokSiapPanen > stokSaatIni) stokSiapPanen = stokSaatIni;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        color: const Color.fromARGB(255, 1, 68, 33),
                        width: double.infinity,
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal, 
                                child: Row(
                                  children: [
                                    // KARTU 1: Total Stok Aktual
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.75, 
                                      child: FarmerTotalPlantCard(
                                        header: 'Total Bibit Ditanam',
                                        plantCount: stokSaatIni,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    
                                    // KARTU 2: Total Siap Panen
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.75,
                                      child: FarmerTotalPlantCard(
                                        header: 'Siap Panen',
                                        plantCount: stokSiapPanen,
                                        plantIcon: Icons.inventory_2_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StyledElevatedButton(
                              text: 'Tambah Data Tanaman ',
                              onPressed: () {
                                Navigator.pushNamed(context, '/add_plant_data');
                              },
                              foregroundColor: Colors.white,
                              backgroundColor: const Color.fromARGB(255, 1, 68, 33),
                              icon: Icons.add,
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Daftar Jadwal Hari Ini',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (isDateMissing)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Info: Tanggal tanam tidak ditemukan.',
                                  style: TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (isLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (info.plantId == null)
                              const Text('Akun petani belum terhubung dengan tanaman.')
                            else if (stokSaatIni == 0 && totalBibitDitanam == 0)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.grey),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Data bibit kosong. Silakan input "Data Tanam".',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              // STREAM 4: Jadwal Perawatan (Untuk status is_done)
                              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('jadwal_perawatan')
                                    .where('id_petani', isEqualTo: info.uid)
                                    .where('id_tanaman', isEqualTo: info.plantId)
                                    .snapshots(),
                                builder: (context, statusSnap) {
                                  final statusDocs = statusSnap.data?.docs ?? [];
                                  final Map<String, bool> statusMap = {};
                                  for (final doc in statusDocs) {
                                    final d = doc.data();
                                    final field = (d['field'] ?? '') as String;
                                    final recordedTanamId = (d['id_data_tanam'] ?? '') as String; 
                                    final ts = d['tanggal'] as Timestamp?;
                                    final date = ts?.toDate();
                                    if (field.isEmpty || date == null) continue;
                                    
                                    final key = '${field}_${DateFormat('yyyy-MM-dd').format(date.toLocal())}_$recordedTanamId';
                                    statusMap[key] = (d['is_done'] ?? false) as bool;
                                  }

                                  final intervalAir = getInterval('jadwal_pengecekan_air_dan_nutrisi');
                                  final intervalCek = getInterval('jadwal_pengecekan_tanaman');
                                  final intervalBersih = getInterval('jadwal_pembersihan_instalasi');

                                  // --- FUNGSI HITUNG TANGGAL JADWAL (MODULO) ---
                                  DateTime calculateNextDate(int interval, DateTime startDate) {
                                    final now = DateTime.now();
                                    final today = DateTime(now.year, now.month, now.day);
                                    final start = DateTime(startDate.year, startDate.month, startDate.day);

                                    if (interval <= 0) return today.add(const Duration(days: 1));
                                    
                                    int diff = today.difference(start).inDays;
                                    
                                    // Jika tanggal tanam di masa depan (baru input)
                                    if (diff < 0) return start.add(Duration(days: interval));

                                    int remainder = diff % interval;
                                    DateTime candidate;
                                    
                                    if (remainder == 0) {
                                      // Hari ini adalah hari jadwalnya!
                                      candidate = today;
                                    } else {
                                      // Jadwal berikutnya
                                      int daysToNext = interval - remainder;
                                      candidate = today.add(Duration(days: daysToNext));
                                    }
                                    return candidate;
                                  }

                                  final List<PlantMaintenanceModel> schedules = [];
                                  final List<Map<String, dynamic>> alarmData = [];
                              
                                  bool isToday(DateTime date) {
                                    final now = DateTime.now();
                                    return date.year == now.year &&
                                        date.month == now.month &&
                                        date.day == now.day;
                                  }

                                  void addSchedule({
                                    required String field,
                                    required String title,
                                    required String description,
                                    required DateTime date,
                                    required String specificTanamId,
                                  }) {
                                    if (!isToday(date)) return;

                                    final key = '${field}_${DateFormat('yyyy-MM-dd').format(date.toLocal())}_$specificTanamId';
                                    final isDone = statusMap[key] ?? false;

                                    // Cek duplikasi agar tampilan rapi (opsional)
                                    bool isDuplicate = schedules.any((s) => s.maintenanceName == title && s.description == description);
                                    if(isDuplicate) return; 

                                    alarmData.add({
                                      'id': schedules.length + 1,
                                      'title': title,
                                      'body': description,
                                      'date': date,
                                    });

                                    schedules.add(
                                      PlantMaintenanceModel(
                                        maintenanceName: title,
                                        description: description,
                                        date: DateFormat('dd MMMM yyyy').format(date),
                                        time: '09:00',
                                        isDone: isDone,
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/maintenance_detail',
                                            arguments: {
                                              'id_petani': info.uid,
                                              'id_tanaman': info.plantId,
                                              'tanam_id': specificTanamId,
                                              'field': field,
                                              'tanggal': date,
                                              'is_done': isDone,
                                              'title': title,
                                              'description': description,
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  }

                                  // --- REVISI: LOOPING UNTUK SETIAP BATCH TANAM ---
                                  for (var doc in sortedDocs) {
                                    final thisDocId = doc.id;
                                    final tglTanamRaw = doc.data()['tanggal_tanam'];
                                    
                                    DateTime? tglTanam;
                                    if (tglTanamRaw is Timestamp) {
                                      tglTanam = tglTanamRaw.toDate();
                                    } else if (tglTanamRaw is String) {
                                      try {
                                        tglTanam = DateTime.parse(tglTanamRaw);
                                      } catch (_) {}
                                    }

                                    if (tglTanam == null) continue;

                                    // 1. Hitung Jadwal Perawatan Rutin untuk Batch ini
                                    DateTime dateAir = calculateNextDate(intervalAir, tglTanam);
                                    DateTime dateCek = calculateNextDate(intervalCek, tglTanam);
                                    DateTime dateBersih = calculateNextDate(intervalBersih, tglTanam);

                                    addSchedule(
                                      field: 'jadwal_pengecekan_air_dan_nutrisi',
                                      title: 'Pengecekan Air & Nutrisi',
                                      description: 'Cek kualitas air dan tambah nutrisi bila diperlukan.',
                                      date: dateAir,
                                      specificTanamId: thisDocId,
                                    );

                                    addSchedule(
                                      field: 'jadwal_pengecekan_tanaman',
                                      title: 'Pengecekan Tanaman',
                                      description: 'Periksa kondisi tanaman dan identifikasi hama/penyakit.',
                                      date: dateCek,
                                      specificTanamId: thisDocId,
                                    );

                                    addSchedule(
                                      field: 'jadwal_pembersihan_instalasi',
                                      title: 'Pembersihan Instalasi',
                                      description: 'Bersihkan pipa dan instalasi hidroponik dari kotoran.',
                                      date: dateBersih,
                                      specificTanamId: thisDocId,
                                    );

                                    // 2. Hitung Estimasi Panen untuk Batch ini
                                    final panenDate = tglTanam.add(Duration(days: masaTanam));
                                    if (isToday(panenDate)) {
                                      addSchedule(
                                        field: 'estimasi_panen',
                                        title: 'Estimasi Panen',
                                        description: 'Waktunya panen berdasarkan masa tanam!',
                                        date: panenDate,
                                        specificTanamId: thisDocId,
                                      );
                                    }
                                  }
                                  // ---------------------------------------------------

                                  if (alarmData.isNotEmpty) {
                                    _scheduleAlarmsAsync(alarmData);
                                  }

                                  if (schedules.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200)
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Tidak ada jadwal perawatan untuk hari ini.',
                                          style: TextStyle(color: Colors.grey, fontSize: 14),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      // Tombol Test Alarm & Notifikasi (Opsional, untuk debug)
                                      /*
                                      SizedBox(
                                        width: double.infinity,
                                        child: StyledElevatedButton(
                                          text: 'Test Alarm (1 menit)',
                                          onPressed: () async {
                                             // ... Logic Test Alarm ...
                                          },
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.orange,
                                          icon: Icons.alarm,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      */
                                      
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: schedules.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          return MaintenanceScheduleCard(
                                            maintenance: schedules[index],
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  void _scheduleAlarmsAsync(List<Map<String, dynamic>> alarmData) {
    debugPrint('📅 Scheduling ${alarmData.length} alarms for today...');
    AlarmService.instance.scheduleTodayAlarms(
      schedules: alarmData,
      isTestMode: false,
    ).then((_) {
      debugPrint('✅ All alarms scheduled successfully');
    }).catchError((e) {
      debugPrint('❌ Error scheduling alarms: $e');
    });
  }
}

class _FarmerInfo {
  final String uid;
  final String name;
  final String role;
  final String? plantId;

  _FarmerInfo({
    required this.uid,
    required this.name,
    required this.role,
    required this.plantId,
  });
}