import 'package:flutter/material.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/rounded_border_button.dart';

class SelectRoleScreen extends StatelessWidget{
  const SelectRoleScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pilih Posisi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            spacing: 10,
            children: [
              RoundedBorderButton(
                text: 'Halaman Petani', 
                onPressed: () {
                  Navigator.pushNamed(context, '/farmer_navigation');
                },
                textColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
              RoundedBorderButton(
                text: 'Halaman Kurir', 
                onPressed: () {
                  Navigator.pushNamed(context, '/courier_navigation');
                },
                textColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
              RoundedBorderButton(
                text: 'Halaman Staf Logistik', 
                onPressed: () {
                  Navigator.pushNamed(context, '/logistic_navigation');
                },
                textColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
              RoundedBorderButton(
                text: 'Halaman Admin', 
                onPressed: () {
                  Navigator.pushNamed(context, '/admin_navigation');
                },
                textColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  
}