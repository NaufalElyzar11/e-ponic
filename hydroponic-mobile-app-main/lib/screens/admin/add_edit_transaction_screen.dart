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
  final String? transactionId;
  
  const AddEditTransactionScreen({super.key, this.transactionId});

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
  bool _isLoading = false;

  // harga sayur per jenis, di-load dari koleksi `tanaman`
  Map<String, double> _prices = {};
  // Menyimpan stok siap panen: Map<NamaTanaman, JumlahSiapPanen>
  Map<String, int> _readyStocks = {}; 
  
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
    _loadReadyStocks(); // Load data stok saat init
    
    // Load transaction data if editing
    if (widget.transactionId != null) {
      _loadTransactionData();
    }
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
        title: Text(
          widget.transactionId != null ? 'Edit Transaksi' : 'Tambah Transaksi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Container(
          padding: EdgeInsetsGeometry.only(left: 15, right: 15, top: 15, bottom: 40),
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
                      lastDate: DateTime.now(), // Membatasi input hanya sampai hari ini
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
                                Text('Selada', style: TextStyle(fontSize: 16)),
                                Expanded(child: Container()), 
                                SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: TextField(
                                    controller: _seladaController,
                                    enabled: isSeladaChecked, 
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: 'Qty',
                                      filled: true,
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
                            // --- PERUBAHAN DI SINI: Format Currency ---
                            NumberFormat.currency(
                              locale: 'id_ID', 
                              symbol: 'Rp ', 
                            ).format(_totalPrice),
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
                      text: widget.transactionId != null 
                          ? (_isSubmitting ? 'Memproses...' : 'Update Transaksi')
                          : (_isSubmitting ? 'Memproses...' : 'Tambah Transaksi'), 
                      onPressed: (_isSubmitting || _isLoading) ? null : _handleSubmit,
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
  // --- FUNGSI BARU: Load Stok Siap Panen ---
  Future<void> _loadReadyStocks() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('tanaman').get();
      final Map<String, int> stocks = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['nama_tanaman'] ?? '') as String;
        final id = doc.id;
        final masaTanam = (data['masa_tanam'] ?? 0) as int;
        
        if (name.isNotEmpty) {
          // Hitung stok siap panen untuk tanaman ini
          stocks[name] = await _calculateStockForPlant(id, masaTanam);
        }
      }
      
      if (mounted) {
        setState(() {
          _readyStocks = stocks;
        });
      }
    } catch (e) {
      debugPrint('Error loading stocks: $e');
    }
  }

  // Helper untuk hitung stok (Logic mirip dengan PlantStatusScreen)
  Future<int> _calculateStockForPlant(String plantId, int masaTanam) async {
    int totalTanamSemua = 0;
    int totalTanamMatang = 0; 
    int totalPanen = 0;

    final now = DateTime.now();

    // 1. Data Tanam
    final tanamSnap = await FirebaseFirestore.instance
        .collection('data_tanam')
        .where('id_tanaman', isEqualTo: plantId)
        .get();
    
    for (final doc in tanamSnap.docs) {
      final jumlah = (doc.data()['jumlah_tanam'] as int? ?? 0);
      final Timestamp? ts = doc.data()['tanggal_tanam'] as Timestamp?;
      
      totalTanamSemua += jumlah;

      if (ts != null) {
        final tanggalTanam = ts.toDate();
        final selisihHari = now.difference(tanggalTanam).inDays;
        if (selisihHari >= masaTanam) {
          totalTanamMatang += jumlah;
        }
      }
    }

    // 2. Data Panen
    final panenSnap = await FirebaseFirestore.instance
        .collection('data_panen')
        .where('id_tanaman', isEqualTo: plantId)
        .get();
    
    for (final doc in panenSnap.docs) {
      totalPanen += (doc.data()['jumlah_panen'] as int? ?? 0);
    }

    // 3. Hitung Sisa Siap Panen
    int sisaTanamanFisik = totalTanamSemua - totalPanen;
    if (sisaTanamanFisik < 0) sisaTanamanFisik = 0;

    // Ready = Matang - Panen
    int sisaSiapPanen = totalTanamMatang - totalPanen;
    if (sisaSiapPanen < 0) sisaSiapPanen = 0;
    
    // Safety: Siap panen tidak boleh melebihi sisa fisik tanaman
    if (sisaSiapPanen > sisaTanamanFisik) sisaSiapPanen = sisaTanamanFisik;

    return sisaSiapPanen;
  }

  // Helper untuk mendapatkan stok berdasarkan nama (case insensitive partial match)
  int _getStockByName(String partialName) {
    for (var entry in _readyStocks.entries) {
      if (entry.key.toLowerCase().contains(partialName.toLowerCase())) {
        return entry.value;
      }
    }
    return 0; // Default jika tidak ketemu
  }

  Future<void> _loadTransactionData() async {
    if (widget.transactionId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('transaksi')
          .doc(widget.transactionId!)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi tidak ditemukan')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data()!;
      
      _buyerNameController.text = (data['nama_pelanggan'] ?? '') as String;
      _buyerAddressController.text = (data['alamat'] ?? '') as String;
      
      final ts = data['tanggal'] as Timestamp?;
      if (ts != null) {
        _selectedDate = ts.toDate();
        _dateController.text = DateFormat('dd MMM yyyy').format(_selectedDate!);
      }
      
      _selectedPaymentStatus = (data['is_paid'] ?? false) as bool 
          ? _paymentStatuses[0] 
          : _paymentStatuses[1];
      
      final items = (data['items'] as List<dynamic>? ?? []);
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final namaTanaman = (itemMap['nama_tanaman'] ?? '') as String;
        final jumlah = (itemMap['jumlah'] as int?) ?? 0;
        
        if (namaTanaman.toLowerCase().contains('selada')) {
          isSeladaChecked = true;
          _seladaController.text = jumlah.toString();
        } else if (namaTanaman.toLowerCase().contains('pakcoy')) {
          isPakcoyChecked = true;
          _pakcoyController.text = jumlah.toString();
        } else if (namaTanaman.toLowerCase().contains('kangkung')) {
          isKangkungChecked = true;
          _kangkungController.text = jumlah.toString();
        }
      }
      
      _recalculateTotal();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data transaksi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
    }
  }

  void _recalculateTotal() {
    double total = 0.0;

    int parseQty(String text) =>
        int.tryParse(text.trim().isEmpty ? '0' : text.trim()) ?? 0;

    if (isSeladaChecked) {
      // Cari harga dengan partial match agar lebih aman
      double harga = 0.0;
      _prices.forEach((key, value) {
        if(key.toLowerCase().contains('selada')) harga = value;
      });
      total += harga * parseQty(_seladaController.text);
    }
    if (isPakcoyChecked) {
      double harga = 0.0;
      _prices.forEach((key, value) {
        if(key.toLowerCase().contains('pakcoy')) harga = value;
      });
      total += harga * parseQty(_pakcoyController.text);
    }
    if (isKangkungChecked) {
      double harga = 0.0;
      _prices.forEach((key, value) {
        if(key.toLowerCase().contains('kangkung')) harga = value;
      });
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

    // --- 3.5 VALIDASI STOK (Bagian Baru) ---
    String stockErrorMessage = '';
    
    if (isSeladaChecked) {
      final qty = int.tryParse(_seladaController.text) ?? 0;
      final available = _getStockByName('selada');
      if (qty > available) {
        stockErrorMessage += '\n- Stok Selada tidak cukup (Tersedia: $available).';
      }
    }
    if (isPakcoyChecked) {
      final qty = int.tryParse(_pakcoyController.text) ?? 0;
      final available = _getStockByName('pakcoy');
      if (qty > available) {
        stockErrorMessage += '\n- Stok Pakcoy tidak cukup (Tersedia: $available).';
      }
    }
    if (isKangkungChecked) {
      final qty = int.tryParse(_kangkungController.text) ?? 0;
      final available = _getStockByName('kangkung');
      if (qty > available) {
        stockErrorMessage += '\n- Stok Kangkung tidak cukup (Tersedia: $available).';
      }
    }

    if (stockErrorMessage.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stok Tidak Mencukupi'),
          content: Text('Mohon kurangi jumlah pesanan:$stockErrorMessage'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Stop proses submit
    }
    // --- AKHIR VALIDASI STOK ---

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

      if (widget.transactionId != null) {
        // Update existing transaction
        await TransactionService.instance.updateTransactionWithDetails(
          transactionId: widget.transactionId!,
          namaPelanggan: _buyerNameController.text.trim(),
          alamat: _buyerAddressController.text.trim(),
          tanggal: _selectedDate!,
          isPaid: _selectedPaymentStatus == 'Lunas',
          quantities: quantities,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil diupdate')),
        );
      } else {
        // Create new transaction
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
      }
      
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