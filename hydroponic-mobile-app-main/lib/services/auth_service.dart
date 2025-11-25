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

  /// Login menggunakan email atau username & password.
  /// Jika input adalah username, akan mencari email berdasarkan nama_pengguna di Firestore.
  Future<User?> signInWithEmailOrUsername({
    required String emailOrUsername,
    required String password,
  }) async {
    String email = emailOrUsername.trim();
    
    // Cek apakah input adalah email (mengandung @) atau username
    if (!email.contains('@')) {
      // Jika tidak mengandung @, anggap sebagai username
      // Cari user berdasarkan nama_pengguna di Firestore
      final userQuery = await _firestore
          .collection('pengguna')
          .where('nama_pengguna', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        throw Exception('Username tidak ditemukan.');
      }
      
      // Ambil email dari dokumen pengguna
      final userData = userQuery.docs.first.data();
      email = (userData['email'] ?? '') as String;
      
      if (email.isEmpty) {
        throw Exception('Email tidak ditemukan untuk username ini.');
      }
    }
    
    // Login menggunakan email yang ditemukan
    return signInWithEmail(email: email, password: password);
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


