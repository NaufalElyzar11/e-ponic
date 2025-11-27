import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/no_leading_text_form_field.dart';
import 'package:hydroponics_app/widgets/styled_date_picker_field.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class EditHarvestDataScreen extends StatefulWidget {
  final String documentId;
  final int currentJumlah;
  final DateTime currentTanggal;

  const EditHarvestDataScreen({
    super.key,
    required this.documentId,
    required this.currentJumlah,
    required this.currentTanggal,
  });

  @override
  State<EditHarvestDataScreen> createState() => _EditHarvestDataScreenState();
}

class _EditHarvestDataScreenState extends State<EditHarvestDataScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _loadData() {
    _quantityController.text = widget.currentJumlah.toString();
    _selectedDate = widget.currentTanggal;
    _dateController.text = DateFormat('dd MMMM yyyy').format(widget.currentTanggal);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Edit Data Panen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              const Text(
                'Jumlah panen:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _gap(10),
              NoLeadingTextFormField(
                controller: _quantityController,
                hintText: 'Masukkan jumlah panen',
                inputType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6), // Maksimal 6 digit (999999)
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Silakan masukkan jumlah panen';
                  }
                  final jumlah = int.tryParse(value.trim());
                  if (jumlah == null || jumlah <= 0) {
                    return 'Jumlah panen harus berupa angka lebih dari 0';
                  }
                  const maxQuantity = 999999;
                  if (jumlah > maxQuantity) {
                    return 'Jumlah panen melebihi batas maksimum ($maxQuantity)';
                  }
                  return null;
                },
              ),
              _gap(15),
              const Text(
                'Tanggal Panen:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _gap(10),
              StyledDatePickerField(
                controller: _dateController,
                onDateSelected: (date) {
                  _selectedDate = date;
                },
              ),
              _gap(20),
              StyledElevatedButton(
                text: _isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan',
                onPressed: _isSubmitting ? null : _handleSubmit,
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gap(double height) {
    return SizedBox(height: height);
  }

  void _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tanggal panen')),
      );
      return;
    }

    final jumlah = int.tryParse(_quantityController.text.trim());
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah panen harus berupa angka lebih dari 0')),
      );
      return;
    }
    const maxQuantity = 999999;
    if (jumlah > maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jumlah panen melebihi batas maksimum ($maxQuantity)')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('data_panen')
          .doc(widget.documentId)
          .update({
        'jumlah_panen': jumlah,
        'tanggal_panen': Timestamp.fromDate(_selectedDate!),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data panen berhasil diperbarui')),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui data: $e')),
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

