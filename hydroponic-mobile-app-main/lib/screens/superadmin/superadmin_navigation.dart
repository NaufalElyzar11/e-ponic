import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydroponics_app/screens/admin/admin_home_screen.dart';
import 'package:hydroponics_app/screens/admin/admin_status_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_home_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_history_screen.dart';
import 'package:hydroponics_app/screens/farmer/farmer_harvest_screen.dart';
import 'package:hydroponics_app/screens/logistic/logistic_home_screen.dart';
import 'package:hydroponics_app/screens/logistic/logistic_delivery_status_screen.dart';
import 'package:hydroponics_app/screens/courier/courier_home_screen.dart';
import 'package:hydroponics_app/screens/profile_screen.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class SuperAdminNavigation extends StatefulWidget {
  const SuperAdminNavigation({super.key});

  @override
  State<SuperAdminNavigation> createState() => _SuperAdminNavigationState();
}

class _SuperAdminNavigationState extends State<SuperAdminNavigation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<int> _selectedBottomIndices = [0, 0, 0, 0]; // Satu untuk setiap role

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild saat tab berubah
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildRoleView(int roleIndex) {
    final bottomIndex = _selectedBottomIndices[roleIndex];

    switch (roleIndex) {
      case 0: // Admin
        return IndexedStack(
          index: bottomIndex,
          children: const [
            AdminHomeScreen(),
            AdminStatusScreen(),
            ProfileScreen(),
          ],
        );
      case 1: // Petani
        return IndexedStack(
          index: bottomIndex,
          children: const [
            FarmerHomeScreen(),
            FarmerHistoryScreen(),
            FarmerHarvestScreen(),
            ProfileScreen(),
          ],
        );
      case 2: // Staf Logistik
        return IndexedStack(
          index: bottomIndex,
          children: const [
            LogisticHomeScreen(),
            LogisticDeliveryStatusScreen(),
            ProfileScreen(),
          ],
        );
      case 3: // Kurir
        return IndexedStack(
          index: bottomIndex,
          children: const [
            CourierHomeScreen(),
            ProfileScreen(),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  List<BottomNavigationBarItem> _getBottomNavItems(int roleIndex) {
    switch (roleIndex) {
      case 0: // Admin
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Cek Status'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      case 1: // Petani
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'Riwayat Tanam'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list), label: 'Tugas Panen'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      case 2: // Staf Logistik
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Status Pengiriman'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      case 3: // Kurir
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      default:
        return [];
    }
  }

  int _getMaxBottomIndex(int roleIndex) {
    switch (roleIndex) {
      case 0: // Admin
        return 2;
      case 1: // Petani
        return 3;
      case 2: // Staf Logistik
        return 2;
      case 3: // Kurir
        return 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoleIndex = _tabController.index;
    final currentBottomIndex = _selectedBottomIndices[currentRoleIndex];
    final maxBottomIndex = _getMaxBottomIndex(currentRoleIndex);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color.fromARGB(255, 231, 255, 237),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Super Admin',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(
                icon: Icon(Icons.admin_panel_settings),
                text: 'Admin',
              ),
              Tab(
                icon: Icon(Icons.eco),
                text: 'Petani',
              ),
              Tab(
                icon: Icon(Icons.local_shipping),
                text: 'Logistik',
              ),
              Tab(
                icon: Icon(Icons.delivery_dining),
                text: 'Kurir',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRoleView(0), // Admin
            _buildRoleView(1), // Petani
            _buildRoleView(2), // Staf Logistik
            _buildRoleView(3), // Kurir
          ],
        ),
        bottomNavigationBar: maxBottomIndex > 0
            ? BottomNavigationBar(
                items: _getBottomNavItems(currentRoleIndex),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: Colors.grey,
                backgroundColor: const Color.fromARGB(255, 231, 255, 237),
                currentIndex: currentBottomIndex > maxBottomIndex
                    ? 0
                    : currentBottomIndex,
                onTap: (index) {
                  setState(() {
                    _selectedBottomIndices[currentRoleIndex] = index;
                  });
                },
              )
            : null,
      ),
    );
  }
}

