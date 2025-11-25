import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hydroponics_app/firebase_options.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Login menggunakan email & password.
  /// Hanya mengizinkan user yang punya dokumen di koleksi `pengguna`.
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _firestore.collection('pengguna').doc(uid).get();
    if (!doc.exists) {
      // Jika akun Firebase ada tapi tidak terdaftar sebagai pengguna perusahaan
      await _auth.signOut();
      throw Exception('Akun tidak terdaftar sebagai karyawan.');
    }

    return credential.user;
  }

  /// Membuat akun karyawan baru.
  /// Hanya dipanggil dari Admin.
  Future<User?> createEmployeeAccount({
    required String email,
    required String password,
    required String namaPengguna,
    required String posisi,
    String? idTanaman,
  }) async {
    // Gunakan FirebaseApp sekunder agar admin tetap login di app utama.
    final FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'ep-employee-admin',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final FirebaseAuth secondaryAuth =
        FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      await _firestore.collection('pengguna').doc(uid).set({
        'nama_pengguna': namaPengguna,
        'email': email,
        'posisi': posisi,
        'id_tanaman': idTanaman,
        'created_at': FieldValue.serverTimestamp(),
      });

      return credential.user;
    } finally {
      // Tutup app sekunder agar tidak menumpuk.
      await secondaryApp.delete();
    }
  }

  /// Mendapatkan dokumen pengguna saat ini dari koleksi `pengguna`.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getCurrentUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('pengguna').doc(user.uid).get();
    if (!doc.exists) return null;
    return doc;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Mengupdate data akun karyawan di koleksi `pengguna`.
  /// Hanya dipanggil dari Admin.
  Future<void> updateAccount({
    required String userId,
    required String namaPengguna,
    required String posisi,
    String? idTanaman,
  }) async {
    final Map<String, dynamic> updateData = {
      'nama_pengguna': namaPengguna,
      'posisi': posisi,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (idTanaman != null) {
      updateData['id_tanaman'] = idTanaman;
    } else if (posisi != 'Petani') {
      // Jika bukan Petani, hapus id_tanaman
      updateData['id_tanaman'] = FieldValue.delete();
    }

    await _firestore.collection('pengguna').doc(userId).update(updateData);
  }
}


