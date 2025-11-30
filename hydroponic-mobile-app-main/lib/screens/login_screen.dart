import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahkan import ini untuk InputFormatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hydroponics_app/theme/app_colors.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';
import 'package:hydroponics_app/widgets/styled_text_form_field.dart';
import 'package:hydroponics_app/widgets/log_reg_header.dart';
import 'package:hydroponics_app/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Center(
          child: SingleChildScrollView(
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
                      LogRegHeader(title: "MASUK", subtitle: "Selamat Datang"),
                      _gap(),

                      // Email atau Username Field
                      StyledTextFormField(
                        controller: _emailController,
                        labelText: 'Email atau Username',
                        hintText: 'Masukkan email atau username Anda',
                        prefixIcon: Icons.person,
                        // Note: Tidak menerapkan filter karakter username disini 
                        // karena field ini juga menerima Email (butuh @, angka, dll).
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan email atau username Anda';
                          }
                          return null;
                        },
                      ),
                      _gap(),

                      // Password Field
                      StyledTextFormField(
                        controller: _passwordController,
                        labelText: 'Kata Sandi',
                        hintText: 'Masukkan kata sandi Anda',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: !_isPasswordVisible,
                        inputFormatters: [
                          // [UPDATE] Batasi maksimal 15 karakter (sama seperti Register)
                          LengthLimitingTextInputFormatter(15),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan kata sandi Anda';
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
                      _gap(),

                      // Login Button
                      StyledElevatedButton(
                        text: _isLoading ? 'Memproses...' : 'Masuk',
                        onPressed: _isLoading ? null : _handleLogin,
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                      ),
                      SizedBox(height: 100)            
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);

  void _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.instance.signInWithEmailOrUsername(
        emailOrUsername: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user == null) {
        throw Exception('Login gagal.');
      }

      // Ambil data pengguna dari Firestore untuk menentukan role dan routing
      final doc = await FirebaseFirestore.instance
          .collection('pengguna')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw Exception('Akun tidak terdaftar sebagai karyawan.');
      }

      final data = doc.data() ?? {};
      final posisi = (data['posisi'] ?? '') as String;

      String route;
      switch (posisi) {
        case 'Petani':
          route = '/farmer_navigation';
          break;
        case 'Kurir':
          route = '/courier_navigation';
          break;
        case 'Staf Logistik':
          route = '/logistic_navigation';
          break;
        case 'Admin':
          route = '/admin_navigation';
          break;
        case 'Super Admin':
          route = '/superadmin_navigation';
          break;
        default:
          route = '/login';
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Terjadi kesalahan saat login.');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}