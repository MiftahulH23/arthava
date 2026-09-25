import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_summary_widget.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppHeroCard memakai gradasi hero dan label heroLabel', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppHeroCard(child: Column(children: [
      AppHeroLabel('Total Saldo Keseluruhan'),
      AppHeroAmount('Rp 12.450.000'),
    ]))));
    final box = tester.widget<Container>(find.descendant(
      of: find.byType(AppHeroCard), matching: find.byType(Container)).first);
    final deco = box.decoration! as BoxDecoration;
    expect((deco.gradient! as LinearGradient).colors, [AppColors.heroGradientStart, AppColors.heroGradientEnd]);
    expect(deco.borderRadius, BorderRadius.circular(28));
    expect(tester.widget<Text>(find.text('Total Saldo Keseluruhan')).style!.color, AppColors.heroLabel);
  });

  testWidgets('AppHeroAmount 15 digit tidak overflow di layar 360', (tester) async {
    await pumpApp(tester, const Scaffold(body: Padding(
      padding: EdgeInsets.all(18),
      child: AppHeroCard(child: AppHeroAmount('Rp 999.999.999.999.999')),
    )), size: const Size(360, 740));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSurfaceCard putih radius 24 dan bisa ditap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppSurfaceCard(onTap: () => taps++, child: const Text('isi'))));
    final material = tester.widget<Material>(find.descendant(
      of: find.byType(AppSurfaceCard), matching: find.byType(Material)).first);
    expect(material.color, AppColors.surface);
    expect(material.borderRadius, BorderRadius.circular(24));
    await tester.tap(find.text('isi'));
    expect(taps, 1);
  });

  testWidgets('AppSummaryWidget label uppercase berwarna dan tinggi minimal 120', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: SizedBox(width: 170, child: AppSummaryWidget(
      icon: PhosphorIconsRegular.chartPie,
      label: 'Anggaran',
      color: AppColors.primary,
      onTap: () => taps++,
      children: const [Text('Rp 3,48 jt')],
    ))));
    expect(tester.widget<Text>(find.text('ANGGARAN')).style!.color, AppColors.primary);
    expect(tester.getSize(find.byType(AppSummaryWidget)).height, greaterThanOrEqualTo(120));
    await tester.tap(find.text('Rp 3,48 jt'));
    expect(taps, 1);
  });
}
