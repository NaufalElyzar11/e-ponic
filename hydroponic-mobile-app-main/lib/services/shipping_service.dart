import 'package:cloud_firestore/cloud_firestore.dart';

/// Service untuk mengelola penugasan kurir & status pengiriman.
class ShippingService {
  ShippingService._();

  static final ShippingService instance = ShippingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Menugaskan kurir untuk sebuah transaksi.
  ///
  /// - Menambahkan dokumen ke koleksi `pengiriman`
  /// - Mengatur flag `is_assigned` pada dokumen `transaksi`
  Future<void> assignCourier({
    required String transactionId,
    required String courierId,
    required DateTime tanggalPengiriman,
  }) async {
    final batch = _db.batch();

    final pengirimanRef = _db.collection('pengiriman').doc();
    batch.set(pengirimanRef, {
      'id_transaksi': transactionId,
      'id_kurir': courierId,
      'tanggal_pengiriman': Timestamp.fromDate(tanggalPengiriman),
      'status_pengiriman': 'Belum Dikirim',
      'catatan_pengiriman': '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    final transaksiRef = _db.collection('transaksi').doc(transactionId);
    batch.update(transaksiRef, {'is_assigned': true});

    await batch.commit();
  }

  /// Update status pengiriman oleh kurir (misalnya: Dalam Perjalanan, Selesai).
  ///
  /// Sesuai requirement: hanya menyimpan waktu & catatan.
  Future<void> updateDeliveryStatus({
    required String shippingId,
    required String statusPengiriman,
    required String catatan,
  }) async {
    final pengirimanRef = _db.collection('pengiriman').doc(shippingId);
    await pengirimanRef.update({
      'status_pengiriman': statusPengiriman,
      'catatan_pengiriman': catatan,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Jika status selesai, tandai transaksi sebagai sudah dikirim.
    if (statusPengiriman.toLowerCase().contains('selesai') ||
        statusPengiriman.toLowerCase().contains('terkirim')) {
      final snapshot = await pengirimanRef.get();
      final data = snapshot.data();
      final transaksiId = data?['id_transaksi'] as String?;
      if (transaksiId != null) {
        await _db
            .collection('transaksi')
            .doc(transaksiId)
            .update({'is_deliver': true});
      }
    }
  }

  /// Mendapatkan stream daftar pengiriman untuk kurir tertentu.
  Stream<QuerySnapshot<Map<String, dynamic>>> courierAssignmentsStream(
      String courierId) {
    return _db
        .collection('pengiriman')
        .where('id_kurir', isEqualTo: courierId)
        .orderBy('tanggal_pengiriman', descending: true)
        .snapshots();
  }

  /// Mendapatkan stream semua pengiriman untuk staf logistik (monitoring).
  Stream<QuerySnapshot<Map<String, dynamic>>> allShipmentsStream() {
    return _db
        .collection('pengiriman')
        .orderBy('created_at', descending: true)
        .snapshots();
  }
}


