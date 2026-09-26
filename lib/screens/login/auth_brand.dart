import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Header branding layar auth (Login & Daftar): ikon aplikasi ala ikon iOS,
/// judul, dan tagline. [filled] = kotak ikon warna primary + glyph putih
/// (Login); false = kotak primarySoft + glyph primary (Daftar).
class AuthBrand extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;

  const AuthBrand({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.filled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: filled ? AppColors.primary : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(24),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 40,
              color: filled ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.subhead,
          ),
        ],
      ),
    );
  }
}

/// Baris "Belum punya akun? Daftar Disini" di bawah form auth.
class AuthFooter extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthFooter({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap: di layar sempit tautan turun ke baris berikut, bukan overflow.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: AppTextStyles.subhead),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: AppTextStyles.subhead.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
