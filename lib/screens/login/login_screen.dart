import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/screens/register/register_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Getter (bukan field) supaya Supabase.instance baru diakses saat login
  // benar-benar dijalankan — layar bisa dirender di widget test tanpa
  // Supabase.initialize.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
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
    return AuthLayout(
      title: 'DompetKu',
      subtitle: 'Cerdas mengelola, tenang finansial',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      children: [
        Text('Masuk ke akunmu', style: AppTextStyles.title.copyWith(fontSize: 16)),
        AppTextField(
          controller: _emailController,
          hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          outlined: true,
        ),
        AppTextField(
          controller: _passwordController,
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
        AppPrimaryButton(
        label: 'Masuk Sekarang',
        onPressed: _isLoading ? null : _login,
        loading: _isLoading,
      ),
        AuthFooter(
        prompt: 'Belum punya akun? ',
        action: 'Daftar Disini',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        },
      ),
      ],
    );
  }
}
