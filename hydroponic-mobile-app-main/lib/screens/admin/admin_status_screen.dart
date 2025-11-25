import 'package:flutter/material.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/trailing_icon_button.dart';

class AdminStatusScreen extends StatefulWidget{
  const AdminStatusScreen({super.key});

  @override
  State<AdminStatusScreen> createState() => _AdminStatusScreenState();
}

class _AdminStatusScreenState extends State<AdminStatusScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cek Status', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 25,
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 1, 68, 33),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(15),
          child: Column(
            spacing: 15,
            children: [
              TrailingIconButton(
                text: 'Status Tanaman', 
                trailingIcon: Icons.grass_sharp, 
                onPressed: () {
                  Navigator.pushNamed(context, '/plant_status');
                },
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
              TrailingIconButton(
                text: 'Status Transaksi', 
                trailingIcon: Icons.shopping_cart, 
                onPressed: () {
                  Navigator.pushNamed(context, '/transaction_status');
                },
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}