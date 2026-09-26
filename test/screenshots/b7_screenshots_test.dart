@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:catat_uang_app/providers/edit_profile_provider.dart';
import 'package:catat_uang_app/screens/edit_profile/edit_profile_screen.dart';
import 'package:catat_uang_app/screens/lock/lock_screen.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/screens/register/register_screen.dart';
import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// Transitif lewat local_auth; tipe parameter authenticate() yang di-override.
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/types/auth_messages.dart';

import 'screenshot_harness.dart';

class _Auth extends LocalAuthentication {
  _Auth(this.result);
  final bool? result;

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
  }) =>
      result == null ? Completer<bool>().future : Future.value(result);
}

class _Profile extends EditProfileNotifier {
  @override
  EditProfileState build() => const EditProfileState();
}

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 login', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const LoginScreen());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_01_login');
  }, skip: skip);

  testWidgets('02 daftar akun', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const RegisterScreen());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_02_register');
  }, skip: skip);

  testWidgets('03 kunci aplikasi (gagal → Buka Kunci)', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, LockScreen(auth: _Auth(false)));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_03_lock');
  }, skip: skip);

  testWidgets('04 pengaturan', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, SettingsScreen(loadBiometricLock: () async => true, biometricAuth: _Auth(true)));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_04_settings');
  }, skip: skip);

  testWidgets('05 edit profil', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const EditProfileScreen(initialName: 'Miftahul Huda', initialEmail: 'akun.tes@email.com'),
      overrides: [editProfileProvider.overrideWith(_Profile.new)],
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_05_edit_profile');
  }, skip: skip);
}
