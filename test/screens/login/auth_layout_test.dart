import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

var tapped = 0;

Widget _layout({bool withFooter = true}) => AuthLayout(
      title: 'Yuk, atur keuanganmu',
      subtitle: 'Tagline',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      footer: withFooter ? const Text('Kaki') : null,
      children: [
        AppTextField(controller: TextEditingController(), label: 'A', hint: 'a', outlined: true),
        AppTextField(controller: TextEditingController(), label: 'B', hint: 'b', outlined: true),
        AppTextField(controller: TextEditingController(), label: 'C', hint: 'c', outlined: true),
        AppPrimaryButton(label: 'Aksi', onPressed: () => tapped++),
      ],
    );

void main() {
  setUp(() => tapped = 0);

  testWidgets('menampilkan hero, isi sheet, dan footer', (tester) async {
    await pumpApp(tester, _layout());
    expect(find.text('Yuk, atur keuanganmu'), findsOneWidget);
    expect(find.text('Tagline'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.text('Kaki'), findsOneWidget);
  });

  testWidgets('sheet putih: latar layar surface', (tester) async {
    await pumpApp(tester, _layout());
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, AppColors.surface);
  });

  testWidgets('layar tinggi: tombol langsung di bawah isian, footer di dasar', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(390, 844));
    final gap = tester.getTopLeft(find.text('Aksi')).dy - tester.getBottomLeft(find.byType(AppTextField).last).dy;
    expect(gap, lessThan(40));
    expect(844 - tester.getBottomLeft(find.text('Kaki')).dy, closeTo(16, 0.5));
  });

  testWidgets('tanpa footer tetap dirender', (tester) async {
    await pumpApp(tester, _layout(withFooter: false));
    expect(tester.takeException(), isNull);
    expect(find.text('Kaki'), findsNothing);
  });

  testWidgets('HP kecil dengan keyboard: tidak overflow, tombol bisa di-scroll dan ditekan', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(320, 568));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Aksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aksi'));
    expect(tapped, 1);
  });

  testWidgets('teks diperbesar 1.3 di 320 lebar tidak overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, _layout(), size: const Size(320, 568));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tepi atas isian pertama bisa diketuk', (tester) async {
    await pumpApp(tester, _layout());
    final top = tester.getTopLeft(find.byType(TextField).first);
    await tester.tapAt(top + const Offset(60, 3));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus, isTrue);
  });

  testWidgets('safe area samping (landscape berponi) tidak menutupi isi', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(844, 600));
    tester.view.padding = const FakeViewPadding(left: 48, right: 48);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Yuk, atur keuanganmu')).dx, greaterThanOrEqualTo(48 + 24));
    expect(tester.getTopLeft(find.byType(AppTextField).first).dx, greaterThanOrEqualTo(48 + 20));
  });

  testWidgets('status bar ikon terang, nav bar Android ikut warna sheet', (tester) async {
    await pumpApp(tester, _layout());
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    expect(SystemChrome.latestStyle?.systemNavigationBarColor, AppColors.surface);
    expect(SystemChrome.latestStyle?.systemNavigationBarIconBrightness, Brightness.dark);
  });
}
