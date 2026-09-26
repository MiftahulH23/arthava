import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppPrimaryButton tinggi 52 dan memanggil onPressed', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPrimaryButton(label: 'Simpan', onPressed: () => taps++)));
    expect(tester.getSize(find.byType(AppPrimaryButton)).height, 52);
    await tester.tap(find.text('Simpan'));
    expect(taps, 1);
  });

  testWidgets('AppPrimaryButton loading menampilkan spinner dan menolak tap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPrimaryButton(label: 'Simpan', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppPrimaryButton));
    expect(taps, 0);
  });

  testWidgets('AppPrimaryButton memakai warna kustom (Bayar Cicilan merah)', (tester) async {
    await pumpApp(tester, Scaffold(body: AppPrimaryButton(label: 'Bayar', color: AppColors.expense, onPressed: () {})));
    final style = tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
    expect(style.backgroundColor!.resolve({}), AppColors.expense);
  });

  testWidgets('AppPillButton soft vs filled', (tester) async {
    await pumpApp(tester, Scaffold(body: Row(children: [
      AppPillButton(label: 'Setor', icon: PhosphorIconsRegular.arrowDown, onPressed: () {}),
      AppPillButton(label: 'Tambah', filled: true, onPressed: () {}),
    ])));
    expect(tester.widget<Text>(find.text('Setor')).style!.color, AppColors.primary);
    expect(tester.widget<Text>(find.text('Tambah')).style!.color, Colors.white);
    expect(tester.getSize(find.widgetWithText(AppPillButton, 'Setor')).height, 36);
  });

  testWidgets('AppPillButton large: tinggi 44 dan bulat penuh', (tester) async {
    await pumpApp(tester, Scaffold(body: Row(children: [
      AppPillButton(label: 'Tambah', filled: true, large: true, onPressed: () {}),
    ])));
    expect(tester.getSize(find.widgetWithText(AppPillButton, 'Tambah')).height, 44);
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppPillButton), matching: find.byType(Material)).first,
    );
    expect(material.borderRadius, BorderRadius.circular(999));
  });

  testWidgets('AppPill menampilkan badge dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPill(
      label: 'Filter', icon: PhosphorIconsRegular.funnel, badgeCount: 2, onTap: () => taps++,
    )));
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Filter'));
    expect(taps, 1);
  });

  testWidgets('AppPillButton selebar isinya, tidak melebar penuh di Wrap/Align', (tester) async {
    await pumpApp(tester, Scaffold(body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: AppPillButton(label: 'Reset', onPressed: () {})),
        Wrap(children: [AppPillButton(label: 'BCA', onPressed: () {})]),
      ],
    )));
    final screen = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getSize(find.widgetWithText(AppPillButton, 'Reset')).width, lessThan(screen / 2));
    expect(tester.getSize(find.widgetWithText(AppPillButton, 'BCA')).width, lessThan(screen / 2));
  });

  testWidgets('badge AppPill tetap bulat kecil (tidak setinggi pill)', (tester) async {
    await pumpApp(tester, Scaffold(body: Center(child: AppPill(
      label: 'Filter', icon: PhosphorIconsRegular.funnel, badgeCount: 1, onTap: () {},
    ))));
    final badge = tester.getSize(find.byType(AppCountBadge));
    expect(badge.height, lessThanOrEqualTo(20));
  });
}
