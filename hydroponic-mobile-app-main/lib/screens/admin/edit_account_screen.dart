import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/log_reg_header.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/widgets/styled_text_form_field.dart';
import 'package:hydroponics_app/widgets/styled_dropdown_button_form_field.dart';
import 'package:hydroponics_app/services/auth_service.dart';

class EditAccountScreen extends StatefulWidget {
  final String userId;
  
  const EditAccountScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  String? _selectedCategory;
  final List<String> _categories = [
    'Petani',
    'Kurir',
    'Staf Logistik',
    'Admin',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedPlantId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _plants = [];
  bool _isLoadingPlants = false;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingPlants = true;
    });

    try {
      // Load user data
      final userDoc = await FirebaseFirestore.instance
          .collection('pengguna')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nameController.text = (data['nama_pengguna'] ?? '') as String;
        _emailController.text = (data['email'] ?? '') as String;
        _selectedCategory = (data['posisi'] ?? '') as String;
        _selectedPlantId = data['id_tanaman'] as String?;
      }

      // Load plants
      final snapshot =
          await FirebaseFirestore.instance.collection('tanaman').get();
      setState(() {
        _plants = snapshot.docs;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingPlants = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Edit Akun', style: TextStyle(fontWeight: FontWeight.bold)),
          titleSpacing: 10,
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromARGB(255, 1, 68, 33),
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Akun', style: TextStyle(fontWeight: FontWeight.bold)),
        titleSpacing: 10,
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 1, 68, 33),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Card(
            color: Colors.white,
            elevation: 0.0,
            child: Container(
              padding: const EdgeInsets.all(10.0),
              constraints: const BoxConstraints(maxWidth: 350),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    LogRegHeader(title: "EDIT AKUN", subtitle: "Edit data akun karyawan"),
                    _gap(),

                    // Username Field
                    StyledTextFormField(
                      controller: _nameController,
                      labelText: 'Nama Pengguna',
                      hintText: 'Masukkan nama pengguna',
                      prefixIcon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan masukkan nama pengguna';
                        }
                        return null;
                      },
                    ),
                    _gap(),

                    // Email Field (read-only)
                    StyledTextFormField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'Email',
                      prefixIcon: Icons.email,
                      enabled: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email harus diisi';
                        }
                        return null;
                      },
                    ),
                    _gap(),

                    // Role Dropdown Field
                    StyledDropdownButtonFormField<String>(
                      hintText: 'Pilih Posisi',
                      prefixIcon: Icons.card_travel,
                      value: _selectedCategory,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                          // reset pilihan tanaman jika bukan petani
                          if (_selectedCategory != 'Petani') {
                            _selectedPlantId = null;
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Silakan pilih posisi karyawan';
                        }
                        return null;
                      },
                    ),
                    _gap(),

                    if (_selectedCategory == 'Petani')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          StyledDropdownButtonFormField<String>(
                            hintText: _isLoadingPlants
                                ? 'Memuat daftar tanaman...'
                                : 'Pilih Tanaman',
                            prefixIcon: Icons.local_florist,
                            value: _selectedPlantId,
                            items: _plants
                                .map(
                                  (doc) => DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text(
                                        doc.data()['nama_tanaman'] ?? 'Tanaman'),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedPlantId = newValue;
                              });
                            },
                            validator: (value) {
                              if (_selectedCategory == 'Petani' &&
                                  (value == null || value.isEmpty)) {
                                return 'Silakan pilih tanaman untuk petani';
                              }
                              return null;
                            },
                          ),
                          _gap(),
                        ],
                      ),

                    _gap(),
                    _gap(),

                    // Update Button
                    StyledElevatedButton(
                      onPressed: _isSubmitting ? null : _handleUpdate,
                      text: _isSubmitting ? 'Memproses...' : 'Update Akun',
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                    ),
                    const SizedBox(height: 10),

                    // Back Button
                    StyledElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      text: 'Kembali',
                      foregroundColor: AppColors.primary,
                      backgroundColor: const Color.fromARGB(255, 233, 233, 233),
                    ),
                    const SizedBox(height: 80)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);

  void _handleUpdate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.instance.updateAccount(
        userId: widget.userId,
        namaPengguna: _nameController.text.trim(),
        posisi: _selectedCategory ?? '',
        idTanaman: _selectedCategory == 'Petani' ? _selectedPlantId : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun berhasil diupdate')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengupdate akun: $e')),
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

