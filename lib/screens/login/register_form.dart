import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/screens/login/auth_parts.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tab "Daftar". Setelah berhasil, [onRegistered] menerima email baru —
/// [LoginScreen] pindah ke tab Masuk (dulu Navigator.pop ke layar Login).
class RegisterForm extends StatefulWidget {
  const RegisterForm({required this.onRegistered, required this.onGoogle, super.key});

  final ValueChanged<String> onRegistered;
  final VoidCallback onGoogle;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Getter lazy: lihat catatan di LoginForm.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
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
          widget.onRegistered(_emailController.text);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _nameController,
          label: 'Nama lengkap',
          hint: 'Masukkan nama asli bos',
          icon: PhosphorIconsRegular.user,
          outlined: true,
        ),
        const SizedBox(height: 12),
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
          hint: 'Buat password yang kuat',
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Minimal 6 karakter.', style: AppTextStyles.caption),
        ),
        const SizedBox(height: 18),
        AppPrimaryButton(label: 'Daftar Sekarang', onPressed: _isLoading ? null : _register, loading: _isLoading),
        const SizedBox(height: 18),
        const AuthDivider(label: 'atau daftar dengan'),
        const SizedBox(height: 18),
        AuthGoogleButton(label: 'Lanjut dengan Google', onTap: widget.onGoogle),
      ],
    );
  }
}
