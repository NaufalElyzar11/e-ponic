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

    // Jika petani memiliki tanaman tertentu, tampilkan "Petani <Nama Tanaman>"
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('data_tanam')
          .where('id_petani', isEqualTo: info.uid)
          .where('id_tanaman', isEqualTo: info.plantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error data tanam: ${snapshot.error}'));
        }

        int totalBibit = 0;
        DateTime? tanggalTanamAwal;
        bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        bool isDateMissing = false;
        
        List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var docs = snapshot.data!.docs.toList();

          // Client-side sorting
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

          totalBibit = docs.fold<int>(
            0,
            (prev, doc) => prev + (doc.data()['jumlah_tanam'] as int? ?? 0),
          );

          if (docs.isNotEmpty) {
            final firstDocData = docs.first.data();
            final rawDate = firstDocData['tanggal_tanam'];
            if (rawDate is Timestamp) {
              tanggalTanamAwal = rawDate.toDate();
            } else if (rawDate is String) {
              try {
                tanggalTanamAwal = DateTime.parse(rawDate);
              } catch (_) {}
            }
          }
        }

        if (totalBibit > 0 && tanggalTanamAwal == null) {
          tanggalTanamAwal = DateTime.now();
          isDateMissing = true;
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                color: const Color.fromARGB(255, 1, 68, 33),
                width: double.infinity,
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : FarmerTotalPlantCard(
                        header: 'Total Bibit Ditanam',
                        plantCount: totalBibit,
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
                      'Daftar Jadwal Hari Ini', // Ubah judul agar sesuai konteks
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (isDateMissing)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Info: Tanggal tanam tidak ditemukan. Simulasi jadwal hari ini.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (info.plantId == null)
                      const Text('Akun petani belum terhubung dengan tanaman.')
                    else if (totalBibit == 0)
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
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey),
                            )),
                          ],
                        ),
                      )
                    else
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
                            final ts = d['tanggal'] as Timestamp?;
                            final date = ts?.toDate();
                            if (field.isEmpty || date == null) continue;
                            final key =
                                '${field}_${DateFormat('yyyy-MM-dd').format(date.toLocal())}';
                            statusMap[key] = (d['is_done'] ?? false) as bool;
                          }

                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('tanaman')
                                .doc(info.plantId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }

                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return const Text(
                                    'Data jenis tanaman tidak ditemukan.');
                              }

                              final data = snapshot.data!.data() ?? {};

                              int getInterval(String field) {
                                final val = data[field];
                                if (val is int) return val;
                                if (val is String) {
                                  return int.tryParse(val) ?? 1;
                                }
                                return 1;
                              }

                              final intervalAir = getInterval(
                                  'jadwal_pengecekan_air_dan_nutrisi');
                              final intervalCek =
                                  getInterval('jadwal_pengecekan_tanaman');
                              final intervalBersih =
                                  getInterval('jadwal_pembersihan_instalasi');
                              final masaTanam = getInterval('masa_tanam');

                              DateTime calculateNextDate(
                                  int interval, DateTime startDate) {
                                final now = DateTime.now();
                                final today =
                                    DateTime(now.year, now.month, now.day);
                                final start = DateTime(startDate.year,
                                    startDate.month, startDate.day);

                                if (interval <= 0) {
                                  return today.add(const Duration(days: 1));
                                }

                                int daysPassed = today.difference(start).inDays;

                                if (daysPassed < 0) {
                                  return start.add(Duration(days: interval));
                                }

                                int cycles = (daysPassed / interval).ceil();
                                if (cycles <= 0) cycles = 1;

                                DateTime candidate = start
                                    .add(Duration(days: cycles * interval));

                                if (candidate.isBefore(today)) {
                                  candidate =
                                      candidate.add(Duration(days: interval));
                                }
                                return candidate;
                              }

                              final baseDate =
                                  tanggalTanamAwal ?? DateTime.now();

                              DateTime dateAir =
                                  calculateNextDate(intervalAir, baseDate);
                              DateTime dateCek =
                                  calculateNextDate(intervalCek, baseDate);
                              DateTime dateBersih =
                                  calculateNextDate(intervalBersih, baseDate);

                              final List<PlantMaintenanceModel> schedules = [];
                              final List<Map<String, dynamic>> alarmData = []; // Untuk menyimpan data alarm
                              
                              // Helper untuk cek apakah tanggal jadwal == HARI INI
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
                              }) {
                                // FILTER: Hanya tampilkan jika tanggal jadwal adalah HARI INI
                                if (!isToday(date)) return;

                                final key =
                                    '${field}_${DateFormat('yyyy-MM-dd').format(date.toLocal())}';
                                final isDone = statusMap[key] ?? false;

                                // Simpan data untuk alarm
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
                                    date: DateFormat('dd MMMM yyyy')
                                        .format(date),
                                    time: '09:00',
                                    isDone: isDone,
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/maintenance_detail',
                                        arguments: {
                                          'id_petani': info.uid,
                                          'id_tanaman': info.plantId,
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

                              addSchedule(
                                field: 'jadwal_pengecekan_air_dan_nutrisi',
                                title: 'Pengecekan Air & Nutrisi',
                                description:
                                    'Cek kualitas air dan tambah nutrisi bila diperlukan.',
                                date: dateAir,
                              );

                              addSchedule(
                                field: 'jadwal_pengecekan_tanaman',
                                title: 'Pengecekan Tanaman',
                                description:
                                    'Periksa kondisi tanaman dan identifikasi hama/penyakit.',
                                date: dateCek,
                              );

                              addSchedule(
                                field: 'jadwal_pembersihan_instalasi',
                                title: 'Pembersihan Instalasi',
                                description:
                                    'Bersihkan pipa dan instalasi hidroponik dari kotoran.',
                                date: dateBersih,
                              );

                              // 4. ESTIMASI PANEN (Looping)
                              for (var doc in sortedDocs) {
                                final tglTanamRaw = doc.data()['tanggal_tanam'];
                                DateTime? tglTanam;
                                if (tglTanamRaw is Timestamp) {
                                  tglTanam = tglTanamRaw.toDate();
                                } else if (tglTanamRaw is String) {
                                  try {
                                    tglTanam = DateTime.parse(tglTanamRaw);
                                  } catch (_) {}
                                }

                                if (tglTanam != null) {
                                  final panenDate = tglTanam
                                      .add(Duration(days: masaTanam));
                                  
                                  // FILTER: Estimasi Panen juga hanya tampil jika hari ini adalah hari panen
                                  if (!isToday(panenDate)) continue;

                                  addSchedule(
                                    field: 'estimasi_panen',
                                    title: 'Estimasi Panen',
                                    description:
                                        'Waktunya panen berdasarkan masa tanam!',
                                    date: panenDate,
                                  );
                                }
                              }

                              // Schedule alarm untuk semua jadwal hari ini (async, tidak blocking UI)
                              if (alarmData.isNotEmpty) {
                                _scheduleAlarmsAsync(alarmData);
                              } else {
                                print('ℹ️ No alarms to schedule (no schedules for today)');
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
                                  // Tombol Test Alarm (untuk testing)
                                  Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: StyledElevatedButton(
                                          text: 'Test Alarm (1 menit)',
                                          onPressed: () async {
                                            if (schedules.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Tidak ada jadwal untuk di-test')),
                                              );
                                              return;
                                            }
                                            final firstSchedule = schedules.first;
                                            try {
                                              await AlarmService.instance.testAlarm(
                                                title: firstSchedule.maintenanceName,
                                                body: firstSchedule.description,
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Test alarm dijadwalkan 1 menit dari sekarang'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          },
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.orange,
                                          icon: Icons.alarm,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: StyledElevatedButton(
                                          text: 'Test Notifikasi',
                                          onPressed: () async {
                                            if (schedules.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Tidak ada jadwal untuk di-test')),
                                              );
                                              return;
                                            }
                                            final firstSchedule = schedules.first;
                                            try {
                                              await AlarmService.instance.showNotificationNow(
                                                title: firstSchedule.maintenanceName,
                                                body: firstSchedule.description,
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Notifikasi ditampilkan sekarang'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          },
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.green,
                                          icon: Icons.notifications_active,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
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

  /// Schedule alarm secara async (tidak blocking UI)
  void _scheduleAlarmsAsync(List<Map<String, dynamic>> alarmData) {
    print('📅 Scheduling ${alarmData.length} alarms for today...');
    AlarmService.instance.scheduleTodayAlarms(
      schedules: alarmData,
      isTestMode: false,
    ).then((_) {
      print('✅ All alarms scheduled successfully');
      // Debug: Tampilkan pending notifications
      AlarmService.instance.getPendingNotifications().then((pending) {
        print('📋 Total pending notifications: ${pending.length}');
      });
    }).catchError((e) {
      print('❌ Error scheduling alarms: $e');
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

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is String) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }
  return null;
}