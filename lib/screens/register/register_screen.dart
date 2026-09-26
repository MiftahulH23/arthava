import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login/auth_brand.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
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

  // Getter lazy: lihat catatan di LoginScreen.
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
    return AppPageScaffold(
      title: 'Daftar Akun',
      backLabel: 'Masuk',
      titleWidget: const AuthBrand(
        icon: PhosphorIconsFill.userCirclePlus,
        title: 'Daftar Akun',
        subtitle: 'Gabung dan mulai atur keuanganmu',
        filled: false,
      ),
      children: [
        AppGroupedSection(
          insetSeparators: false,
          children: [
            AppTextField(
              controller: _nameController,
              hint: 'Masukkan nama asli bos',
              icon: PhosphorIconsRegular.user,
            ),
            AppTextField(
              controller: _emailController,
              hint: 'email@contoh.com',
              icon: PhosphorIconsRegular.envelopeSimple,
              keyboardType: TextInputType.emailAddress,
            ),
            AppTextField(
              controller: _passwordController,
              hint: 'Buat password yang kuat',
              icon: PhosphorIconsRegular.lockKey,
              obscure: _isObscure,
              suffix: IconButton(
                onPressed: () => setState(() => _isObscure = !_isObscure),
                icon: Icon(
                  _isObscure
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeSlash,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        AppPrimaryButton(
          label: 'Daftar Sekarang',
          onPressed: _isLoading ? null : _register,
          loading: _isLoading,
        ),
        AuthFooter(
          prompt: 'Sudah punya akun? ',
          action: 'Masuk Disini',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
