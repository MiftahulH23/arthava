import 'package:supabase_flutter/supabase_flutter.dart';

/// Setting "Kunci dengan biometrik" user yang login (`profiles.use_biometric_lock`,
/// default mati). Dipakai Pengaturan (switch) dan AppEntryGate (cold start).
Future<bool> loadBiometricLockSetting() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;
  final row = await client.from('profiles').select('use_biometric_lock').eq('id', uid).maybeSingle();
  return (row?['use_biometric_lock'] as bool?) ?? false;
}

Future<void> saveBiometricLockSetting(bool value) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from('profiles')
      .update({'use_biometric_lock': value})
      .eq('id', client.auth.currentUser!.id)
      .select('id');
  // UPDATE tanpa baris profil tidak error di Postgres: jangan laporkan sukses.
  if (rows.isEmpty) throw StateError('Profil tidak ditemukan.');
}
