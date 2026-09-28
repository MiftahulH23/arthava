import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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

  BoxDecoration ring(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
  Color prefixColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.envelopeSimple)).color!;

  testWidgets('outlined: garis tepi track, fokus menampilkan cincin dan ikon biru', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, hint: 'email', icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    final enabled = deco.enabledBorder! as OutlineInputBorder;
    expect(enabled.borderSide.color, AppColors.track);
    expect(enabled.borderSide.width, 1.5);
    expect((deco.focusedBorder! as OutlineInputBorder).borderSide.color, AppColors.primary);
    expect(ring(tester).boxShadow, anyOf(isNull, isEmpty));
    expect(prefixColor(tester), AppColors.textSecondary);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow!.single.color, AppColors.focusRing);
    expect(ring(tester).boxShadow!.single.spreadRadius, 4);
    expect(prefixColor(tester), AppColors.primary);
  });

  testWidgets('outlined memakai focusNode pemanggil tanpa men-dispose-nya', (tester) async {
    final controller = TextEditingController();
    final node = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(node.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, focusNode: node, icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    node.requestFocus();
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow, isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    // Node masih milik pemanggil: tidak boleh sudah di-dispose.
    expect(() => node.addListener(() {}), returnsNormally);
  });

  testWidgets('tanpa outlined: tetap tanpa garis tepi dan tanpa cincin', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'x')));
    final enabled = tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder! as OutlineInputBorder;
    expect(enabled.borderSide, BorderSide.none);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
