# Rencana Implementasi: Refactor Struktur Kode — Fase 1 (Fondasi)

> **Untuk pekerja agentik:** SUB-SKILL WAJIB: Gunakan superpowers:subagent-driven-development (direkomendasikan) atau superpowers:executing-plans untuk mengimplementasikan rencana ini task demi task. Langkah-langkah menggunakan sintaks checkbox (`- [ ]`) untuk pelacakan.

**Tujuan:** Membangun fondasi component library (berbasis `forui`, direstyle sesuai `AppColors`) dan pola state management (Riverpod), lalu membuktikannya end-to-end dengan migrasi penuh `wallet_screen.dart`.

**Arsitektur:** Satu `FThemeData` sentral memetakan `AppColors` ke tema forui, sehingga widget wrapper (`AppCard`, `AppButton`, `AppTabSelector`) sebagian besar tinggal pakai widget forui apa adanya (styling datang dari tema, bukan diulang di tiap wrapper). Business logic Supabase dipindah dari screen ke Riverpod provider. Struktur folder screen jadi feature-first (`lib/screens/wallet/wallet_screen.dart`) dengan `lib/widgets/` global untuk komponen bersama.

**Tech Stack:** Flutter 3.38.5 / Dart 3.10.4 (sudah terpasang), `forui: ^0.17.0`, `flutter_riverpod: ^3.3.2` (kedua versi sudah divalidasi lewat `flutter pub add --dry-run` terhadap toolchain project ini — bukan asumsi dari dokumentasi versi terbaru).

**Spec:** `docs/superpowers/specs/2026-09-13-refactor-phase1-foundation-design.md`

## Batasan Global

- Semua base component di `lib/widgets/` WAJIB membungkus widget `forui` — jangan bikin widget custom dari nol (instruksi eksplisit user).
- Tidak ada perubahan pada schema Supabase.
- Tidak ada redesign visual di luar yang diperlukan untuk konsistensi — restyle forui memakai palet `AppColors` yang sudah ada, bukan tampilan baru.
- Tidak ada `riverpod_generator`/`build_runner` — pakai API Riverpod polos (`NotifierProvider`/`FutureProvider`).
- Hanya `wallet_screen.dart` yang dimigrasi ke struktur folder baru di fase ini; 23 screen lain tetap flat di `lib/screens/` sampai fase migrasi berikutnya.
- Screen mengimpor langsung dari `lib/widgets/` secara default. Folder `widgets/` lokal di dalam folder screen HANYA dibuat kalau screen itu butuh varian yang berbeda dari versi global — jangan dibuat preemptif.
- Commit pakai Conventional Commits, regex: `^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9_-]+\))?!?: .+` (hook `commit-msg` dari setup agent-first sudah menegakkan ini).
- Setiap `Container`/kartu baru yang dibungkus lewat `AppCard` memakai radius sudut standar **16** (nilai tengah yang dipilih dari distribusi radius yang ada di codebase saat ini: 12 paling sering dipakai [100x], 15 kedua [95x], 20/16/24/25 tersebar; 16 dipilih sebagai titik tengah yang rapi dan konsisten dengan konvensi Material 3 default — bukan usaha memaksakan satu nilai yang sudah dominan, karena tidak ada yang benar-benar dominan).

---

## Task 1: Tambah dependency forui + flutter_riverpod, setup FTheme + ProviderScope

**Files:**
- Ubah: `pubspec.yaml`, `pubspec.lock` (lewat `flutter pub add`)
- Buat: `lib/theme/app_forui_theme.dart`
- Ubah: `lib/main.dart`

**Interfaces:**
- Menghasilkan: `appForuiTheme` (top-level `FThemeData` di `lib/theme/app_forui_theme.dart`) yang dipakai Task 2-5 untuk membangun wrapper widget. `ProviderScope` di root widget tree yang dibutuhkan Task 6 (Riverpod provider tidak akan berfungsi tanpa ini).

- [ ] **Langkah 1: Tambah dependency**

Jalankan:
```bash
flutter pub add forui flutter_riverpod
```
Ekspektasi: `pubspec.yaml` menambahkan `forui: ^0.17.0` dan `flutter_riverpod: ^3.3.2` (atau versi compatible terdekat yang pub resolve saat ini — kalau berbeda dari sini, itu normal karena registry berubah seiring waktu, yang penting `flutter pub get` sukses tanpa conflict).

- [ ] **Langkah 2: Buat file tema forui sentral**

