import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/screens/login/login_form.dart';
import 'package:catat_uang_app/screens/login/register_form.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Layar auth tunggal: tab Masuk | Daftar di atas sheet putih.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0;
  final _loginEmail = TextEditingController();
  // Naik tiap daftar berhasil → RegisterForm dibuat ulang dengan isian kosong.
  int _registerRound = 0;

  @override
  void dispose() {
    _loginEmail.dispose();
    super.dispose();
  }

  void _google() =>
      AppNotification.info(context, 'Login Google belum tersedia. Pakai email dan password dulu ya.');

  void _onRegistered(String email) => setState(() {
        _loginEmail.text = email;
        _tab = 0;
        _registerRound++;
      });

  void _switchTab(int tab) {
    // Kursor di tab yang disembunyikan jangan tetap aktif (keyboard nyasar).
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = tab);
  }

  /// Kedua form tetap ter-mount (hanya disembunyikan) supaya request login/
  /// daftar yang sedang berjalan tidak hilang saat pengguna pindah tab, dan
  /// isian yang sudah diketik tetap ada.
  Widget _tabBody(int tab, Widget form) => Offstage(
        offstage: _tab != tab,
        child: TickerMode(enabled: _tab == tab, child: form),
      );

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Yuk, atur keuanganmu',
      subtitle: 'Masuk atau buat akun untuk mulai mencatat pemasukan dan pengeluaranmu.',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      footer: _tab == 0
          ? Text(
              'Datamu hanya bisa dilihat dari akunmu sendiri.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            )
          : null,
      children: [
        AppSegmentedControl(
          labels: const ['Masuk', 'Daftar'],
          selectedIndex: _tab,
          onChanged: _switchTab,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabBody(0, LoginForm(emailController: _loginEmail, onGoogle: _google)),
            _tabBody(
              1,
              RegisterForm(key: ValueKey(_registerRound), onRegistered: _onRegistered, onGoogle: _google),
            ),
          ],
        ),
      ],
    );
  }
}
