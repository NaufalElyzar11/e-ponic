import 'package:flutter/material.dart';
import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:intl/intl.dart';

class StyledDatePickerField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<DateTime?>? onDateSelected;
  final DateTime? lastDate; // Parameter baru untuk batas akhir tanggal

  const StyledDatePickerField({
    super.key,
    this.controller,
    this.onDateSelected,
    this.lastDate, // Tambahkan ke constructor
  });

  @override
  State<StyledDatePickerField> createState() => _StyledDatePickerFieldState();
}

class _StyledDatePickerFieldState extends State<StyledDatePickerField> {
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = widget.controller ?? TextEditingController();
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    // Gunakan widget.lastDate jika ada, jika tidak gunakan default 2101
    final effectiveLastDate = widget.lastDate ?? DateTime(2101);

    // Pastikan initialDate tidak melebihi lastDate untuk mencegah error
    // Jika 'sekarang' lebih besar dari batas akhir, gunakan batas akhir sebagai awal
    DateTime initialDate = now;
    if (initialDate.isAfter(effectiveLastDate)) {
      initialDate = effectiveLastDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate, 
      firstDate: DateTime(2000),   
      lastDate: effectiveLastDate, // Gunakan batas akhir yang dinamis
    );

    if (picked != null) {
      setState(() {
        String formattedDate = DateFormat('dd-MM-yyyy').format(picked);
        _dateController.text = formattedDate;
      });
      widget.onDateSelected?.call(picked);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _dateController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: () {
        _selectDate(context);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Silakan pilih tanggal';
        }
        return null;
      },
      decoration: const InputDecoration( // Saya tambahkan const untuk optimasi
        hintText: 'Pilih tanggal',
        filled: true,
        fillColor: Color.fromARGB(255, 236, 236, 236),
        suffixIcon: Icon(Icons.calendar_today_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(style: BorderStyle.none),
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2.0
          )
        )
      ),
    );
  }
}