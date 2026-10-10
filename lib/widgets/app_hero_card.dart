import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Kartu gradasi biru untuk angka ringkasan utama halaman (spec G8).
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
    );
  }
}

/// Label kecil di kartu hero (putih 88%, kontras cukup di atas gradasi).
class AppHeroLabel extends StatelessWidget {
  const AppHeroLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.heroLabel));
  }
}

/// Nominal besar di kartu hero; mengecil otomatis bila tidak muat.
/// Butuh lebar terbatas: di dalam `Row`, bungkus dengan `Expanded` (tanpa itu
/// FittedBox tidak bisa mengecil dan Row overflow).
class AppHeroAmount extends StatelessWidget {
  const AppHeroAmount(this.text, {this.fontSize = 32, super.key});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: AppTextStyles.amountHero.copyWith(fontSize: fontSize)),
    );
  }
}
