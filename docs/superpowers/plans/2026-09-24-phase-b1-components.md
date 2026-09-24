# Phase B1 — Komponen Bersama iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun seluruh fondasi UI Phase B (warna tambahan, `AppTextStyles`, formatter Rupiah, 20+ komponen bersama gaya iOS, helper test `pumpApp`) persis sesuai kontrak API di spec §6, sehingga Plan B2–B7 tinggal merakit screen.

**Architecture:** Semua komponen adalah widget stateless/stateful kecil di `lib/widgets/`, satu tanggung jawab per file (beberapa widget yang selalu dipakai bersama digabung dalam satu file sesuai kontrak). Warna hanya dari `AppColors`, teks hanya dari `AppTextStyles`. Tidak ada dependency baru. Setiap komponen punya widget test yang mengunci perilaku yang diandalkan plan berikutnya.

**Tech Stack:** Flutter 3.38.5 (Dart ^3.10.4), `google_fonts` (Plus Jakarta Sans), `phosphor_flutter`, `intl`, `flutter_riverpod` 2.6.1, `forui` 0.17.0 (hanya lewat `showAppBottomSheet` yang sudah ada), `flutter/cupertino.dart` (CupertinoSwitch, CupertinoAlertDialog).

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (baca §3–§6 dan §9 sebelum mulai). Mockup: `docs/design/dompetku-redesign-mockup.html`.

## Global Constraints

- Branch: `redesign/phase-b1-components` dibuat dari `main`.
- Nama class/fungsi/parameter WAJIB persis seperti spec §6 (plan B2–B7 bergantung padanya). Parameter tambahan hanya yang tercantum di "Penyesuaian kontrak" di bawah.
- Warna hanya dari `AppColors` (+ `Colors.white`, `Colors.transparent`, `Colors.black` untuk bayangan). Tidak ada hex di `lib/widgets/`.
- Teks hanya dari `AppTextStyles` (atau `.copyWith`). Tidak ada `GoogleFonts.poppins` di file baru.
- Pakai `color.withValues(alpha: x)` (bukan `withOpacity`) di file baru; campuran "warna X% di atas putih" = `Color.alphaBlend(color.withValues(alpha: x), AppColors.surface)`.
- Ikon hanya `phosphor_flutter` (Regular; Fill untuk emfasis).
- Tidak ada dependency baru di `pubspec.yaml`.
- Jangan `dart format` file yang sudah ada secara keseluruhan; file BARU boleh ditulis rapi apa adanya dari plan ini.
- Token ukuran dari spec §4.2: padding halaman 18, jarak blok 14, radius kartu 24, radius grup 20, radius hero 28, radius sheet 28, baris min 56 (padding 12/16), tile 40 radius 12 ikon 20, inset separator 68/16 tebal 0.5, segmented tinggi 36 radius 10 pill 8, chip tabs tinggi 30 radius 15, tombol utama 52 radius 16, tombol kecil 36 radius 12, progress 8.
- Setiap commit diakhiri baris atribusi sesi:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
  ```
- Sebelum tiap commit: `git checkout -- linux macos windows` (file registrant plugin berubah line-ending saja).

## Penyesuaian kontrak (dibanding spec §6)

Tambahan parameter OPSIONAL (tidak mengubah yang sudah ada) — plan B2–B7 boleh memakainya:

1. `AppTextField`: tambah `onChanged` (`ValueChanged<String>?`) dan `inputFormatters` (`List<TextInputFormatter>?`). Dibutuhkan kolom cari "Semua Fitur" (B3) dan field nominal di form.
2. `AppSwipeActions`: tambah `deleteConfirmTitle` (default `'Hapus?'`) dan `deleteConfirmMessage` (default `'Data ini akan dihapus permanen.'`) supaya screen bisa memakai teks dialog aslinya (mis. "Hapus Transaksi?").
3. `AppPageScaffold`: konstanta publik `AppPageScaffold.horizontalPadding = 18` dan `AppPageScaffold.blockGap = 14` untuk dipakai screen yang merakit baris manual.
4. `AppNavAction`: tambah field `tooltip` internal (tidak di constructor) — `.add` otomatis bertooltip "Tambah".

Tidak ada nama/parameter di spec §6 yang diubah atau dihapus.

## Review Focus

1. Nominal sangat besar (15 digit) di `AppHeroAmount`/`AppAmountDisplay` di layar 360 pt — harus mengecil (FittedBox), tidak overflow kuning-hitam. Test di Task 6 & 9.
2. `AppSwipeActions` di dalam `AppGroupedSection` (baris putih): tombol aksi tidak boleh terlihat menembus baris saat tertutup (child harus berlatar opaque), dan tap baris saat terbuka harus menutup, bukan memicu `onTap` baris. Test di Task 10.
3. `RupiahInputFormatter` saat user menempel teks campur ("Rp 1.250.000,-") atau menghapus semua digit — hasil harus "1.250.000" / "" tanpa exception. Test di Task 1.
4. `AppPageScaffold(embedded: true)` di dalam Home dengan `extendBody` — konten terakhir harus bisa discroll keluar dari bawah navbar (padding bawah = 24 + `MediaQuery.padding.bottom`). Test di Task 3.
5. `AppProgressBar`/`AppProgressRing` dengan nilai di luar 0..1 (over budget 113%, NaN dari pembagian 0/0) — harus dijepit tanpa exception. Test di Task 7.

---

### Task 1: Formatter Rupiah

**Files:**
- Create: `lib/core/formatters.dart`
- Test: `test/core/formatters_test.dart`

**Interfaces:**
- Consumes: `package:intl` (`NumberFormat`).
- Produces:
  - `String formatRupiah(num value)` → `"Rp 1.250.000"`, negatif `"-Rp 1.250.000"`, dibulatkan ke rupiah.
  - `String formatRupiahSigned(num value, {required bool isIncome})` → `"+Rp 45.000"` / `"-Rp 45.000"` (tanda dari `isIncome`, nilai absolut).
  - `String formatRupiahCompact(num value)` → `"Rp 8,2 jt"`, `"Rp 742 rb"`, `"Rp 1,5 rb"`, `"Rp 950"`, negatif diawali `-`.
  - `int parseRupiah(String text)` → hanya digit (maks 15), kosong/sampah → `0`.
  - `class RupiahInputFormatter extends TextInputFormatter` (`static const int maxDigits = 15`).

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/core/formatters_test.dart
import 'package:catat_uang_app/core/formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _apply(String oldText, String newText) {
  return RupiahInputFormatter().formatEditUpdate(
    TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: oldText.length)),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length)),
  );
}

void main() {
  group('formatRupiah', () {
    test('memakai titik ribuan dan prefix Rp', () {
      expect(formatRupiah(1250000), 'Rp 1.250.000');
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(950), 'Rp 950');
    });
    test('negatif diawali minus', () {
      expect(formatRupiah(-45000), '-Rp 45.000');
    });
    test('dibulatkan ke rupiah terdekat', () {
      expect(formatRupiah(1999.6), 'Rp 2.000');
      expect(formatRupiah(-0.4), 'Rp 0');
    });
  });

  group('formatRupiahSigned', () {
    test('tanda mengikuti isIncome, nilai absolut', () {
      expect(formatRupiahSigned(45000, isIncome: true), '+Rp 45.000');
      expect(formatRupiahSigned(45000, isIncome: false), '-Rp 45.000');
      expect(formatRupiahSigned(-45000, isIncome: false), '-Rp 45.000');
    });
  });

  group('formatRupiahCompact', () {
    test('cabang juta', () {
      expect(formatRupiahCompact(8200000), 'Rp 8,2 jt');
      expect(formatRupiahCompact(5000000), 'Rp 5 jt');
      expect(formatRupiahCompact(1250000000), 'Rp 1.250 jt');
    });
    test('cabang ribu', () {
      expect(formatRupiahCompact(742000), 'Rp 742 rb');
      expect(formatRupiahCompact(1500), 'Rp 1,5 rb');
    });
    test('cabang polos', () {
      expect(formatRupiahCompact(950), 'Rp 950');
      expect(formatRupiahCompact(0), 'Rp 0');
    });
    test('negatif', () {
      expect(formatRupiahCompact(-3100000), '-Rp 3,1 jt');
    });
  });

  group('parseRupiah', () {
    test('membaca format lengkap', () {
      expect(parseRupiah('Rp 1.250.000'), 1250000);
      expect(parseRupiah('1.250.000'), 1250000);
    });
    test('kosong dan sampah jadi 0', () {
      expect(parseRupiah(''), 0);
      expect(parseRupiah('abc'), 0);
      expect(parseRupiah('Rp '), 0);
    });
    test('dibatasi 15 digit', () {
      expect(parseRupiah('1234567890123456789'), 123456789012345);
    });
  });

  group('RupiahInputFormatter', () {
    test('menyisipkan titik ribuan dan kursor di akhir', () {
      final v = _apply('', '1250000');
      expect(v.text, '1.250.000');
      expect(v.selection, const TextSelection.collapsed(offset: 9));
    });
    test('membersihkan teks tempelan campur', () {
      expect(_apply('', 'Rp 1.250.000,-').text, '1.250.000');
    });
    test('menghapus semua digit menghasilkan string kosong', () {
      final v = _apply('5', '');
      expect(v.text, '');
      expect(v.selection, const TextSelection.collapsed(offset: 0));
    });
    test('membuang nol di depan', () {
      expect(_apply('', '000450').text, '450');
    });
    test('dibatasi 15 digit', () {
      final v = _apply('', '9999999999999999999');
      expect(v.text, '999.999.999.999.999');
      expect(v.selection.baseOffset, v.text.length);
    });
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/core/formatters_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'catat_uang_app' ... formatters.dart` / "Method not found: 'formatRupiah'".

