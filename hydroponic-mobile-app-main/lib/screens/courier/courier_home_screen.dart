import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/models/plant_model.dart';
import 'package:hydroponics_app/models/plant_quantity_model.dart';
import 'package:hydroponics_app/models/transaction_model.dart';
import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/widgets/delivery_assignment_card.dart';
import 'package:hydroponics_app/widgets/home_app_bar.dart';
import 'package:hydroponics_app/services/auth_service.dart';
import 'package:hydroponics_app/services/shipping_service.dart';

class CourierHomeScreen extends StatefulWidget{
  const CourierHomeScreen({super.key});
  
  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User tidak ditemukan, silakan login ulang')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: HomeAppBar(
          user: UserModel(
            username: user.displayName ?? 'Kurir', 
            role: 'Kurir',
            onNotificationTap: () {
              Navigator.pushNamed(context, '/notification');
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 25, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Daftar Pengiriman',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 25,),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    ShippingService.instance.courierAssignmentsStream(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('Belum ada penugasan pengiriman.');
                  }

                  final shippingDocs = snapshot.data!.docs;

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shippingDocs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final shipDoc = shippingDocs[index];
                      final shipData = shipDoc.data();
                      final transaksiId =
                          (shipData['id_transaksi'] ?? '') as String;

                      return FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('transaksi')
                            .doc(transaksiId)
                            .get(),
                        builder: (context, txSnapshot) {
                          if (txSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 60,
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }

                          if (!txSnapshot.hasData ||
                              !txSnapshot.data!.exists) {
                            return const SizedBox();
                          }

                          final txData = txSnapshot.data!.data()!;
                          final items =
                              (txData['items'] as List<dynamic>? ??
                                  <dynamic>[]);

                          final plantQuantity = items.map((item) {
                            final m = item as Map<String, dynamic>;
                            final plant = PlantModel(
                              plantName:
                                  (m['nama_tanaman'] ?? '') as String,
                              price: (m['harga'] as num?)?.toDouble() ??
                                  0.0,
                            );
                            return PlantQuantityModel(
                              plant: plant,
                              quantity: (m['jumlah'] as int?) ?? 0,
                            );
                          }).toList();

                          final txModel = TransactionModel(
                            id: transaksiId,
                            customerName:
                                (txData['nama_pelanggan'] ?? '') as String,
                            plantQuantity: plantQuantity,
                            address: (txData['alamat'] ?? '') as String,
                            date: '',
                            time: '',
                            isPaid: (txData['is_paid'] ?? false) as bool,
                            isAssigned:
                                (txData['is_assigned'] ?? false) as bool,
                            isHarvest:
                                (txData['is_harvest'] ?? false) as bool,
                            isDeliver:
                                (txData['is_deliver'] ?? false) as bool,
                          );

                          final assignment = DeliveryAssigntmentModel(
                            transaction: txModel,
                            courier: UserModel(
                              username:
                                  user.email ?? 'Kurir', // display only
                              role: 'Kurir',
                              onNotificationTap: () {},
                            ),
                            isDone: (shipData['status_pengiriman'] ??
                                        '') ==
                                    'Selesai',
                          );

                          return DeliveryAssignmentCard(
                            assignment: assignment,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/courier_delivery_detail',
                                arguments: {
                                  'shippingId': shipDoc.id,
                                  'assignment': assignment,
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                    separatorBuilder:
                        (BuildContext context, int index) {
                      return const SizedBox(height: 7);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}