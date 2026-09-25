import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

double _factor(WidgetTester tester) =>
    tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;

void main() {
  testWidgets('menjepit nilai di atas 1 (over budget) dan di bawah 0', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: 1.13, color: AppColors.expense)));
    expect(_factor(tester), 1.0);
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: -0.2, color: AppColors.expense)));
    expect(_factor(tester), 0.0);
  });

  testWidgets('NaN dari pembagian 0/0 jadi 0 tanpa exception', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: double.nan, color: AppColors.primary)));
    expect(_factor(tester), 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tinggi mengikuti parameter', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: 0.5, color: AppColors.primary, height: 6)));
    expect(tester.getSize(find.byType(AppProgressBar)).height, 6);
  });

  testWidgets('AppProgressRing merender center dan ukuran', (tester) async {
    await pumpApp(tester, const Scaffold(body: Center(child: AppProgressRing(
      value: 0.82, color: AppColors.tintOrange, center: Text('82%'),
    ))));
    expect(find.text('82%'), findsOneWidget);
    expect(tester.getSize(find.byType(AppProgressRing)), const Size(110, 110));
  });

  test('AppProgressRingPainter menjepit nilai', () {
    expect(AppProgressRingPainter(value: 2, color: AppColors.primary, strokeWidth: 11).value, 1.0);
    expect(AppProgressRingPainter(value: double.nan, color: AppColors.primary, strokeWidth: 11).value, 0.0);
  });
}
