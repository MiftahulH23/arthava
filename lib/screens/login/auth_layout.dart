import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Kerangka layar auth (mockup A): hero gradasi biru di atas, sheet abu
/// dengan sudut atas membulat yang masuk ke hero. Tombol & footer menempel di
/// bawah pada layar tinggi; seluruh isi bisa di-scroll saat keyboard terbuka.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.fields,
    required this.action,
    required this.footer,
    this.sheetTitle,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final String? sheetTitle;
  final List<Widget> fields;
  final Widget action;
  final Widget footer;

  static const double _sheetRadius = 26;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.onHero,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(padding.left + 24, padding.top + 16, padding.right + 24, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              leading,
                              const SizedBox(height: 14),
                              Text(title, style: AppTextStyles.title.copyWith(fontSize: 24, color: AppColors.white)),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: AppTextStyles.subhead.copyWith(fontSize: 12.5, color: AppColors.heroLabel),
                              ),
                            ],
                          ),
                        ),
                        // Tutup sudut sheet di atas gradasi: tata letaknya nyata
                        // (bukan Transform), jadi tidak ada ruang kosong di bawah.
                        Container(
                          height: _sheetRadius,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding.left + 20, 0, padding.right + 20, padding.bottom + 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (sheetTitle != null) ...[
                            Text(sheetTitle!, style: AppTextStyles.title.copyWith(fontSize: 16)),
                            const SizedBox(height: 14),
                          ],
                          for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(height: 12), fields[i]],
                          const SizedBox(height: 24),
                          const Spacer(),
                          action,
                          const SizedBox(height: 14),
                          footer,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak logo kecil di hero Login (putih 18% di atas gradasi).
class AuthLogo extends StatelessWidget {
  const AuthLogo({required this.icon, super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 24, color: AppColors.white),
    );
  }
}

/// Tombol kembali "‹ Masuk" putih di hero Daftar.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsBold.caretLeft, size: 16, color: AppColors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w600, color: AppColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris "Belum punya akun? Daftar Disini" di bawah form auth.
class AuthFooter extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthFooter({required this.prompt, required this.action, required this.onTap, super.key});

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
            style: AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
