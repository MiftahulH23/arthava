import 'dart:async';

import 'package:catat_uang_app/theme/app_forui_theme.dart';

/// Konfigurasi global untuk semua test di folder ini.
///
/// `appForuiTheme` memetakan font Poppins lewat `GoogleFonts.poppins()`, dan
/// `google_fonts` mengunduh file font itu lewat HTTP secara async. Di
/// lingkungan test semua HTTP request dipaksa gagal (status 400), sehingga
/// unduhan yang gagal itu jadi unhandled async error yang dilaporkan sebagai
/// kegagalan pada test mana pun yang kebetulan pertama kali menyentuh
/// `appForuiTheme` — padahal assertion test-nya sendiri lolos.
///
/// Karena `appForuiTheme` adalah top-level `final` (lazy), cukup sentuh sekali
/// di sini — di luar zona test mana pun — supaya inisialisasinya (dan error
/// unduhan font-nya) tidak lagi dibebankan ke sebuah test. Error-nya ditelan
/// secara eksplisit di zona terpisah: font tidak tersedia di test memang wajar,
/// Flutter akan fallback ke font default dan itu tidak memengaruhi assertion
/// apa pun (nama font family tetap dikembalikan dengan benar).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await runZonedGuarded(() async {
    appForuiTheme.typography.defaultFontFamily;
  }, (_, _) {});

  await testMain();
}
