import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/home_app_bar.dart';
import 'package:hydroponics_app/widgets/trailing_icon_button.dart';

class AdminHomeScreen extends StatefulWidget{
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('pengguna')
          .doc(user?.uid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final name = (data['nama_pengguna'] ?? 'Admin') as String;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: HomeAppBar(
              user: UserModel(
                username: name,
                role: 'Admin',
                onNotificationTap: () {
                  Navigator.pushNamed(context, '/notification');
                },
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(15),
              child: Column(
                spacing: 15,
                children: [
                  TrailingIconButton(
                    text: 'Tambah Transaksi', 
                    trailingIcon: Icons.add_shopping_cart,
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_edit_transaction');
                    },
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.primary,
                  ),
                  TrailingIconButton(
                    text: 'Tambah Akun', 
                    trailingIcon: Icons.person_add,
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.primary,
                  ),
                  TrailingIconButton(
                    text: 'Daftar Akun Karyawan', 
                    trailingIcon: Icons.people,
                    onPressed: () {
                      Navigator.pushNamed(context, '/employee_account_list');
                    },
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          )
        );
      },
    );
  }
}