import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppSwitch memakai CupertinoSwitch warna income', (tester) async {
    bool? value;
    await pumpApp(tester, Scaffold(body: AppSwitch(value: false, onChanged: (v) => value = v)));
    final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(sw.activeTrackColor, AppColors.income);
    await tester.tap(find.byType(CupertinoSwitch));
    expect(value, isTrue);
  });

  testWidgets('AppTextField meneruskan onChanged dan hint', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changed;
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, hint: 'Cari fitur', onChanged: (v) => changed = v,
    )));
    expect(find.text('Cari fitur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'anggar');
    expect(changed, 'anggar');
  });

  testWidgets('AppAmountField memformat ribuan dan prefix Rp selalu tampil', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppAmountField(controller: controller, label: 'Nominal')));
    expect(find.text('Rp'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1250000');
    expect(controller.text, '1.250.000');
  });

  testWidgets('AppAmountDisplay 15 digit tidak overflow di 360', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppAmountDisplay(
      label: 'Jumlah Uang', amountText: 'Rp 999.999.999.999.999',
    )), size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    expect(find.text('Jumlah Uang'), findsOneWidget);
  });
}
