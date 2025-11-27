import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydroponics_app/screens/farmer/farmer_harvest_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_history_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_home_screen.dart';
import 'package:hydroponics_app/screens/profile_screen.dart';
import 'package:hydroponics_app/services/notification_service.dart'; // IMPORT PENTING

class FarmerNavigation extends StatefulWidget{
  const FarmerNavigation({super.key});

  @override
  State<FarmerNavigation> createState() => _FarmerNavigationState();
}

class _FarmerNavigationState extends State<FarmerNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _halaman = [
    const FarmerHomeScreen(),
    const FarmerHistoryScreen(),
    const FarmerHarvestScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 1. Inisialisasi Notifikasi di level Navigasi agar aktif di semua tab
    NotificationService.instance.initialize().then((_) {
      NotificationService.instance.startListening();
    });
  }

  @override
  void dispose() {
    // 2. Matikan notifikasi saat user logout/keluar
    NotificationService.instance.stopListening();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
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
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color.fromARGB(255, 1, 68, 33),
          unselectedItemColor: Colors.grey,
          backgroundColor: const Color.fromARGB(255, 231, 255, 237),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      )
    );
  }
}