Buat `lib/theme/app_forui_theme.dart`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Tema forui project ini, dipetakan dari [AppColors] yang sudah ada.
///
/// Semua widget di lib/widgets/ mengandalkan tema ini untuk warna —
/// jangan override warna per-widget kecuali benar-benar perlu varian
/// khusus, supaya satu perubahan di AppColors otomatis menyebar ke
/// semua komponen forui.
final FThemeData appForuiTheme = FThemes.zinc.light.copyWith(
  colors: FThemes.zinc.light.colors.copyWith(
    primary: AppColors.primary,
    primaryForeground: AppColors.white,
    background: AppColors.background,
    foreground: AppColors.textPrimary,
    secondary: AppColors.accent,
    secondaryForeground: AppColors.white,
    mutedForeground: AppColors.textSecondary,
    destructive: AppColors.expense,
  ),
  style: FThemes.zinc.light.style.copyWith(
    borderRadius: BorderRadius.circular(16),
  ),
);
```

- [ ] **Langkah 2b: Cek nama field valid dengan flutter analyze**

Jalankan:
```bash
flutter analyze lib/theme/app_forui_theme.dart
```
Ekspektasi: bersih. **Kalau ada error field tidak dikenal** (nama field `FColors`/`FStyle` di forui 0.17.0 sedikit berbeda dari yang ditulis di atas), buka source package yang sebenarnya terpasang di
`$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/forui-0.17.0/lib/src/theme/colors.dart` dan
`.../lib/src/theme/style.dart` untuk melihat nama field yang benar, lalu sesuaikan. Ini kemungkinan kecil karena field-field di atas sudah diverifikasi langsung dari source saat rencana ini ditulis, tapi versi minor forui yang di-resolve saat implementasi bisa saja sedikit berbeda dari 0.17.0 yang diverifikasi.

- [ ] **Langkah 3: Bungkus `main.dart` dengan `ProviderScope` dan `FTheme`**

Baca `lib/main.dart` dulu untuk melihat struktur `MyApp`/`MaterialApp` saat ini. Lakukan dua perubahan:

1. Di fungsi `main()`, ubah:
   ```dart
   runApp(const MyApp());
   ```
   menjadi:
   ```dart
   runApp(const ProviderScope(child: MyApp()));
   ```
   dan tambah import:
   ```dart
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   ```

2. Di dalam `build()` method `MyApp`, bungkus `MaterialApp` (atau widget yang dikembalikan `ValueListenableBuilder`) dengan `FTheme`, memakai `appForuiTheme` yang baru dibuat:
   ```dart
   import 'package:catat_uang_app/theme/app_forui_theme.dart';
   import 'package:forui/forui.dart';
   ```
   Cara membungkusnya: `FTheme` butuh `MaterialApp` di dalamnya (bukan sebaliknya) supaya widget forui bisa dipakai di seluruh screen yang dirender lewat `MaterialApp`. Jadi urutannya:
   ```dart
   return ValueListenableBuilder<ThemeMode>(
     valueListenable: themeNotifier,
     builder: (context, currentMode, child) {
       return MaterialApp(
         // ...isi MaterialApp yang sudah ada, tidak berubah...
         builder: (context, child) => FTheme(
           data: appForuiTheme,
           child: child!,
         ),
       );
     },
   );
   ```
   Pakai parameter `builder` milik `MaterialApp` (bukan membungkus dari luar) supaya `Navigator`/route tetap didefinisikan oleh `MaterialApp` sendiri, dan `FTheme` tersedia untuk semua screen yang dinavigasi.

- [ ] **Langkah 4: Verifikasi app masih jalan**

Jalankan:
```bash
flutter analyze
```
Ekspektasi: tidak ada error baru dibanding baseline 245 issues yang sudah ada sebelumnya (boleh ada warning `info` baru dari forui sendiri, itu bukan masalah kita — fokus ke tidak adanya **error** baru dari perubahan `main.dart`/`app_forui_theme.dart`).

- [ ] **Langkah 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/theme/app_forui_theme.dart lib/main.dart
git commit -m "feat: add forui + Riverpod foundation with AppColors-mapped theme"
```

---

## Task 2: `AppCard` — wrapper `FCard`

**Files:**
- Buat: `lib/widgets/app_card.dart`
- Buat: `test/widgets/app_card_test.dart`

**Interfaces:**
- Konsumsi: `appForuiTheme` (Task 1) — widget test membungkus dengan `FTheme(data: appForuiTheme, ...)`.
- Menghasilkan: `AppCard` widget dengan constructor `AppCard({Widget? title, Widget? subtitle, required Widget child, Key? key})`, dipakai Task 7.

- [ ] **Langkah 1: Tulis widget test yang gagal**

Buat `test/widgets/app_card_test.dart`:

```dart
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('AppCard menampilkan child-nya', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppCard(child: Text('Isi kartu')),
        ),
      ),
    );

    expect(find.text('Isi kartu'), findsOneWidget);
  });

  testWidgets('AppCard menampilkan title dan subtitle jika diberikan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppCard(
            title: Text('Judul'),
            subtitle: Text('Subjudul'),
            child: Text('Isi'),
          ),
        ),
      ),
    );

    expect(find.text('Judul'), findsOneWidget);
    expect(find.text('Subjudul'), findsOneWidget);
    expect(find.text('Isi'), findsOneWidget);
  });
}
```

- [ ] **Langkah 2: Jalankan test, pastikan gagal (file `app_card.dart` belum ada)**

Jalankan:
```bash
flutter test test/widgets/app_card_test.dart
```
Ekspektasi: GAGAL dengan error "Target of URI doesn't exist" atau sejenisnya untuk `package:catat_uang_app/widgets/app_card.dart`.

- [ ] **Langkah 3: Buat implementasi minimal**