- [ ] **Step 3: Implementasi**

```dart
// lib/core/formatters.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern('id_ID');
final NumberFormat _compact = NumberFormat('#,##0.#', 'id_ID');

/// "Rp 1.250.000"; negatif -> "-Rp 1.250.000". Dibulatkan ke rupiah.
String formatRupiah(num value) {
  final rounded = value.round();
  final text = 'Rp ${_grouped.format(rounded.abs())}';
  return rounded < 0 ? '-$text' : text;
}

/// "+Rp 45.000" bila [isIncome], "-Rp 45.000" bila tidak. Nilai selalu absolut.
String formatRupiahSigned(num value, {required bool isIncome}) {
  return '${isIncome ? '+' : '-'}${formatRupiah(value.abs())}';
}

/// "Rp 8,2 jt", "Rp 742 rb", "Rp 950". Untuk ruang sempit (kartu hero, widget).
String formatRupiahCompact(num value) {
  final abs = value.abs();
  final String body;
  if (abs >= 1000000) {
    body = 'Rp ${_compact.format(abs / 1000000)} jt';
  } else if (abs >= 1000) {
    body = 'Rp ${_compact.format(abs / 1000)} rb';
  } else {
    body = 'Rp ${_grouped.format(abs.round())}';
  }
  return value < 0 && abs.round() != 0 ? '-$body' : body;
}

/// Mengambil digit saja (maks [RupiahInputFormatter.maxDigits]); kosong/sampah -> 0.
int parseRupiah(String text) {
  var digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  if (digits.length > RupiahInputFormatter.maxDigits) {
    digits = digits.substring(0, RupiahInputFormatter.maxDigits);
  }
  return int.tryParse(digits) ?? 0;
}

/// Hanya digit, sisip titik ribuan, maks 15 digit, kursor selalu di akhir.
class RupiahInputFormatter extends TextInputFormatter {
  static const int maxDigits = 15;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final text = _grouped.format(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/core/formatters_test.dart`
Expected: PASS (semua test di file).

Catatan: bila `formatRupiahCompact(1250000000)` menghasilkan `"Rp 1.250 jt"` tetapi `NumberFormat('#,##0.#')` membulatkan `8.2` menjadi `8,2` — sudah sesuai. Jika assertion `1.500 → "1,5 rb"` gagal karena pemisah desimal, pastikan locale `'id_ID'` dipakai di `_compact` (pemisah desimal koma).

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/core/formatters.dart test/core/formatters_test.dart
git commit -m "$(cat <<'EOF'
feat(core): add shared Rupiah formatters and input formatter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: Warna tambahan, `AppTextStyles`, konfigurasi test, helper `pumpApp`

**Files:**
- Modify: `lib/core/colors.dart` (tambah konstanta di akhir class, edit terarah)
- Create: `lib/theme/app_text_styles.dart`
- Modify: `test/flutter_test_config.dart`
- Create: `test/helpers/pump_app.dart`
- Test: `test/theme/app_text_styles_test.dart`

**Interfaces:**
- Consumes: `AppColors` yang sudah ada (`primary`, `background`, `textPrimary`, `textSecondary`, `heroLabel`, dll).
- Produces:
  - `AppColors.surface, track, separator, primarySoft, accentSoft, tintRed, tintOrange, tintAmber, tintTeal, tintBlue, tintIndigo, tintPink, tintBrown, tintGreen, tintSky, tintGray` (nilai spec §4.1).
  - `abstract final class AppTextStyles` dengan `static final TextStyle largeTitle, title, headline, body, bodyStrong, subhead, caption, groupLabel, navLabel, amountHero, amountLarge, amountRow, button`.
  - `Future<void> pumpApp(WidgetTester tester, Widget child, {List<Override> overrides = const [], Size size = const Size(390, 844)})`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/theme/app_text_styles_test.dart
import 'dart:ui' show FontFeature;

import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('AppColors punya token Phase B dengan nilai spec', () {
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.track, const Color(0xFFE5E5EA));
    expect(AppColors.separator, const Color(0xFFD8D8DD));
    expect(AppColors.primarySoft, const Color(0xFFE5F1FF));
    expect(AppColors.accentSoft, const Color(0xFFFFF1DC));
    expect(AppColors.tintOrange, const Color(0xFFF0913A));
    expect(AppColors.tintGray, const Color(0xFF8E8E93));
  });

  test('AppTextStyles memakai Plus Jakarta Sans dan skala spec', () {
    expect(AppTextStyles.largeTitle.fontFamily, contains('PlusJakartaSans'));
    expect(AppTextStyles.largeTitle.fontSize, 32);
    expect(AppTextStyles.largeTitle.fontWeight, FontWeight.w800);
    expect(AppTextStyles.body.fontSize, 16);
    expect(AppTextStyles.caption.fontSize, 12);
    expect(AppTextStyles.caption.color, AppColors.textSecondary);
    expect(AppTextStyles.navLabel.color, AppColors.primary);
    expect(AppTextStyles.amountHero.color, Colors.white);
  });

  test('gaya nominal memakai angka tabular', () {
    for (final style in [AppTextStyles.amountHero, AppTextStyles.amountLarge, AppTextStyles.amountRow]) {
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  testWidgets('pumpApp menyiapkan ukuran HP dan locale id_ID', (tester) async {
    late Locale locale;
    await pumpApp(tester, Builder(builder: (context) {
      locale = Localizations.localeOf(context);
      return const Text('halo');
    }));
    expect(find.text('halo'), findsOneWidget);
    expect(locale, const Locale('id', 'ID'));
    expect(tester.view.physicalSize, const Size(390, 844));
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/theme/app_text_styles_test.dart`
Expected: FAIL — `Undefined name 'AppTextStyles'` / `Member not found: 'surface'` / `pump_app.dart` tidak ada.

- [ ] **Step 3a: Tambah warna di `lib/core/colors.dart`**

Tambahkan tepat sebelum `}` penutup class `AppColors` (jangan ubah baris yang sudah ada):

```dart
  // --- Phase B (spec §4.1) ---
  static const Color surface = Color(0xFFFFFFFF); // Kartu, grouped list, field
  static const Color track = Color(0xFFE5E5EA); // Track segmented/progress, switch off
  static const Color separator = Color(0xFFD8D8DD); // Garis pemisah baris grouped list
  static const Color primarySoft = Color(0xFFE5F1FF); // Latar tombol soft, callout info
  static const Color accentSoft = Color(0xFFFFF1DC); // Callout rekomendasi, chip tempo
  static const Color tintRed = Color(0xFFE0564F);
  static const Color tintOrange = Color(0xFFF0913A); // Peringatan >80%, tombol Transfer/Tarik
  static const Color tintAmber = Color(0xFFD9A21B);
  static const Color tintTeal = Color(0xFF2FA39A); // Chip "Mutasi Internal"
  static const Color tintBlue = Color(0xFF4A7FE0); // Tombol edit (pensil)
  static const Color tintIndigo = Color(0xFF6A67CE);
  static const Color tintPink = Color(0xFFD8578C);
  static const Color tintBrown = Color(0xFF8A5A44);
  static const Color tintGreen = Color(0xFF2E9E68);
  static const Color tintSky = Color(0xFF3AA6D8);
  static const Color tintGray = Color(0xFF8E8E93); // Ikon netral (mutasi internal)
```

- [ ] **Step 3b: Buat `lib/theme/app_text_styles.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Skala teks Phase B (spec §5). Semua screen memakai ini, bukan GoogleFonts langsung.
abstract final class AppTextStyles {
  static final TextStyle largeTitle = GoogleFonts.plusJakartaSans(
    fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15,
    color: AppColors.textPrimary,
  );
  static final TextStyle title = GoogleFonts.plusJakartaSans(
    fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static final TextStyle headline = GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static final TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static final TextStyle bodyStrong = GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static final TextStyle subhead = GoogleFonts.plusJakartaSans(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
  static final TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
  static final TextStyle groupLabel = GoogleFonts.plusJakartaSans(
    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textSecondary,
  );
  static final TextStyle navLabel = GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.primary,
  );
  static final TextStyle amountHero = GoogleFonts.plusJakartaSans(
    fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Colors.white,
    fontFeatures: _tabular,
  );
  static final TextStyle amountLarge = GoogleFonts.plusJakartaSans(
    fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );
  static final TextStyle amountRow = GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );
  static final TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
  );
}
```

- [ ] **Step 3c: Perbarui `test/flutter_test_config.dart`**

`GoogleFonts` mengunduh file font per bobot secara async dan unduhan gagal di test. Sama seperti `appForuiTheme`, semua `AppTextStyles` disentuh sekali di zona terpisah supaya error unduhannya tidak jatuh ke test mana pun. Ganti isi fungsi `testExecutable` jadi:

```dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
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
  }, (_, _) {});

  await testMain();
}
```

Tambahkan import `import 'package:catat_uang_app/theme/app_text_styles.dart';` di atas file, dan tambahkan satu kalimat di doc comment: "Hal yang sama berlaku untuk `AppTextStyles` (Phase B)."

- [ ] **Step 3d: Buat `test/helpers/pump_app.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Memompa [child] seperti di aplikasi: ProviderScope (dengan [overrides]),
/// MaterialApp locale id_ID + delegasi lokalisasi, FTheme(appForuiTheme),
/// dan ukuran layar HP [size] (logical pixel, devicePixelRatio 1).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
}) async {
  await initializeDateFormatting('id_ID', null);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: AppColors.background,
        ),
        builder: (context, navChild) => FTheme(data: appForuiTheme, child: navChild!),
        home: child,
      ),
    ),
  );
  await tester.pump();
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/theme/app_text_styles_test.dart`
Expected: PASS.

Lalu jalankan seluruh suite untuk memastikan konfigurasi test tidak merusak test lama:
Run: `flutter test`
Expected: semua lulus kecuali `test/widget_test.dart` (counter, sudah gagal sejak dulu — dihapus di Task 11).

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/core/colors.dart lib/theme/app_text_styles.dart test/flutter_test_config.dart test/helpers/pump_app.dart test/theme/app_text_styles_test.dart
git commit -m "$(cat <<'EOF'
feat(theme): add Phase B color tokens, AppTextStyles, and pumpApp test helper

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: `AppPageScaffold` + `AppNavAction`

**Files:**
- Create: `lib/widgets/app_page_scaffold.dart`
- Test: `test/widgets/app_page_scaffold_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles` (Task 2).
- Produces (persis spec §6):
  - `AppPageScaffold({required String title, String? backLabel, List<Widget> actions = const [], required List<Widget> children, Widget? bottomBar, Future<void> Function()? onRefresh, bool embedded = false, bool largeTitle = true, Widget? titleWidget, Key? key})`
  - `static const double AppPageScaffold.horizontalPadding = 18`, `static const double AppPageScaffold.blockGap = 14`
  - `AppNavAction.add({required VoidCallback onPressed, Key? key})`, `AppNavAction.text(String label, {required VoidCallback onPressed, Key? key})`, `AppNavAction.icon(IconData icon, {required VoidCallback onPressed, Color? color, Key? key})`
- Perilaku:
  - Nav bar (tinggi 44) muncul bila `backLabel != null || actions.isNotEmpty || !largeTitle`. Kiri: chevron + `backLabel` (primary) → `Navigator.maybePop`. Tengah: `title` kecil (headline) hanya bila `largeTitle == false`. Kanan: `actions` berjarak 4.
  - `largeTitle == true`: judul besar (`titleWidget` bila diberikan menggantikan teks judul) jadi item pertama list.
  - `largeTitle == false` dan `titleWidget != null`: `titleWidget` jadi item pertama list (mis. header avatar Detail Utang).
  - `children` dirender berjarak `blockGap`, padding horizontal 18, padding bawah `24 + (embedded ? MediaQuery.padding.bottom : 0)`.
  - `bottomBar` menempel di bawah luar area scroll, padding `18, 8, 18, 12 (+ padding.bottom bila embedded)`.
  - `embedded == true`: TIDAK ada `Scaffold`; dibungkus `SafeArea(bottom: false)`. `embedded == false`: `Scaffold(backgroundColor: AppColors.background, body: SafeArea(...))`.
  - `onRefresh` → `RefreshIndicator(color: AppColors.primary)` dengan list `AlwaysScrollableScrollPhysics`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_page_scaffold_test.dart
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('mode biasa punya Scaffold, judul besar, dan jarak antar blok 14', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Anggaran',
      children: [SizedBox(key: Key('a'), height: 10), SizedBox(key: Key('b'), height: 10)],
    ));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Anggaran'), findsOneWidget);
    final a = tester.getBottomLeft(find.byKey(const Key('a')));
    final b = tester.getTopLeft(find.byKey(const Key('b')));
    expect(b.dy - a.dy, AppPageScaffold.blockGap);
    expect(a.dx, AppPageScaffold.horizontalPadding);
  });

  testWidgets('embedded tanpa Scaffold dan menambah padding bawah navbar', (tester) async {
    await pumpApp(tester, const MediaQuery(
      data: MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(bottom: 100)),
      child: AppPageScaffold(title: 'Transaksi', embedded: true, children: [Text('isi')]),
    ));
    expect(find.byType(Scaffold), findsNothing);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.padding! as EdgeInsets).bottom, 124);
  });

  testWidgets('tombol kembali memakai backLabel dan menutup halaman', (tester) async {
    await pumpApp(tester, Builder(builder: (context) {
      return Scaffold(body: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const AppPageScaffold(title: 'Detail', backLabel: 'Beranda', children: []),
        )),
        child: const Text('buka'),
      ));
    }));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget);
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('AppNavAction.add dan .text memanggil onPressed', (tester) async {
    var added = 0;
    var edited = 0;
    await pumpApp(tester, AppPageScaffold(
      title: 'Utang',
      actions: [
        AppNavAction.text('Edit', onPressed: () => edited++),
        AppNavAction.add(onPressed: () => added++),
      ],
      children: const [],
    ));
    await tester.tap(find.text('Edit'));
    await tester.tap(find.byTooltip('Tambah'));
    expect(edited, 1);
    expect(added, 1);
  });

  testWidgets('largeTitle false menaruh judul kecil di nav dan titleWidget di list', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Detail Utang',
      largeTitle: false,
      titleWidget: Text('BS'),
      children: [],
    ));
    expect(find.text('Detail Utang'), findsOneWidget);
    expect(find.text('BS'), findsOneWidget);
  });

  testWidgets('bottomBar dirender di luar list', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Export',
      bottomBar: Text('Cetak'),
      children: [],
    ));
    expect(find.descendant(of: find.byType(ListView), matching: find.text('Cetak')), findsNothing);
    expect(find.text('Cetak'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_page_scaffold_test.dart`
