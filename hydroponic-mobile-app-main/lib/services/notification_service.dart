// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io'; 
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
    // Reset waktu cek ke SEKARANG saat listener dimulai ulang.
    // Agar user baru tidak mendapat notifikasi sampah dari sesi sebelumnya.
    _lastCheckTime = DateTime.now(); 
    
    if (!_initialized) initialize().then((_) => _listen());
    else _listen();
    
    print("🔔 NotificationService: Listening started for current user.");
  }

  void _listen() {
    _notificationSubscription = getNotificationsStream().listen((notifications) {
      notifications.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
      DateTime? maxTimestampInBatch; 

      for (var data in notifications) {
        final timestamp = data['timestamp'] as DateTime;
        final title = data['title'] ?? 'Info';
        
        if (data['type'] == 'maintenance' || data['type'] == 'harvest_estimate') {
          continue; 
        }

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
        case 'Admin': return _getAdminNotificationsStream();
        case 'Super Admin': return Stream.fromFuture(_getSuperAdminNotifications());
        default: return Stream.value([]);
      }
    });
  }

  // --- 5. LOGIKA PER ROLE ---

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

  Stream<List<Map<String, dynamic>>> _getCourierNotificationsStream(String courierId) {
    return _db.collection('pengiriman').where('id_kurir', isEqualTo: courierId).orderBy('created_at', descending: true).limit(10).snapshots()
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();
            final status = (data['status_pengiriman'] ?? 'Belum Dikirim') as String;
            final transaksiId = (data['id_transaksi'] ?? '') as String;
            
            String namaPelanggan = 'Pelanggan';
            if (transaksiId.isNotEmpty) {
              try {
                final txDoc = await _db.collection('transaksi').doc(transaksiId).get();
                if (txDoc.exists) namaPelanggan = (txDoc.data()?['nama_pelanggan'] ?? 'Pelanggan') as String;
              } catch (_) {}
            }

            notifications.add(_formatNotification(
              id: '${doc.id}_assigned',
              title: 'Pengiriman Baru',
              body: 'Tugas baru: Antar ke $namaPelanggan',
              timestamp: createdAt,
              type: 'delivery',
              referenceId: doc.id,
            ));

            if (status.toLowerCase().contains('selesai') || status.toLowerCase().contains('terkirim')) {
              if (updatedAt != null) {
                notifications.add(_formatNotification(
                  id: '${doc.id}_done',
                  title: 'Pengiriman Selesai',
                  body: 'Sukses mengantar ke $namaPelanggan',
                  timestamp: updatedAt,
                  type: 'delivery_done',
                  referenceId: doc.id,
                ));
              }
            }
          }
          notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          return notifications;
        });
  }

  Stream<List<Map<String, dynamic>>> _getLogisticNotificationsStream() {
    final s1 = _db.collection('transaksi').where('is_harvest', isEqualTo: true).where('is_assigned', isEqualTo: false).snapshots()
        .map((s) => s.docs.map((d) {
            final date = (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
            return _formatNotification(
              id: '${d.id}_ready', title: 'Siap Dikirim', body: 'Pesanan ${d['nama_pelanggan']}', timestamp: date, type: 'shipping', referenceId: d.id
            );
        }).toList());

    final s2 = _db.collection('pengiriman').orderBy('updated_at', descending: true).limit(10).snapshots()
        .map((s) => s.docs.where((d) => (d['status_pengiriman']??'').toString().toLowerCase().contains('selesai'))
            .map((d) {
              final date = (d['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now();
              return _formatNotification(
                id: '${d.id}_done', title: 'Pengiriman Selesai', body: 'Kurir menyelesaikan pengiriman', timestamp: date, type: 'delivery_status', referenceId: d.id
              );
            }).toList());

    return _combineLists([s1, s2]);
  }

  Stream<List<Map<String, dynamic>>> _getFarmerNotificationsStream(String userId, String? plantId) {
    if (plantId == null) return Stream.value([]);
    
    return _db.collection('transaksi').orderBy('created_at', descending: true).limit(20).snapshots()
        .asyncMap((snapshot) async {
          final notifications = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final items = (data['items'] as List?) ?? [];
            
            if (items.any((i) => i['id_tanaman'].toString() == plantId)) {
              final isHarvested = data['is_harvest'] == true;
              final date = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
              final namaPelanggan = data['nama_pelanggan'] ?? 'Pelanggan';

              notifications.add(_formatNotification(
                id: '${doc.id}_todo', title: 'Tugas Panen', body: 'Pesanan baru: $namaPelanggan', timestamp: date, type: 'harvest', referenceId: doc.id
              ));

              if (isHarvested) {
                // Gunakan updated_at untuk histori panen selesai, atau fallback ke created_at
                final dateDone = (data['updated_at'] as Timestamp?)?.toDate() ?? date;
                notifications.add(_formatNotification(
                  id: '${doc.id}_done', title: 'Panen Selesai', body: 'Pesanan $namaPelanggan telah dipanen', timestamp: dateDone, type: 'harvest_done', referenceId: doc.id
                ));
              }
            }
          }
          
          try {
            final maintenance = await _getFarmerMaintenance(userId, plantId);
            notifications.addAll(maintenance);
          } catch (_) {}

          notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          return notifications;
        });
  }

  Stream<List<Map<String, dynamic>>> _getAdminNotificationsStream() {
    return _db.collection('transaksi')
        .orderBy('updated_at', descending: true)
        .limit(20) 
        .snapshots()
        .map((snapshot) {
          final notifications = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            // Ambil waktu spesifik per kejadian
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();
            final harvestedAt = (data['harvested_at'] as Timestamp?)?.toDate();
            final deliveredAt = (data['delivered_at'] as Timestamp?)?.toDate();
            
            final namaPelanggan = data['nama_pelanggan'] ?? 'Pelanggan';

            // 1. Notifikasi Panen
            // Gunakan harvestedAt sebagai timestamp. Jika null, pakai createdAt (biasanya data lama)
            if (data['is_harvest'] == true) {
              notifications.add(_formatNotification(
                id: '${doc.id}_harvest_alert',
                title: 'Tanaman Dipanen',
                body: 'Pesanan untuk $namaPelanggan telah selesai dipanen.',
                timestamp: harvestedAt ?? createdAt ?? DateTime(2000),
                type: 'admin_harvest',
                referenceId: doc.id,
              ));
            }

            // 2. Notifikasi Pengiriman Selesai
            // Gunakan deliveredAt sebagai timestamp
            if (data['is_deliver'] == true) {
              notifications.add(_formatNotification(
                id: '${doc.id}_delivery_done',
                title: 'Pengiriman Selesai',
                body: 'Pesanan untuk $namaPelanggan telah berhasil dikirim.',
                timestamp: deliveredAt ?? createdAt ?? DateTime(2000),
                type: 'admin_delivery_done',
                referenceId: doc.id,
              ));
            }
            
            // 3. Pembayaran
            if (data['is_paid'] == true) {
               // Untuk saat ini pakai createdAt karena biasanya bayar di awal
              notifications.add(_formatNotification(
                id: '${doc.id}_paid_alert',
                title: 'Pembayaran Diterima',
                body: 'Pesanan $namaPelanggan telah lunas.',
                timestamp: createdAt ?? DateTime(2000),
                type: 'admin_payment',
                referenceId: doc.id,
              ));
            }
          }
          
          // Urutkan
          notifications.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          return notifications;
        });
  }

  // --- LOGIKA HITUNG JADWAL (DENGAN FILTER WAKTU JAM 9) ---
  Future<List<Map<String, dynamic>>> _getFarmerMaintenance(String userId, String plantId) async {
    final notifications = <Map<String, dynamic>>[];
    
    // --- PENGECEKAN WAKTU ---
    final now = DateTime.now();
    final todayNineAM = DateTime(now.year, now.month, now.day, 9, 0);

    // Jika sekarang BELUM jam 09:00 pagi, jangan tampilkan riwayat perawatan
    if (now.isBefore(todayNineAM)) {
      return [];
    }

    try {
      final plantDoc = await _db.collection('tanaman').doc(plantId).get();
      if (!plantDoc.exists) return [];
      final plantData = plantDoc.data() ?? {};
      int getInt(String k) {
        final val = plantData[k];
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 1;
        return 1;
      }
      final intAir = getInt('jadwal_pengecekan_air_dan_nutrisi');
      final intCek = getInt('jadwal_pengecekan_tanaman');
      final intBersih = getInt('jadwal_pembersihan_instalasi');
      final masaTanam = getInt('masa_tanam');

      final dataTanamSnap = await _db.collection('data_tanam')
          .where('id_tanaman', isEqualTo: plantId)
          .where('id_petani', isEqualTo: userId)
          .get();

      final today = DateTime(now.year, now.month, now.day);
      // Gunakan todayNineAM sebagai timestamp agar konsisten jam 9
      final notificationTime = todayNineAM;

      final Set<String> tasks = {};

      for (var doc in dataTanamSnap.docs) {
        final d = doc.data();
        DateTime? tgl;
        if(d['tanggal_tanam'] is Timestamp) tgl = (d['tanggal_tanam'] as Timestamp).toDate();
        else if(d['tanggal_tanam'] is String) tgl = DateTime.tryParse(d['tanggal_tanam']);
        
        if (tgl == null) continue;
        final start = DateTime(tgl.year, tgl.month, tgl.day);
        final diff = today.difference(start).inDays;
        
        if (diff <= 0) continue; 

        bool isTodaySchedule(int interval) => interval > 0 && (diff % interval == 0);

        if (isTodaySchedule(intAir)) tasks.add('Pengecekan Air & Nutrisi');
        if (isTodaySchedule(intCek)) tasks.add('Pengecekan Tanaman');
        if (isTodaySchedule(intBersih)) tasks.add('Pembersihan Instalasi');
        
        final panenDate = start.add(Duration(days: masaTanam));
        if (panenDate.year == today.year && panenDate.month == today.month && panenDate.day == today.day) {
          notifications.add(_formatNotification(
            id: 'panen_${doc.id}', title: 'Estimasi Panen', body: 'Waktunya panen untuk batch ini!', timestamp: notificationTime, type: 'harvest_estimate'
          ));
        }
      }

      if (tasks.isNotEmpty) {
        final combinedBody = tasks.map((t) => "• $t").join("\n");
        
        notifications.add(_formatNotification(
          id: 'maintenance_today_combined',
          title: 'Jadwal Perawatan',
          body: combinedBody,
          timestamp: notificationTime,
          type: 'maintenance'
        ));
      }

    } catch (_) {}
    return notifications;
  }

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

  Future<List<Map<String, dynamic>>> _getSuperAdminNotifications() async => [];
  Future<void> markAsRead(String notificationId) async {}
}