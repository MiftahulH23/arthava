import 'dart:async';

import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Konfigurasi global untuk semua test di folder ini.
///
/// `appForuiTheme` dan `AppTextStyles` memakai font Plus Jakarta Sans lewat
/// `GoogleFonts`, dan
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
///
/// Binding diinisialisasi dulu supaya google_fonts gagal secara wajar (HTTP
/// ditolak di test) alih-alih error "Binding has not yet been initialized", dan
/// pesan cetak dari zona ini ditelan supaya output test bersih.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await runZonedGuarded(() async {
    appForuiTheme.typography.defaultFontFamily;
    // Sentuh semua gaya supaya unduhan font tiap bobot dimulai (dan gagal) di zona ini.
    for (final style in [
      AppTextStyles.largeTitle, AppTextStyles.title, AppTextStyles.headline,
      AppTextStyles.body, AppTextStyles.bodyStrong, AppTextStyles.subhead,
      AppTextStyles.caption, AppTextStyles.groupLabel, AppTextStyles.navLabel,
      AppTextStyles.amountHero, AppTextStyles.amountLarge, AppTextStyles.amountRow,
      AppTextStyles.button,
    ]) {
      style.fontFamily;
    }
  }, (_, _) {}, zoneSpecification: ZoneSpecification(
    // google_fonts mencetak pesan gagal-unduh di zona tempat font pertama kali
    // disentuh (zona ini saja); telan supaya output test bersih.
    print: (_, _, _, _) {},
  ));

  await testMain();
}
