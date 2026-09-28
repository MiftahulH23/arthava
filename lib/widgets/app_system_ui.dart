import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gaya status bar & nav bar default seluruh aplikasi (dipasang sekali di
/// `MaterialApp.builder`). Flutter tidak mengembalikan gaya sistem saat layar
/// yang memasang gaya lain ditutup, jadi default ini wajib ada di atas
/// Navigator; layar seperti [AuthLayout] menimpanya dengan [onHero].
class AppSystemUi extends StatelessWidget {
  const AppSystemUi({required this.child, super.key});

  final Widget child;

  /// Ikon gelap di atas latar abu terang.
  static final SystemUiOverlayStyle standard = SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// Ikon status bar terang di atas hero gradasi biru; nav bar tetap
  /// mengikuti latar sheet di bawah.
  static final SystemUiOverlayStyle onHero = SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(value: standard, child: child);
}
