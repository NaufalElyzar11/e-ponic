import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hydroponics_app/firebase_options.dart'; // Pastikan import ini benar
import 'package:intl/intl.dart';

class BackgroundServiceHelper {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Notifikasi untuk menandakan service berjalan (Wajib untuk Android Foreground Service)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'Background Service', // title
      description: 'Menjalankan pemantauan data di latar belakang',
      importance: Importance.low, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // Fungsi utama yang akan dijalankan
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'E-Ponic Service',
        initialNotificationContent: 'Memantau status pertanian...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // iOS memiliki batasan ketat, biasanya butuh 'Background Fetch' atau Push Notification
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // 1. Inisialisasi Firebase di Isolate terpisah ini
    DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Setup Notifikasi Lokal untuk memunculkan alert
    final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await localNotif.initialize(initializationSettings);

    // 3. Cek User Login & Role
    // Auth state biasanya persist, jadi kita bisa ambil currentUser
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Ambil role pengguna dari Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('pengguna')
            .doc(user.uid)
            .get();
        
        final role = userDoc.data()?['posisi'] ?? '';
        print("Background Service Running for Role: $role");

        // 4. Jalankan Listener sesuai Role
        if (role == 'Admin') {
          _listenForAdmin(localNotif);
        } else if (role == 'Petani') {
          final plantId = userDoc.data()?['id_tanaman'];
          if (plantId != null) {
            _listenForPetani(localNotif, plantId);
          }
        } else if (role == 'Kurir') {
          _listenForKurir(localNotif, user.uid);
        }

      } catch (e) {
        print("Error in background service: $e");
      }
    }
  }

  // --- LOGIKA LISTENER ADMIN (Copied & Adapted from NotificationService) ---
  static void _listenForAdmin(FlutterLocalNotificationsPlugin localNotif) {
    // Variabel untuk menyimpan waktu terakhir cek agar tidak notif berulang saat restart service
    DateTime lastCheck = DateTime.now(); 

    FirebaseFirestore.instance
        .collection('transaksi')
        .orderBy('updated_at', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();
        final harvestedAt = (data['harvested_at'] as Timestamp?)?.toDate();
        final deliveredAt = (data['delivered_at'] as Timestamp?)?.toDate();
        final namaPelanggan = data['nama_pelanggan'] ?? 'Pelanggan';

        // Logika Panen
        if (data['is_harvest'] == true && harvestedAt != null) {
          if (harvestedAt.isAfter(lastCheck)) {
            _showNotification(localNotif, doc.id.hashCode, 'Tanaman Dipanen',
                'Pesanan $namaPelanggan telah dipanen.');
          }
        }

        // Logika Pengiriman Selesai
        if (data['is_deliver'] == true && deliveredAt != null) {
          if (deliveredAt.isAfter(lastCheck)) {
            _showNotification(localNotif, doc.id.hashCode + 1, 'Pengiriman Selesai',
                'Pesanan $namaPelanggan telah sampai.');
          }
        }
        
        // Update lastCheck agar kejadian yang sama tidak notif lagi di loop berikutnya
        if (updatedAt != null && updatedAt.isAfter(lastCheck)) {
           lastCheck = updatedAt;
        }
      }
    });
  }

  // --- LOGIKA LISTENER PETANI ---
  static void _listenForPetani(FlutterLocalNotificationsPlugin localNotif, String plantId) {
    DateTime lastCheck = DateTime.now();
    FirebaseFirestore.instance
        .collection('transaksi')
        .orderBy('created_at', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['created_at'] as Timestamp?)?.toDate();
        final items = (data['items'] as List?) ?? [];

        // Cek apakah ada item milik petani ini
        if (items.any((i) => i['id_tanaman'] == plantId)) {
           if (createdAt != null && createdAt.isAfter(lastCheck)) {
             _showNotification(localNotif, doc.id.hashCode, 'Tugas Panen Baru', 
               'Ada pesanan baru yang perlu dipanen.');
             lastCheck = createdAt;
           }
        }
      }
    });
  }

  // --- LOGIKA LISTENER KURIR ---
  static void _listenForKurir(FlutterLocalNotificationsPlugin localNotif, String courierId) {
    DateTime lastCheck = DateTime.now();
    FirebaseFirestore.instance
        .collection('pengiriman')
        .where('id_kurir', isEqualTo: courierId)
        .orderBy('created_at', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
       for (var doc in snapshot.docs) {
         final data = doc.data();
         final createdAt = (data['created_at'] as Timestamp?)?.toDate();
         
         if (createdAt != null && createdAt.isAfter(lastCheck)) {
            _showNotification(localNotif, doc.id.hashCode, 'Tugas Pengiriman', 
               'Anda mendapatkan tugas pengiriman baru.');
            lastCheck = createdAt;
         }
       }
    });
  }

  static Future<void> _showNotification(
      FlutterLocalNotificationsPlugin localNotif, int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'main_channel', 
      'Notifikasi Penting',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await localNotif.show(id, title, body, platformChannelSpecifics);
  }
}