Expected: FAIL — `app_page_scaffold.dart` tidak ditemukan.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_page_scaffold.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Kerangka halaman gaya iOS (spec G1, G2, G13): nav bar tipis, judul besar
/// rata kiri, isi yang discroll, dan bottom bar opsional.
///
/// `embedded: true` untuk tab di dalam Home (Scaffold Home memakai
/// `extendBody: true`): tanpa Scaffold, SafeArea(bottom: false), dan padding
/// bawah ditambah `MediaQuery.padding.bottom` supaya konten terakhir bisa
/// discroll keluar dari bawah navbar melayang.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,
    this.backLabel,
    this.actions = const [],
    required this.children,
    this.bottomBar,
    this.onRefresh,
    this.embedded = false,
    this.largeTitle = true,
    this.titleWidget,
    super.key,
  });

  static const double horizontalPadding = 18;
  static const double blockGap = 14;

  final String title;
  final String? backLabel;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;
  final bool embedded;
  final bool largeTitle;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final bottomInset = embedded ? MediaQuery.of(context).padding.bottom : 0.0;
    final hasNav = backLabel != null || actions.isNotEmpty || !largeTitle;

    final items = <Widget>[
      if (largeTitle)
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: titleWidget ?? Text(title, style: AppTextStyles.largeTitle),
        )
      else if (titleWidget != null)
        titleWidget!,
      ...children,
    ];

    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        hasNav ? 4 : 12,
        horizontalPadding,
        24 + bottomInset,
      ),
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: blockGap),
          items[i],
        ],
      ],
    );

    if (onRefresh != null) {
      list = RefreshIndicator(color: AppColors.primary, onRefresh: onRefresh!, child: list);
    }

    final body = Column(
      children: [
        if (hasNav)
          _AppNavBar(backLabel: backLabel, title: largeTitle ? null : title, actions: actions),
        Expanded(child: list),
        if (bottomBar != null)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12 + bottomInset),
            child: bottomBar,
          ),
      ],
    );

    if (embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(child: body));
  }
}

class _AppNavBar extends StatelessWidget {
  const _AppNavBar({required this.backLabel, required this.title, required this.actions});

