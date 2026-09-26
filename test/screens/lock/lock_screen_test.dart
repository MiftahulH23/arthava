import 'dart:async';

import 'package:catat_uang_app/screens/lock/lock_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// Transitif lewat local_auth; tipe parameter authenticate() yang di-override.
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({this.result});

  /// null = authenticate tidak pernah selesai (untuk menguji state loading).
  final bool? result;
  int authenticateCalls = 0;
  final _never = Completer<bool>();

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    authenticateCalls++;
    expect(localizedReason, 'Gunakan biometrik untuk membuka DompetKu');
    return result == null ? _never.future : Future.value(result);
  }
}

void main() {
  testWidgets('Biometrik gagal menampilkan tombol Buka Kunci yang memicu ulang', (tester) async {
    final auth = _FakeLocalAuth(result: false);
    await pumpApp(tester, LockScreen(auth: auth));
    await tester.pump(); // _checkBiometrics
    await tester.pump(); // authenticate selesai

    expect(find.text('Aplikasi Terkunci'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.lockSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.userFocus), findsOneWidget);
    expect(find.text('Aman bersama DompetKu'), findsOneWidget);
    expect(find.text('Buka Kunci'), findsOneWidget);
    expect(auth.authenticateCalls, 1);

    await tester.tap(find.text('Buka Kunci'));
    await tester.pump();
    await tester.pump();
    expect(auth.authenticateCalls, 2);
  });

  testWidgets('Selama verifikasi tampil spinner dan teks, tanpa tombol', (tester) async {
    await pumpApp(tester, LockScreen(auth: _FakeLocalAuth()));
    await tester.pump();

    expect(find.text('Sedang memverifikasi...'), findsOneWidget);
    expect(find.text('Buka Kunci'), findsNothing);
  });
}