Buat `lib/widgets/app_card.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Kartu standar aplikasi, membungkus [FCard] milik forui.
///
/// Warna/border mengikuti [appForuiTheme] secara global — lihat
/// lib/theme/app_forui_theme.dart. Jangan override warna di sini
/// kecuali screen tertentu benar-benar butuh varian berbeda.
class AppCard extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget child;

  const AppCard({this.title, this.subtitle, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return FCard(
      title: title,
      subtitle: subtitle,
      child: child,
    );
  }
}
```

- [ ] **Langkah 4: Jalankan test, pastikan lulus**

Jalankan:
```bash
flutter test test/widgets/app_card_test.dart
```
Ekspektasi: LULUS (2/2 test). Kalau `FCard` melempar error karena parameter tidak sesuai (kemungkinan kecil, lihat catatan di Task 1 Langkah 2b), sesuaikan dengan signature `FCard` yang sebenarnya terpasang di `$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/forui-0.17.0/lib/src/widgets/card/card.dart`.

- [ ] **Langkah 5: Commit**

```bash
git add lib/widgets/app_card.dart test/widgets/app_card_test.dart
git commit -m "feat(widgets): add AppCard wrapping forui FCard"
```

---

## Task 3: `AppBottomSheet` — helper `showFSheet`

**Files:**
- Buat: `lib/widgets/app_bottom_sheet.dart`
- Buat: `test/widgets/app_bottom_sheet_test.dart`

**Interfaces:**
- Menghasilkan: fungsi `Future<T?> showAppBottomSheet<T>({required BuildContext context, required WidgetBuilder builder})`, dipakai Task 7 menggantikan `showModalBottomSheet` manual di `wallet_screen.dart`.

- [ ] **Langkah 1: Tulis widget test yang gagal**

Buat `test/widgets/app_bottom_sheet_test.dart`:

```dart
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('showAppBottomSheet menampilkan konten builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAppBottomSheet(
                context: context,
                builder: (context) => const Text('Isi bottom sheet'),
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.text('Isi bottom sheet'), findsOneWidget);
  });
}
```

- [ ] **Langkah 2: Jalankan test, pastikan gagal**

Jalankan:
```bash
flutter test test/widgets/app_bottom_sheet_test.dart
```
Ekspektasi: GAGAL — `app_bottom_sheet.dart` belum ada.

- [ ] **Langkah 3: Buat implementasi minimal**

Buat `lib/widgets/app_bottom_sheet.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Helper standar untuk menampilkan bottom sheet aplikasi, membungkus
/// [showFSheet] milik forui dengan konfigurasi yang konsisten (dari
/// bawah layar, bisa di-drag, mengikuti tema global).
///
/// Ganti semua pemanggilan `showModalBottomSheet` di screen dengan ini
/// supaya padding/radius/drag-handle konsisten di semua screen.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showFSheet<T>(
    context: context,
    side: FLayout.btt,
    builder: builder,
  );
}
```

- [ ] **Langkah 4: Jalankan test, pastikan lulus**

Jalankan:
```bash
flutter test test/widgets/app_bottom_sheet_test.dart
```
Ekspektasi: LULUS. Kalau parameter `showFSheet` berbeda dari yang dipakai di atas, cek signature sebenarnya di
`$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/forui-0.17.0/lib/src/widgets/sheet/modal_sheet.dart` (fungsi `showFSheet<T>`).

- [ ] **Langkah 5: Commit**

```bash
git add lib/widgets/app_bottom_sheet.dart test/widgets/app_bottom_sheet_test.dart
git commit -m "feat(widgets): add showAppBottomSheet wrapping forui showFSheet"
```

---

## Task 4: `AppButton` — wrapper `FButton`

**Files:**
- Buat: `lib/widgets/app_button.dart`
- Buat: `test/widgets/app_button_test.dart`

**Interfaces:**
- Menghasilkan: `AppButton` widget dengan constructor `AppButton({required String label, required VoidCallback? onPressed, Key? key})` dan factory `AppButton.destructive({required String label, required VoidCallback? onPressed})` untuk aksi berbahaya (misal hapus), dipakai Task 7.

- [ ] **Langkah 1: Tulis widget test yang gagal**

Buat `test/widgets/app_button_test.dart`:

