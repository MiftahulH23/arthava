import 'dart:convert';
import 'dart:io';

/// URL & anon key Supabase untuk E2E: dari env var `SUPABASE_URL` /
/// `SUPABASE_ANON_KEY` bila ada, kalau tidak dari `env.json` di root repo
/// (file yang sama dengan `flutter run --dart-define-from-file=env.json`).
({String url, String anonKey})? readSupabaseEnv() {
  var url = Platform.environment['SUPABASE_URL'] ?? '';
  var anonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
  final file = File('env.json');
  if ((url.isEmpty || anonKey.isEmpty) && file.existsSync()) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (url.isEmpty) url = (json['SUPABASE_URL'] as String?) ?? '';
    if (anonKey.isEmpty) anonKey = (json['SUPABASE_ANON_KEY'] as String?) ?? '';
  }
  if (url.isEmpty || anonKey.isEmpty) return null;
  return (url: url, anonKey: anonKey);
}
