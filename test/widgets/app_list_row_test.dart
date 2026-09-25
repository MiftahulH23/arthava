import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('menampilkan judul, subjudul, value, chevron, dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsRegular.calendar, color: AppColors.primary),
      title: 'Bulan Laporan',
      subtitle: 'Pilih periode',
      value: 'September 2026',
      showChevron: true,
      onTap: () => taps++,
    )));
    expect(find.text('Bulan Laporan'), findsOneWidget);
    expect(find.text('Pilih periode'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.caretRight), findsOneWidget);
    await tester.tap(find.text('Bulan Laporan'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(AppListRow)).height, greaterThanOrEqualTo(56));
  });

  testWidgets('titleColor dipakai untuk judul (mis. Keluar merah)', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppListRow(title: 'Keluar', titleColor: AppColors.expense)));
    expect(tester.widget<Text>(find.text('Keluar')).style!.color, AppColors.expense);
  });

  testWidgets('AppIconTile tinted vs filled vs round', (tester) async {
    await pumpApp(tester, const Scaffold(body: Column(children: [
      AppIconTile(key: Key('t'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue),
      AppIconTile(key: Key('f'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue, filled: true),
      AppIconTile(key: Key('r'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue, round: true),
    ])));
    BoxDecoration deco(String k) => tester.widget<Container>(
      find.descendant(of: find.byKey(Key(k)), matching: find.byType(Container)).first,
    ).decoration! as BoxDecoration;
    expect(deco('t').color, isNot(AppColors.tintBlue));
    expect(deco('t').borderRadius, BorderRadius.circular(12));
    expect(deco('f').color, AppColors.tintBlue);
    expect(deco('r').shape, BoxShape.circle);
    final filledIcon = tester.widget<Icon>(find.descendant(of: find.byKey(const Key('f')), matching: find.byType(Icon)));
    expect(filledIcon.color, Colors.white);
  });
}
