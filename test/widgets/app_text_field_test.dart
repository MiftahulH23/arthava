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

  testWidgets('isian biasa: sudut garis fokus 20 = radius kartu grouped section', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'Catatan')));
    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    final focused = deco.focusedBorder! as OutlineInputBorder;
    expect(focused.borderRadius, BorderRadius.circular(20));
    expect(focused.borderSide.color, AppColors.primary);
    expect((deco.enabledBorder! as OutlineInputBorder).borderRadius, BorderRadius.circular(20));
  });

  testWidgets('AppTextField tanpa label tidak menambah teks apa pun', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'x')));
    expect(find.byType(Column), findsNothing);
  });

  BoxDecoration box(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
  BoxDecoration ring(WidgetTester tester) => box(tester);
  Color borderColor(WidgetTester tester) => (box(tester).border! as Border).top.color;
  Color prefixColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.envelopeSimple)).color!;

  testWidgets('outlined: kotak bergaris track, fokus jadi biru dengan cincin', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, hint: 'email', icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(deco.border, InputBorder.none);
    expect(deco.enabledBorder, InputBorder.none);
    expect(deco.focusedBorder, InputBorder.none);
    expect(borderColor(tester), AppColors.track);
    expect((box(tester).border! as Border).top.width, 1.5);
    expect(box(tester).boxShadow, anyOf(isNull, isEmpty));
    expect(prefixColor(tester), AppColors.textSecondary);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(borderColor(tester), AppColors.primary);
    expect(box(tester).boxShadow!.single.color, AppColors.focusRing);
    expect(box(tester).boxShadow!.single.spreadRadius, 4);
    expect(prefixColor(tester), AppColors.primary);
  });

  testWidgets('outlined + label: label kecil di dalam kotak, di atas teks isian', (tester) async {
    final controller = TextEditingController(text: 'miftahul@contoh.com');
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: Padding(
      padding: const EdgeInsets.all(16),
      child: AppTextField(controller: controller, label: 'Email', hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple, outlined: true),
    )));

    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.labelText, 'Email');
    expect(find.descendant(of: find.byType(AnimatedContainer), matching: find.text('Email')), findsOneWidget);
    final labelRect = tester.getRect(find.text('Email'));
    final inputRect = tester.getRect(find.byType(EditableText));
    final boxRect = tester.getRect(find.byType(AnimatedContainer));
    expect(labelRect.bottom, lessThanOrEqualTo(inputRect.top + 1));
    expect(labelRect.top, greaterThan(boxRect.top));
    expect(labelRect.left, greaterThan(tester.getRect(find.byIcon(PhosphorIconsRegular.envelopeSimple)).right));
  });

  testWidgets('outlined + label pada teks 1.3x: tidak overflow, label tetap di atas teks dan di dalam kotak', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = TextEditingController(text: 'nama.panjang.sekali@contoh.com');
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: Center(child: SizedBox(width: 280, child: AppTextField(
      controller: controller, label: 'Email', icon: PhosphorIconsRegular.envelopeSimple, outlined: true)))),
      size: const Size(320, 568));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final labelRect = tester.getRect(find.text('Email'));
    final inputRect = tester.getRect(find.byType(EditableText));
    final boxRect = tester.getRect(find.byType(AnimatedContainer));
    expect(labelRect.bottom, lessThanOrEqualTo(inputRect.top + 1));
    expect(labelRect.top, greaterThan(boxRect.top));
    expect(inputRect.bottom, lessThanOrEqualTo(boxRect.bottom));
    expect(labelRect.left, greaterThan(tester.getRect(find.byIcon(PhosphorIconsRegular.envelopeSimple)).right));
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

  testWidgets('outlined: cincin tetap mengikuti fokus saat focusNode diganti (pemanggil → sendiri → pemanggil)', (tester) async {
    final controller = TextEditingController();
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    Future<void> pumpWith(FocusNode? node) => pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, focusNode: node, icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    await pumpWith(a);
    await pumpWith(null);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow, isNotEmpty);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow, isEmpty);

    await pumpWith(b);
    b.requestFocus();
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow, isNotEmpty);
    b.unfocus();
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow, isEmpty);
  });
}
