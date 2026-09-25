import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
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

  testWidgets('AppPill menampilkan badge dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPill(
      label: 'Filter', icon: PhosphorIconsRegular.funnel, badgeCount: 2, onTap: () => taps++,
    )));
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Filter'));
    expect(taps, 1);
  });
}
