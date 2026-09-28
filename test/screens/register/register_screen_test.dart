import 'package:catat_uang_app/screens/register/register_screen.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
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

    expect(find.text('Buat akun baru'), findsOneWidget);
    expect(find.text('Gabung dan mulai atur keuanganmu'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget); // tombol kembali di hero
    expect(find.byIcon(PhosphorIconsBold.caretLeft), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.user), findsOneWidget);
    expect(find.text('Nama lengkap'), findsOneWidget); // hint
    expect(find.text('Minimal 6 karakter.'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
    expect(find.text('Masuk Disini'), findsOneWidget);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 3);
    expect(fields.every((f) => f.outlined), isTrue);
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

  testWidgets('isian hanya spasi ditolak dengan toast wajib diisi', (tester) async {
    await pumpApp(tester, const RegisterScreen());
    for (final f in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(f.widget), '   ');
    }
    await tester.tap(find.text('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Daftar dengan keyboard terbuka di HP kecil tidak overflow', (tester) async {
    await pumpApp(tester, const RegisterScreen(), size: const Size(320, 568));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Daftar Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
