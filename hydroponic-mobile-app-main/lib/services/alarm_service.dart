// ignore_for_file: avoid_print

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

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

  /// Schedule alarm tunggal (Helper function)
  Future<void> _setAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: 'assets/audio/alarm.mp3', // file audio
      loopAudio: true,
      vibrate: true,
      fadeDuration: 3.0,
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Saya Mengerti',
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('✅ Alarm set: $title at $dateTime');
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
    }
  }

  Future<void> scheduleDailySummaryAlarm({
    required String body,
    bool isTestMode = false,
  }) async {
    if (!_initialized) await initialize();

    // ID Tetap (misal 1) agar setiap hari alarmnya di-update/overwrite, 
    // sehingga tidak menumpuk banyak alarm.
    const int dailyAlarmId = 1;

    // Stop alarm sebelumnya (jika ada) untuk update konten baru
    await Alarm.stop(dailyAlarmId);

    DateTime alarmTime;

    if (isTestMode) {
      // Test: Bunyi dalam 10 detik
      alarmTime = DateTime.now().add(const Duration(seconds: 10));
    } else {
      final now = DateTime.now();
      // Set ke Jam 09:00:00 hari ini
      alarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        9, // Jam
        0, // Menit
      );

      // Jika jam 09:00 sudah lewat hari ini, kita tidak perlu membunyikan alarm lagi
      if (alarmTime.isBefore(now)) {
        debugPrint('⏰ Waktu alarm harian (09:00) sudah lewat untuk hari ini.');
        return;
      }
    }

    await _setAlarm(
      id: dailyAlarmId,
      title: 'Jadwal Perawatan Hari Ini',
      body: body,
      dateTime: alarmTime,
    );
  }

  /// Cancel alarm berdasarkan ID
  Future<void> cancelAlarm(int id) async {
    await Alarm.stop(id);
  }

  /// Cancel semua alarm
  Future<void> cancelAllAlarms() async {
    await Alarm.stopAll();
    print("⏰ Semua alarm berhasil dibatalkan.");
  }
}