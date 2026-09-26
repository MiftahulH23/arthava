import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('Toast error memakai warna AppColors dan font tema', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppNotification.error(context, 'Nama tidak boleh kosong'),
            child: const Text('tes'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tes'));
    await tester.pump();

    final text = tester.widget<Text>(find.text('Nama tidak boleh kosong'));
    expect(text.style?.color, AppColors.textPrimary);
    expect(text.style?.fontFamily, isNot(contains('Poppins')));

    final icons = tester.widgetList<Icon>(find.byType(Icon)).where((i) => i.color == AppColors.expense);
    expect(icons, isNotEmpty);

    await tester.pump(const Duration(seconds: 4));
  });
}