  final String? backLabel;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: Text(title!, style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Row(
            children: [
              if (backLabel != null)
                Semantics(
                  button: true,
                  label: 'Kembali ke $backLabel',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.maybePop(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.caretLeft, size: 22, color: AppColors.primary),
                          const SizedBox(width: 2),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(backLabel!, style: AppTextStyles.navLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                actions[i],
              ],
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aksi di kanan nav bar: tombol "+" (spec G3), teks ("Edit"), atau ikon.
class AppNavAction extends StatelessWidget {
  const AppNavAction.add({required this.onPressed, super.key})
      : icon = PhosphorIconsRegular.plus,
        label = null,
        color = null,
        tooltip = 'Tambah';

  const AppNavAction.text(String this.label, {required this.onPressed, super.key})
      : icon = null,
        color = null,
        tooltip = null;

  const AppNavAction.icon(IconData this.icon, {required this.onPressed, this.color, super.key})
      : label = null,
        tooltip = null;

  final IconData? icon;
  final String? label;
  final Color? color;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(label!, style: AppTextStyles.navLabel.copyWith(fontWeight: FontWeight.w600)),
        ),
      );
    }
    final button = InkResponse(
      radius: 22,
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 24, color: color ?? AppColors.primary),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_page_scaffold_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_page_scaffold.dart test/widgets/app_page_scaffold_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add AppPageScaffold with iOS nav bar and large title

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: `AppGroupedSection` + `AppListRow` + `AppIconTile`

**Files:**
- Create: `lib/widgets/app_grouped_section.dart`
- Create: `lib/widgets/app_list_row.dart`
- Test: `test/widgets/app_grouped_section_test.dart`, `test/widgets/app_list_row_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles`.
- Produces:
  - `AppGroupedSection({String? header, String? headerAction, VoidCallback? onHeaderAction, required List<Widget> children, bool insetSeparators = true, Key? key})` — header di-UPPERCASE; separator punya key `ValueKey('grouped-separator-$i')` (i = indeks child di bawah separator, mulai 1), inset kiri 68 (atau 16 bila `insetSeparators == false`), tebal 0.5, warna `AppColors.separator`. Latar `Material(color: surface, radius 20)` supaya `InkWell` baris punya ripple.
  - `AppListRow({Widget? leading, required String title, Color? titleColor, String? subtitle, Widget? subtitleWidget, Widget? trailing, String? value, bool showChevron = false, VoidCallback? onTap, Key? key})`.
  - `AppIconTile({required IconData icon, required Color color, bool filled = false, bool round = false, double size = 40, Key? key})` — tinted: latar `color` 14% di atas putih, ikon `color`; filled: latar `color`, ikon putih; radius `size * 0.3` (40 → 12) atau lingkaran.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_grouped_section_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('header di-uppercase, aksi header bisa ditap, separator di antara baris', (tester) async {
    var tapped = 0;
    await pumpApp(tester, Scaffold(body: AppGroupedSection(
      header: 'Dompet',
      headerAction: 'Kelola',
      onHeaderAction: () => tapped++,
      children: const [SizedBox(height: 56), SizedBox(height: 56), SizedBox(height: 56)],
    )));
    expect(find.text('DOMPET'), findsOneWidget);
    await tester.tap(find.text('Kelola'));
    expect(tapped, 1);
    expect(find.byKey(const ValueKey('grouped-separator-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('grouped-separator-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('grouped-separator-3')), findsNothing);
  });

  testWidgets('separator inset 68 atau 16', (tester) async {
    Future<double> insetOf(bool inset) async {
      await pumpApp(tester, Scaffold(body: AppGroupedSection(
        insetSeparators: inset,
        children: const [SizedBox(height: 56), SizedBox(height: 56)],
      )));
      final sep = find.byKey(const ValueKey('grouped-separator-1'));
      return tester.getTopLeft(sep).dx - tester.getTopLeft(find.byType(AppGroupedSection)).dx;
    }
    expect(await insetOf(true), 68);
    expect(await insetOf(false), 16);
    final box = tester.widget<Container>(find.byKey(const ValueKey('grouped-separator-1')));
    expect((box.color), AppColors.separator);
  });
}
```

```dart
// test/widgets/app_list_row_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('menampilkan judul, subjudul, value, chevron, dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsRegular.calendar, color: AppColors.primary),
      title: 'Bulan Laporan',
      subtitle: 'Pilih periode',
      value: 'September 2026',
      showChevron: true,
      onTap: () => taps++,
    )));
    expect(find.text('Bulan Laporan'), findsOneWidget);
    expect(find.text('Pilih periode'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.caretRight), findsOneWidget);
    await tester.tap(find.text('Bulan Laporan'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(AppListRow)).height, greaterThanOrEqualTo(56));
  });

  testWidgets('titleColor dipakai untuk judul (mis. Keluar merah)', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppListRow(title: 'Keluar', titleColor: AppColors.expense)));
    expect(tester.widget<Text>(find.text('Keluar')).style!.color, AppColors.expense);
  });

  testWidgets('AppIconTile tinted vs filled vs round', (tester) async {
    await pumpApp(tester, const Scaffold(body: Column(children: [
      AppIconTile(key: Key('t'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue),
      AppIconTile(key: Key('f'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue, filled: true),
      AppIconTile(key: Key('r'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue, round: true),
    ])));
    BoxDecoration deco(String k) => tester.widget<Container>(
      find.descendant(of: find.byKey(Key(k)), matching: find.byType(Container)).first,
    ).decoration! as BoxDecoration;
    expect(deco('t').color, isNot(AppColors.tintBlue));
    expect(deco('t').borderRadius, BorderRadius.circular(12));
    expect(deco('f').color, AppColors.tintBlue);
    expect(deco('r').shape, BoxShape.circle);
    final filledIcon = tester.widget<Icon>(find.descendant(of: find.byKey(const Key('f')), matching: find.byType(Icon)));
    expect(filledIcon.color, Colors.white);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_grouped_section_test.dart test/widgets/app_list_row_test.dart`
Expected: FAIL — file widget belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_grouped_section.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Grouped list ala Settings iPhone (spec G5): label grup HURUF BESAR di atas,
/// kartu putih radius 20, pemisah tipis antar baris yang menjorok setelah ikon.
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({
    this.header,
    this.headerAction,
    this.onHeaderAction,
    required this.children,
    this.insetSeparators = true,
    super.key,
  });

  final String? header;
  final String? headerAction;
  final VoidCallback? onHeaderAction;
  final List<Widget> children;
  final bool insetSeparators;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null || headerAction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: header == null
                      ? const SizedBox.shrink()
                      : Text(header!.toUpperCase(), style: AppTextStyles.groupLabel),
                ),
                if (headerAction != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onHeaderAction,
                    child: Text(
                      headerAction!,
                      style: AppTextStyles.subhead.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: insetSeparators ? 68 : 16),
                    child: Container(
                      key: ValueKey('grouped-separator-$i'),
                      height: 0.5,
                      color: AppColors.separator,
                    ),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
```

```dart
// lib/widgets/app_list_row.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Satu baris grouped list (spec §4.2: min 56, padding 12/16).
class AppListRow extends StatelessWidget {
  const AppListRow({
    this.leading,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.value,
    this.showChevron = false,
    this.onTap,
    super.key,
  });

  final Widget? leading;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final String? value;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyStrong.copyWith(color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  if (subtitleWidget != null)
                    Padding(padding: const EdgeInsets.only(top: 4), child: subtitleWidget!),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value!,
                  style: AppTextStyles.subhead,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

/// Ikon bertinta (spec G10): tinted (latar 14%) atau filled (latar penuh, ikon putih).
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    required this.color,
    this.filled = false,
    this.round = false,
    this.size = 40,
    super.key,
  });

  final IconData icon;
  final Color color;
  final bool filled;
  final bool round;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = filled ? color : Color.alphaBlend(color.withValues(alpha: 0.14), AppColors.surface);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: filled ? Colors.white : color),
    );
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_grouped_section_test.dart test/widgets/app_list_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_grouped_section.dart lib/widgets/app_list_row.dart test/widgets/app_grouped_section_test.dart test/widgets/app_list_row_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add grouped section, list row, and icon tile

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 5: `AppSegmentedControl` + `AppChipTabs`

**Files:**
- Create: `lib/widgets/app_segmented_control.dart`
- Create: `lib/widgets/app_chip_tabs.dart`
- Test: `test/widgets/app_segmented_control_test.dart`, `test/widgets/app_chip_tabs_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles`.
- Produces:
  - `AppSegmentedControl({required List<String> labels, required int selectedIndex, required ValueChanged<int> onChanged, List<Color>? selectedLabelColors, Key? key})` — **controlled** (parent memegang `selectedIndex`); tap segmen lain memanggil `onChanged(index)`; tap segmen yang sudah terpilih tidak memanggil apa pun. Track `AppColors.track` tinggi 36 radius 10 padding 2; pill terpilih `surface` radius 8 berbayang; teks terpilih `selectedLabelColors[i]` (default `textPrimary`), tidak terpilih `textPrimary`.
  - `AppChipTabs({required List<String> labels, required int selectedIndex, required ValueChanged<int> onChanged, Key? key})` — controlled; chip terpilih latar `textPrimary` teks putih, tidak terpilih transparan teks `textSecondary`; scroll horizontal.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_segmented_control_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('memanggil onChanged dengan index yang ditap, bukan untuk segmen aktif', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: 0,
      onChanged: calls.add,
    )));
    await tester.tap(find.text('Pengeluaran'));
    await tester.tap(find.text('Pemasukan'));
    expect(calls, [1]);
  });

  testWidgets('warna teks terpilih mengikuti selectedLabelColors', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: 1,
      selectedLabelColors: const [AppColors.income, AppColors.expense],
      onChanged: (_) {},
    )));
    expect(tester.widget<Text>(find.text('Pengeluaran')).style!.color, AppColors.expense);
    expect(tester.widget<Text>(find.text('Pemasukan')).style!.color, AppColors.textPrimary);
  });

  testWidgets('tinggi 36', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['A', 'B', 'C'], selectedIndex: 2, onChanged: (_) {},
    )));
    expect(tester.getSize(find.byType(AppSegmentedControl)).height, 36);
  });
}
```

```dart
// test/widgets/app_chip_tabs_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('chip terpilih putih di atas textPrimary, tap memanggil onChanged', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, Scaffold(body: AppChipTabs(
      labels: const ['Harian', 'Bulanan', 'Tahunan', 'Periode'],
      selectedIndex: 1,
      onChanged: calls.add,
    )));
    expect(tester.widget<Text>(find.text('Bulanan')).style!.color, Colors.white);
    expect(tester.widget<Text>(find.text('Harian')).style!.color, AppColors.textSecondary);
    await tester.tap(find.text('Periode'));
    expect(calls, [3]);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_segmented_control_test.dart test/widgets/app_chip_tabs_test.dart`
Expected: FAIL — file belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_segmented_control.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Segmented control iOS (spec G6). Controlled: parent memegang [selectedIndex].
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.selectedLabelColors,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Color>? selectedLabelColors;

  Color _selectedColor(int i) {
    final colors = selectedLabelColors;
    if (colors != null && i < colors.length) return colors[i];
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i != selectedIndex) onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: i == selectedIndex
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 4, offset: const Offset(0, 1))]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: i == selectedIndex ? _selectedColor(i) : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

```dart
// lib/widgets/app_chip_tabs.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Chip tabs untuk filter periode (spec G7). Controlled.
class AppChipTabs extends StatelessWidget {
  const AppChipTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex ? AppColors.textPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      labels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == selectedIndex ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_segmented_control_test.dart test/widgets/app_chip_tabs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_segmented_control.dart lib/widgets/app_chip_tabs.dart test/widgets/app_segmented_control_test.dart test/widgets/app_chip_tabs_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add iOS segmented control and chip tabs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 6: Kartu — `AppHeroCard`/`AppHeroLabel`/`AppHeroAmount`, `AppSurfaceCard`, `AppSummaryWidget`

**Files:**
- Create: `lib/widgets/app_hero_card.dart`
- Create: `lib/widgets/app_surface_card.dart`
- Create: `lib/widgets/app_summary_widget.dart`
- Test: `test/widgets/app_cards_test.dart`

**Interfaces:**
- Consumes: `AppColors` (`heroGradientStart/End`, `heroLabel`, `surface`, `primary`), `AppTextStyles`.
- Produces:
  - `AppHeroCard({required Widget child, Key? key})` — lebar penuh, padding 20, radius 28, gradasi topLeft→bottomRight, bayangan primary 28%, `DefaultTextStyle` putih.
  - `AppHeroLabel(String text, {Key? key})` — `caption` warna `heroLabel`.
  - `AppHeroAmount(String text, {double fontSize = 32, Key? key})` — `amountHero`, 1 baris, `FittedBox(scaleDown)` rata kiri.
  - `AppSurfaceCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16), Color? color, VoidCallback? onTap, Key? key})` — radius 24, tanpa border.
  - `AppSummaryWidget({required IconData icon, required String label, required Color color, required List<Widget> children, VoidCallback? onTap, Key? key})` — kartu putih radius 24 padding 14 min tinggi 120; header ikon 14 + label UPPERCASE 11 w800 warna `color`; children berjarak 4.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_cards_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_summary_widget.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppHeroCard memakai gradasi hero dan label heroLabel', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppHeroCard(child: Column(children: [
      AppHeroLabel('Total Saldo Keseluruhan'),
      AppHeroAmount('Rp 12.450.000'),
    ]))));
    final box = tester.widget<Container>(find.descendant(
      of: find.byType(AppHeroCard), matching: find.byType(Container)).first);
    final deco = box.decoration! as BoxDecoration;
    expect((deco.gradient! as LinearGradient).colors, [AppColors.heroGradientStart, AppColors.heroGradientEnd]);
    expect(deco.borderRadius, BorderRadius.circular(28));
    expect(tester.widget<Text>(find.text('Total Saldo Keseluruhan')).style!.color, AppColors.heroLabel);
  });

  testWidgets('AppHeroAmount 15 digit tidak overflow di layar 360', (tester) async {
    await pumpApp(tester, const Scaffold(body: Padding(
      padding: EdgeInsets.all(18),
      child: AppHeroCard(child: AppHeroAmount('Rp 999.999.999.999.999')),
    )), size: const Size(360, 740));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSurfaceCard putih radius 24 dan bisa ditap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppSurfaceCard(onTap: () => taps++, child: const Text('isi'))));
    final material = tester.widget<Material>(find.descendant(
      of: find.byType(AppSurfaceCard), matching: find.byType(Material)).first);
    expect(material.color, AppColors.surface);
    expect(material.borderRadius, BorderRadius.circular(24));
    await tester.tap(find.text('isi'));
    expect(taps, 1);
  });

  testWidgets('AppSummaryWidget label uppercase berwarna dan tinggi minimal 120', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: SizedBox(width: 170, child: AppSummaryWidget(
      icon: PhosphorIconsRegular.chartPie,
      label: 'Anggaran',
      color: AppColors.primary,
      onTap: () => taps++,
      children: const [Text('Rp 3,48 jt')],
    ))));
    expect(tester.widget<Text>(find.text('ANGGARAN')).style!.color, AppColors.primary);
    expect(tester.getSize(find.byType(AppSummaryWidget)).height, greaterThanOrEqualTo(120));
    await tester.tap(find.text('Rp 3,48 jt'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_cards_test.dart`
