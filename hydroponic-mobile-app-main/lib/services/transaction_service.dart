import 'package:cloud_firestore/cloud_firestore.dart';

/// Service untuk mengelola transaksi, pelanggan, dan detail_transaksi.
class TransactionService {
  TransactionService._();

  static final TransactionService instance = TransactionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Membuat atau mengambil pelanggan berdasarkan nama + alamat.
  Future<String> _createOrGetCustomer({
    required String nama,
    required String alamat,
    String? noHp,
    String? email,
  }) async {
    final existing = await _db
        .collection('pelanggan')
        .where('nama_pelanggan', isEqualTo: nama)
        .where('alamat', isEqualTo: alamat)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Update email jika ada
      if (email != null && email.isNotEmpty) {
        await _db.collection('pelanggan').doc(existing.docs.first.id).update({
          'email': email,
        });
      }
      return existing.docs.first.id;
    }

    final doc = await _db.collection('pelanggan').add({
      'nama_pelanggan': nama,
      'alamat': alamat,
      'no_hp': noHp ?? '',
      'email': email ?? '',
      'created_at': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Mengambil data tanaman dan membangun map nama_tanaman -> dokumen.
  Future<Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getPlantsByName() async {
    final snapshot = await _db.collection('tanaman').get();
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> result = {};
    for (final doc in snapshot.docs) {
      final name = (doc.data()['nama_tanaman'] ?? '') as String;
      if (name.isNotEmpty) {
        result[name.toLowerCase()] = doc;
      }
    }
    return result;
  }

  /// Membuat transaksi baru beserta detail_transaksi.
  ///
  /// [quantities] berisi pasangan nama sayur -> jumlah (misal: {'Selada': 10}).
  Future<void> createTransactionWithDetails({
    required String namaPelanggan,
    required String alamat,
    String? noHp,
    String? email,
    required DateTime tanggal,
    required bool isPaid,
    required Map<String, int> quantities,
  }) async {
    final pelangganId = await _createOrGetCustomer(
      nama: namaPelanggan,
      alamat: alamat,
      noHp: noHp,
      email: email,
    );

    final plantsByName = await _getPlantsByName();

    final List<Map<String, dynamic>> items = [];
    double totalHarga = 0;

    quantities.forEach((name, qty) {
      if (qty <= 0) return;
      final plantDoc = plantsByName[name.toLowerCase()];
      if (plantDoc == null) return;

      final data = plantDoc.data();
      final harga = (data['harga'] as num?)?.toDouble() ?? 0.0;
      final subtotal = harga * qty;
      totalHarga += subtotal;

      items.add({
        'id_tanaman': plantDoc.id,
        'nama_tanaman': data['nama_tanaman'],
        'jumlah': qty,
        'harga': harga,
        'total_bayar': subtotal,
      });
    });

    if (items.isEmpty) {
      throw Exception('Minimal satu jenis sayur harus memiliki jumlah > 0');
    }

    final transaksiRef = await _db.collection('transaksi').add({
      'id_pelanggan': pelangganId,
      'nama_pelanggan': namaPelanggan,
      'alamat': alamat,
      'email': email ?? '',
      'tanggal': Timestamp.fromDate(tanggal),
      'is_paid': isPaid,
      'is_assigned': false,
      'is_harvest': false,
      'is_deliver': false,
      'items': items,
      'total_harga': totalHarga,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'harvested_at': FieldValue.serverTimestamp(),
      'delivered_at': FieldValue.serverTimestamp(),
    });

    final batch = _db.batch();
    for (final item in items) {
      final detailRef = _db.collection('detail_transaksi').doc();
      batch.set(detailRef, {
        'id_transaksi': transaksiRef.id,
        'id_tanaman': item['id_tanaman'],
        'jumlah': item['jumlah'],
        'total_bayar': item['total_bayar'],
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updatePaymentStatus({
    required String transactionId,
    required bool isPaid,
  }) {
    return _db
        .collection('transaksi')
        .doc(transactionId)
        .update({'is_paid': isPaid});
  }

  /// Mengupdate transaksi yang sudah ada beserta detail_transaksi.
  Future<void> updateTransactionWithDetails({
    required String transactionId,
    required String namaPelanggan,
    required String alamat,
    String? noHp,
    String? email,
    required DateTime tanggal,
    required bool isPaid,
    required Map<String, int> quantities,
  }) async {
    final pelangganId = await _createOrGetCustomer(
      nama: namaPelanggan,
      alamat: alamat,
      noHp: noHp,
      email: email,
    );

    final plantsByName = await _getPlantsByName();

    final List<Map<String, dynamic>> items = [];
    double totalHarga = 0;

    quantities.forEach((name, qty) {
      if (qty <= 0) return;
      final plantDoc = plantsByName[name.toLowerCase()];
      if (plantDoc == null) return;

      final data = plantDoc.data();
      final harga = (data['harga'] as num?)?.toDouble() ?? 0.0;
      final subtotal = harga * qty;
      totalHarga += subtotal;

      items.add({
        'id_tanaman': plantDoc.id,
        'nama_tanaman': data['nama_tanaman'],
        'jumlah': qty,
        'harga': harga,
        'total_bayar': subtotal,
      });
    });

    if (items.isEmpty) {
      throw Exception('Minimal satu jenis sayur harus memiliki jumlah > 0');
    }

    // Update transaksi
    await _db.collection('transaksi').doc(transactionId).update({
      'id_pelanggan': pelangganId,
      'nama_pelanggan': namaPelanggan,
      'alamat': alamat,
      'email': email ?? '',
      'tanggal': Timestamp.fromDate(tanggal),
      'is_paid': isPaid,
      'items': items,
      'total_harga': totalHarga,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Hapus detail_transaksi lama dan buat yang baru
    final batch = _db.batch();

    // Hapus detail lama
    final detailSnapshot = await _db
        .collection('detail_transaksi')
        .where('id_transaksi', isEqualTo: transactionId)
        .get();

    for (final doc in detailSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Tambahkan detail baru
    for (final item in items) {
      final detailRef = _db.collection('detail_transaksi').doc();
      batch.set(detailRef, {
        'id_transaksi': transactionId,
        'id_tanaman': item['id_tanaman'],
        'jumlah': item['jumlah'],
        'total_bayar': item['total_bayar'],
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteTransactionWithDetails(String transactionId) async {
    final batch = _db.batch();

    final detailSnapshot = await _db
        .collection('detail_transaksi')
        .where('id_transaksi', isEqualTo: transactionId)
        .get();

    for (final doc in detailSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_db.collection('transaksi').doc(transactionId));

    await batch.commit();
  }
}