```dart
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('AppButton memanggil onPressed saat ditekan', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppButton(
            label: 'Simpan',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Simpan'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('AppButton tidak bisa ditekan saat onPressed null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppButton(label: 'Nonaktif', onPressed: null),
        ),
      ),
    );

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Langkah 2: Jalankan test, pastikan gagal**

Jalankan:
```bash
flutter test test/widgets/app_button_test.dart
```
Ekspektasi: GAGAL — `app_button.dart` belum ada.

- [ ] **Langkah 3: Buat implementasi minimal**

Buat `lib/widgets/app_button.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Tombol standar aplikasi, membungkus [FButton] milik forui.
///
/// Warna mengikuti [appForuiTheme] secara global. Pakai
/// [AppButton.destructive] untuk aksi berbahaya (hapus, dsb) supaya
/// selalu memakai warna destructive dari tema, bukan warna primary.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FButtonStyle Function(FButtonStyles style)? _styleSelector;

  const AppButton({required this.label, required this.onPressed, super.key})
      : _styleSelector = null;

  const AppButton.destructive({required this.label, required this.onPressed, super.key})
      : _styleSelector = _destructiveStyle;

  static FButtonStyle _destructiveStyle(FButtonStyles styles) => styles.destructive;

  @override
  Widget build(BuildContext context) {
    final styles = context.theme.buttonStyles;
    return FButton(
      style: _styleSelector != null ? _styleSelector(styles) : styles.primary,
      onPress: onPressed,
      child: Text(label),
    );
  }
}
```

- [ ] **Langkah 4: Jalankan test, pastikan lulus**

Jalankan:
```bash
flutter test test/widgets/app_button_test.dart
```
Ekspektasi: LULUS. Kalau `FButton` tidak menerima parameter `style` bertipe `FButtonStyle` langsung (constructor `FButton()` normal vs `FButton.raw`), cek signature sebenarnya di
`$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/forui-0.17.0/lib/src/widgets/button/button.dart` dan sesuaikan — constructor utama `FButton()` menerima parameter `style` bertipe callback (`FBaseButtonStyle Function(FButtonStyle style)`), bukan `FButtonStyle` langsung; kalau demikian, ubah pendekatan jadi:
```dart
FButton(
  style: _styleSelector != null ? (_) => _styleSelector(styles) : null,
  onPress: onPressed,
  child: Text(label),
)
```
Sesuaikan berdasarkan apa yang benar-benar diterima compiler.

- [ ] **Langkah 5: Commit**

```bash
git add lib/widgets/app_button.dart test/widgets/app_button_test.dart
git commit -m "feat(widgets): add AppButton wrapping forui FButton"
```

---

## Task 5: `AppTabSelector` — wrapper `FTabs`

**Files:**
- Buat: `lib/widgets/app_tab_selector.dart`
- Buat: `test/widgets/app_tab_selector_test.dart`

**Interfaces:**
- Menghasilkan: `AppTabSelector` widget dengan constructor `AppTabSelector({required List<String> labels, required int initialIndex, required ValueChanged<int> onChanged, Key? key})`. Ini widget target untuk masalah konsistensi tab yang dilaporkan user — dipakai di fase migrasi berikutnya untuk `home_screen.dart`/`stats_screen.dart`, TIDAK dipakai `wallet_screen.dart` (yang tidak punya tab).

- [ ] **Langkah 1: Tulis widget test yang gagal**

Buat `test/widgets/app_tab_selector_test.dart`:

```dart
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_tab_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('AppTabSelector menampilkan semua label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppTabSelector(
            labels: const ['Harian', 'Bulanan', 'Tahunan'],
            initialIndex: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Harian'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Tahunan'), findsOneWidget);
  });

  testWidgets('AppTabSelector memanggil onChanged dengan index yang benar', (tester) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppTabSelector(
            labels: const ['Harian', 'Bulanan'],
            initialIndex: 0,
            onChanged: (index) => selected = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });
}
```

- [ ] **Langkah 2: Jalankan test, pastikan gagal**

Jalankan:
```bash
flutter test test/widgets/app_tab_selector_test.dart
```
Ekspektasi: GAGAL — `app_tab_selector.dart` belum ada.

- [ ] **Langkah 3: Buat implementasi minimal**

Buat `lib/widgets/app_tab_selector.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Selector tab standar aplikasi, membungkus [FTabs] milik forui.
///
/// Dibuat khusus untuk konsistensi tab lintas screen — sebelumnya
/// setiap screen bikin tab manual sendiri-sendiri (Row + GestureDetector)
/// dengan tampilan yang berbeda-beda. Pakai widget ini, jangan bikin
/// tab manual lagi di screen baru.
class AppTabSelector extends StatefulWidget {
  final List<String> labels;
  final int initialIndex;
  final ValueChanged<int> onChanged;

  const AppTabSelector({
    required this.labels,
    required this.initialIndex,
    required this.onChanged,
    super.key,
  });

  @override
  State<AppTabSelector> createState() => _AppTabSelectorState();
}