Expected: FAIL — file belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_hero_card.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Kartu gradasi biru untuk angka ringkasan utama halaman (spec G8).
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
    );
  }
}

/// Label kecil di kartu hero (putih 88%, kontras cukup di atas gradasi).
class AppHeroLabel extends StatelessWidget {
  const AppHeroLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.heroLabel));
  }
}

/// Nominal besar di kartu hero; mengecil otomatis bila tidak muat.
class AppHeroAmount extends StatelessWidget {
  const AppHeroAmount(this.text, {this.fontSize = 32, super.key});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: AppTextStyles.amountHero.copyWith(fontSize: fontSize)),
    );
  }
}
```

```dart
// lib/widgets/app_surface_card.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';

/// Kartu putih radius 24 tanpa border (spec G9).
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
```

```dart
// lib/widgets/app_summary_widget.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Kartu ringkasan ala widget iPhone di Beranda (spec §7.2).
class AppSummaryWidget extends StatelessWidget {
  const AppSummaryWidget({
    required this.icon,
    required this.label,
    required this.color,
    required this.children,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 120),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              children[i],
            ],
          ],
        ),
      ),
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_cards_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_hero_card.dart lib/widgets/app_surface_card.dart lib/widgets/app_summary_widget.dart test/widgets/app_cards_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add hero, surface, and summary cards

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 7: `AppProgressBar` + `AppProgressRing`

**Files:**
- Create: `lib/widgets/app_progress.dart`
- Test: `test/widgets/app_progress_test.dart`

**Interfaces:**
- Consumes: `AppColors` (`track`).
- Produces:
  - `AppProgressBar({required double value, required Color color, double height = 8, bool onDark = false, Key? key})` — nilai dijepit 0..1 (NaN/∞ → 0); track `AppColors.track` atau putih 22% bila `onDark`; radius penuh. Bagian isi memakai `FractionallySizedBox(widthFactor: v)`.
  - `AppProgressRing({required double value, required Color color, double size = 110, double strokeWidth = 11, Widget? center, Key? key})` — `CustomPaint` dengan painter `AppProgressRingPainter` (publik supaya bisa diuji), track `AppColors.track`, busur mulai jam 12, ujung bulat.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_progress_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

double _factor(WidgetTester tester) =>
    tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;

void main() {
  testWidgets('menjepit nilai di atas 1 (over budget) dan di bawah 0', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: 1.13, color: AppColors.expense)));
    expect(_factor(tester), 1.0);
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: -0.2, color: AppColors.expense)));
    expect(_factor(tester), 0.0);
  });

  testWidgets('NaN dari pembagian 0/0 jadi 0 tanpa exception', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: double.nan, color: AppColors.primary)));
    expect(_factor(tester), 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tinggi mengikuti parameter', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppProgressBar(value: 0.5, color: AppColors.primary, height: 6)));
    expect(tester.getSize(find.byType(AppProgressBar)).height, 6);
  });

  testWidgets('AppProgressRing merender center dan ukuran', (tester) async {
    await pumpApp(tester, const Scaffold(body: Center(child: AppProgressRing(
      value: 0.82, color: AppColors.tintOrange, center: Text('82%'),
    ))));
    expect(find.text('82%'), findsOneWidget);
    expect(tester.getSize(find.byType(AppProgressRing)), const Size(110, 110));
  });

  test('AppProgressRingPainter menjepit nilai', () {
    expect(AppProgressRingPainter(value: 2, color: AppColors.primary, strokeWidth: 11).value, 1.0);
    expect(AppProgressRingPainter(value: double.nan, color: AppColors.primary, strokeWidth: 11).value, 0.0);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_progress_test.dart`
Expected: FAIL — file belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_progress.dart
import 'dart:math' as math;

import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';

double _clampProgress(double value) {
  if (value.isNaN || value.isInfinite) return 0;
  return value.clamp(0.0, 1.0).toDouble();
}

/// Progress bar radius penuh (spec §4.2 tinggi 8, 6 di dalam baris list).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    required this.color,
    this.height = 8,
    this.onDark = false,
    super.key,
  });

  final double value;
  final Color color;
  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.22) : AppColors.track,
        borderRadius: radius,
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: _clampProgress(value),
        heightFactor: 1,
        child: Container(decoration: BoxDecoration(color: color, borderRadius: radius)),
      ),
    );
  }
}

/// Cincin progres (Detail Anggaran, spec §7).
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    required this.value,
    required this.color,
    this.size = 110,
    this.strokeWidth = 11,
    this.center,
    super.key,
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: AppProgressRingPainter(value: value, color: color, strokeWidth: strokeWidth),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class AppProgressRingPainter extends CustomPainter {
  AppProgressRingPainter({required double value, required this.color, required this.strokeWidth})
      : value = _clampProgress(value);

  final double value;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = AppColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(AppProgressRingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_progress_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_progress.dart test/widgets/app_progress_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add clamped progress bar and progress ring

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 8: `AppChip` + `AppCountBadge` + `AppCallout` + `AppEmptyState`

**Files:**
- Create: `lib/widgets/app_chip.dart`
- Create: `lib/widgets/app_callout.dart`
- Create: `lib/widgets/app_empty_state.dart`
- Test: `test/widgets/app_chip_callout_empty_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles`.
- Produces:
  - `AppChip({required String label, Color? color, IconData? icon, Key? key})` — latar `color` 13% di atas putih, teks/ikon `color` (null → `textSecondary`), radius 8, teks 11 w700, ikon 11.
  - `AppCountBadge(int count, {Key? key})` — `count <= 0` → `SizedBox.shrink()`; selainnya lingkaran/pill `expense` min 18×18 teks putih 10 w800.
  - `enum AppCalloutTone { info, accent }`; `AppCallout({required IconData icon, required Widget child, AppCalloutTone tone = AppCalloutTone.info, Key? key})` — info: latar `primarySoft` ikon `primary`; accent: latar `accentSoft` ikon `tintOrange`; radius 16 padding 12; teks default `subhead` warna `textPrimary`.
  - `AppEmptyState({required IconData icon, required String title, String? subtitle, Widget? action, Key? key})` — ikon 56 `textSecondary` 50%, judul `headline`, subjudul `subhead`, center.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_chip_callout_empty_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppChip memakai warna untuk teks dan latar lembut', (tester) async {
    await pumpApp(tester, const Scaffold(body: Row(children: [
      AppChip(label: 'Terlambat 2 hari', color: AppColors.expense),
      AppChip(label: 'BCA', icon: PhosphorIconsRegular.wallet),
    ])));
    expect(tester.widget<Text>(find.text('Terlambat 2 hari')).style!.color, AppColors.expense);
    expect(tester.widget<Text>(find.text('BCA')).style!.color, AppColors.textSecondary);
    expect(find.byIcon(PhosphorIconsRegular.wallet), findsOneWidget);
  });

  testWidgets('AppCountBadge tersembunyi untuk 0', (tester) async {
    await pumpApp(tester, const Scaffold(body: Row(children: [AppCountBadge(0), AppCountBadge(2)])));
    expect(find.text('0'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('AppCallout tone menentukan latar', (tester) async {
    await pumpApp(tester, const Scaffold(body: Column(children: [
      AppCallout(key: Key('i'), icon: PhosphorIconsRegular.info, child: Text('info')),
      AppCallout(key: Key('a'), icon: PhosphorIconsRegular.lightbulb, tone: AppCalloutTone.accent, child: Text('saran')),
    ])));
    Color bg(String k) => (tester.widget<Container>(find.descendant(
      of: find.byKey(Key(k)), matching: find.byType(Container)).first).decoration! as BoxDecoration).color!;
    expect(bg('i'), AppColors.primarySoft);
    expect(bg('a'), AppColors.accentSoft);
  });

  testWidgets('AppEmptyState menampilkan judul, subjudul, aksi', (tester) async {
    await pumpApp(tester, Scaffold(body: AppEmptyState(
      icon: PhosphorIconsRegular.receipt,
      title: 'Tidak ada transaksi',
      subtitle: 'Coba ganti periode',
      action: TextButton(onPressed: () {}, child: const Text('Tambah')),
    )));
    expect(find.text('Tidak ada transaksi'), findsOneWidget);
    expect(find.text('Coba ganti periode'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_chip_callout_empty_test.dart`
Expected: FAIL — file belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_chip.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Chip kecil (chip dompet, badge LUNAS/Terlambat/Tempo, "Mutasi Internal").
class AppChip extends StatelessWidget {
  const AppChip({required this.label, this.color, this.icon, super.key});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.13), AppColors.surface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: c), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge angka merah (jumlah filter aktif). 0 = tidak tampil.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(9)),
      child: Text(
        '$count',
        style: AppTextStyles.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}
