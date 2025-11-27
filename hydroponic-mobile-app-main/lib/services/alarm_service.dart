import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola alarm/notifikasi jadwal petani menggunakan package `alarm`
/// agar berfungsi seperti alarm jam native (berdering terus & fullscreen).
class AlarmService {
  AlarmService._();

  static final AlarmService instance = AlarmService._();
  bool _initialized = false;

  /// Inisialisasi service alarm
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('AlarmService already initialized');
      return;
    }

    debugPrint('Initializing AlarmService (native alarm)...');
    await Alarm.init();
    
    _initialized = true;
    debugPrint('AlarmService initialization complete');
  }

  /// Schedule alarm untuk jadwal petani
  /// 
  /// [scheduleId] - ID unik untuk alarm
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
    if (!_initialized) await initialize();

    // Pastikan alarm lama dengan ID sama dihapus
    await Alarm.stop(scheduleId);

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

      // Jika waktu alarm sudah lewat hari ini, skip atau schedule untuk besok?
      // Requirement: Jadwal perawatan hari ini. Jika sudah lewat jam 9, mungkin tetap schedule 1 menit lagi?
      // Atau skip saja.
      if (alarmTime.isBefore(DateTime.now())) {
        debugPrint('Alarm time has passed, skipping: $title');
        return;
      }
    }

    // Konfigurasi Alarm
    final alarmSettings = AlarmSettings(
      id: scheduleId,
      dateTime: alarmTime,
      assetAudioPath: 'assets/audio/alarm.mp3', // Pastikan file ini ada
      loopAudio: true, // Berdering terus sampai dimatikan
      vibrate: true,
      fadeDuration: 3.0,
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop', // Tombol stop di notifikasi
      ),
      warningNotificationOnKill: true, // Notifikasi tetap muncul jika app dimatikan
      androidFullScreenIntent: true, // Tampil fullscreen di Android
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('✅ Alarm scheduled successfully: $title at ${alarmTime.toString()}');
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
      // Jika gagal (misal asset audio tidak ketemu), coba fallback atau log error
    }
  }

  /// Schedule multiple alarms untuk semua jadwal hari ini
  /// 
  /// [spreadTime] - Jika true, alarm akan di-spread dengan interval 1 menit
  /// untuk menghindari semua alarm berbunyi bersamaan
  Future<void> scheduleTodayAlarms({
    required List<Map<String, dynamic>> schedules,
    bool isTestMode = false,
    bool spreadTime = false, // Default false: semua alarm jam 9:00
  }) async {
    if (!_initialized) await initialize();

    // Hentikan semua alarm yang ada agar tidak duplikat
    // (Opsional, tergantung logika yang diinginkan. Alarm.stopAll() akan menghapus semua)
    // await Alarm.stopAll(); 

    int offsetMinutes = 0; // Untuk spread time
    
    for (final schedule in schedules) {
      final scheduleId = schedule['id'] as int; // Pastikan ID unique integer
      final title = schedule['title'] as String;
      final body = schedule['body'] as String;
      DateTime date = schedule['date'] as DateTime;
      
      // Jika spreadTime aktif, tambahkan offset menit
      if (spreadTime && !isTestMode) {
        date = date.add(Duration(minutes: offsetMinutes));
        offsetMinutes++; // Setiap alarm berikutnya +1 menit
      }

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
    await Alarm.stop(id);
  }

  /// Cancel semua alarm
  Future<void> cancelAllAlarms() async {
    await Alarm.stopAll();
  }

  /// Test alarm - schedule alarm 1 menit dari sekarang
  Future<void> testAlarm({
    required String title,
    required String body,
  }) async {
    await scheduleMaintenanceAlarm(
      scheduleId: 9999,
      title: title,
      body: body,
      scheduledDate: DateTime.now(), // Date diabaikan jika isTestMode=true
      isTestMode: true,
    );
  }
}
