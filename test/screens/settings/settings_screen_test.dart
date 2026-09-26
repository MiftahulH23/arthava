import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// Transitif lewat local_auth; tipe parameter authenticate() yang di-override.
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeAuth extends LocalAuthentication {
  _FakeAuth({this.supported = true, this.result = true});
  final bool supported;
  final bool result;
  int calls = 0;

  @override
  Future<bool> get canCheckBiometrics async => supported;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    calls++;
    expect(localizedReason, 'Konfirmasi untuk mengaktifkan kunci DompetKu');
    return result;
  }
}

Future<List<bool>> _pumpBiometric(
  WidgetTester tester, {
  bool initial = false,
  _FakeAuth? auth,
  bool saveFails = false,
}) async {
  final saved = <bool>[];
  await pumpApp(
    tester,
    SettingsScreen(
      loadBiometricLock: () async => initial,
      saveBiometricLock: (v) async {
        if (saveFails) throw Exception('offline');
        saved.add(v);
      },
      biometricAuth: auth ?? _FakeAuth(),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

bool _switchValue(WidgetTester tester) => tester.widget<AppSwitch>(find.byType(AppSwitch).last).value;

void main() {
  testWidgets('Pengaturan menampilkan grup Umum dan Lainnya ala Settings iPhone', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('UMUM'), findsOneWidget);
    expect(find.text('LAINNYA'), findsOneWidget);
    expect(find.text('Profil Akun'), findsOneWidget);
    expect(find.text('Atur nama dan info akun'), findsOneWidget);
    expect(find.text('Tentang Aplikasi'), findsOneWidget);
    expect(find.text('Versi 1.0.0'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Logout dari akun'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.signOut), findsOneWidget);
  });

  testWidgets('Tentang Aplikasi menampilkan snackbar versi', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    await tester.tap(find.text('Tentang Aplikasi'));
    await tester.pump();

    expect(find.text('Aplikasi DompetKu v1.0 by Miftahul Huda'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('baris "Kunci dengan biometrik" tampil, default mati', (tester) async {
    await _pumpBiometric(tester);
    expect(find.text('Kunci dengan biometrik'), findsOneWidget);
    expect(find.text('Minta sidik jari / Face ID saat aplikasi dibuka'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.fingerprint), findsOneWidget);
    expect(_switchValue(tester), isFalse);
  });

  testWidgets('nyalakan: verifikasi biometrik berhasil → simpan true + toast', (tester) async {
    final auth = _FakeAuth();
    final saved = await _pumpBiometric(tester, auth: auth);
    await tester.tap(find.byType(AppSwitch).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.calls, 1);
    expect(saved, [true]);
    expect(_switchValue(tester), isTrue);
    expect(find.text('Kunci biometrik aktif.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('nyalakan tapi verifikasi dibatalkan → tidak disimpan, tetap mati', (tester) async {
    final saved = await _pumpBiometric(tester, auth: _FakeAuth(result: false));
    await tester.tap(find.byType(AppSwitch).last);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(_switchValue(tester), isFalse);
  });

  testWidgets('perangkat tidak mendukung → toast, tidak disimpan', (tester) async {
    final saved = await _pumpBiometric(tester, auth: _FakeAuth(supported: false));
    await tester.tap(find.byType(AppSwitch).last);
    await tester.pump();
    expect(find.text('Perangkat ini tidak mendukung biometrik.'), findsOneWidget);
    expect(saved, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('matikan: tanpa verifikasi → simpan false + toast', (tester) async {
    final auth = _FakeAuth();
    final saved = await _pumpBiometric(tester, initial: true, auth: auth);
    expect(_switchValue(tester), isTrue);
    await tester.tap(find.byType(AppSwitch).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.calls, 0);
    expect(saved, [false]);
    expect(find.text('Kunci biometrik dimatikan.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('gagal menyimpan → toast error, switch kembali', (tester) async {
    await _pumpBiometric(tester, saveFails: true);
    await tester.tap(find.byType(AppSwitch).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gagal menyimpan pengaturan.'), findsOneWidget);
    expect(_switchValue(tester), isFalse);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
