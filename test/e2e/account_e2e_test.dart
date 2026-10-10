@Tags(['e2e'])
library;

// E2E backend B7 (Login, Edit Profil, Pengaturan) terhadap Supabase sungguhan,
// lewat kode ASLI app. Semua nilai akun (nama, saldo minimal, kunci biometrik)
// dikembalikan ke nilai awal di akhir. Daftar akun sengaja TIDAK dijalankan ke
// akun baru sungguhan (hindari akun sampah) — lihat test widget tab Daftar di LoginScreen.
//
//   E2E_EMAIL=... E2E_PASSWORD=... flutter test test/e2e/account_e2e_test.dart
//
// Tanpa env, test di-skip (tidak ikut `flutter test` biasa).
import '../../tool/e2e/e2e_env.dart';
import 'dart:io';

import 'package:catat_uang_app/providers/edit_profile_provider.dart';
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/services/biometric_lock_setting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// Transitif lewat supabase_flutter; hanya untuk menyiapkan test.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _email = Platform.environment['E2E_EMAIL'];
final _password = Platform.environment['E2E_PASSWORD'];
final _env = readSupabaseEnv();
final _skip = _email == null || _password == null || _env == null;

late SupabaseClient db;
late ProviderContainer container;
final _failures = <String>[];

void check(String label, bool ok, [Object? detail]) {
  if (!ok) _failures.add(label);
  // ignore: avoid_print
  print('${ok ? 'PASS' : 'FAIL'}  $label${ok || detail == null ? '' : '  ->  $detail'}');
}

void report(String name) {
  // ignore: avoid_print
  print(_failures.isEmpty ? '\nSEMUA LULUS ($name)' : '\n${_failures.length} GAGAL ($name): ${_failures.join(' | ')}');
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 1500));

void main() {
  setUpAll(() async {
    if (_skip) return;
    HttpOverrides.global = null; // flutter test memblokir HTTP; E2E butuh jaringan sungguhan.
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('id_ID', null);
    await Supabase.initialize(
      url: _env!.url,
      anonKey: _env!.anonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false, localStorage: EmptyLocalStorage()),
    );
    db = Supabase.instance.client;
    await db.auth.signInWithPassword(email: _email!, password: _password!);
    container = ProviderContainer();
  });

  test('akun: login, edit profil, pengaturan, keluar', () async {
    _failures.clear();
    final userId = db.auth.currentUser!.id;
    final profile = await db.from('profiles').select('name, include_min_balance, use_biometric_lock').eq('id', userId).single();
    final originalName = profile['name'] as String?;
    final originalMin = profile['include_min_balance'] as bool;
    final originalBio = profile['use_biometric_lock'] as bool;

    container.listen(editProfileProvider, (_, _) {});
    container.listen(homeProvider, (_, _) {});
    await settle();

    try {
      // ---------- Login ----------
      Object? wrong;
      try {
        await db.auth.signInWithPassword(email: _email!, password: '${_password!}-salah');
      } catch (e) {
        wrong = e;
      }
      check('L1 password salah ditolak (layar menampilkan "Email atau password salah.")', wrong is AuthException, wrong);
      check('L1 sesi yang ada tidak berubah', db.auth.currentUser?.id == userId);

      // ---------- Edit Profil ----------
      await container.read(editProfileProvider.notifier).updateProfile('E2E Nama Uji');
      final saved = await db.from('profiles').select('name').eq('id', userId).single();
      check('P1 nama baru tersimpan di profiles', saved['name'] == 'E2E Nama Uji', saved);
      check('P1 metadata auth ikut berubah', db.auth.currentUser?.userMetadata?['name'] == 'E2E Nama Uji',
          db.auth.currentUser?.userMetadata);
      await container.read(homeProvider.notifier).getUserProfile();
      check('P2 Beranda menampilkan nama baru', container.read(homeProvider).userName.contains('E2E Nama Uji'),
          container.read(homeProvider).userName);
      await container.read(editProfileProvider.notifier).fetchLatestName();
      check('P3 Edit Profil membaca nama terbaru', container.read(editProfileProvider).latestName == 'E2E Nama Uji');

      // ---------- Pengaturan ----------
      // "Hitung saldo minimal" diuji di wallet_transaction_e2e_test.dart (W-series);
      // tidak diubah di sini karena file E2E berjalan bersamaan di akun yang sama.
      await saveBiometricLockSetting(!originalBio);
      check('S2 kunci biometrik tersimpan & terbaca ulang', await loadBiometricLockSetting() == !originalBio);
      await saveBiometricLockSetting(originalBio);
      check('S2 kunci biometrik bisa dimatikan lagi', await loadBiometricLockSetting() == originalBio);
    } finally {
      await container.read(editProfileProvider.notifier).updateProfile(originalName ?? '');
      await db.from('profiles').update({
        'name': originalName,
        'use_biometric_lock': originalBio,
      }).eq('id', userId);
    }

    final restored = await db.from('profiles').select('name, include_min_balance, use_biometric_lock').eq('id', userId).single();
    check('R nilai akun kembali seperti semula',
        restored['name'] == originalName && restored['include_min_balance'] == originalMin && restored['use_biometric_lock'] == originalBio,
        restored);

    // ---------- Keluar & masuk lagi (paling akhir: file E2E lain memakai sesi masing-masing) ----------
    await db.auth.signOut();
    check('K1 keluar menghapus sesi', db.auth.currentUser == null);
    await db.auth.signInWithPassword(email: _email!, password: _password!);
    check('K2 masuk dengan email/password benar', db.auth.currentUser?.id == userId);

    report('akun');
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    if (_skip) return;
    container.dispose();
    await db.auth.signOut();
  });
}
