import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: AuthService.instance.getCurrentUserDoc(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final name =
            (data['nama_pengguna'] ?? user?.email ?? 'Pengguna') as String;
        final posisi = (data['posisi'] ?? '-') as String;
        final idTanaman = data['id_tanaman'] as String?;

        // Jika bukan petani atau tidak punya id_tanaman, cukup tampilkan posisi
        if (posisi != 'Petani' || idTanaman == null) {
          return _buildScaffold(
            context: context,
            name: name,
            roleText: posisi,
          );
        }

        // Jika petani, ambil nama tanaman untuk menampilkan "Petani Selada" dll.
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('tanaman')
              .doc(idTanaman)
              .get(),
          builder: (context, plantSnap) {
            final plantName =
                (plantSnap.data?.data()?['nama_tanaman'] ?? '') as String;
            final displayRole = plantName.isNotEmpty
                ? 'Petani $plantName'
                : 'Petani';

            return _buildScaffold(
              context: context,
              name: name,
              roleText: displayRole,
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold({
    required BuildContext context,
    required String name,
    required String roleText,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 25,
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 1, 68, 33),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          child: Column(children: [
            Center(
                heightFactor: 1.5,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        const Icon(
                          Icons.account_circle,
                          size: 150,
                          color: Color.fromARGB(255, 1, 68, 33),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: BoxBorder.all(
                                    color: const Color.fromARGB(
                                        255, 1, 68, 33),
                                    width: 2),
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(20))),
                            child: IconButton(
                              onPressed: () {
                                // actions
                              },
                              icon: const Icon(
                                Icons.edit,
                                color:
                                    Color.fromARGB(255, 1, 68, 33),
                              ),
                              iconSize: 21,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                      ),
                    ),
                    Text(roleText),
                  ],
                )),
            ListTile(
              leading: const Icon(
                Icons.settings,
                size: 25,
              ),
              title: const Text('Pengaturan'),
              onTap: () {
                // actions
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.headset_mic,
                size: 25,
              ),
              title: const Text('Bantuan & dukungan'),
              onTap: () {
                // actions
              },
            ),
            const Divider(),
            ListTile(
              textColor: Colors.red,
              iconColor: Colors.red,
              leading: const Icon(
                Icons.logout,
                size: 25,
              ),
              title: const Text('Keluar'),
              onTap: () async {
                await AuthService.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
            ),
            const Divider()
          ]),
        ),
      ),
    );
  }
}