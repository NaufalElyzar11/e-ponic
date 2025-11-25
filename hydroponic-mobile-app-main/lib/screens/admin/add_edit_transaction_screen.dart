import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/no_leading_text_form_field.dart';
import 'package:hydroponics_app/widgets/styled_date_picker_field.dart';
import 'package:hydroponics_app/widgets/styled_dropdown_button_form_field.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/services/transaction_service.dart';

class AddEditTransactionScreen extends StatefulWidget{
  const AddEditTransactionScreen({super.key});

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  bool isSeladaChecked = false;
  bool isPakcoyChecked = false;
  bool isKangkungChecked = false;

  // Controller untuk setiap text field
  late TextEditingController _seladaController;
  late TextEditingController _pakcoyController;
  late TextEditingController _kangkungController;
  final TextEditingController _buyerNameController = TextEditingController();
  final TextEditingController _buyerAddressController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSubmitting = false;

  // harga sayur per jenis, di-load dari koleksi `tanaman`
  Map<String, double> _prices = {};
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller
    _seladaController = TextEditingController();
    _pakcoyController = TextEditingController();
    _kangkungController = TextEditingController();

    _seladaController.addListener(_recalculateTotal);
    _pakcoyController.addListener(_recalculateTotal);
    _kangkungController.addListener(_recalculateTotal);

