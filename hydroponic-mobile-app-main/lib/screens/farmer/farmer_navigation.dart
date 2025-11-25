import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydroponics_app/screens/farmer/farmer_harvest_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_history_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_home_screen.dart';
import 'package:hydroponics_app/screens/profile_screen.dart';

class FarmerNavigation extends StatefulWidget{
  const FarmerNavigation({super.key});

  @override
  State<FarmerNavigation> createState() => _FarmerNavigationState();
}

class _FarmerNavigationState extends State<FarmerNavigation> {
  int _selectedIndex = 0;

  // daftar halaman yang akan ditampilkan
  final List<Widget> _halaman = [
    const FarmerHomeScreen(),
    const FarmerHistoryScreen(),
    const FarmerHarvestScreen(),
    const ProfileScreen(),
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
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat Tanam'),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tugas Panen'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],

          type: BottomNavigationBarType.fixed, // Memaksa agar tetap tipe fixed

          selectedItemColor: Color.fromARGB(255, 1, 68, 33), // Warna item aktif
          unselectedItemColor: Colors.grey, // Warna item tidak aktif
          backgroundColor: const Color.fromARGB(255, 231, 255, 237),

          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      )
    );
  }
}