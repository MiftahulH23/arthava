import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppTextField meneruskan autofocus dan textCapitalization', (tester) async {
    final controller = TextEditingController();
    await pumpApp(
      tester,
      Scaffold(
        body: AppTextField(
          controller: controller,
          hint: 'Nama',
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.textCapitalization, TextCapitalization.sentences);
  });
}
