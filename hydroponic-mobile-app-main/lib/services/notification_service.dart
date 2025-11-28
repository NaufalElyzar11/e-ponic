import 'dart:async';
import 'dart:io'; 
import 'package:async/async.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  DateTime _lastCheckTime = DateTime.now().subtract(const Duration(seconds: 10));
  StreamSubscription? _notificationSubscription;

  // --- 1. INISIALISASI ---
  Future<void> initialize() async {
    if (_initialized) return;
    
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotifications.initialize(initSettings);
    
    const androidChannel = AndroidNotificationChannel(
      'main_channel', 'Notifikasi Aplikasi',
      description: 'Pemberitahuan penting aplikasi',
      importance: Importance.max, playSound: true, enableVibration: true,
    );

    const scheduleChannel = AndroidNotificationChannel(
      'schedule_channel', 'Jadwal Perawatan',
      description: 'Notifikasi jadwal harian',
      importance: Importance.high, playSound: true, enableVibration: true,
    );
    
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidChannel);
      await androidImplementation.createNotificationChannel(scheduleChannel);
      if (Platform.isAndroid) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
    
    _initialized = true;
    print("🔔 NotificationService Initialized.");
  }

  // --- 2. JADWAL NOTIFIKASI ---
  Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();

    if (scheduledDate.isBefore(now)) {
      const androidDetails = AndroidNotificationDetails(
        'schedule_channel', 'Jadwal Perawatan',
        importance: Importance.high, priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );
      await _localNotifications.show(
        id, title, body,
        const NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails()),
      );
    } else {
      final scheduledTimeUtc = tz.TZDateTime.from(scheduledDate.toUtc(), tz.UTC);
      const androidDetails = AndroidNotificationDetails(
        'schedule_channel', 'Jadwal Perawatan',
        importance: Importance.high, priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );
      
      try {
        await _localNotifications.zonedSchedule(
          id, title, body,
          scheduledTimeUtc,
          NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, 
        );
      } catch (e) {
        print("❌ Gagal schedule notif: $e");
      }
    }
  }

  // --- 3. LISTENER UTAMA ---
  void startListening() {
    stopListening();
    if (!_initialized) initialize().then((_) => _listen());
    else _listen();
  }

  void _listen() {
    _notificationSubscription = getNotificationsStream().listen((notifications) {
      notifications.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
      DateTime? maxTimestampInBatch; 

      for (var data in notifications) {
        final timestamp = data['timestamp'] as DateTime;
        final title = data['title'] ?? 'Info';
        
        // Cek ID unik (termasuk suffix _assigned / _done) agar tidak spam notif yang sama
        // Logic sederhana: cek timestamp
        if (timestamp.isAfter(_lastCheckTime)) {
          _showLocalNotification(
            id: data['id'].hashCode,
            title: title,
            body: data['body'] ?? '',
            payload: data['referenceId'],
          );
          if (maxTimestampInBatch == null || timestamp.isAfter(maxTimestampInBatch!)) {
            maxTimestampInBatch = timestamp;
          }
        }
      }
      if (maxTimestampInBatch != null) _lastCheckTime = maxTimestampInBatch!;
    }, onError: (e) => print("❌ Stream Error: $e"));
  }

  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  Future<void> _showLocalNotification({required int id, required String title, required String body, String? payload}) async {
    if (!_initialized) await initialize();
    const androidDetails = AndroidNotificationDetails('main_channel', 'Notifikasi Aplikasi', importance: Importance.max, priority: Priority.high);
    await _localNotifications.show(id, title, body, NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()), payload: payload);
  }

  // --- 4. ROUTING STREAM ---
  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db.collection('pengguna').doc(user.uid).snapshots().asyncExpand((userDoc) {
      final userData = userDoc.data();
      if (userData == null) return Stream.value([]);
      final role = (userData['posisi'] ?? '') as String;

      switch (role) {
        case 'Kurir': return _getCourierNotificationsStream(user.uid);
        case 'Staf Logistik': return _getLogisticNotificationsStream();
        case 'Petani':
          final plantId = userData['id_tanaman'] as String?;
          return _getFarmerNotificationsStream(user.uid, plantId);
        case 'Admin': return Stream.fromFuture(_getAdminNotifications());
        case 'Super Admin': return Stream.fromFuture(_getSuperAdminNotifications());
        default: return Stream.value([]);
      }
    });
  }

  // --- 5. LOGIKA PER ROLE (MODIFIED FOR HISTORY SPLIT) ---

  Map<String, dynamic> _formatNotification({
    required String id,
    required String title,
    required String body,
    required DateTime timestamp,
    required String type,
    String? referenceId,
  }) {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'date': DateFormat('dd MMM yyyy').format(timestamp),
      'time': DateFormat('HH:mm').format(timestamp),
      'isRead': false,
      'type': type,
      'referenceId': referenceId ?? id,
    };
  }

  /// KURIR: Memecah 1 dokumen menjadi 2 histori (Tugas Baru & Selesai)
  Stream<List<Map<String, dynamic>>> _getCourierNotificationsStream(String courierId) {
    return _db
        .collection('pengiriman')
        .where('id_kurir', isEqualTo: courierId)
        .orderBy('created_at', descending: true) // Gunakan created_at sebagai base sort
        .limit(10)
        .snapshots()
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            
            final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();
            
            final status = (data['status_pengiriman'] ?? 'Belum Dikirim') as String;
            final transaksiId = (data['id_transaksi'] ?? '') as String;
            
            // Fetch nama pelanggan
            String namaPelanggan = 'Pelanggan';
            if (transaksiId.isNotEmpty) {
               try {
                 final txDoc = await _db.collection('transaksi').doc(transaksiId).get();
                 if (txDoc.exists) {
                   namaPelanggan = (txDoc.data()?['nama_pelanggan'] ?? 'Pelanggan') as String;
                 }
               } catch (_) {}
            }

            // ITEM 1: Histori Penugasan (Selalu muncul)
            notifications.add(_formatNotification(
              id: '${doc.id}_assigned', // ID Unik agar tidak bentrok
              title: 'Pengiriman Baru',
              body: 'Tugas baru: Antar ke $namaPelanggan',
              timestamp: createdAt,
              type: 'delivery',
              referenceId: doc.id,
            ));

            // ITEM 2: Histori Selesai (Muncul HANYA jika status selesai)
            // Ini menciptakan riwayat terpisah di list
            if (status.toLowerCase().contains('selesai') || status.toLowerCase().contains('terkirim')) {
               if (updatedAt != null) {
                 notifications.add(_formatNotification(
                    id: '${doc.id}_done', // ID Unik berbeda
                    title: 'Pengiriman Selesai',
                    body: 'Sukses mengantar ke $namaPelanggan',
                    timestamp: updatedAt,
                    type: 'delivery_done',
                    referenceId: doc.id,
                 ));
               }
            }
          }
          // Sort ulang agar yang "Selesai" (terbaru) ada di paling atas
          notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          return notifications;
        });
  }

  /// LOGISTIK: Sudah menggabungkan 2 stream (Otomatis terpisah)
  Stream<List<Map<String, dynamic>>> _getLogisticNotificationsStream() {
    // 1. Transaksi Siap (Source: Transaksi)
    final s1 = _db.collection('transaksi')
        .where('is_harvest', isEqualTo: true)
        .where('is_assigned', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map((d) {
            final date = (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            return _formatNotification(
              id: '${d.id}_ready',
              title: 'Siap Dikirim',
              body: 'Pesanan ${d['nama_pelanggan']}',
              timestamp: date,
              type: 'shipping',
              referenceId: d.id
            );
        }).toList());

    // 2. Pengiriman Selesai (Source: Pengiriman)
    final s2 = _db.collection('pengiriman')
        .orderBy('updated_at', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs
            .where((d) => (d['status_pengiriman']??'').toString().toLowerCase().contains('selesai'))
            .map((d) {
              final date = (d['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now();
              return _formatNotification(
                id: '${d.id}_done',
                title: 'Pengiriman Selesai',
                body: 'Kurir menyelesaikan pengiriman',
                timestamp: date,
                type: 'delivery_status',
                referenceId: d.id
              );
            }).toList());

    return _combineLists([s1, s2]);
  }

  /// PETANI: Menambahkan riwayat Panen Selesai (sebelumnya hilang)
  Stream<List<Map<String, dynamic>>> _getFarmerNotificationsStream(String userId, String? plantId) {
    if (plantId == null) return Stream.value([]);
    
    // Kita ambil SEMUA transaksi (baik yang belum maupun sudah panen) untuk membuat histori lengkap
    // Limit 20 agar tidak terlalu berat
    return _db.collection('transaksi')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final items = (data['items'] as List?) ?? [];
            
            // Cek apakah ada tanaman petani ini
            if (items.any((i) => i['id_tanaman'].toString() == plantId)) {
              final isHarvested = data['is_harvest'] == true;
              final date = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
              final namaPelanggan = data['nama_pelanggan'] ?? 'Pelanggan';

              if (!isHarvested) {
                // Item 1: Tugas Masuk
                notifications.add(_formatNotification(
                  id: '${doc.id}_todo',
                  title: 'Tugas Panen',
                  body: 'Pesanan baru: $namaPelanggan',
                  timestamp: date,
                  type: 'harvest',
                  referenceId: doc.id
                ));
              } else {
                // Item 2: Riwayat Sudah Dipanen (Agar tidak hilang dari list)
                // Kita gunakan tanggal transaksi sebagai referensi (atau updated_at jika ada)
                notifications.add(_formatNotification(
                  id: '${doc.id}_done',
                  title: 'Panen Selesai',
                  body: 'Pesanan $namaPelanggan telah dipanen',
                  timestamp: date, // Idealnya updated_at, tapi fallback ke created_at
                  type: 'harvest_done',
                  referenceId: doc.id
                ));
              }
            }
          }
          
          // Tambahkan Jadwal Perawatan (Opsional)
          try {
            final maintenance = await _getFarmerMaintenance(plantId);
            notifications.addAll(maintenance);
          } catch (_) {}

          // Sort Terlama -> Terbaru
          notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          return notifications;
        });
  }

  // Helper Combine List
  Stream<List<T>> _combineLists<T>(List<Stream<List<T>>> streams) {
    StreamController<List<T>> controller = StreamController<List<T>>();
    List<List<T>> latestValues = List.filled(streams.length, []);
    int activeStreams = streams.length;

    for (int i = 0; i < streams.length; i++) {
      streams[i].listen((data) {
        latestValues[i] = data;
        final combined = latestValues.expand((x) => x).toList();
        if (combined.isNotEmpty && combined.first is Map && (combined.first as Map).containsKey('timestamp')) {
           combined.sort((a, b) {
             final tA = (a as Map)['timestamp'] as DateTime;
             final tB = (b as Map)['timestamp'] as DateTime;
             return tB.compareTo(tA);
           });
        }
        controller.add(combined);
      }, onDone: () {
        activeStreams--;
        if (activeStreams == 0) controller.close();
      });
    }
    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> _getFarmerMaintenance(String plantId) async => [];
  Future<List<Map<String, dynamic>>> _getAdminNotifications() async => [];
  Future<List<Map<String, dynamic>>> _getSuperAdminNotifications() async => [];
  Future<void> markAsRead(String notificationId) async {}
}