```

```dart
// lib/widgets/app_callout.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

enum AppCalloutTone { info, accent }

/// Kotak info/saran (info Zakat, rekomendasi nabung Target).
class AppCallout extends StatelessWidget {
  const AppCallout({required this.icon, required this.child, this.tone = AppCalloutTone.info, super.key});

  final IconData icon;
  final Widget child;
  final AppCalloutTone tone;

  @override
  Widget build(BuildContext context) {
    final isInfo = tone == AppCalloutTone.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInfo ? AppColors.primarySoft : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isInfo ? AppColors.primary : AppColors.tintOrange),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle(
              style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, height: 1.45),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/widgets/app_empty_state.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Empty state (spec G16).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({required this.icon, required this.title, this.subtitle, this.action, super.key});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.headline),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: AppTextStyles.subhead),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_chip_callout_empty_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_chip.dart lib/widgets/app_callout.dart lib/widgets/app_empty_state.dart test/widgets/app_chip_callout_empty_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add chip, count badge, callout, and empty state

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 9: Tombol, switch, field teks, nominal

**Files:**
- Create: `lib/widgets/app_buttons.dart` (`AppPrimaryButton`, `AppPillButton`, `AppPill`)
- Create: `lib/widgets/app_switch.dart`
- Create: `lib/widgets/app_text_field.dart`
- Create: `lib/widgets/app_amount_display.dart` (`AppAmountDisplay`, `AppAmountField`)
- Test: `test/widgets/app_buttons_test.dart`, `test/widgets/app_inputs_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles`, `AppCountBadge` (Task 8), `RupiahInputFormatter` (Task 1).
- Produces:
  - `AppPrimaryButton({required String label, required VoidCallback? onPressed, IconData? icon, Color? color, bool loading = false, Key? key})` — lebar penuh, tinggi 52, radius 16, latar `color ?? primary`; `loading` → spinner putih dan tombol disabled; `onPressed == null` → disabled (latar 45%).
  - `AppPillButton({required String label, required VoidCallback? onPressed, IconData? icon, Color? color, bool filled = false, Key? key})` — tinggi 36 radius 12; soft = latar 13% teks `color ?? primary`; filled = latar penuh teks putih; disabled = opacity 0.45.
  - `AppPill({required String label, IconData? icon, Widget? trailing, int badgeCount = 0, bool expand = false, VoidCallback? onTap, Key? key})` — pill putih tinggi 36 radius 18 (pemilih tanggal, "Filter"); `expand` = label mengisi lebar (bungkus dengan `Expanded` di Row pemanggil).
  - `AppSwitch({required bool value, required ValueChanged<bool>? onChanged, Key? key})` — `CupertinoSwitch(activeTrackColor: income, inactiveTrackColor: track)`.
  - `AppTextField({required TextEditingController controller, String? hint, IconData? icon, bool obscure = false, Widget? suffix, TextInputType? keyboardType, bool readOnly = false, int maxLines = 1, VoidCallback? onTap, ValueChanged<String>? onChanged, List<TextInputFormatter>? inputFormatters, Key? key})` — putih radius 16 tanpa border; fokus = border primary 1.5; `readOnly` = latar `track`.
  - `AppAmountDisplay({required String label, required String amountText, Color? color, Widget? below, Key? key})`.
  - `AppAmountField({required TextEditingController controller, required String label, Color? color, bool autofocus = false, ValueChanged<String>? onChanged, Key? key})` — prefix "Rp" selalu terlihat, `RupiahInputFormatter`, keyboard angka, rata tengah, `amountLarge`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_buttons_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppPrimaryButton tinggi 52 dan memanggil onPressed', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPrimaryButton(label: 'Simpan', onPressed: () => taps++)));
    expect(tester.getSize(find.byType(AppPrimaryButton)).height, 52);
    await tester.tap(find.text('Simpan'));
    expect(taps, 1);
  });

  testWidgets('AppPrimaryButton loading menampilkan spinner dan menolak tap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPrimaryButton(label: 'Simpan', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppPrimaryButton));
    expect(taps, 0);
  });

  testWidgets('AppPrimaryButton memakai warna kustom (Bayar Cicilan merah)', (tester) async {
    await pumpApp(tester, Scaffold(body: AppPrimaryButton(label: 'Bayar', color: AppColors.expense, onPressed: () {})));
    final style = tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
    expect(style.backgroundColor!.resolve({}), AppColors.expense);
  });

  testWidgets('AppPillButton soft vs filled', (tester) async {
    await pumpApp(tester, Scaffold(body: Row(children: [
      AppPillButton(label: 'Setor', icon: PhosphorIconsRegular.arrowDown, onPressed: () {}),
      AppPillButton(label: 'Tambah', filled: true, onPressed: () {}),
    ])));
    expect(tester.widget<Text>(find.text('Setor')).style!.color, AppColors.primary);
    expect(tester.widget<Text>(find.text('Tambah')).style!.color, Colors.white);
    expect(tester.getSize(find.widgetWithText(AppPillButton, 'Setor')).height, 36);
  });

  testWidgets('AppPill menampilkan badge dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppPill(
      label: 'Filter', icon: PhosphorIconsRegular.funnel, badgeCount: 2, onTap: () => taps++,
    )));
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Filter'));
    expect(taps, 1);
  });
}
```

```dart
// test/widgets/app_inputs_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppSwitch memakai CupertinoSwitch warna income', (tester) async {
    bool? value;
    await pumpApp(tester, Scaffold(body: AppSwitch(value: false, onChanged: (v) => value = v)));
    final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(sw.activeTrackColor, AppColors.income);
    await tester.tap(find.byType(CupertinoSwitch));
    expect(value, isTrue);
  });

  testWidgets('AppTextField meneruskan onChanged dan hint', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changed;
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, hint: 'Cari fitur', onChanged: (v) => changed = v,
    )));
    expect(find.text('Cari fitur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'anggar');
    expect(changed, 'anggar');
  });

  testWidgets('AppAmountField memformat ribuan dan prefix Rp selalu tampil', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppAmountField(controller: controller, label: 'Nominal')));
    expect(find.text('Rp'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1250000');
    expect(controller.text, '1.250.000');
  });

  testWidgets('AppAmountDisplay 15 digit tidak overflow di 360', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppAmountDisplay(
      label: 'Jumlah Uang', amountText: 'Rp 999.999.999.999.999',
    )), size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    expect(find.text('Jumlah Uang'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_buttons_test.dart test/widgets/app_inputs_test.dart`
Expected: FAIL — file belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_buttons.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:flutter/material.dart';

/// Tombol aksi utama lebar penuh (spec §4.2: tinggi 52 radius 16).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: base,
          foregroundColor: Colors.white,
          disabledBackgroundColor: base.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTextStyles.button,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Flexible(child: Text(label, style: AppTextStyles.button, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Tombol kecil (Setor/Tarik, + Nabung, Transfer/Tambah).
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.filled = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final fg = filled ? Colors.white : c;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: filled ? c : Color.alphaBlend(c.withValues(alpha: 0.13), AppColors.surface),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subhead.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill putih untuk pemilih tanggal dan tombol "Filter".
class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.icon,
    this.trailing,
    this.badgeCount = 0,
    this.expand = false,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;
  final int badgeCount;
  final bool expand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: AppColors.textPrimary), const SizedBox(width: 6)],
              if (expand) Expanded(child: text) else Flexible(child: text),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              if (badgeCount > 0) ...[const SizedBox(width: 6), AppCountBadge(badgeCount)],
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/widgets/app_switch.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/cupertino.dart';

/// Switch gaya iOS; aktif = hijau income.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.income,
      inactiveTrackColor: AppColors.track,
    );
  }
}
```

```dart
// lib/widgets/app_text_field.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Field putih radius 16 tanpa border (gaya iOS).
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.onTap,
    this.onChanged,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: obscure ? 1 : maxLines,
      onTap: onTap,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: readOnly ? AppColors.track : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
```

```dart
// lib/widgets/app_amount_display.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Nominal besar di tengah (read-only), mis. "Jumlah Uang" di sheet.
class AppAmountDisplay extends StatelessWidget {
  const AppAmountDisplay({required this.label, required this.amountText, this.color, this.below, super.key});

  final String label;
  final String amountText;
  final Color? color;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amountText,
            maxLines: 1,
            style: AppTextStyles.amountLarge.copyWith(color: color ?? AppColors.textPrimary),
          ),
        ),
        if (below != null) ...[const SizedBox(height: 8), below!],
      ],
    );
  }
}

/// Input nominal besar di tengah dengan prefix "Rp" dan titik ribuan otomatis.
class AppAmountField extends StatelessWidget {
  const AppAmountField({
    required this.controller,
    required this.label,
    this.color,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Color? color;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.amountLarge.copyWith(color: color ?? AppColors.textPrimary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
          textAlign: TextAlign.center,
          style: style,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: '0',
            hintStyle: style.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('Rp', style: style.copyWith(fontSize: 28, color: AppColors.textSecondary)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
      ],
    );
  }
}
```

Catatan: `prefixIcon` (bukan `prefixText`) dipakai karena `prefixText` hanya tampil saat field fokus/berisi — "Rp" harus selalu terlihat seperti mockup.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_buttons_test.dart test/widgets/app_inputs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_buttons.dart lib/widgets/app_switch.dart lib/widgets/app_text_field.dart lib/widgets/app_amount_display.dart test/widgets/app_buttons_test.dart test/widgets/app_inputs_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add buttons, pill, switch, text field, and amount inputs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 10: `showAppFormSheet` + `showAppConfirmDialog` + `AppSwipeActions`

**Files:**
- Create: `lib/widgets/app_sheet.dart`
- Create: `lib/widgets/app_dialogs.dart`
- Create: `lib/widgets/app_swipe_actions.dart`
- Test: `test/widgets/app_sheet_dialog_test.dart`, `test/widgets/app_swipe_actions_test.dart`

**Interfaces:**
- Consumes: `showAppBottomSheet` (`lib/widgets/app_bottom_sheet.dart`, sudah ada), `AppColors`, `AppTextStyles`.
- Produces:
  - `Future<T?> showAppFormSheet<T>({required BuildContext context, required String title, String cancelLabel = 'Batal', required WidgetBuilder builder})` — latar `background`, radius atas 28, grabber 36×5 warna `track`, header tinggi 44: kiri teks `cancelLabel` (navLabel, menutup sheet dengan `Navigator.pop()`), tengah `title` (headline); padding 18. Isi = `builder(context)`.
  - `Future<bool> showAppConfirmDialog({required BuildContext context, required String title, required String message, String confirmLabel = 'Hapus', String cancelLabel = 'Batal', bool destructive = true})` — `CupertinoAlertDialog`; hasil `true` hanya bila tombol konfirmasi ditekan; ditutup lewat barrier → `false`.
  - `AppSwipeActions({required Widget child, VoidCallback? onEdit, VoidCallback? onDelete, String deleteConfirmTitle = 'Hapus?', String deleteConfirmMessage = 'Data ini akan dihapus permanen.', Key? key})` — geser kiri membuka tombol (Edit: `tintBlue` ikon pensil + teks "Edit"; Hapus: `expense` ikon sampah + teks "Hapus"; lebar 72 per tombol). `onDelete` dipanggil hanya setelah `showAppConfirmDialog` mengembalikan `true`. Child berlatar `AppColors.surface` (opaque). Saat terbuka, tap child menutup tanpa meneruskan tap ke child. Bila `onEdit` dan `onDelete` null → kembalikan child apa adanya.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_sheet_dialog_test.dart
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Widget _opener(Future<void> Function(BuildContext) onOpen) => Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => onOpen(context), child: const Text('buka')),
      ),
    );

