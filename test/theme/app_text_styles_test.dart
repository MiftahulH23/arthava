import 'dart:ui' show FontFeature;

import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('AppColors punya token Phase B dengan nilai spec', () {
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.track, const Color(0xFFE5E5EA));
    expect(AppColors.separator, const Color(0xFFD8D8DD));
    expect(AppColors.primarySoft, const Color(0xFFE5F1FF));
    expect(AppColors.accentSoft, const Color(0xFFFFF1DC));
    expect(AppColors.tintOrange, const Color(0xFFF0913A));
    expect(AppColors.tintGray, const Color(0xFF8E8E93));
  });

  test('AppTextStyles memakai Plus Jakarta Sans dan skala spec', () {
    expect(AppTextStyles.largeTitle.fontFamily, contains('PlusJakartaSans'));
    expect(AppTextStyles.largeTitle.fontSize, 32);
    expect(AppTextStyles.largeTitle.fontWeight, FontWeight.w800);
    expect(AppTextStyles.body.fontSize, 16);
    expect(AppTextStyles.caption.fontSize, 12);
    expect(AppTextStyles.caption.color, AppColors.textSecondary);
    expect(AppTextStyles.navLabel.color, AppColors.primary);
    expect(AppTextStyles.amountHero.color, Colors.white);
  });

  test('gaya nominal memakai angka tabular', () {
    for (final style in [AppTextStyles.amountHero, AppTextStyles.amountLarge, AppTextStyles.amountRow]) {
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  testWidgets('pumpApp menyiapkan ukuran HP dan locale id_ID', (tester) async {
    late Locale locale;
    await pumpApp(tester, Builder(builder: (context) {
      locale = Localizations.localeOf(context);
      return const Text('halo');
    }));
    expect(find.text('halo'), findsOneWidget);
    expect(locale, const Locale('id', 'ID'));
    expect(tester.view.physicalSize, const Size(390, 844));
  });
}
