import 'dart:async';
import 'dart:io'; // Penting: Untuk cek Platform
import 'package:async/async.dart'; // Pastikan package ini ada di pubspec.yaml
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
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  
  // REVISI: Mundurkan waktu cek terakhir 10 detik ke belakang.
  // Ini memberi toleransi jika ada selisih waktu antara server dan device,
  // atau jika event terjadi tepat saat aplikasi baru dibuka.
  DateTime _lastCheckTime = DateTime.now().subtract(const Duration(seconds: 10));
  StreamSubscription? _notificationSubscription;

  /// Inisialisasi local notifications
  Future<void> initialize() async {
    if (_initialized) return;
    
    // 1. Setup Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // 2. Setup iOS
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
        // Handle jika notifikasi diklik
      },
    );
    
    // 3. Buat Notification Channel (Android)
    const androidChannel = AndroidNotificationChannel(
      'main_channel', 
      'Notifikasi Aplikasi',
      description: 'Pemberitahuan penting aplikasi',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    await androidImplementation?.createNotificationChannel(androidChannel);

    // REVISI: Request Permission secara eksplisit (Wajib untuk Android 13+)
    if (Platform.isAndroid) {
      await androidImplementation?.requestNotificationsPermission();
    }
    
    _initialized = true;
    print("🔔 NotificationService Initialized. Last Check Time: $_lastCheckTime");
  }

  /// Mulai mendengarkan stream notifikasi
  void startListening() {
    stopListening(); // Hentikan listener lama jika ada

    if (!_initialized) {
      initialize().then((_) => _listen());
    } else {
      _listen();
    }
  }

  /// Logika utama pendengar stream
  void _listen() {
    print("🎧 Start Listening to Notification Stream...");
    
    _notificationSubscription = getNotificationsStream().listen((notifications) {
      // 1. Urutkan dari yang Terlama -> Terbaru (Ascending)
      notifications.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

      DateTime? maxTimestampInBatch; 
      int newCount = 0;

      // 2. Loop semua data yang masuk
      for (var data in notifications) {
        final timestamp = data['timestamp'] as DateTime;
        final title = data['title'] ?? 'Info';
        
        // 3. Filter: Hanya tampilkan jika LEBIH BARU dari waktu cek terakhir
        if (timestamp.isAfter(_lastCheckTime)) {
          print("🚀 TRIGGER NOTIF: $title (Time: $timestamp vs Last: $_lastCheckTime)");
          
          _showLocalNotification(
            id: data['id'].hashCode,
            title: title,
            body: data['body'] ?? '',
            payload: data['referenceId'],
          );
          
          newCount++;

          // Cari waktu paling baru di batch ini untuk update _lastCheckTime nanti
          if (maxTimestampInBatch == null || timestamp.isAfter(maxTimestampInBatch!)) {
            maxTimestampInBatch = timestamp;
          }
        }
      }

      // 4. Update _lastCheckTime SETELAH semua diproses
      if (maxTimestampInBatch != null) {
        _lastCheckTime = maxTimestampInBatch!;
        print("✅ Processed $newCount new notifications. Updated Last Check to: $_lastCheckTime");
      }
    }, onError: (e) {
      print("❌ Error in Notification Stream: $e");
    });
  }

  /// Berhenti mendengarkan notifikasi
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    print("🛑 Notification Listener Stopped");
  }

  /// Helper untuk menampilkan notifikasi sistem
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Pastikan terinisialisasi
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Notifikasi Aplikasi',
      channelDescription: 'Pemberitahuan penting aplikasi',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''), // Agar teks panjang tampil penuh
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> testNotification({required String title, required String body}) async {
    await _showLocalNotification(id: 9999, title: title, body: body);
  }

  // ==================== STREAM CONTROLLER (ROUTING) ====================

  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Listen ke perubahan user doc untuk menangani perubahan role/plantId
    return _db.collection('pengguna').doc(user.uid).snapshots().asyncExpand((userDoc) {
      final userData = userDoc.data();
      if (userData == null) return Stream.value([]);

      final role = (userData['posisi'] ?? '') as String;
      print("👤 Notification Service - User Role: $role"); 

      switch (role) {
        case 'Kurir':
          return _getCourierNotificationsStream(user.uid);
        
        case 'Staf Logistik':
          return _getLogisticNotificationsStream();

        case 'Petani':
          final plantId = userData['id_tanaman'] as String?;
          print("🌱 Notification Service - Petani Plant ID: $plantId");
          return _getFarmerNotificationsStream(user.uid, plantId);

        case 'Admin':
          return Stream.fromFuture(_getAdminNotifications());
        
        case 'Super Admin':
          return Stream.fromFuture(_getSuperAdminNotifications());
        
        default:
          return Stream.value([]);
      }
    });
  }

  // ==================== LOGIKA STREAM PER ROLE ====================

  /// STREAM Notifikasi untuk Kurir
  Stream<List<Map<String, dynamic>>> _getCourierNotificationsStream(String courierId) {
    return _db
        .collection('pengiriman')
        .where('id_kurir', isEqualTo: courierId)
        .orderBy('tanggal_pengiriman', descending: true)
        .limit(10)
        .snapshots() 
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            
            final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();
            // Gunakan updated_at jika ada (misal status berubah)
            final effectiveTimestamp = updatedAt ?? createdAt;

            final status = (data['status_pengiriman'] ?? 'Belum Dikirim') as String;
            final transaksiId = (data['id_transaksi'] ?? '') as String;
            
            String namaPelanggan = 'Pelanggan';
            if (transaksiId.isNotEmpty) {
              try {
                final txDoc = await _db.collection('transaksi').doc(transaksiId).get();
                if (txDoc.exists) {
                   namaPelanggan = (txDoc.data()?['nama_pelanggan'] ?? 'Pelanggan') as String;
                }
              } catch (_) {}
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
              'timestamp': effectiveTimestamp,
              'date': DateFormat('dd MMM yyyy').format(effectiveTimestamp),
              'time': DateFormat('HH:mm').format(effectiveTimestamp),
              'type': 'delivery',
              'referenceId': doc.id,
              'isRead': false,
            });
          }
          return notifications;
        });
  }

  /// STREAM Notifikasi untuk Staf Logistik (DIPERBAIKI)
  Stream<List<Map<String, dynamic>>> _getLogisticNotificationsStream() {
    // STREAM 1: Transaksi Siap Dikirim (Sesuai Logic Lama)
    final readyToShipStream = _db
        .collection('transaksi')
        .where('is_harvest', isEqualTo: true)
        .where('is_assigned', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();
            final effectiveTimestamp = updatedAt ?? createdAt;
            final namaPelanggan = (data['nama_pelanggan'] ?? 'Pelanggan') as String;
            
            notifications.add({
              'id': 'pengiriman_${doc.id}',
              'title': 'Siap Dikirim',
              'body': 'Pesanan $namaPelanggan siap dijemput & dikirim',
              'timestamp': effectiveTimestamp,
              'date': DateFormat('dd MMM yyyy').format(effectiveTimestamp),
              'time': DateFormat('HH:mm').format(effectiveTimestamp),
              'type': 'shipping',
              'referenceId': doc.id,
              'isRead': false,
            });
          }
          return notifications;
        });

    // STREAM 2: Status Pengiriman Selesai (Sesuai Logic LogisticDeliveryStatusScreen)
    // Kita memantau koleksi 'pengiriman' secara langsung
    final deliveryCompletedStream = _db
        .collection('pengiriman')
        .orderBy('updated_at', descending: true)
        .limit(10) // Ambil 10 update terakhir
        .snapshots()
        .asyncMap((snapshot) async {
           final notifications = <Map<String, dynamic>>[];
           
           for (final doc in snapshot.docs) {
             final data = doc.data();
             final status = (data['status_pengiriman'] ?? '') as String;
             
             // Filter: Hanya ambil yang statusnya Selesai/Terkirim
             if (status.toLowerCase().contains('selesai') || 
                 status.toLowerCase().contains('terkirim')) {
               
                final updatedAt = (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now();
                final transaksiId = (data['id_transaksi'] ?? '') as String;

                // Ambil Nama Pelanggan dari Transaksi untuk detail notifikasi
                String namaPelanggan = 'Pelanggan';
                if (transaksiId.isNotEmpty) {
                  try {
                    final txDoc = await _db.collection('transaksi').doc(transaksiId).get();
                    if (txDoc.exists) {
                       namaPelanggan = (txDoc.data()?['nama_pelanggan'] ?? 'Pelanggan') as String;
                    }
                  } catch (_) {}
                }

                notifications.add({
                  'id': 'selesai_${doc.id}', // ID Unik
                  'title': 'Pengiriman Selesai',
                  'body': 'Kurir telah menyelesaikan pengiriman ke $namaPelanggan',
                  'timestamp': updatedAt, 
                  'date': DateFormat('dd MMM yyyy').format(updatedAt),
                  'time': DateFormat('HH:mm').format(updatedAt),
                  'type': 'delivery_status',
                  'referenceId': doc.id,
                  'isRead': false,
                });
             }
           }
           return notifications;
        });

    // Menggabungkan kedua stream agar Logistik menerima notifikasi dari kedua sumber
    return StreamGroup.merge([readyToShipStream, deliveryCompletedStream]);
  }

  /// STREAM Notifikasi untuk Petani
  Stream<List<Map<String, dynamic>>> _getFarmerNotificationsStream(String userId, String? plantId) {
    if (plantId == null) {
      return Stream.value([]);
    }

    // 1. Listen ke 'transaksi' yang BELUM dipanen (is_harvest == false)
    return _db
        .collection('transaksi')
        .where('is_harvest', isEqualTo: false) 
        .snapshots()
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];

          // A. Proses Tugas Panen (Real-time)
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final items = (data['items'] as List?) ?? [];
            
            bool isMyTask = false;
            int myTotalItems = 0;
            String myPlantName = 'Tanaman';

            for (var item in items) {
              final m = item as Map<String, dynamic>;
              if (m['id_tanaman'].toString() == plantId.toString()) {
                isMyTask = true;
                myTotalItems += (m['jumlah'] ?? 0) as int;
                myPlantName = (m['nama_tanaman'] ?? 'Tanaman') as String;
              }
            }

            if (isMyTask && myTotalItems > 0) {
              final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? 
                                (data['tanggal'] as Timestamp?)?.toDate() ??
                                DateTime.now();
              
              final namaPelanggan = (data['nama_pelanggan'] ?? 'Pelanggan') as String;
              
              notifications.add({
                'id': 'panen_${doc.id}',
                'title': 'Tugas Panen Baru', 
                'body': 'Permintaan $myTotalItems $myPlantName untuk $namaPelanggan',
                'timestamp': createdAt, 
                'date': DateFormat('dd MMM yyyy').format(createdAt),
                'time': DateFormat('HH:mm').format(createdAt),
                'type': 'harvest',
                'referenceId': doc.id,
                'isRead': false,
              });
            }
          }

          // B. Gabungkan dengan Jadwal Perawatan (Fetch Future manual)
          try {
              final maintenanceList = await _getFarmerMaintenance(plantId);
              notifications.addAll(maintenanceList);
          } catch (_) {}
          
          return notifications;
        });
  }

  /// Helper: Get Jadwal Perawatan (Future)
  Future<List<Map<String, dynamic>>> _getFarmerMaintenance(String? plantId) async {
    final notifications = <Map<String, dynamic>>[];
    if (plantId == null) return notifications;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
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
        
        notifications.add({
          'id': 'perawatan_${doc.id}',
          'title': 'Jadwal Perawatan',
          'body': 'Jangan lupa: $namaPerawatan hari ini',
          'timestamp': tanggal,
          'date': DateFormat('dd MMM yyyy').format(tanggal),
          'time': DateFormat('HH:mm').format(tanggal),
          'type': 'maintenance',
          'referenceId': doc.id,
          'isRead': false,
        });
      }
    } catch (e) {}
    return notifications;
  }

  // ==================== LOGIKA ROLE LAIN (Future) ====================

  /// Notifikasi untuk Admin
  Future<List<Map<String, dynamic>>> _getAdminNotifications() async {
    final notifications = <Map<String, dynamic>>[];

    // 1. Transaksi baru
    try {
      final newTransactions = await _db.collection('transaksi')
          .where('is_harvest', isEqualTo: false)
          .limit(10).get();

      for (final doc in newTransactions.docs) {
        final data = doc.data();
        final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        final namaPelanggan = (data['nama_pelanggan'] ?? 'Pelanggan') as String;
        
        notifications.add({
          'id': 'transaksi_${doc.id}',
          'title': 'Transaksi Baru',
          'body': 'Transaksi dari $namaPelanggan menunggu panen',
          'timestamp': createdAt,
          'date': DateFormat('dd MMM yyyy').format(createdAt),
          'time': DateFormat('HH:mm').format(createdAt),
          'type': 'transaction',
          'referenceId': doc.id,
          'isRead': false,
        });
      }
    } catch (_) {}

    // 2. Akun baru
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    try {
      final newAccounts = await _db.collection('pengguna')
          .where('created_at', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .limit(10).get();

      for (final doc in newAccounts.docs) {
        final data = doc.data();
        final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        final namaPengguna = (data['nama_pengguna'] ?? 'Karyawan') as String;
        
        notifications.add({
          'id': 'akun_${doc.id}',
          'title': 'Akun Baru Dibuat',
          'body': '$namaPengguna telah terdaftar',
          'timestamp': createdAt,
          'date': DateFormat('dd MMM yyyy').format(createdAt),
          'time': DateFormat('HH:mm').format(createdAt),
          'type': 'account',
          'referenceId': doc.id,
          'isRead': false,
        });
      }
    } catch (_) {}

    return notifications;
  }

  /// Notifikasi untuk Super Admin
  Future<List<Map<String, dynamic>>> _getSuperAdminNotifications() async {
    final notifications = <Map<String, dynamic>>[];
    final adminNotif = await _getAdminNotifications();
    
    // Untuk Logistik di SuperAdmin, kita fetch manual sekali saja (bukan stream)
    final logisticStream = _getLogisticNotificationsStream();
    final logisticNotif = await logisticStream.first.catchError((_) => <Map<String,dynamic>>[]);
    
    notifications.addAll(adminNotif);
    notifications.addAll(logisticNotif);
    
    return notifications;
  }

  Future<void> markAsRead(String notificationId) async {}
}