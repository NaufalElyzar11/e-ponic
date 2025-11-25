import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/screens/admin/add_edit_transaction_screen.dart';
import 'package:hydroponics_app/screens/admin/admin_navigation.dart';
import 'package:hydroponics_app/screens/admin/employee_account_list_screen.dart';
import 'package:hydroponics_app/screens/admin/plant_status_screen.dart';
import 'package:hydroponics_app/screens/admin/transaction_status_screen.dart';
import 'package:hydroponics_app/screens/courier/courier_delivery_detail_screen.dart';
import 'package:hydroponics_app/screens/courier/courier_navigation.dart';
import 'package:hydroponics_app/screens/farmer/add_plant_data_screen.dart';
import 'package:hydroponics_app/screens/farmer/maintenance_detail_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_navigation.dart';
import 'package:hydroponics_app/screens/login_screen.dart';
import 'package:hydroponics_app/screens/logistic/logistic_assignment_detail_screen.dart';
import 'package:hydroponics_app/screens/logistic/logistic_navigation.dart';
import 'package:hydroponics_app/screens/notification_screen.dart';
import 'package:hydroponics_app/screens/register_screen.dart';
import 'package:hydroponics_app/screens/select_role_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HydroponicApp());
}

class HydroponicApp extends StatelessWidget {
  const HydroponicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Ponic',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      debugShowCheckedModeBanner: false,
      // Gunakan wrapper untuk menentukan halaman awal berdasarkan status login
      home: const _AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/select_role': (context) => const SelectRoleScreen(),
        '/farmer_navigation': (context) => const FarmerNavigation(),
        '/add_plant_data': (context) => const AddPlantDataScreen(),
        '/maintenance_detail': (context) => const MaintenanceDetailScreen(),
        '/notification': (context) => const NotificationScreen(),
        '/courier_navigation': (context) => const CourierNavigation(),
        '/courier_delivery_detail': (context) => const CourierDeliveryDetailScreen(),
        '/admin_navigation': (context) => const AdminNavigation(),
        '/add_edit_transaction': (context) => const AddEditTransactionScreen(),
        '/employee_account_list': (context) => const EmployeeAccountListScreen(),
        '/transaction_status': (context) => const TransactionStatusScreen(),
        '/plant_status': (context) => const PlantStatusScreen(),
        '/logistic_navigation': (context) => const LogisticNavigation(),
        '/logistic_assignment_detail': (context) => const LogisticAssignmentDetailScreen(),
      },
    );
  }
}

/// Widget pembungkus untuk menentukan halaman awal
/// jika user masih login maka langsung diarahkan ke halaman sesuai role
class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Masih loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Belum login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // Sudah login -> tentukan halaman awal berdasarkan role di Firestore
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('pengguna')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // Jika akun Auth tidak punya dokumen pengguna, paksa logout
              // agar tidak bisa memilih role sembarang.
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final data = userSnapshot.data!.data() ?? {};
            final posisi = (data['posisi'] ?? '') as String;

            switch (posisi) {
              case 'Petani':
                return const FarmerNavigation();
              case 'Kurir':
                return const CourierNavigation();
              case 'Staf Logistik':
                return const LogisticNavigation();
              case 'Admin':
                return const AdminNavigation();
              default:
                return const LoginScreen();
            }
          },
        );
      },
    );
  }
}