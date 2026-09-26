import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('Login menampilkan layout iOS sesuai mockup', (tester) async {
    await pumpApp(tester, const LoginScreen());

    expect(find.text('DompetKu'), findsWidgets);
    expect(find.text('Cerdas mengelola, tenang finansial'), findsOneWidget);
    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Silakan masuk untuk melanjutkan'), findsOneWidget);
    expect(find.text('Masuk Sekarang'), findsOneWidget);
    expect(find.text('Daftar Disini'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.wallet), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.envelopeSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.lockKey), findsOneWidget);
    // Label field lama sengaja tidak ditampilkan (mockup: placeholder saja).
    expect(find.text('Alamat Email'), findsNothing);
  });

  testWidgets('Login kosong menampilkan toast validasi tanpa menyentuh Supabase', (tester) async {
    await pumpApp(tester, const LoginScreen());

    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pump();

    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    // Toast AppNotification memakai Timer 3 detik; habiskan supaya tidak ada timer tertunda.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Ikon mata men-toggle visibilitas password', (tester) async {
    await pumpApp(tester, const LoginScreen());

    // Urutan field: email (index 0) lalu password (index 1).
    EditableText passwordField() =>
        tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(1);

    expect(find.byIcon(PhosphorIconsRegular.eye), findsOneWidget);
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(PhosphorIconsRegular.eye));
    await tester.pump();

    expect(find.byIcon(PhosphorIconsRegular.eyeSlash), findsOneWidget);
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('isian hanya spasi ditolak dengan toast wajib diisi', (tester) async {
    await pumpApp(tester, const LoginScreen());
    for (final f in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(f.widget), '   ');
    }
    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pump();
    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