    _loadPrices();
  }

  @override
  void dispose() {
    // WAJIB: Hapus controller saat widget tidak dipakai
    // untuk menghindari memory leaks
    _seladaController.dispose();
    _pakcoyController.dispose();
    _kangkungController.dispose();
    _buyerNameController.dispose();
    _buyerAddressController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String? _selectedPaymentStatus;
  final List<String> _paymentStatuses = [
    'Lunas',
    'Belum Lunas',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tambah Transaksi', style: TextStyle(fontWeight: FontWeight.bold),),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: Color.fromARGB(255, 1, 68, 33),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsetsGeometry.all(15),
          child: Form(
            key: _formKey,
            child: Card(
              color: AppColors.primary,
              child: Container(
                width: double.infinity,
                padding: EdgeInsetsGeometry.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsetsGeometry.only(bottom: 7),
                      child: Text('Nama Pembeli:', style: TextStyle(color: Colors.white, fontSize: 18),),
                    ),
                    NoLeadingTextFormField(
                      controller: _buyerNameController,
                      hintText: 'Masukkan nama pembeli', 
                      inputType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan masukkan nama pembeli';
                        }
                        return null;
                      },
                    ),

                    Padding(
                      padding: EdgeInsetsGeometry.only(top: 15, bottom: 7),
                      child: Text('Alamat Pembeli:', style: TextStyle(color: Colors.white, fontSize: 18),),
                    ),
                    NoLeadingTextFormField(
                      controller: _buyerAddressController,
                      hintText: 'Masukkan alamat pembeli', 
                      inputType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan masukkan alamat pembeli';
                        }
                        return null;
                      },
                    ),

                    Padding(
                      padding: EdgeInsetsGeometry.only(top: 15, bottom: 7),
                      child: Text('Tanggal Transaksi:', style: TextStyle(color: Colors.white, fontSize: 18),),
                    ),
                    StyledDatePickerField(
                      controller: _dateController,
                      onDateSelected: (date) {
                        _selectedDate = date;
                      },
                    ),

                    Padding(
                      padding: EdgeInsetsGeometry.only(top: 15, bottom: 7),
                      child: Text('Jenis & Jumlah Sayur:', style: TextStyle(color: Colors.white, fontSize: 18),),
                    ),
                    Card(
                      color: Color.fromARGB(255, 236, 236, 236),
                      child: Padding(
                        padding: EdgeInsetsGeometry.all(15),
                        child: Column(
                          children: [
                            // --- Baris untuk SELADA ---
                            Row(
                              children: [
                                // 1. Checkbox
                                Checkbox(
                                  value: isSeladaChecked,
                                  activeColor: AppColors.primary,
                                  onChanged: (bool? newValue) {
                                    setState(() {
                                      isSeladaChecked = newValue!;
                                    });
                                _recalculateTotal();
                                  },
                                ),
                                
                                // 2. Label
                                Text('Selada', style: TextStyle(fontSize: 16)),
                                
                                // 3. Spacer
                                // Ini akan mendorong TextField ke paling kanan
                                Expanded(child: Container()), 
                                
                                // 4. TextField Kuantitas
                                SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: TextField(
                                    controller: _seladaController,
                                    // Kunci Logika: TextField hanya aktif jika di-centang
                                    enabled: isSeladaChecked, 
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: 'Qty',
                                      filled: true,
                                      // Ganti warna jika non-aktif
                                      fillColor: isSeladaChecked ? Colors.white : Colors.grey[300],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // --- Baris untuk PAKCOY ---
                            Row(
                              children: [
                                Checkbox(
                                  value: isPakcoyChecked,
                                  activeColor: AppColors.primary,
                                  onChanged: (bool? newValue) {
                                    setState(() {
                                      isPakcoyChecked = newValue!;
                                    });
                                    _recalculateTotal();
                                  },
                                ),
                                Text('Pakcoy', style: TextStyle(fontSize: 16)),
                                Expanded(child: Container()), 
                                SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: TextField(
                                    controller: _pakcoyController,
                                    enabled: isPakcoyChecked, // Logic
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: 'Qty',
                                      filled: true,
                                      fillColor: isPakcoyChecked ? Colors.white : Colors.grey[300],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // --- Baris untuk KANGKUNG ---
                            Row(
                              children: [
                                Checkbox(
                                  value: isKangkungChecked,
                                  activeColor: AppColors.primary,
                                  onChanged: (bool? newValue) {
                                    setState(() {
                                      isKangkungChecked = newValue!;
                                    });
                                    _recalculateTotal();
                                  },
                                ),
                                Text('Kangkung', style: TextStyle(fontSize: 16)),
                                Expanded(child: Container()), 
                                SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: TextField(
                                    controller: _kangkungController,
                                    enabled: isKangkungChecked, // Logic
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: 'Qty',
                                      filled: true,
                                      fillColor: isKangkungChecked ? Colors.white : Colors.grey[300],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsetsGeometry.only(top: 15, bottom: 7),
                      child: Text('Total Harga:', style: TextStyle(color: Colors.white, fontSize: 18),),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        color: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1.0,
                            color: Colors.grey
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsetsGeometry.all(10),
                          child: Text(
                            'Rp $_totalPrice',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsetsGeometry.only(top: 15, bottom: 7),
                      child: Text('Status Pembayaran:', style: TextStyle(color: Colors.white, fontSize: 18),),
                    ),
                    StyledDropdownButtonFormField(
                      hintText: 'Pilih Status Pembayaran', 
                      prefixIcon: Icons.payment,
                      value: _selectedPaymentStatus,
                      items: _paymentStatuses.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                          setState(() {
                            _selectedPaymentStatus = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Silakan pilih status pembayaran';
                          }
                          return null;
                        },
                    ),

                    SizedBox(height: 20,),
                    StyledElevatedButton(
                      text: 'Tambah Transaksi', 
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      foregroundColor: AppColors.primary,
                      backgroundColor: Colors.white,
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  bool get isNotNullOrEmpty => trim().isNotEmpty;
}

extension _AddEditTransactionScreenLogic on _AddEditTransactionScreenState {
  Future<void> _loadPrices() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('tanaman').get();
      final Map<String, double> map = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['nama_tanaman'] ?? '') as String;
        final harga = (data['harga'] as num?)?.toDouble() ?? 0.0;
        if (name.isNotEmpty) {
          map[name] = harga;
        }
      }
      setState(() {
        _prices = map;
      });
      _recalculateTotal();
    } catch (_) {
      // kalau gagal load harga, biarkan total 0 (tetap aman karena backend
      // TransactionService akan menghitung total dari Firestore).
    }
  }

  void _recalculateTotal() {
    double total = 0.0;

    int parseQty(String text) =>
        int.tryParse(text.trim().isEmpty ? '0' : text.trim()) ?? 0;

    if (isSeladaChecked) {
      final harga = _prices['Selada'] ?? 0.0;
      total += harga * parseQty(_seladaController.text);
    }
    if (isPakcoyChecked) {
      final harga = _prices['Pakcoy'] ?? 0.0;
      total += harga * parseQty(_pakcoyController.text);
    }
    if (isKangkungChecked) {
      final harga = _prices['Kangkung'] ?? 0.0;
      total += harga * parseQty(_kangkungController.text);
    }

    setState(() {
      _totalPrice = total;
    });
  }

  void _handleSubmit() async {
    // 1. Validasi field yang MUDAH (Nama, Alamat, Status)
    final isFormValid = _formKey.currentState?.validate() ?? false;

    // 2. Validasi field yang KOMPLEKS (Logika Sayur)
    final isSeladaValid = !isSeladaChecked ||
        (isSeladaChecked &&
            _seladaController.text.isNotNullOrEmpty &&
            _seladaController.text != '0');
    final isPakcoyValid = !isPakcoyChecked ||
        (isPakcoyChecked &&
            _pakcoyController.text.isNotNullOrEmpty &&
            _pakcoyController.text != '0');
    final isKangkungValid = !isKangkungChecked ||
        (isKangkungChecked &&
            _kangkungController.text.isNotNullOrEmpty &&
            _kangkungController.text != '0');

    // 3. Cek apakah setidaknya satu sayur dipilih
    final isAtLeastOneChecked =
        isSeladaChecked || isPakcoyChecked || isKangkungChecked;

    if (_selectedPaymentStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih status pembayaran')),
      );
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tanggal transaksi')),
      );
    }

    // 4. Cek apakah semua validasi lolos
    if (!(isFormValid &&
        isSeladaValid &&
        isPakcoyValid &&
        isKangkungValid &&
        isAtLeastOneChecked &&
        _selectedDate != null &&
        _selectedPaymentStatus != null)) {
      // Tampilkan pesan error ringkas
      String errorMessage = 'Mohon periksa kembali data Anda:';

      if (!isAtLeastOneChecked) {
        errorMessage += '\n- Pilih minimal satu jenis sayur.';
      }
      if (!isSeladaValid) {
        errorMessage += '\n- Kuantitas Selada harus diisi (> 0).';
      }
      if (!isPakcoyValid) {
        errorMessage += '\n- Kuantitas Pakcoy harus diisi (> 0).';
      }
      if (!isKangkungValid) {
        errorMessage += '\n- Kuantitas Kangkung harus diisi (> 0).';
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Data Tidak Lengkap'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final quantities = <String, int>{};
      if (isSeladaChecked) {
        quantities['Selada'] = int.parse(_seladaController.text);
      }
      if (isPakcoyChecked) {
        quantities['Pakcoy'] = int.parse(_pakcoyController.text);
      }
      if (isKangkungChecked) {
        quantities['Kangkung'] = int.parse(_kangkungController.text);
      }

      await TransactionService.instance.createTransactionWithDetails(
        namaPelanggan: _buyerNameController.text.trim(),
        alamat: _buyerAddressController.text.trim(),
        tanggal: _selectedDate!,
        isPaid: _selectedPaymentStatus == 'Lunas',
        quantities: quantities,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil ditambahkan')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambah transaksi: $e')),
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