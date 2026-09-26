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

  testWidgets('AppTextField menampilkan label kecil di atas input bila diberikan', (tester) async {
    final controller = TextEditingController(text: 'Akun Tes');
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Scaffold(body: AppTextField(controller: controller, label: 'Nama Lengkap')),
    );

    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Akun Tes'), findsOneWidget);
    final labelTop = tester.getTopLeft(find.text('Nama Lengkap')).dy;
    final inputTop = tester.getTopLeft(find.byType(EditableText)).dy;
    expect(labelTop, lessThan(inputTop));
  });

  testWidgets('AppTextField tanpa label tidak menambah teks apa pun', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'x')));
    expect(find.byType(Column), findsNothing);
  });
}
