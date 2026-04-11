import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      AppNotification.error(context, "Semua kolom wajib diisi ya bos!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        data: {'name': _nameController.text},
      );

      if (res.user != null) {
        try {
          await _supabase.from('profiles').upsert({
            'id': res.user!.id,
            'name': _nameController.text,
          });
        } catch (profileError) {
          debugPrint("Warning: Gagal simpan profil: $profileError");
        }

        if (mounted) {
          AppNotification.success(
            context,
            "Registrasi Berhasil! Silakan Login.",
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. AREA ATAS (HEADER MINIMALIS)
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: const BoxDecoration(color: Colors.white),
            child: Stack(
              children: [
                // Aksen Lingkaran Halus
                Positioned(
                  top: -30,
                  left: -30,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundColor: AppColors.primary.withOpacity(0.04),
                  ),
                ),
                Positioned(
                  bottom: 50,
                  right: 20,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.03),
                  ),
                ),

                // Tombol Back
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 10),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                // Branding Section
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          PhosphorIconsFill.userCirclePlus,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Daftar Akun",
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        "Gabung dan mulai atur keuanganmu",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. AREA BAWAH (FORM CARD)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 40,
                    offset: const Offset(0, -15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: "Nama Lengkap",
                      hint: "Masukkan nama asli bos",
                      icon: PhosphorIconsRegular.user,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _emailController,
                      label: "Alamat Email",
                      hint: "email@contoh.com",
                      icon: PhosphorIconsRegular.envelopeSimple,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      hint: "Buat password yang kuat",
                      isPassword: _isObscure,
                      icon: PhosphorIconsRegular.lockKey,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _isObscure = !_isObscure),
                        icon: Icon(
                          _isObscure
                              ? PhosphorIconsRegular.eye
                              : PhosphorIconsRegular.eyeSlash,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Tombol Register
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                "Daftar Sekarang",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Footer Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Sudah punya akun? ",
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            "Masuk Disini",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
