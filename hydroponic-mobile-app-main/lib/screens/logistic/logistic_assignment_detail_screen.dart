import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/models/plant_model.dart';
import 'package:hydroponics_app/models/plant_quantity_model.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/logistic_delivery_detail_card.dart';
import 'package:hydroponics_app/widgets/styled_dropdown_button_form_field.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/services/shipping_service.dart';

class LogisticAssignmentDetailScreen extends StatefulWidget {
  const LogisticAssignmentDetailScreen({super.key});

  @override
  State<LogisticAssignmentDetailScreen> createState() => _LogisticAssignmentDetailScreenState();
}

class _LogisticAssignmentDetailScreenState extends State<LogisticAssignmentDetailScreen> {
  String? _selectedCourierId;

  @override
  Widget build(BuildContext context) {
    final transactionId =
        ModalRoute.of(context)?.settings.arguments as String?;

    if (transactionId == null) {
      return const Scaffold(
        body: Center(child: Text('Transaksi tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Detail Penugasan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildAssignmentCard(transactionId),
              const SizedBox(height: 20),
              _buildAssignForm(transactionId),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildAssignmentCard(String transactionId) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('transaksi')
          .doc(transactionId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Data transaksi tidak ditemukan.');
        }

        final data = snapshot.data!.data()!;
        final items =
            (data['items'] as List<dynamic>? ?? <dynamic>[]);

        final plantQuantity = items.map((item) {
          final m = item as Map<String, dynamic>;
          final plant = PlantModel(
            plantName: (m['nama_tanaman'] ?? '') as String,
            price: (m['harga'] as num?)?.toDouble() ?? 0.0,
          );
          return PlantQuantityModel(
            plant: plant,
            quantity: (m['jumlah'] as int?) ?? 0,
          );
        }).toList();

        // --- PERBAIKAN DI SINI ---
        final dt = (data['tanggal'] as Timestamp?)?.toDate();
        final createdAt = (data['created_at'] as Timestamp?)?.toDate(); // Ambil created_at

        final dateStr =
            dt != null ? DateFormat('dd MMM yyyy').format(dt) : '';
        
        // Gunakan createdAt untuk jam, jika ada.
        final timeStr = createdAt != null 
            ? DateFormat('HH:mm').format(createdAt) 
            : (dt != null ? DateFormat('HH:mm').format(dt) : '');
        // -------------------------
        
        final tx = TransactionModel(
          id: transactionId,
          customerName: (data['nama_pelanggan'] ?? '') as String,
          plantQuantity: plantQuantity,
          address: (data['alamat'] ?? '') as String,
          date: dateStr,
          time: timeStr,
          isPaid: (data['is_paid'] ?? false) as bool,
          isAssigned: (data['is_assigned'] ?? false) as bool,
          isHarvest: (data['is_harvest'] ?? false) as bool,
          isDeliver: (data['is_deliver'] ?? false) as bool,
        );

        final assignment = DeliveryAssigntmentModel(
          transaction: tx,
          courier: UserModel(
            username: '-',
            role: 'Kurir',
            onNotificationTap: () {},
          ),
        );

        return LogisticDeliveryDetailCard(assignment: assignment);
      },
    );
  }

  Widget _buildAssignForm(String transactionId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Pilih Kurir',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pengguna')
              .where('posisi', isEqualTo: 'Kurir')
              .orderBy('nama_pengguna')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                'Gagal memuat daftar kurir: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Text(
                'Belum ada akun kurir di sistem. Tambahkan akun dengan posisi "Kurir" di halaman Admin.',
                style: TextStyle(fontSize: 12),
              );
            }

            return StyledDropdownButtonFormField<String>(
              hintText: 'Pilih Kurir',
              prefixIcon: Icons.person,
              value: _selectedCourierId,
              items: docs
                  .map(
                    (doc) => DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(
                        doc.data()['nama_pengguna'] ?? 'Tanpa Nama',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCourierId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Silakan pilih kurir';
                }
                return null;
              },
            );
          },
        ),
        const SizedBox(height: 20),
        StyledElevatedButton(
          text: 'Tugaskan Kurir',
          onPressed: () async {
            if (_selectedCourierId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Silakan pilih kurir')),
              );
              return;
            }

            // Tanggal pengiriman otomatis: maksimal esok hari pukul 23:59
            final now = DateTime.now();
            final autoDate = DateTime(
              now.year,
              now.month,
              now.day + 1,
              23,
              59,
            );

            await ShippingService.instance.assignCourier(
              transactionId: transactionId,
              courierId: _selectedCourierId!,
              tanggalPengiriman: autoDate,
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kurir berhasil ditugaskan')),
            );
            Navigator.pop(context);
          },
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
        ),
      ],
    );
  }
  
}