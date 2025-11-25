import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/employee_list_card.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class EmployeeAccountListScreen extends StatefulWidget{
  const EmployeeAccountListScreen({super.key});

  @override
  State<EmployeeAccountListScreen> createState() => _EmployeeAccountListScreenState();
}

class _EmployeeAccountListScreenState extends State<EmployeeAccountListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Daftar Akun Karyawan', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 1, 68, 33),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            width: double.infinity,
            padding: EdgeInsets.all(15),
            child: StyledElevatedButton(
              text: 'Ekspor Data', 
              onPressed: () {
                
              },
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white,
            ),
          ),
          Expanded(child: 
            SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(15),
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
                      spacing: 7,
                      children: [
                        EmployeeListCard(
                          role: 'Petani',
                          userData: farmers,
                          onDelete: (user) =>
                              _deleteAccount(user, docs),
                        ),
                        EmployeeListCard(
                          role: 'Kurir',
                          userData: couriers,
                          onDelete: (user) =>
                              _deleteAccount(user, docs),
                        ),
                        EmployeeListCard(
                          role: 'Staf Logistik',
                          userData: logistics,
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
}