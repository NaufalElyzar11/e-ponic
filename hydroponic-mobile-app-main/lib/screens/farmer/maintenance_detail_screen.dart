import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/models/plant_maintenance_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/maintenance_detail_card.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  const MaintenanceDetailScreen({super.key});
  
  @override
  State<MaintenanceDetailScreen> createState() => _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  late PlantMaintenanceModel maintenance;
  String? _idPetani;
  String? _idTanaman;
  String? _field;
  DateTime? _rawDate;
  bool _isDone = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _idPetani = args?['id_petani'] as String?;
      _idTanaman = args?['id_tanaman'] as String?;
      _field = args?['field'] as String?;
      _rawDate = args?['tanggal'] as DateTime?;
      _isDone = (args?['is_done'] ?? false) as bool;
      final title = (args?['title'] ??
              'Perawatan Tanaman') as String;
      final desc = (args?['description'] ??
              '') as String;

      final displayDate = _rawDate != null
          ? DateFormat('dd MMMM yyyy').format(_rawDate!)
          : '';
      final displayTime =
          _rawDate != null ? DateFormat('HH:mm').format(_rawDate!) : '';

      maintenance = PlantMaintenanceModel(
        maintenanceName: title,
        description: desc,
        date: displayDate,
        time: displayTime,
        onTap: () {},
        isDone: _isDone,
      );

      _initialized = true;
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
          'Detail Perawatan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: MaintenanceDetailCard(
            maintenance: maintenance,
            onMarkDone: _toggleDone,
          ),
        ),
      )
    );
  }

  Future<void> _toggleDone() async {
    if (_idPetani == null ||
        _idTanaman == null ||
        _field == null ||
        _rawDate == null) {
      Navigator.pop(context);
      return;
    }

    final keyDate =
        DateFormat('yyyy-MM-dd').format(_rawDate!.toLocal());
    final docId = '${_idPetani}_${_idTanaman}_${_field}_$keyDate';

    final ref = FirebaseFirestore.instance
        .collection('jadwal_perawatan')
        .doc(docId);

    final snap = await ref.get();
    final newStatus = !_isDone;

    if (snap.exists) {
      await ref.update({
        'is_done': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'id_petani': _idPetani,
        'id_tanaman': _idTanaman,
        'field': _field,
        'tanggal': Timestamp.fromDate(_rawDate!),
        'is_done': newStatus,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}