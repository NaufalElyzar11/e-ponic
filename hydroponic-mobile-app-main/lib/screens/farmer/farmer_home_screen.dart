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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: const Color.fromARGB(255, 1, 68, 33),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('data_tanam')
                  .where('id_petani', isEqualTo: info.uid)
                  .where('id_tanaman', isEqualTo: info.plantId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const FarmerTotalPlantCard(
                    header: 'Total Bibit Ditanam',
                    plantCount: 0,
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final total = docs.fold<int>(
                  0,
                  (prev, doc) =>
                      prev + (doc.data()['jumlah_tanam'] as int? ?? 0),
                );

                return FarmerTotalPlantCard(
                  header: 'Total Bibit Ditanam',
                  plantCount: total,
                );
              },
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
                  'Daftar Jadwal',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (info.plantId == null)
                  const Text(
                    'Akun petani belum terhubung dengan tanaman.',
                  )
                else
                  // Stream status penyelesaian jadwal perawatan
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData ||
                              !snapshot.data!.exists) {
                            return const Text('Data tanaman tidak ditemukan.');
                          }

                          final data = snapshot.data!.data() ?? {};

                          final List<PlantMaintenanceModel> schedules = [];

                          void addSchedule({
                            required String field,
                            required String title,
                            required String description,
                          }) {
                            final raw = data[field];
                            final date = _parseDate(raw);
                            if (date == null) return;

                            final key =
                                '${field}_${DateFormat('yyyy-MM-dd').format(date.toLocal())}';
                            final isDone =
                                statusMap[key] ?? false;

                            schedules.add(
                              PlantMaintenanceModel(
                                maintenanceName: title,
                                description: description,
                                date:
                                    DateFormat('dd MMMM yyyy').format(date),
                                time: DateFormat('HH:mm').format(date),
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
                          );
                          addSchedule(
                            field: 'jadwal_pengecekan_tanaman',
                            title: 'Pengecekan Tanaman',
                            description:
                                'Periksa kondisi tanaman dan identifikasi hama/penyakit.',
                          );
                          addSchedule(
                            field: 'jadwal_pembersihan_instalasi',
                            title: 'Pembersihan Instalasi',
                            description:
                                'Bersihkan pipa dan instalasi hidroponik dari kotoran.',
                          );

                          if (schedules.isEmpty) {
                            return const Text('Belum ada jadwal perawatan.');
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount: schedules.length,
                            itemBuilder:
                                (BuildContext context, int index) {
                              return MaintenanceScheduleCard(
                                maintenance: schedules[index],
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
        ],
      ),
    );
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

// Logika toggle status jadwal dipindahkan ke `MaintenanceDetailScreen`
