import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tab "Masuk". Controller email milik [LoginScreen] supaya email hasil daftar
/// bisa diisikan ke sini.
class LoginForm extends StatefulWidget {
  const LoginForm({required this.emailController, required this.onGoogle, super.key});

  final TextEditingController emailController;
  final VoidCallback onGoogle;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  TextEditingController get _emailController => widget.emailController;
  final _passwordController = TextEditingController();

  // Getter (bukan field) supaya Supabase.instance baru diakses saat login
  // benar-benar dijalankan — layar bisa dirender di widget test tanpa
  // Supabase.initialize.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          outlined: true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Masukkan password Anda',
          icon: PhosphorIconsRegular.lockKey,
          obscure: _isObscure,
          outlined: true,
          suffix: IconButton(
            onPressed: () => setState(() => _isObscure = !_isObscure),
            icon: Icon(
              _isObscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppPrimaryButton(label: 'Masuk', onPressed: _isLoading ? null : _login, loading: _isLoading),
        const SizedBox(height: 18),
        const AuthDivider(label: 'atau masuk dengan'),
        const SizedBox(height: 18),
        AuthGoogleButton(label: 'Lanjut dengan Google', onTap: widget.onGoogle),
      ],
    );
  }
}
