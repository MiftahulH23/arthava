import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('chip terpilih putih di atas textPrimary, tap memanggil onChanged', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, Scaffold(body: AppChipTabs(
      labels: const ['Harian', 'Bulanan', 'Tahunan', 'Periode'],
      selectedIndex: 1,
      onChanged: calls.add,
    )));
    expect(tester.widget<Text>(find.text('Bulanan')).style!.color, Colors.white);
    expect(tester.widget<Text>(find.text('Harian')).style!.color, AppColors.textSecondary);
    await tester.ensureVisible(find.text('Periode'));
    await tester.tap(find.text('Periode'));
    expect(calls, [3]);
  });
}
