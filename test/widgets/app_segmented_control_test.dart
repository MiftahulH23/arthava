import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('memanggil onChanged dengan index yang ditap, bukan untuk segmen aktif', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: 0,
      onChanged: calls.add,
    )));
    await tester.tap(find.text('Pengeluaran'));
    await tester.tap(find.text('Pemasukan'));
    expect(calls, [1]);
  });

  testWidgets('warna teks terpilih mengikuti selectedLabelColors', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: 1,
      selectedLabelColors: const [AppColors.income, AppColors.expense],
      onChanged: (_) {},
    )));
    expect(tester.widget<Text>(find.text('Pengeluaran')).style!.color, AppColors.expense);
    expect(tester.widget<Text>(find.text('Pemasukan')).style!.color, AppColors.textPrimary);
  });

  testWidgets('tinggi 36', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['A', 'B', 'C'], selectedIndex: 2, onChanged: (_) {},
    )));
    expect(tester.getSize(find.byType(AppSegmentedControl)).height, 36);
  });
}
