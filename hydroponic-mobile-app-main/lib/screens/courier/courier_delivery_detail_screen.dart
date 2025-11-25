import 'package:flutter/material.dart';

import 'package:hydroponics_app/models/delivery_assigntment_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/delivery_detail_card.dart';

class CourierDeliveryDetailScreen extends StatefulWidget{
  const CourierDeliveryDetailScreen({super.key});

  @override
  State<CourierDeliveryDetailScreen> createState() => _StateCourierDeliveryDetailScreen();
}

class _StateCourierDeliveryDetailScreen extends State<CourierDeliveryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String shippingId = args?['shippingId'] as String;
    final DeliveryAssigntmentModel assignment =
        args?['assignment'] as DeliveryAssigntmentModel;

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
          'Detail Pengiriman',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: DeliveryDetailCard(
            assignment: assignment,
            shippingId: shippingId,
          ),
        ),
      )
    );
  }
  
}