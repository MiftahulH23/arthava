import 'package:catat_uang_app/screens/register/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

Future<void> _openRegister(WidgetTester tester) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text('buka'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Daftar Akun menampilkan layout sesuai mockup', (tester) async {
    await _openRegister(tester);

    expect(find.text('Daftar Akun'), findsWidgets);
    expect(find.text('Gabung dan mulai atur keuanganmu'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget); // label tombol kembali nav bar
    expect(find.byIcon(PhosphorIconsFill.userCirclePlus), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.user), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
    expect(find.text('Masuk Disini'), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsNothing);
  });

  testWidgets('Daftar kosong menampilkan toast validasi', (tester) async {
    await _openRegister(tester);

    await tester.tap(find.text('Daftar Sekarang'));
    await tester.pump();

    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('"Masuk Disini" dan tombol kembali menutup layar', (tester) async {
    await _openRegister(tester);
    await tester.tap(find.text('Masuk Disini'));
    await tester.pumpAndSettle();
    expect(find.text('buka'), findsOneWidget);

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('buka'), findsOneWidget);
  });
}