void main() {
  testWidgets('showAppFormSheet menampilkan header Batal·judul dan menutup saat Batal', (tester) async {
    await pumpApp(tester, _opener((context) => showAppFormSheet<void>(
      context: context,
      title: 'Buat Anggaran',
      builder: (_) => const Text('isi form'),
    )));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Buat Anggaran'), findsOneWidget);
    expect(find.text('isi form'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('isi form'), findsNothing);
  });

  testWidgets('showAppConfirmDialog true saat dikonfirmasi, false saat batal', (tester) async {
    final results = <bool>[];
    await pumpApp(tester, _opener((context) async {
      results.add(await showAppConfirmDialog(
        context: context, title: 'Hapus Transaksi?', message: 'Data ini akan dihapus permanen.',
      ));
    }));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });
}
```

```dart
// test/widgets/app_swipe_actions_test.dart
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<void> pumpRow(WidgetTester tester, {VoidCallback? onEdit, VoidCallback? onDelete, VoidCallback? onRowTap}) {
    return pumpApp(tester, Scaffold(body: AppSwipeActions(
      onEdit: onEdit,
      onDelete: onDelete,
      deleteConfirmTitle: 'Hapus Transaksi?',
      child: ListTile(title: const Text('Makan'), onTap: onRowTap),
    )));
  }

  testWidgets('geser kiri memperlihatkan Edit dan Hapus', (tester) async {
    await pumpRow(tester, onEdit: () {}, onDelete: () {});
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Makan')).dx, lessThan(0));
  });

  testWidgets('onDelete hanya dipanggil setelah konfirmasi', (tester) async {
    var deleted = 0;
    await pumpRow(tester, onDelete: () => deleted++);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('tap baris saat terbuka menutup tanpa memicu onTap baris', (tester) async {
    var rowTaps = 0;
    await pumpRow(tester, onEdit: () {}, onRowTap: () => rowTaps++);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(rowTaps, 0);
    expect(tester.getTopLeft(find.text('Makan')).dx, greaterThanOrEqualTo(0));
    await tester.tap(find.text('Makan'));
    expect(rowTaps, 1);
  });

  testWidgets('tanpa aksi mengembalikan child apa adanya', (tester) async {
    await pumpRow(tester);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus'), findsNothing);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_sheet_dialog_test.dart test/widgets/app_swipe_actions_test.dart`
Expected: FAIL — file belum ada.

- [ ] **Step 3: Implementasi**

```dart
// lib/widgets/app_sheet.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Form sheet gaya iOS (spec G4): grabber, header Batal · judul, isi dari [builder].
/// Dibangun di atas [showAppBottomSheet] (Material ancestor, batas tinggi & keyboard sudah ditangani).
Future<T?> showAppFormSheet<T>({
  required BuildContext context,
  required String title,
  String cancelLabel = 'Batal',
  required WidgetBuilder builder,
}) {
  return showAppBottomSheet<T>(
    context: context,
    builder: (sheetContext) => _AppFormSheet(title: title, cancelLabel: cancelLabel, builder: builder),
  );
}

class _AppFormSheet extends StatelessWidget {
  const _AppFormSheet({required this.title, required this.cancelLabel, required this.builder});

  final String title;
  final String cancelLabel;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(cancelLabel, style: AppTextStyles.navLabel),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headline,
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),
            const SizedBox(height: 8),
            builder(context),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/widgets/app_dialogs.dart
import 'package:flutter/cupertino.dart';

/// Dialog konfirmasi gaya iOS. `true` hanya bila tombol konfirmasi ditekan.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel = 'Batal',
  bool destructive = true,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

```dart
// lib/widgets/app_swipe_actions.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Geser kiri untuk Edit/Hapus (spec G12). Tanpa dependency: GestureDetector + AnimationController.
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({
    required this.child,
    this.onEdit,
    this.onDelete,
    this.deleteConfirmTitle = 'Hapus?',
    this.deleteConfirmMessage = 'Data ini akan dihapus permanen.',
    super.key,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String deleteConfirmTitle;
  final String deleteConfirmMessage;

  @override
  State<AppSwipeActions> createState() => _AppSwipeActionsState();
}

class _AppSwipeActionsState extends State<AppSwipeActions> with SingleTickerProviderStateMixin {
  static const double _actionWidth = 72;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  int get _actionCount => (widget.onEdit != null ? 1 : 0) + (widget.onDelete != null ? 1 : 0);
  double get _maxOffset => _actionWidth * _actionCount;
  bool get _isOpen => _controller.value > 0.01;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => _controller.animateTo(0, curve: Curves.easeOut);

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value = (_controller.value - details.primaryDelta! / _maxOffset).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300 || (velocity <= 300 && _controller.value > 0.4)) {
      _controller.animateTo(1, curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: widget.deleteConfirmTitle,
      message: widget.deleteConfirmMessage,
    );
    if (!mounted) return;
    _close();
    if (confirmed) widget.onDelete?.call();
  }

  void _handleEdit() {
    _close();
    widget.onEdit?.call();
  }

  Widget _action({required Color color, required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: _actionWidth,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_actionCount == 0) return widget.child;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onEdit != null)
                    _action(color: AppColors.tintBlue, icon: PhosphorIconsRegular.pencilSimple, label: 'Edit', onTap: _handleEdit),
                  if (widget.onDelete != null)
                    _action(color: AppColors.expense, icon: PhosphorIconsRegular.trash, label: 'Hapus', onTap: _handleDelete),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_controller.value * _maxOffset, 0),
              child: child,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTap: _isOpen ? _close : null,
              child: ColoredBox(
                color: AppColors.surface,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => AbsorbPointer(absorbing: _isOpen, child: child),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Catatan: tombol aksi hanya terlihat setelah child bergeser (child opaque `surface`), jadi di dalam `AppGroupedSection` tidak ada warna yang menembus saat tertutup (Review Focus #2). Saat terbuka, `AbsorbPointer` mencegah `onTap` baris; `onTap` detektor luar menutup.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_sheet_dialog_test.dart test/widgets/app_swipe_actions_test.dart`
Expected: PASS.

Jika test "tap baris saat terbuka" gagal karena `onTap: _isOpen ? _close : null` tidak ikut rebuild saat `_controller` berubah, bungkus `GestureDetector` luar dalam `AnimatedBuilder` yang sama (atau panggil `setState` di listener controller) — perilaku yang dikunci test tetap: tap pertama menutup, tap kedua memicu `onTap` baris.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add lib/widgets/app_sheet.dart lib/widgets/app_dialogs.dart lib/widgets/app_swipe_actions.dart test/widgets/app_sheet_dialog_test.dart test/widgets/app_swipe_actions_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add form sheet, iOS confirm dialog, and swipe actions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 11: Galeri verifikasi + hapus test counter template

**Files:**
- Create: `test/widgets/component_gallery_test.dart`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Consumes: semua komponen Task 1–10, `pumpApp`.
- Produces: satu test yang merender seluruh komponen dalam satu `AppPageScaffold` (pengganti "halaman galeri"), dijalankan tanpa exception di layar 390 dan 360. Tanpa golden file; cukup lulus tanpa exception dan tanpa overflow.

- [ ] **Step 1: Tulis test galeri (gagal hanya bila ada komponen yang rusak)**

```dart
// test/widgets/component_gallery_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_summary_widget.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

Widget _gallery(TextEditingController text, TextEditingController amount) {
  return AppPageScaffold(
    title: 'Galeri Komponen',
    backLabel: 'Beranda',
    actions: [AppNavAction.add(onPressed: () {})],
    bottomBar: AppPrimaryButton(label: 'Simpan', onPressed: () {}),
    children: [
      AppHeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppHeroLabel('Total Saldo Keseluruhan'),
          AppHeroAmount(formatRupiah(12450000)),
          const SizedBox(height: 10),
          const AppProgressBar(value: 0.7, color: Colors.white, onDark: true),
        ]),
      ),
      AppSegmentedControl(
        labels: const ['Pemasukan', 'Pengeluaran'],
        selectedIndex: 1,
        selectedLabelColors: const [AppColors.income, AppColors.expense],
        onChanged: (_) {},
      ),
      AppChipTabs(labels: const ['Harian', 'Bulanan', 'Tahunan', 'Periode'], selectedIndex: 1, onChanged: (_) {}),
      const Row(children: [
        Expanded(child: AppPill(label: 'September 2026', icon: PhosphorIconsRegular.calendarBlank, expand: true)),
        SizedBox(width: 8),
        AppPill(label: 'Filter', icon: PhosphorIconsRegular.funnel, badgeCount: 2),
      ]),
      AppGroupedSection(header: 'Dompet', headerAction: 'Kelola', onHeaderAction: () {}, children: [
        const AppListRow(
          leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.tintBlue, filled: true),
          title: 'BCA',
          trailing: Text('Rp 9.300.000'),
        ),
        AppSwipeActions(
          onEdit: () {},
          onDelete: () {},
          child: const AppListRow(
            leading: AppIconTile(icon: PhosphorIconsRegular.forkKnife, color: AppColors.tintOrange),
            title: 'Makan',
            subtitleWidget: AppChip(label: 'BCA', icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue),
            trailing: Text('-Rp 45.000'),
          ),
        ),
        const AppListRow(title: 'Bulan Laporan', value: 'September 2026', showChevron: true),
        AppListRow(title: 'Catat ke Dompet?', trailing: AppSwitch(value: true, onChanged: (_) {})),
      ]),
      const Row(children: [
        Expanded(child: AppSummaryWidget(
          icon: PhosphorIconsRegular.chartPie, label: 'Anggaran', color: AppColors.primary,
          children: [Text('Rp 3,48 jt'), AppProgressBar(value: 0.7, color: AppColors.primary, height: 6)],
        )),
        SizedBox(width: 12),
        Expanded(child: AppSummaryWidget(
          icon: PhosphorIconsRegular.handCoins, label: 'Utang', color: AppColors.expense,
          children: [Text('Budi Santoso'), AppChip(label: 'Terlambat 2 hari', color: AppColors.expense)],
        )),
      ]),
      const AppSurfaceCard(child: Row(children: [
        AppProgressRing(value: 0.82, color: AppColors.tintOrange, size: 90, center: Text('82%')),
        SizedBox(width: 12),
        Expanded(child: AppCallout(
          icon: PhosphorIconsRegular.lightbulb,
          tone: AppCalloutTone.accent,
          child: Text('Nabung Rp 84.000 / hari agar tercapai.'),
        )),
      ])),
      const AppCallout(icon: PhosphorIconsRegular.info, child: Text('Kalkulator Zakat Maal menghitung 2.5%.')),
      Row(children: [
        AppPillButton(label: 'Setor', icon: PhosphorIconsRegular.arrowDown, onPressed: () {}),
        const SizedBox(width: 8),
        AppPillButton(label: 'Tarik', icon: PhosphorIconsRegular.arrowUp, color: AppColors.tintOrange, onPressed: () {}),
        const SizedBox(width: 8),
        AppPillButton(label: 'Tambah', filled: true, onPressed: () {}),
      ]),
      AppTextField(controller: text, hint: 'Cari fitur', icon: PhosphorIconsRegular.magnifyingGlass),
      AppAmountField(controller: amount, label: 'Nominal'),
      const AppAmountDisplay(label: 'Jumlah Uang', amountText: 'Rp 2.000.000'),
      const AppEmptyState(icon: PhosphorIconsRegular.receipt, title: 'Tidak ada transaksi'),
    ],
  );
}

void main() {
  for (final size in const [Size(390, 844), Size(360, 740)]) {
    testWidgets('galeri komponen dirender tanpa exception di ${size.width.toInt()}', (tester) async {
      final text = TextEditingController();
      final amount = TextEditingController();
      addTearDown(text.dispose);
      addTearDown(amount.dispose);
      await pumpApp(tester, _gallery(text, amount), size: size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tidak ada transaksi'), findsOneWidget);
    });
  }
}
```

- [ ] **Step 2: Jalankan test galeri**

Run: `flutter test test/widgets/component_gallery_test.dart`
Expected: PASS. Bila gagal karena overflow (RenderFlex overflowed), perbaiki KOMPONEN yang overflow (bukan galeri) lalu jalankan ulang test komponen terkait.

- [ ] **Step 3: Hapus test counter template**

`test/widget_test.dart` adalah template "Counter increments smoke test" yang mencari teks "0" dan selalu gagal (spec §7.5).

```bash
git rm test/widget_test.dart
```

- [ ] **Step 4: Jalankan seluruh suite**

Run: `flutter test`
Expected: semua PASS, 0 gagal.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows
git add test/widgets/component_gallery_test.dart
git commit -m "$(cat <<'EOF'
test(widgets): add component gallery smoke test and drop counter template test

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

Untuk melihat galeri secara visual (opsional, bagi koordinator/user): sementara ganti `home:` di `lib/main.dart` lokal dengan `_gallery(...)` dari test — JANGAN di-commit. Atau cukup bandingkan komponen saat screen pertama (B2) jadi.

---

### Task 12: Verifikasi akhir Plan B1

**Files:** tidak ada perubahan (kecuali perbaikan yang ditemukan).

- [ ] **Step 1: Analyzer**

Run: `flutter analyze`
Expected: tidak ada error/warning baru dibanding `main` (info `withOpacity`/`curly_braces` lama di screen boleh). File baru di `lib/widgets/`, `lib/core/formatters.dart`, `lib/theme/app_text_styles.dart` harus 0 issue — cek: `flutter analyze lib/widgets lib/core/formatters.dart lib/theme/app_text_styles.dart`.

- [ ] **Step 2: Test**

Run: `flutter test`
Expected: semua PASS, 0 gagal (test counter sudah dihapus).

- [ ] **Step 3: Cek kontrak**

Run:
```bash
grep -rn "GoogleFonts.poppins\|Color(0x" lib/widgets lib/core/formatters.dart lib/theme/app_text_styles.dart
```
Expected: tidak ada hasil (hex hanya boleh di `lib/core/colors.dart`).

Cocokkan tiap signature di spec §6 dengan kode (nama class, nama & default parameter). Setiap perbedaan = bug di plan ini; perbaiki kodenya, bukan spec (kecuali 4 penyesuaian di atas).

- [ ] **Step 4: Status akhir**

Run: `git status --short` → bersih (setelah `git checkout -- linux macos windows`).
Run: `git log --oneline main..HEAD` → 11 commit (Task 1–11).

Tidak ada commit di task ini kecuali ada perbaikan; bila ada:

```bash
git checkout -- linux macos windows
git add <file yang diperbaiki>
git commit -m "$(cat <<'EOF'
fix(widgets): align component with spec contract

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

Setelah itu serahkan ke koordinator untuk review seluruh branch (`flutter-code-reviewer`) dan merge ke `main` sebelum Plan B2 dimulai.
