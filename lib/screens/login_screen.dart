import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home_screen.dart';
import 'package:catat_uang_app/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/core/app_notification.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      AppNotification.error(context, "Email dan Password wajib diisi!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        AppNotification.success(context, "Selamat datang kembali!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, "Email atau password salah.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Dasar putih biar terang
      body: Stack(
        children: [
          // 1. AREA ATAS (CERAH & MINIMALIS)
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              color: Colors.white, // Ganti ke Putih total
            ),
            child: Stack(
              children: [
                // Elemen Dekoratif Sangat Halus (Cuma aksen tipis)
                Positioned(
                  top: -40,
                  right: -40,
                  child: CircleAvatar(
                    radius: 100,
                    backgroundColor: AppColors.primary.withOpacity(0.04),
                  ),
                ),
                Positioned(
                  top: 120,
                  left: 20,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.03),
                  ),
                ),

                // Branding Minimalis
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo dengan shadow yang sangat lembut
                      Container(
                        padding: const EdgeInsets.all(18),
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
                          PhosphorIconsFill.wallet,
                          size: 45,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "CatatUang",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Cerdas mengelola, tenang finansial",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. AREA BAWAH (CARD FORM DENGAN ELEVASI HALUS)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.fromLTRB(30, 45, 30, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      0.04,
                    ), // Shadow lebih tipis biar bersih
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
                    Text(
                      "Selamat Datang!",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Silakan masuk untuk melanjutkan",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Input Email
                    _buildTextField(
                      controller: _emailController,
                      label: "Alamat Email",
                      hint: "email@contoh.com",
                      icon: PhosphorIconsRegular.envelopeSimple,
                    ),
                    const SizedBox(height: 20),

                    // Input Password
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      hint: "Masukkan password Anda",
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

                    // Tombol Login
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0, // Flat design lebih modern
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
                                "Masuk Sekarang",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Footer Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Belum punya akun? ",
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Daftar Disini",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
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
