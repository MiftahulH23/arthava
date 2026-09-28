import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kerangka layar auth (gaya referensi Rotta): hero gradasi biru berdekorasi
/// lingkaran tipis, lalu sheet putih bersudut atas membulat. [children]
/// tersusun dari atas dengan jarak 12; [footer] opsional menempel di dasar.
/// Seluruh isi bisa di-scroll saat keyboard terbuka.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.children,
    this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final List<Widget> children;
  final Widget? footer;

  static const double _sheetRadius = 24;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.onHero,
      child: Scaffold(
        backgroundColor: AppColors.surface,
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
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        const Positioned(right: -80, top: -70, child: _Ring(size: 240)),
                        const Positioned(right: -36, top: -26, child: _Ring(size: 150)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(padding.left + 24, padding.top + 20, padding.right + 24, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  leading,
                                  const SizedBox(height: 18),
                                  Text(
                                    title,
                                    style: AppTextStyles.title.copyWith(fontSize: 26, color: AppColors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    style: AppTextStyles.subhead.copyWith(fontSize: 13, color: AppColors.heroLabel),
                                  ),
                                ],
                              ),
                            ),
                            // Sudut sheet sebagai kotak nyata (bukan Transform),
                            // jadi tidak ada ruang kosong tersembunyi di bawah.
                            Container(
                              height: _sheetRadius,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
                              ),
                            ),
                          ],
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
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            children[i],
                          ],
                          const SizedBox(height: 24),
                          const Spacer(),
                          if (footer != null) footer!,
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

/// Lingkaran garis tipis dekoratif di hero.
class _Ring extends StatelessWidget {
  const _Ring({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.13), width: 1.5),
      ),
    );
  }
}
