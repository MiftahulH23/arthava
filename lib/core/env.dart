/// Konfigurasi build yang diisi lewat `--dart-define-from-file=env.json`
/// (lihat `env.example.json` dan README). Tidak ada kunci yang di-commit.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasGemini => geminiApiKey.isNotEmpty;
}