class _AppTabSelectorState extends State<AppTabSelector> with SingleTickerProviderStateMixin {
  late final FTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FTabController(
      vsync: this,
      length: widget.labels.length,
      initialIndex: widget.initialIndex,
    );
    _controller.addListener(() {
      if (!_controller.indexIsChanging) {
        widget.onChanged(_controller.index);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FTabs(
      control: FTabManagedControl(controller: _controller),
      children: [
        for (final label in widget.labels) FTabEntry.entry(label: Text(label), child: const SizedBox.shrink()),
      ],
    );
  }
}
```

- [ ] **Langkah 4: Jalankan test, pastikan lulus**

Jalankan:
```bash
flutter test test/widgets/app_tab_selector_test.dart
```
Ekspektasi: LULUS. **Ini bagian dengan risiko API-mismatch tertinggi** di antara semua task Fase 1 — `FTabController`/`FTabManagedControl` adalah API yang paling dalam/kompleks yang diverifikasi saat rencana ini ditulis (lihat `tabs.control.dart`), jadi kemungkinan besar perlu penyesuaian kecil terhadap signature sebenarnya. Cek:
`$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/forui-0.17.0/lib/src/widgets/tabs/tabs.dart` dan
`.../lib/src/widgets/tabs/tabs.control.dart` untuk constructor `FTabController` yang valid dan cara membaca index terpilih. Kalau `FTabController`/`FTabManagedControl` tidak tersedia sebagai constructor publik seperti di atas, cek juga apakah `FTabs` punya mode "uncontrolled" yang lebih sederhana (`FTabControl` punya varian selain `FTabManagedControl` — cek `case FTabManagedControl(...)` di source untuk nama varian lain) dan pakai itu sebagai alternatif yang lebih simpel kalau tersedia.

- [ ] **Langkah 5: Commit**

```bash
git add lib/widgets/app_tab_selector.dart test/widgets/app_tab_selector_test.dart
git commit -m "feat(widgets): add AppTabSelector wrapping forui FTabs"
```

---

## Task 6: `walletProvider` — logic Supabase lewat Riverpod

**Files:**
- Buat: `lib/providers/wallet_provider.dart`
- Buat: `test/providers/wallet_provider_test.dart`

**Interfaces:**
- Konsumsi: `WalletModel` (`lib/models/wallet_model.dart`, sudah ada, tidak berubah).
- Menghasilkan: `walletProvider` (`NotifierProvider<WalletNotifier, WalletState>`), `WalletState` (class berisi `List<WalletModel> wallets`, `bool isLoading`), `WalletNotifier` dengan method `fetchWallets()`, `addWallet(...)`, `updateWallet(...)`, `deleteWallet(int id)`, `transfer({required int sourceId, required int destId, required double amount})`. Dipakai Task 7.

- [ ] **Langkah 1: Tulis test untuk bagian yang bisa diuji tanpa Supabase**

`WalletNotifier` sebagian besar memanggil Supabase langsung (seperti kode aslinya), jadi tidak semuanya bisa diuji unit tanpa koneksi nyata — ini konsisten dengan keterbatasan yang sudah didokumentasikan di subagent `flutter-qa-writer`. Yang bisa diuji murni adalah **state transition logic** transfer (validasi saldo cukup, validasi sumber≠tujuan) — logic ini akan diekstrak jadi method terpisah yang testable.

Buat `test/providers/wallet_provider_test.dart`:

```dart
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTransfer', () {
    final source = WalletModel(id: 1, userId: 'u1', name: 'BCA', balance: 100000);
    final dest = WalletModel(id: 2, userId: 'u1', name: 'GoPay', balance: 50000);

    test('mengembalikan null (valid) jika saldo cukup dan wallet berbeda', () {
      final error = validateTransfer(source: source, dest: dest, amount: 50000);
      expect(error, isNull);
    });

    test('menolak jika saldo sumber tidak cukup', () {
      final error = validateTransfer(source: source, dest: dest, amount: 150000);
      expect(error, isNotNull);
    });

    test('menolak jika sumber dan tujuan sama', () {
      final error = validateTransfer(source: source, dest: source, amount: 1000);
      expect(error, isNotNull);
    });

    test('menolak jika amount nol atau negatif', () {
      final error = validateTransfer(source: source, dest: dest, amount: 0);
      expect(error, isNotNull);
    });
  });
}
```

- [ ] **Langkah 2: Jalankan test, pastikan gagal**

Jalankan:
```bash
flutter test test/providers/wallet_provider_test.dart
```
Ekspektasi: GAGAL — `wallet_provider.dart` belum ada.

- [ ] **Langkah 3: Buat implementasi**

Buat `lib/providers/wallet_provider.dart`. Logic Supabase dipindah verbatim dari `_WalletScreenState` di `lib/screens/wallet_screen.dart` (lihat method `_fetchWallets`, `_deleteWallet`, dan bagian `onPressed` di dalam `_showTransferSheet`/`_showAddEditWalletSheet`) — bukan ditulis ulang query-nya, hanya dipindah lokasinya dan dibungkus API Riverpod:

```dart
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'wallet_provider.g.dart';

class WalletState {
  final List<WalletModel> wallets;
  final bool isLoading;

  const WalletState({this.wallets = const [], this.isLoading = true});

