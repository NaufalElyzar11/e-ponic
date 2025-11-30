import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/screens/admin/add_edit_transaction_screen.dart';
import 'package:hydroponics_app/screens/admin/admin_navigation.dart';
import 'package:hydroponics_app/screens/admin/edit_account_screen.dart';
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
import 'package:hydroponics_app/screens/superadmin/superadmin_navigation.dart';
import 'package:hydroponics_app/services/alarm_service.dart';
import 'package:alarm/alarm.dart';
import 'package:hydroponics_app/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);
  await NotificationService.instance.initialize();
  NotificationService.instance.startListening();
  // Initialize alarm service
  await AlarmService.instance.initialize();
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
      // dan menangani alarm
      home: const _AlarmWrapper(),
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
        '/superadmin_navigation': (context) => const SuperAdminNavigation(),
      },
    );
  }
}

/// Widget pembungkus untuk menangani alarm dan menentukan halaman awal
class _AlarmWrapper extends StatefulWidget {
  const _AlarmWrapper();

  @override
  State<_AlarmWrapper> createState() => _AlarmWrapperState();
}

class _AlarmWrapperState extends State<_AlarmWrapper> {
  AlarmSettings? _currentRingingAlarm;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Listen to alarm stream
    Alarm.ringStream.stream.listen((alarmSettings) {
      if (mounted) {
        setState(() {
          _currentRingingAlarm = alarmSettings;
        });
      }
    });

    // Check if any alarm is currently ringing on init
    _checkRingingAlarm();
    
    // Polling untuk memastikan state tetap sinkron (setiap 1 detik)
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _checkRingingAlarm();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkRingingAlarm() async {
    if (!mounted) return;
    
    final isRinging = await Alarm.isRinging();
    if (isRinging) {
      // Get the ringing alarm
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        final ringing = await Alarm.isRinging(alarm.id);
        if (ringing) {
          if (mounted && _currentRingingAlarm?.id != alarm.id) {
            setState(() {
              _currentRingingAlarm = alarm;
            });
          }
          return;
        }
      }
    } else {
      // Tidak ada alarm yang berbunyi
      if (mounted && _currentRingingAlarm != null) {
        setState(() {
          _currentRingingAlarm = null;
        });
      }
    }
  }
  
  void onAlarmStopped() {
    if (mounted) {
      setState(() {
        _currentRingingAlarm = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jika alarm sedang berbunyi, tampilkan UI untuk stop alarm
    if (_currentRingingAlarm != null) {
      return _AlarmRingingScreen(
        alarmSettings: _currentRingingAlarm!,
        onAlarmStopped: onAlarmStopped,
      );
    }
    
    // Jika tidak ada alarm, tampilkan halaman normal
    return const _AuthWrapper();
  }
}

/// Screen yang ditampilkan saat alarm berbunyi
class _AlarmRingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final VoidCallback onAlarmStopped;
  
  const _AlarmRingingScreen({
    required this.alarmSettings,
    required this.onAlarmStopped,
  });

  @override
  State<_AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<_AlarmRingingScreen> {
  bool _isStopping = false;

  Future<void> _stopAlarm() async {
    if (_isStopping) return;
    
    setState(() {
      _isStopping = true;
    });

    try {
      // Stop alarm
      await Alarm.stop(widget.alarmSettings.id);
      debugPrint('Alarm stopped: ${widget.alarmSettings.id}');
      
      // Tunggu sebentar untuk memastikan alarm benar-benar berhenti
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verifikasi alarm sudah berhenti
      final isStillRinging = await Alarm.isRinging(widget.alarmSettings.id);
      if (!isStillRinging && mounted) {
        widget.onAlarmStopped();
      }
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
      if (mounted) {
        setState(() {
          _isStopping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Jika user tekan back, stop alarm dulu
        await _stopAlarm();
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.alarm,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                Text(
                  widget.alarmSettings.notificationSettings.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.alarmSettings.notificationSettings.body,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 64),
                ElevatedButton(
                  onPressed: _isStopping ? null : _stopAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 64,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isStopping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'STOP ALARM',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
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
              case 'Super Admin':
                return const SuperAdminNavigation();
              default:
                return const LoginScreen();
            }
          },
        );
      },
    );
  }
}