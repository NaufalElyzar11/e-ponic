import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

/// Service untuk mengelola notifikasi berdasarkan role user
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  /// Inisialisasi local notifications
  Future<void> initialize() async {
    if (_initialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap jika diperlukan
      },
    );
    
    // Buat notification channel untuk Android
    const androidChannel = AndroidNotificationChannel(
      'test_channel',
      'Test Notifications',
      description: 'Channel untuk test notifikasi',
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    _initialized = true;
  }

  /// Test notifikasi - menampilkan notifikasi langsung
  Future<void> testNotification({
    String title = 'Test Notifikasi',
    String body = 'Ini adalah notifikasi test dari E-Ponic',
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel untuk test notifikasi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      9999, // ID unik untuk test notification
      title,
      body,
      notificationDetails,
    );
  }

  /// Mendapatkan notifikasi berdasarkan role user
  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Ambil role user dari Firestore dan listen perubahan
    return _db.collection('pengguna').doc(user.uid).snapshots().asyncMap((userDoc) async {
      final userData = userDoc.data();
      if (userData == null) return <Map<String, dynamic>>[];

      final role = (userData['posisi'] ?? '') as String;
      
      try {
        switch (role) {
          case 'Admin':
            return await _getAdminNotifications();
          case 'Petani':
            return await _getFarmerNotifications(user.uid, userData['id_tanaman'] as String?);
          case 'Staf Logistik':
            return await _getLogisticNotifications();
          case 'Kurir':
            return await _getCourierNotifications(user.uid);
          case 'Super Admin':
            return await _getSuperAdminNotifications();
          default:
            return <Map<String, dynamic>>[];
        }
      } catch (e) {
        print('Error getting notifications: $e');
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Notifikasi untuk Admin
  Future<List<Map<String, dynamic>>> _getAdminNotifications() async {
    final notifications = <Map<String, dynamic>>[];

    // 1. Transaksi baru (belum di-harvest)
    QuerySnapshot<Map<String, dynamic>> newTransactions;
    try {
      newTransactions = await _db
          .collection('transaksi')
          .where('is_harvest', isEqualTo: false)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Jika error (mungkin karena index), coba tanpa orderBy
      newTransactions = await _db
          .collection('transaksi')
          .where('is_harvest', isEqualTo: false)
          .limit(10)
          .get();
    }

    for (final doc in newTransactions.docs) {
      final data = doc.data();
      // Gunakan created_at untuk waktu yang benar
      final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      final namaPelanggan = (data['nama_pelanggan'] ?? 'Pelanggan') as String;
      
      notifications.add({
        'id': 'transaksi_${doc.id}',
        'title': 'Transaksi Baru',
        'body': 'Transaksi dari $namaPelanggan menunggu panen',
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt),
        'time': DateFormat('HH:mm', 'id_ID').format(createdAt),
        'timestamp': createdAt,
        'type': 'transaction',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // 2. Akun baru dibuat (dalam 7 hari terakhir)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    QuerySnapshot<Map<String, dynamic>> newAccounts;
    try {
      newAccounts = await _db
          .collection('pengguna')
          .where('created_at', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Jika error (mungkin karena index), coba tanpa orderBy
      newAccounts = await _db
          .collection('pengguna')
          .where('created_at', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .limit(10)
          .get();
    }

    for (final doc in newAccounts.docs) {
      final data = doc.data();
      final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      final namaPengguna = (data['nama_pengguna'] ?? 'Karyawan') as String;
      final posisi = (data['posisi'] ?? '') as String;
      
      notifications.add({
        'id': 'akun_${doc.id}',
        'title': 'Akun Baru Dibuat',
        'body': '$namaPengguna ($posisi) telah terdaftar',
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt),
        'time': DateFormat('HH:mm', 'id_ID').format(createdAt),
        'timestamp': createdAt,
        'type': 'account',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // Sort berdasarkan timestamp terbaru
    notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return notifications.take(20).toList();
  }

  /// Notifikasi untuk Petani
  Future<List<Map<String, dynamic>>> _getFarmerNotifications(String userId, String? plantId) async {
    final notifications = <Map<String, dynamic>>[];

    if (plantId == null) return notifications;

    // 1. Jadwal perawatan hari ini
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todaySchedules = await _db
        .collection('perawatan_tanaman')
        .where('id_tanaman', isEqualTo: plantId)
        .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('tanggal', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    for (final doc in todaySchedules.docs) {
      final data = doc.data();
      final tanggal = (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now();
      final namaPerawatan = (data['nama_perawatan'] ?? 'Perawatan') as String;
      final deskripsi = (data['deskripsi'] ?? '') as String;
      
      notifications.add({
        'id': 'perawatan_${doc.id}',
        'title': 'Jadwal Perawatan Hari Ini',
        'body': '$namaPerawatan: $deskripsi',
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(tanggal),
        'time': DateFormat('HH:mm', 'id_ID').format(tanggal),
        'timestamp': tanggal,
        'type': 'maintenance',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // 2. Tugas panen (transaksi yang perlu di-harvest)
    QuerySnapshot<Map<String, dynamic>> harvestTasks;
    try {
      harvestTasks = await _db
          .collection('transaksi')
          .where('is_harvest', isEqualTo: false)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Jika error (mungkin karena index), coba tanpa orderBy
      harvestTasks = await _db
          .collection('transaksi')
          .where('is_harvest', isEqualTo: false)
          .limit(10)
          .get();
    }

    for (final doc in harvestTasks.docs) {
      final data = doc.data();
      final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      final namaPelanggan = (data['nama_pelanggan'] ?? 'Pelanggan') as String;
      final items = (data['items'] as List?) ?? [];
      final totalItems = items.fold<int>(0, (sum, item) => sum + ((item['jumlah'] ?? 0) as int));
      
      notifications.add({
        'id': 'panen_${doc.id}',
        'title': 'Tugas Panen',
        'body': 'Panen $totalItems item untuk $namaPelanggan',
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt),
        'time': DateFormat('HH:mm', 'id_ID').format(createdAt),
        'timestamp': createdAt,
        'type': 'harvest',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // Sort berdasarkan timestamp terbaru
    notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return notifications.take(20).toList();
  }

  /// Notifikasi untuk Staf Logistik
  Future<List<Map<String, dynamic>>> _getLogisticNotifications() async {
    final notifications = <Map<String, dynamic>>[];

    // Transaksi yang sudah di-harvest tapi belum di-assign kurir
    QuerySnapshot<Map<String, dynamic>> readyToShip;
    try {
      readyToShip = await _db
          .collection('transaksi')
          .where('is_harvest', isEqualTo: true)
          .where('is_assigned', isEqualTo: false)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Jika error (mungkin karena index), coba tanpa orderBy
      readyToShip = await _db
          .collection('transaksi')
          .where('is_harvest', isEqualTo: true)
          .where('is_assigned', isEqualTo: false)
          .limit(10)
          .get();
    }

    for (final doc in readyToShip.docs) {
      final data = doc.data();
      final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      final namaPelanggan = (data['nama_pelanggan'] ?? 'Pelanggan') as String;
      final alamat = (data['alamat'] ?? '') as String;
      
      notifications.add({
        'id': 'pengiriman_${doc.id}',
        'title': 'Siap Dikirim',
        'body': 'Transaksi dari $namaPelanggan siap untuk dikirim ke $alamat',
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt),
        'time': DateFormat('HH:mm', 'id_ID').format(createdAt),
        'timestamp': createdAt,
        'type': 'shipping',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // Status pengiriman terbaru
    QuerySnapshot<Map<String, dynamic>> recentShipments;
    try {
      recentShipments = await _db
          .collection('pengiriman')
          .orderBy('updated_at', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Jika error (mungkin karena index), coba tanpa orderBy
      recentShipments = await _db
          .collection('pengiriman')
          .limit(10)
          .get();
    }

    for (final doc in recentShipments.docs) {
      final data = doc.data();
      final updatedAt = (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      final status = (data['status_pengiriman'] ?? '') as String;
      final transaksiId = (data['id_transaksi'] ?? '') as String;
      
      // Ambil nama pelanggan dari transaksi
      String namaPelanggan = 'Pelanggan';
      if (transaksiId.isNotEmpty) {
        final transaksiDoc = await _db.collection('transaksi').doc(transaksiId).get();
        final transaksiData = transaksiDoc.data();
        namaPelanggan = (transaksiData?['nama_pelanggan'] ?? 'Pelanggan') as String;
      }
      
      notifications.add({
        'id': 'status_${doc.id}',
        'title': 'Update Status Pengiriman',
        'body': 'Pengiriman ke $namaPelanggan: $status',
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(updatedAt),
        'time': DateFormat('HH:mm', 'id_ID').format(updatedAt),
        'timestamp': updatedAt,
        'type': 'delivery_status',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // Sort berdasarkan timestamp terbaru
    notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return notifications.take(20).toList();
  }

  /// Notifikasi untuk Kurir
  Future<List<Map<String, dynamic>>> _getCourierNotifications(String courierId) async {
    final notifications = <Map<String, dynamic>>[];

    // Pengiriman yang ditugaskan ke kurir ini
    QuerySnapshot<Map<String, dynamic>> assignments;
    try {
      assignments = await _db
          .collection('pengiriman')
          .where('id_kurir', isEqualTo: courierId)
          .orderBy('tanggal_pengiriman', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Jika error (mungkin karena index), coba tanpa orderBy
      assignments = await _db
          .collection('pengiriman')
          .where('id_kurir', isEqualTo: courierId)
          .limit(10)
          .get();
    }

    for (final doc in assignments.docs) {
      final data = doc.data();
      // Gunakan created_at untuk waktu yang benar
      final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      final status = (data['status_pengiriman'] ?? 'Belum Dikirim') as String;
      final transaksiId = (data['id_transaksi'] ?? '') as String;
      
      // Ambil detail transaksi
      String namaPelanggan = 'Pelanggan';
      String alamat = '';
      if (transaksiId.isNotEmpty) {
        final transaksiDoc = await _db.collection('transaksi').doc(transaksiId).get();
        final transaksiData = transaksiDoc.data();
        namaPelanggan = (transaksiData?['nama_pelanggan'] ?? 'Pelanggan') as String;
        alamat = (transaksiData?['alamat'] ?? '') as String;
      }
      
      String title = 'Pengiriman Baru';
      String body = 'Pengiriman ke $namaPelanggan';
      
      if (status.toLowerCase().contains('selesai') || status.toLowerCase().contains('terkirim')) {
        title = 'Pengiriman Selesai';
        body = 'Pengiriman ke $namaPelanggan telah selesai';
      } else if (status != 'Belum Dikirim') {
        title = 'Update Pengiriman';
        body = 'Status: $status - $namaPelanggan';
      }
      
      notifications.add({
        'id': 'kurir_${doc.id}',
        'title': title,
        'body': body,
        'date': DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt),
        'time': DateFormat('HH:mm', 'id_ID').format(createdAt),
        'timestamp': createdAt,
        'type': 'delivery',
        'referenceId': doc.id,
        'isRead': false,
      });
    }

    // Sort berdasarkan timestamp terbaru
    notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return notifications.take(20).toList();
  }

  /// Notifikasi untuk Super Admin (gabungan semua notifikasi)
  Future<List<Map<String, dynamic>>> _getSuperAdminNotifications() async {
    final notifications = <Map<String, dynamic>>[];

    // Gabungkan semua notifikasi dari semua role
    final adminNotif = await _getAdminNotifications();
    final logisticNotif = await _getLogisticNotifications();
    
    notifications.addAll(adminNotif);
    notifications.addAll(logisticNotif);

    // Tambahkan label untuk membedakan sumber notifikasi
    for (var notif in notifications) {
      if (adminNotif.contains(notif)) {
        notif['source'] = 'Admin';
      } else if (logisticNotif.contains(notif)) {
        notif['source'] = 'Logistik';
      }
    }

    // Sort berdasarkan timestamp terbaru
    notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return notifications.take(30).toList();
  }

  /// Mark notifikasi sebagai sudah dibaca (opsional, bisa disimpan di Firestore)
  Future<void> markAsRead(String notificationId) async {
    // Bisa diimplementasikan dengan menyimpan ke Firestore jika diperlukan
    // Untuk sekarang, hanya return (karena notifikasi real-time)
  }
}

