import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/no_leading_text_form_field.dart';
import 'package:hydroponics_app/widgets/styled_date_picker_field.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/services/auth_service.dart';

class AddPlantDataScreen extends StatefulWidget{
  const AddPlantDataScreen({super.key});

  @override
  State<AddPlantDataScreen> createState() => _AddPlantDataScreenState();
}

class _AddPlantDataScreenState extends State<AddPlantDataScreen>{
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  String? _plantId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFarmerPlant();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadFarmerPlant() async {
    final userDoc = await AuthService.instance.getCurrentUserDoc();
    final data = userDoc?.data();
    setState(() {
      _plantId = data?['id_tanaman'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          }, 
          icon: const Icon(Icons.arrow_back)
        ),
        title: const Text('Tambah Data Tanaman', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Jumlah bibit:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                ),
              ),
              _gap(10),
              NoLeadingTextFormField(
                controller: _quantityController,
                hintText: 'Masukkan jumlah bibit', 
                inputType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6), // Maksimal 6 digit (999999)
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Silakan masukkan jumlah bibit yang Anda tanam';
                  }
                  final jumlah = int.tryParse(value.trim());
                  if (jumlah == null || jumlah <= 0) {
                    return 'Jumlah bibit harus berupa angka lebih dari 0';
                  }
                  const maxQuantity = 999999;
                  if (jumlah > maxQuantity) {
                    return 'Jumlah bibit melebihi batas maksimum ($maxQuantity)';
                  }
                  return null;
                },
              ),
              _gap(15),
              const Text('Tanggal Tanam:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                ),
              ),
              _gap(10),
              
              StyledDatePickerField(
                controller: _dateController,
                lastDate: DateTime.now(), 
                onDateSelected: (date) {
                  _selectedDate = date;
                },
              ),
              
              _gap(20),
              StyledElevatedButton(
                text: 'Tambah Data', 
                onPressed: _isSubmitting ? null : _handleSubmit,
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
              )
            ]
          ),
        ),
      )
    );
  }

  Widget _gap(double height){
    return SizedBox(height: height,);
  }

  void _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tanggal tanam')),
      );
      return;
    }
    if (_plantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun petani belum memiliki tanaman')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User tidak valid, silakan login ulang')),
      );
      return;
    }

    final jumlah = int.tryParse(_quantityController.text.trim());
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah bibit harus berupa angka lebih dari 0')),
      );
      return;
    }
    const maxQuantity = 999999;
    if (jumlah > maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jumlah bibit melebihi batas maksimum ($maxQuantity)')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('data_tanam').add({
        'id_petani': user.uid,
        'id_tanaman': _plantId,
        'jumlah_tanam': jumlah,
        'tanggal_tanam': Timestamp.fromDate(_selectedDate!),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data tanam berhasil ditambahkan')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambah data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}