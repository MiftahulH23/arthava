import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

var tapped = 0;

Widget _layout() => AuthLayout(
      title: 'DompetKu',
      subtitle: 'Tagline',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      sheetTitle: 'Masuk ke akunmu',
      fields: [
        AppTextField(controller: TextEditingController(), hint: 'a', outlined: true),
        AppTextField(controller: TextEditingController(), hint: 'b', outlined: true),
        AppTextField(controller: TextEditingController(), hint: 'c', outlined: true),
      ],
      action: AppPrimaryButton(label: 'Aksi', onPressed: () => tapped++),
      footer: AuthFooter(prompt: 'Belum? ', action: 'Daftar', onTap: () {}),
    );

void main() {
  setUp(() => tapped = 0);

  testWidgets('menampilkan hero, judul sheet, isian, tombol, footer', (tester) async {
    await pumpApp(tester, _layout());
    expect(find.text('DompetKu'), findsOneWidget);
    expect(find.text('Tagline'), findsOneWidget);
    expect(find.text('Masuk ke akunmu'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.text('Daftar'), findsOneWidget);
  });

  testWidgets('layar tinggi: tombol menempel dekat bawah', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(390, 844));
    expect(tester.getBottomLeft(find.text('Daftar')).dy, greaterThan(760));
    expect(tester.getTopLeft(find.text('Aksi')).dy - tester.getBottomLeft(find.text('c')).dy, greaterThan(100));
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

  testWidgets('AuthBackButton memanggil onTap', (tester) async {
    var back = 0;
    await pumpApp(tester, Scaffold(body: ColoredBox(
      color: Colors.black, child: AuthBackButton(label: 'Masuk', onTap: () => back++))));
    await tester.tap(find.text('Masuk'));
    expect(back, 1);
    expect(find.byIcon(PhosphorIconsBold.caretLeft), findsOneWidget);
  });
}
