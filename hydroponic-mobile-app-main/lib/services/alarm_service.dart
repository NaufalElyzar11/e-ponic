import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Service untuk mengelola alarm/notifikasi jadwal petani
class AlarmService {
  AlarmService._();

  static final AlarmService instance = AlarmService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Inisialisasi service alarm
  Future<void> initialize() async {
    if (_initialized) {
      print('AlarmService already initialized');
      return;
    }

    print('Initializing AlarmService...');

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    print('Timezone initialized: Asia/Jakarta');

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('Notifications initialized: $initialized');

    // Request permissions (Android 13+)
    await _requestPermissions();

    // Create notification channel untuk Android
    await _createNotificationChannel();

    _initialized = true;
    print('AlarmService initialization complete');
  }

  /// Create notification channel untuk Android dengan konfigurasi alarm
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'maintenance_channel',
      'Jadwal Perawatan',
      description: 'Alarm untuk jadwal perawatan tanaman',
      importance: Importance.max, // MAX untuk alarm yang lebih kuat
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      print('✅ Notification channel created with MAX importance');
    }
  }

  /// Request permissions untuk notifikasi
  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final notificationPermission = await androidPlugin.requestNotificationsPermission();
      print('Notification permission: $notificationPermission');
      
      final exactAlarmPermission = await androidPlugin.requestExactAlarmsPermission();
      print('Exact alarm permission: $exactAlarmPermission');
    }

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      final iosPermission = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('iOS permission: $iosPermission');
    }
  }

  /// Handler ketika notifikasi di-tap
  void _onNotificationTapped(NotificationResponse response) {
    // Bisa ditambahkan navigasi ke halaman tertentu jika diperlukan
    print('Notification tapped: ${response.payload}');
  }

  /// Schedule alarm untuk jadwal petani
  /// 
  /// [scheduleId] - ID unik untuk alarm (bisa menggunakan field + tanggal)
  /// [title] - Judul notifikasi
  /// [body] - Isi notifikasi
  /// [scheduledDate] - Tanggal dan waktu alarm (akan di-set ke jam 09:00)
  /// [isTestMode] - Jika true, alarm akan di-set 1 menit dari sekarang (untuk testing)
  Future<void> scheduleMaintenanceAlarm({
    required int scheduleId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isTestMode = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel alarm yang sudah ada dengan ID yang sama
    await cancelAlarm(scheduleId);

    DateTime alarmTime;
    
    if (isTestMode) {
      // Untuk testing: set alarm 1 menit dari sekarang
      alarmTime = DateTime.now().add(const Duration(minutes: 1));
    } else {
      // Set alarm ke jam 09:00 pada tanggal yang ditentukan
      alarmTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, // Jam 09:00
        0, // Menit 0
      );

      // Jika waktu alarm sudah lewat hari ini, skip
      if (alarmTime.isBefore(DateTime.now())) {
        print('Alarm time has passed, skipping: $title');
        return;
      }
    }

    final tzAlarmTime = tz.TZDateTime.from(alarmTime, tz.local);

    // Android notification details - Konfigurasi untuk alarm yang kuat
    // Tidak bisa const karena vibrationPattern menggunakan Int64List.fromList()
    final androidDetails = AndroidNotificationDetails(
      'maintenance_channel',
      'Jadwal Perawatan',
      channelDescription: 'Alarm untuk jadwal perawatan tanaman',
      importance: Importance.max, // MAX untuk alarm yang lebih kuat
      priority: Priority.max, // MAX priority
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]), // Pattern getar yang lebih kuat
      fullScreenIntent: true, // Membangunkan layar saat alarm
      category: AndroidNotificationCategory.alarm, // Kategori alarm
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(''), // Style untuk notifikasi besar
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        scheduleId,
        title,
        body,
        tzAlarmTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: isTestMode
            ? null
            : DateTimeComponents.dateAndTime,
      );

      print('✅ Alarm scheduled successfully: $title at ${alarmTime.toString()}');
      print('   Schedule ID: $scheduleId');
      print('   Timezone time: ${tzAlarmTime.toString()}');
    } catch (e) {
      print('❌ Error scheduling alarm: $e');
      rethrow;
    }
  }

  /// Schedule multiple alarms untuk semua jadwal hari ini
  Future<void> scheduleTodayAlarms({
    required List<Map<String, dynamic>> schedules,
    bool isTestMode = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel semua alarm yang sudah ada
    await cancelAllAlarms();

    for (final schedule in schedules) {
      final scheduleId = schedule['id'] as int;
      final title = schedule['title'] as String;
      final body = schedule['body'] as String;
      final date = schedule['date'] as DateTime;

      await scheduleMaintenanceAlarm(
        scheduleId: scheduleId,
        title: title,
        body: body,
        scheduledDate: date,
        isTestMode: isTestMode,
      );
    }
  }

  /// Cancel alarm berdasarkan ID
  Future<void> cancelAlarm(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel semua alarm
  Future<void> cancelAllAlarms() async {
    await _notifications.cancelAll();
  }

  /// Get semua pending notifications (untuk debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Test alarm - schedule alarm 1 menit dari sekarang
  Future<void> testAlarm({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final testTime = DateTime.now().add(const Duration(minutes: 1));
    final tzTestTime = tz.TZDateTime.from(testTime, tz.local);

    print('🧪 Scheduling test alarm...');
    print('   Title: $title');
    print('   Body: $body');
    print('   Test time: ${testTime.toString()}');
    print('   Timezone time: ${tzTestTime.toString()}');

    // Android notification details untuk test alarm - Konfigurasi alarm yang kuat
    // Tidak bisa const karena vibrationPattern menggunakan Int64List.fromList()
    final androidDetails = AndroidNotificationDetails(
      'maintenance_channel',
      'Jadwal Perawatan',
      channelDescription: 'Alarm untuk jadwal perawatan tanaman',
      importance: Importance.max, // MAX untuk alarm yang lebih kuat
      priority: Priority.max, // MAX priority
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]), // Pattern getar yang lebih kuat
      fullScreenIntent: true, // Membangunkan layar saat alarm
      category: AndroidNotificationCategory.alarm, // Kategori alarm
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(''), // Style untuk notifikasi besar
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        9999, // ID khusus untuk test
        title,
        body,
        tzTestTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Test alarm scheduled successfully for 1 minute from now');
      
      // Tampilkan pending notifications untuk debugging
      final pending = await getPendingNotifications();
      print('📋 Total pending notifications: ${pending.length}');
      for (final p in pending) {
        print('   - ID: ${p.id}, Title: ${p.title}');
      }
    } catch (e) {
      print('❌ Error scheduling test alarm: $e');
      rethrow;
    }
  }

  /// Show notification langsung (untuk testing)
  Future<void> showNotificationNow({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'maintenance_channel',
      'Jadwal Perawatan',
      channelDescription: 'Notifikasi untuk jadwal perawatan tanaman',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
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

    await _notifications.show(
      8888, // ID khusus untuk immediate notification
      title,
      body,
      notificationDetails,
    );

    print('✅ Immediate notification shown: $title');
  }
}

