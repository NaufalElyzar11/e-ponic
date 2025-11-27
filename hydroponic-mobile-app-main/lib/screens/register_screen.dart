import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/log_reg_header.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/widgets/styled_text_form_field.dart';
import 'package:hydroponics_app/widgets/styled_dropdown_button_form_field.dart';
import 'package:hydroponics_app/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedPlantId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _plants = [];
  bool _isLoadingPlants = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPlants() async {
    setState(() {
      _isLoadingPlants = true;
    });
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('tanaman').get();
      setState(() {
        _plants = snapshot.docs;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlants = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    LogRegHeader(title: "BUAT AKUN", subtitle: "Buat akun karyawan"),
                    _gap(),

                    // Username Field
                    StyledTextFormField(
                      controller: _nameController,
                      labelText: 'Nama Pengguna',
                      hintText: 'Masukkan nama pengguna',
                      prefixIcon: Icons.person,
                      inputFormatters: [
                        // Hanya memperbolehkan huruf, spasi, titik (.), dan dash (-)
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s.\-]')),
                        LengthLimitingTextInputFormatter(30), // Batasi maksimal 30 karakter
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan masukkan nama pengguna';
                        }
                        // Validasi: tidak boleh hanya angka
                        if (RegExp(r'^\d+$').hasMatch(value.trim())) {
                          return 'Nama tidak boleh hanya angka';
                        }
                        // Validasi: harus ada huruf
                        if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                          return 'Nama harus mengandung huruf';
                        }
                        return null;
                      },
                    ),
                    _gap(),

                    // Email Field
                    StyledTextFormField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'contoh@email.com',
                      prefixIcon: Icons.email,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan masukkan email';
                        }
                        final email = value.trim().toLowerCase();
                        // Validasi: harus berakhiran @gmail.com atau @*.ac.id (misalnya @ulm.ac.id)
                        final isGmail = email.endsWith('@gmail.com');
                        final isAcId = RegExp(r'@[a-zA-Z0-9.-]+\.ac\.id$').hasMatch(email);
                        
                        if (!isGmail && !isAcId) {
                          return 'Email harus berakhiran @gmail.com atau @*.ac.id';
                        }
                        // Validasi format email dasar
                        if (!RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
                          return 'Format email tidak valid';
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

                    // Password Field
                    StyledTextFormField(
                      controller: _passwordController,
                      labelText: 'Kata Sandi',
                      hintText: 'Minimal 6 karakter, huruf & angka',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan masukkan kata sandi';
                        }
                        // Validasi: minimal 6 karakter
                        if (value.length < 6) {
                          return 'Kata sandi minimal 6 karakter';
                        }
                        // Validasi: harus ada huruf
                        if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                          return 'Kata sandi harus mengandung huruf';
                        }
                        // Validasi: harus ada angka
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Kata sandi harus mengandung angka';
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    _gap(),

                    // Confirm Password Field
                    StyledTextFormField(
                      controller: _confirmPasswordController,
                      labelText: 'Konfirmasi Kata Sandi',
                      hintText: 'Masukkan kembali kata sandi',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: !_isConfirmPasswordVisible,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan konfirmasi kata sandi';
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    _gap(),
                    _gap(),

                    // Register Button
                    StyledElevatedButton(
                      onPressed: _isSubmitting ? null : _handleRegister,
                      text: _isSubmitting ? 'Memproses...' : 'Tambah Akun',
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                    ),
                    SizedBox(height: 10,),

                    // Back Button
                    StyledElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);                        
                      },
                      text: 'Kembali',
                      foregroundColor: AppColors.primary,
                      backgroundColor: const Color.fromARGB(255, 233, 233, 233),
                    ),
                    SizedBox(height: 80,)
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

  void _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi dan konfirmasi tidak sama')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.instance.createEmployeeAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        namaPengguna: _nameController.text.trim(),
        posisi: _selectedCategory ?? '',
        idTanaman: _selectedCategory == 'Petani' ? _selectedPlantId : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun karyawan berhasil dibuat')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat akun: $e')),
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