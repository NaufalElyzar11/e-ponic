import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydroponics_app/screens/logistic/logistic_delivery_status_screen.dart';
import 'package:hydroponics_app/screens/logistic/logistic_home_screen.dart';
import 'package:hydroponics_app/screens/profile_screen.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class LogisticNavigation extends StatefulWidget {
  const LogisticNavigation({super.key});

  @override
  State<LogisticNavigation> createState() => _StateLogisticNavigation();
}

class _StateLogisticNavigation extends State<LogisticNavigation> {
  int _selectedIndex = 0;

  // daftar halaman yang akan ditampilkan
  final List<Widget> _halaman = [
    const LogisticHomeScreen(),
    const LogisticDeliveryStatusScreen(),
    const ProfileScreen()
  ];

  // fungsi untuk mengubah index halaman saat item diklik
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // Warna Status Bar (atas)
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        
        // Warna Navigasi (bawah)
        systemNavigationBarColor: Color.fromARGB(255, 231, 255, 237),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _halaman,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Status Pengiriman'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],

          type: BottomNavigationBarType.fixed, // Memaksa agar tetap tipe fixed

          selectedItemColor: AppColors.primary, // Warna item aktif
          unselectedItemColor: Colors.grey, // Warna item tidak aktif
          backgroundColor: const Color.fromARGB(255, 231, 255, 237),

          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      )
    );
  }
}