  WalletState copyWith({List<WalletModel>? wallets, bool? isLoading}) {
    return WalletState(
      wallets: wallets ?? this.wallets,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Mengembalikan pesan error kalau transfer tidak valid, atau null kalau valid.
/// Diekstrak dari logic validasi di WalletScreen._showTransferSheet's tombol
/// "Transfer Sekarang" supaya bisa diuji unit tanpa Supabase.
String? validateTransfer({
  required WalletModel source,
  required WalletModel dest,
  required double amount,
}) {
  if (amount <= 0) return 'Nominal tidak boleh kosong!';
  if (source.id == dest.id) return 'Dompet asal dan tujuan tidak boleh sama!';
  if (source.balance < amount) return 'Saldo di ${source.name} tidak cukup!';
  return null;
}

class WalletNotifier extends Notifier<WalletState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  WalletState build() {
    fetchWallets();
    return const WalletState();
  }

  Future<void> fetchWallets() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      state = state.copyWith(
        wallets: (res as List).map((e) => WalletModel.fromJson(e)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addWallet({
    required String name,
    required double balance,
    required String color,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('wallets').insert({
      'user_id': userId,
      'name': name,
      'balance': balance,
      'color': color,
      'icon': 'wallet',
    });
    await fetchWallets();
  }

  Future<void> updateWallet({
    required int id,
    required String name,
    required double balance,
    required String color,
  }) async {
    await _supabase.from('wallets').update({
      'name': name,
      'balance': balance,
      'color': color,
      'icon': 'wallet',
    }).eq('id', id);
    await fetchWallets();
  }

  Future<void> deleteWallet(int id) async {
    await _supabase.from('wallets').delete().eq('id', id);
    await fetchWallets();
  }

  Future<void> transfer({
    required int sourceId,
    required int destId,
    required double amount,
  }) async {
    final source = state.wallets.firstWhere((w) => w.id == sourceId);
    final dest = state.wallets.firstWhere((w) => w.id == destId);

    final error = validateTransfer(source: source, dest: dest, amount: amount);
    if (error != null) throw Exception(error);

    await _supabase.from('wallets').update({'balance': source.balance - amount}).eq('id', sourceId);
    await _supabase.from('wallets').update({'balance': dest.balance + amount}).eq('id', destId);
    await fetchWallets();
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);
```

Catatan: baris `part 'wallet_provider.g.dart';` **DIHAPUS** dari kode di atas — itu peninggalan pola `riverpod_generator` yang secara eksplisit TIDAK dipakai di fase ini (lihat Batasan Global). Pastikan file final tidak menyertakan baris itu. `NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new)` adalah API Riverpod versi 3.x tanpa codegen — kalau `Notifier`/`NotifierProvider` tidak tersedia dengan bentuk ini di versi yang benar-benar ter-resolve, cek alternatif `StateNotifierProvider`/`StateNotifier` (API Riverpod yang lebih lama tapi masih didukung) sebagai fallback.

- [ ] **Langkah 4: Jalankan test, pastikan lulus**

Jalankan:
```bash
flutter test test/providers/wallet_provider_test.dart
```
Ekspektasi: LULUS (4/4 test).

- [ ] **Langkah 5: `flutter analyze` pada file baru**

Jalankan:
```bash
flutter analyze lib/providers/wallet_provider.dart
```
Ekspektasi: bersih. Kalau `NotifierProvider`/`Notifier` API tidak cocok, sesuaikan berdasar error compiler (lihat catatan fallback di Langkah 3).

- [ ] **Langkah 6: Commit**

```bash
git add lib/providers/wallet_provider.dart test/providers/wallet_provider_test.dart
git commit -m "feat(providers): add walletProvider with Supabase logic moved from WalletScreen"
```

---

## Task 7: Migrasi `wallet_screen.dart` (pembuktian pola)

**Files:**
- Buat: `lib/screens/wallet/wallet_screen.dart`
- Hapus: `lib/screens/wallet_screen.dart`
- Ubah: `lib/screens/home_screen.dart` (baris import + referensi ke `WalletScreen`)

**Interfaces:**
- Konsumsi: `walletProvider`/`WalletNotifier`/`WalletState` (Task 6), `AppCard` (Task 2), `showAppBottomSheet` (Task 3), `AppButton` (Task 4).
- Tidak ada perubahan pada constructor `WalletScreen({super.key})` — pemanggil (`home_screen.dart`) hanya perlu ganti baris import, bukan cara pemanggilannya.

Screen asli (665 baris) berisi: state list wallet + loading flag, fetch/delete wallet, dua bottom sheet (transfer & tambah/edit), dan `build()` yang merender card gradient per-wallet + FAB. Migrasi ini memindahkan business logic ke `walletProvider` (Task 6) dan menata ulang bagian card/bottom sheet memakai widget baru — TAPI desain visual card gradient per-wallet (bukan bagian dari masalah konsistensi yang dilaporkan user, itu card yang sudah unik/khas per wallet) **tetap dipertahankan seperti aslinya**, tidak diganti `AppCard` polos, supaya tidak menghilangkan detail visual (gradient warna wallet, ornamen) yang memang disengaja. `AppCard` dipakai untuk kotak-kotak form generik di dalam bottom sheet, bukan kartu wallet itu sendiri.

- [ ] **Langkah 1: Baca ulang file asli untuk referensi persis**

```bash
cat lib/screens/wallet_screen.dart
```
(Sudah dibaca penuh saat menyusun rencana ini — implementer membaca ulang untuk memastikan tidak ada detail perilaku yang terlewat, terutama validasi dan pesan `AppNotification` yang harus tetap sama persis.)

- [ ] **Langkah 2: Buat folder dan file baru**

```bash
mkdir -p lib/screens/wallet
```

Buat `lib/screens/wallet/wallet_screen.dart`:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:catat_uang_app/widgets/app_button.dart';
import 'package:catat_uang_app/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const List<String> _colorOptions = [
    '#1E3A8A', '#00796B', '#5E35B1', '#E65100',
    '#C62828', '#2E7D32', '#37474F', '#E91E63',
  ];

  void _showTransferSheet(BuildContext context, WidgetRef ref, List<WalletModel> wallets) {
    if (wallets.length < 2) {
      AppNotification.error(context, "Minimal butuh 2 dompet untuk transfer.");
      return;
    }

    int? sourceId = wallets[0].id;
    int? destId = wallets[1].id;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final amountController = TextEditingController();

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: AppCard(
                title: Text("Transfer Antar Dompet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Dari Dompet (Sumber)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: sourceId,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
                        items: wallets.map((w) {
                          return DropdownMenuItem<int>(
                            value: w.id,
                            child: Text("${w.name} (Sisa: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(w.balance)})", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == destId) {
                            AppNotification.error(context, "Dompet asal dan tujuan tidak boleh sama!");
                            return;
                          }
                          setSheetState(() => sourceId = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Center(child: Icon(PhosphorIconsBold.arrowDown, color: AppColors.primary, size: 24)),
                    const SizedBox(height: 15),
                    Text("Ke Dompet (Tujuan)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: destId,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
                        items: wallets.map((w) {
                          return DropdownMenuItem<int>(value: w.id, child: Text(w.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)));
                        }).toList(),
                        onChanged: (val) {
                          if (val == sourceId) {
                            AppNotification.error(context, "Dompet tujuan dan asal tidak boleh sama!");
                            return;
                          }
                          setSheetState(() => destId = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("Nominal Transfer", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      onChanged: (value) {
                        final cleanValue = value.replaceAll('.', '');
                        if (cleanValue.isNotEmpty) {
                          final formatted = currencyFormatter.format(int.parse(cleanValue));
                          amountController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }
                      },
                      decoration: const InputDecoration(hintText: "0", prefixText: "Rp "),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: "Transfer Sekarang",
                        onPressed: () async {
                          if (amountController.text.isEmpty) {
                            AppNotification.error(context, "Nominal tidak boleh kosong!");
                            return;
                          }
                          final cleanAmount = double.parse(amountController.text.replaceAll('.', ''));
                          try {
                            await ref.read(walletProvider.notifier).transfer(
                                  sourceId: sourceId!,
                                  destId: destId!,
                                  amount: cleanAmount,
                                );
                            if (context.mounted) {
                              AppNotification.success(context, "Transfer Rp ${currencyFormatter.format(cleanAmount)} berhasil!");
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditWalletSheet(BuildContext context, WidgetRef ref, {WalletModel? wallet}) {
    final isEdit = wallet != null;
    final nameController = TextEditingController(text: isEdit ? wallet.name : '');
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final balanceController = TextEditingController(text: isEdit ? currencyFormatter.format(wallet.balance) : '');
    String selectedColor = isEdit && wallet.color != null ? wallet.color! : _colorOptions[0];

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: AppCard(
                title: Text(isEdit ? "Edit Dompet" : "Tambah Dompet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nama Dompet (cth: BCA, GoPay, Tunai)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(controller: nameController, decoration: const InputDecoration(hintText: "Masukkan nama dompet")),
                    const SizedBox(height: 20),
                    Text("Saldo Saat Ini", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        final cleanValue = value.replaceAll('.', '');
                        if (cleanValue.isNotEmpty) {
                          final formatted = currencyFormatter.format(int.parse(cleanValue));
                          balanceController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }
                      },
                      decoration: const InputDecoration(hintText: "0", prefixText: "Rp "),
                    ),
                    const SizedBox(height: 20),
                    Text("Pilih Warna", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _colorOptions.map((hexColor) {
                          final color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
                          final isSelected = selectedColor == hexColor;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedColor = hexColor),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.black54, width: 3) : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: "Simpan Dompet",
                        onPressed: () async {
                          if (nameController.text.isEmpty || balanceController.text.isEmpty) {
                            AppNotification.error(context, "Harap isi semua data!");
                            return;
                          }
                          final cleanBalance = double.parse(balanceController.text.replaceAll('.', ''));
                          try {
                            if (isEdit) {
                              await ref.read(walletProvider.notifier).updateWallet(
                                    id: wallet.id,
                                    name: nameController.text.trim(),
                                    balance: cleanBalance,
                                    color: selectedColor,
                                  );
                            } else {
                              await ref.read(walletProvider.notifier).addWallet(
                                    name: nameController.text.trim(),
                                    balance: cleanBalance,
                                    color: selectedColor,
                                  );
                            }
                            if (context.mounted) {
                              AppNotification.success(context, isEdit ? "Dompet diperbarui!" : "Dompet berhasil ditambahkan!");
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) AppNotification.error(context, "Gagal menyimpan dompet.");
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletProvider);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Dompet Saya", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.wallets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsRegular.wallet, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 15),
                      Text("Belum ada dompet", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  itemCount: state.wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = state.wallets[index];
                    final colorHex = wallet.color ?? '#1E3A8A';
                    final walletColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

                    // Kartu gradient per-wallet TETAP dipertahankan seperti desain
                    // asli (bukan AppCard) — ini bukan bagian dari masalah
                    // konsistensi tab/card generik yang dilaporkan user.
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [walletColor, walletColor.withOpacity(0.8)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 16),
                                    const SizedBox(width: 10),
                                    Text(wallet.name.toUpperCase(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Theme(
                                  data: Theme.of(context).copyWith(iconTheme: const IconThemeData(color: Colors.white, size: 20)),
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showAddEditWalletSheet(context, ref, wallet: wallet);
                                      } else if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Hapus Dompet?"),
                                            content: Text("Yakin ingin menghapus ${wallet.name}?"),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  ref.read(walletProvider.notifier).deleteWallet(wallet.id).catchError((_) {
                                                    if (context.mounted) {
                                                      AppNotification.error(context, "Gagal menghapus dompet. Pastikan tidak ada transaksi di dompet ini.");
                                                    }
                                                  });
                                                },
                                                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'edit', child: Text("Edit")),
                                      PopupMenuItem(value: 'delete', child: Text("Hapus")),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text("TOTAL SALDO", style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w600)),
                            Text(currencyFormat.format(wallet.balance), style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: state.wallets.isEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditWalletSheet(context, ref),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.wallets.length >= 2) ...[
                  TextButton.icon(
                    onPressed: () => _showTransferSheet(context, ref, state.wallets),
                    icon: const Icon(PhosphorIconsBold.arrowsLeftRight, color: Colors.orange),
                    label: const Text("Transfer", style: TextStyle(color: Colors.orange)),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => _showAddEditWalletSheet(context, ref),
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  label: const Text("Tambah", style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
```

- [ ] **Langkah 3: Hapus file lama**

```bash
git rm lib/screens/wallet_screen.dart
```

- [ ] **Langkah 4: Update import di `home_screen.dart`**

Di `lib/screens/home_screen.dart`, ubah baris:
```dart
import 'package:catat_uang_app/screens/wallet_screen.dart';
```
menjadi:
```dart
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
```
Semua 6 pemanggilan `WalletScreen()` di file yang sama tidak perlu diubah — constructor-nya tidak berubah.

- [ ] **Langkah 5: `flutter analyze`**

Jalankan:
```bash
flutter analyze lib/screens/wallet/wallet_screen.dart lib/screens/home_screen.dart
```
Ekspektasi: tidak ada error baru. Perbaiki error compile apa pun yang muncul (kemungkinan ada penyesuaian kecil kalau API `AppCard`/`showAppBottomSheet`/`walletProvider` dari task sebelumnya sedikit berbeda dari yang diasumsikan di sini).

- [ ] **Langkah 6: `flutter test` (seluruh suite, pastikan tidak ada regresi)**

Jalankan:
```bash
flutter test
```
Ekspektasi: semua test baru (Task 2-6) lulus. Kegagalan `test/widget_test.dart` (scaffold counter default) tetap ada seperti sebelumnya — itu pre-existing dan di luar cakupan rencana ini (lihat ledger setup agent-first).

- [ ] **Langkah 7: Verifikasi visual pakai skill `run-and-screenshot`**

Jalankan aplikasi (`flutter run -d chrome`), login, buka halaman Dompet, cek:
- List wallet tampil dengan gradient card seperti sebelumnya (tidak berubah visual).
- Tombol "Tambah" membuka bottom sheet baru (dari `showAppBottomSheet`), form berfungsi, submit berhasil menambah wallet.
- Kalau ada ≥2 wallet, tombol "Transfer" muncul dan bottom sheet transfer berfungsi (validasi saldo, validasi sumber≠tujuan, transfer berhasil mengubah saldo kedua wallet).
- Edit dan hapus wallet dari popup menu masih berfungsi seperti semula.

Laporkan temuan visual apa adanya — kalau ada yang terlihat rusak dibanding versi asli, catat sebagai temuan untuk diperbaiki di langkah ini, bukan dilaporkan selesai begitu saja.

- [ ] **Langkah 8: Commit**

```bash
git add -A lib/screens/wallet lib/screens/home_screen.dart
git commit -m "refactor(wallet): migrate WalletScreen to feature-first folder with provider + shared widgets"
```

---

## Task 8: Verifikasi akhir

**Files:** tidak ada (hanya verifikasi)

- [ ] **Langkah 1: `flutter analyze` penuh**

Jalankan:
```bash
flutter analyze
```
Ekspektasi: tidak ada **error** baru dibanding baseline (245 issues pre-existing yang sudah didokumentasikan sebelum rencana ini, semuanya `info`-level, tidak terkait perubahan Fase 1).

- [ ] **Langkah 2: `flutter test` penuh**

Jalankan:
```bash
flutter test
```
Ekspektasi: semua test baru dari Task 2, 3, 4, 5, 6 lulus (total 11 test baru: 2+1+2+2+4). Satu kegagalan pre-existing (`test/widget_test.dart`) tetap ada, sudah didokumentasikan sebagai di luar cakupan.

- [ ] **Langkah 3: Konfirmasi struktur folder sesuai rencana**

Jalankan:
```bash
ls lib/widgets/ lib/providers/ lib/theme/ lib/screens/wallet/
```
Ekspektasi:
- `lib/widgets/`: `app_card.dart`, `app_bottom_sheet.dart`, `app_button.dart`, `app_tab_selector.dart`
- `lib/providers/`: `wallet_provider.dart`
- `lib/theme/`: `app_forui_theme.dart`
- `lib/screens/wallet/`: `wallet_screen.dart` (dan TIDAK ada `lib/screens/wallet_screen.dart` lagi)

- [ ] **Langkah 4: Status git bersih**

Jalankan:
```bash
git status
git log --oneline -10
```
Ekspektasi: working tree bersih, terlihat 8 commit baru (Task 1-8) dengan pesan Conventional Commits.
