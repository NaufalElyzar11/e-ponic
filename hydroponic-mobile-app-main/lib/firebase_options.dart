import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Konfigurasi Firebase yang diambil dari `android/app/google-services.json`.
///
/// File ini dibuat manual agar Anda tidak perlu menunggu FlutterFire CLI.
/// Jika nanti Anda berhasil menjalankan `flutterfire configure`, silakan
/// ganti file ini dengan file yang dihasilkan otomatis.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk platform ini.',
        );
    }
  }

  /// Opsi untuk Android – nilai diambil dari `google-services.json`.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC11HNWU0ZO1QNprj7Rt_AvdJ-nvoDCIwY',
    appId: '1:167331292376:android:cb10a5ee5f7afba38c63ad',
    messagingSenderId: '167331292376',
    projectId: 'e-ponic',
    storageBucket: 'e-ponic.firebasestorage.app',
  );
}

