import 'package:catat_uang_app/screens/login/login_form.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/screens/login/register_form.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

Finder _primary(String label) => find.widgetWithText(AppPrimaryButton, label);

Future<void> _toDaftar(WidgetTester tester) async {
  await tester.tap(find.text('Daftar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tab Masuk tampil default sesuai mockup', (tester) async {
    await pumpApp(tester, const LoginScreen());
    expect(find.text('Yuk, atur keuanganmu'), findsOneWidget);
    expect(find.text('Masuk atau buat akun untuk mulai mencatat pemasukan dan pengeluaranmu.'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.wallet), findsOneWidget);
    expect(find.byType(LoginForm), findsOneWidget);
    expect(find.byType(RegisterForm), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(_primary('Masuk'), findsOneWidget);
    expect(find.text('atau masuk dengan'), findsOneWidget);
    expect(find.text('Lanjut dengan Google'), findsOneWidget);
    expect(find.text('Datamu hanya bisa dilihat dari akunmu sendiri.'), findsOneWidget);
    expect(find.textContaining('Facebook'), findsNothing);
    expect(find.text('Lupa password?'), findsNothing);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 2);
    expect(fields.every((f) => f.outlined), isTrue);
  });

  testWidgets('Masuk kosong menampilkan toast validasi', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await tester.tap(_primary('Masuk'));
    await tester.pump();
    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Masuk: isian hanya spasi ditolak', (tester) async {
    await pumpApp(tester, const LoginScreen());
    for (final f in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(f.widget), '   ');
    }
    await tester.tap(_primary('Masuk'));
    await tester.pump();
    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('ikon mata men-toggle visibilitas password', (tester) async {
    await pumpApp(tester, const LoginScreen());
    EditableText password() => tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(1);
    expect(password().obscureText, isTrue);
    await tester.tap(find.byIcon(PhosphorIconsRegular.eye));
    await tester.pump();
    expect(find.byIcon(PhosphorIconsRegular.eyeSlash), findsOneWidget);
    expect(password().obscureText, isFalse);
  });

  testWidgets('pindah ke tab Daftar menampilkan form daftar tanpa footer', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    expect(find.byType(RegisterForm), findsOneWidget);
    expect(find.text('Nama lengkap'), findsOneWidget);
    expect(find.text('Minimal 6 karakter.'), findsOneWidget);
    expect(_primary('Daftar Sekarang'), findsOneWidget);
    expect(find.text('atau daftar dengan'), findsOneWidget);
    expect(find.text('Datamu hanya bisa dilihat dari akunmu sendiri.'), findsNothing);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 3);
    expect(fields.every((f) => f.outlined), isTrue);
  });

  testWidgets('Daftar kosong dan spasi saja ditolak dengan pesan lama', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    await tester.ensureVisible(_primary('Daftar Sekarang'));
    await tester.tap(_primary('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    for (final f in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(f.widget), '   ');
    }
    await tester.ensureVisible(_primary('Daftar Sekarang'));
    await tester.tap(_primary('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  for (final tab in ['Masuk', 'Daftar']) {
    testWidgets('Google di tab $tab memunculkan info belum tersedia', (tester) async {
      await pumpApp(tester, const LoginScreen());
      if (tab == 'Daftar') await _toDaftar(tester);
      await tester.ensureVisible(find.text('Lanjut dengan Google'));
      await tester.tap(find.text('Lanjut dengan Google'));
      await tester.pump();
      expect(find.text('Login Google belum tersedia. Pakai email dan password dulu ya.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  }

  testWidgets('daftar berhasil: kembali ke tab Masuk dengan email terisi', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    tester.widget<RegisterForm>(find.byType(RegisterForm)).onRegistered('baru@contoh.com');
    await tester.pumpAndSettle();
    expect(find.byType(LoginForm), findsOneWidget);
    expect(find.text('baru@contoh.com'), findsOneWidget);
  });

  testWidgets('pindah tab tidak membuang form yang sedang memproses (tetap ter-mount)', (tester) async {
    await pumpApp(tester, const LoginScreen());
    final loginState = tester.state(find.byType(LoginForm));
    await _toDaftar(tester);
    final registerState = tester.state(find.byType(RegisterForm));
    expect(loginState.mounted, isTrue);
    expect(identical(tester.state(find.byType(LoginForm, skipOffstage: false)), loginState), isTrue);
    await tester.tap(find.text('Masuk').first);
    await tester.pumpAndSettle();
    expect(registerState.mounted, isTrue);
    expect(identical(tester.state(find.byType(RegisterForm, skipOffstage: false)), registerState), isTrue);
  });

  testWidgets('isian Daftar tetap ada setelah bolak-balik tab', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    await tester.enterText(find.byType(TextField).first, 'Miftahul Huda');
    await tester.tap(find.text('Masuk').first);
    await tester.pumpAndSettle();
    await _toDaftar(tester);
    expect(find.text('Miftahul Huda'), findsOneWidget);
  });

  testWidgets('setelah daftar berhasil, form Daftar kosong lagi', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    await tester.enterText(find.byType(TextField).first, 'Miftahul Huda');
    tester.widget<RegisterForm>(find.byType(RegisterForm)).onRegistered('baru@contoh.com');
    await tester.pumpAndSettle();
    await _toDaftar(tester);
    expect(find.text('Miftahul Huda'), findsNothing);
  });

  for (final tab in ['Masuk', 'Daftar']) {
    testWidgets('tab $tab dengan keyboard di HP kecil tidak overflow', (tester) async {
      await pumpApp(tester, const LoginScreen(), size: const Size(320, 568));
      if (tab == 'Daftar') await _toDaftar(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = _primary(tab == 'Masuk' ? 'Masuk' : 'Daftar Sekarang');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(
        find.text(tab == 'Masuk' ? 'Email dan Password wajib diisi!' : 'Semua kolom wajib diisi ya bos!'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  }

  testWidgets('geser layar pindah Masuk ↔ Daftar tanpa membuang isian', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await tester.timedDrag(find.text('Yuk, atur keuanganmu'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterForm), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Miftahul Huda');
    await tester.timedDrag(find.text('Yuk, atur keuanganmu'), const Offset(250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(LoginForm), findsOneWidget);
    await tester.timedDrag(find.text('Yuk, atur keuanganmu'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Miftahul Huda'), findsOneWidget);
  });
}
