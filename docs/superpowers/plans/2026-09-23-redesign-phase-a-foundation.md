# Redesign Phase A (Fondasi + Home Screen) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti palet warna DompetKu ke hijau, ganti font ke Plus Jakarta Sans, bangun komponen floating-pill bottom nav baru, dan bangun ulang layout visual `home_screen.dart` (mobile + web) mengikuti referensi fintech — tanpa mengubah fitur/data/fungsi apa pun.

**Arsitektur:** Perubahan warna & font di `lib/core/colors.dart` + `lib/theme/app_forui_theme.dart` + `lib/main.dart` bersifat global (satu tempat, otomatis nyebar ke semua screen lewat `appForuiTheme`). Komponen baru `AppBottomNav` ditambah ke `lib/widgets/`. Layout `home_screen.dart` diubah section-per-section (bukan rewrite total) supaya tiap perubahan bisa diverifikasi terpisah — semua binding ke `homeProvider` tetap sama persis.

**Tech Stack:** Flutter/Dart, `forui` (sudah terpasang), `google_fonts` (sudah terpasang, tinggal ganti nama font), Riverpod (tidak berubah — provider tetap `homeProvider`).

**Spec:** `docs/superpowers/specs/2026-09-23-redesign-phase-a-foundation-design.md`

## Global Constraints

- **Fitur/fungsi/data TIDAK BOLEH berubah** — semua yang bisa dilakukan user hari ini (navigasi ke 12 fitur, lihat saldo, lihat 4 stat card, lihat list dompet, tambah transaksi, ganti tab bawah) harus tetap bisa dilakukan persis sama setelah redesign. Hanya presentasi visualnya yang berubah.
- Warna semantik `income` (hijau) dan `expense` (merah) TIDAK berubah maknanya — tetap dipakai untuk indikasi pemasukan/pengeluaran di seluruh app.
- Tidak ada perubahan skema Supabase, tidak ada perubahan ke `homeProvider`'s state shape atau logic.
- Font berubah secara GLOBAL (bukan cuma Home) — begitu Task 1 selesai, semua 24 screen langsung pakai Plus Jakarta Sans.
- `home_screen.dart`'s mobile layout (`_buildMobileLayout`) DAN web layout (`_buildWebHomeContent`/`_buildWebLayout`) berdua harus di-update — tidak boleh cuma salah satu.
- Web layout memakai `NavigationRail` (sidebar), BUKAN floating pill bottom nav — itu pola navigasi yang sudah sesuai untuk layar lebar, hanya direstyle warnanya, bukan diganti strukturnya (sesuai spec Bagian 4, "implementer boleh mengadaptasi... didokumentasikan").
- Commit pakai Conventional Commits, regex: `^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9_-]+\))?!?: .+`.

---

## Task 1: Palet warna baru + font Plus Jakarta Sans

**Files:**
- Modify: `lib/core/colors.dart`
- Modify: `lib/theme/app_forui_theme.dart`
- Modify: `lib/main.dart:61`, `lib/main.dart:84`
- Modify: `AGENTS.md` (Conventions section — font)

**Interfaces:**
- Menghasilkan: `AppColors` dengan nilai baru (nama field TIDAK berubah — semua kode yang sudah memakai `AppColors.primary` dkk di seluruh app tetap valid tanpa perubahan lain), font global Plus Jakarta Sans.

- [ ] **Langkah 1: Update `lib/core/colors.dart`**

Ganti isi file jadi:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1B4D3E); // Hijau tua (hero card, tombol utama)
  static const Color background = Color(0xFFF2FAF5); // Hijau pastel sangat muda
  static const Color white = Colors.white;
  static const Color income = Color(0xFF4ADE80); // Hijau segar, dibedakan dari primary
  static const Color expense = Color(0xFFE74C3C); // Merah soft (tidak berubah)
  static const Color textPrimary = Color(0xFF1C2B24); // Hitam kehijauan
  static const Color textSecondary = Color(0xFF6B8577); // Abu kehijauan
  static const Color accent = Color(0xFFF5A623); // Amber hangat, aksen pelengkap
}
```

- [ ] **Langkah 2: Update `lib/theme/app_forui_theme.dart`**

Baca file saat ini dulu untuk memastikan konteks di sekitar baris 44 masih sama. Ganti baris:
```dart
    defaultFontFamily: GoogleFonts.poppins().fontFamily!,
```
menjadi:
```dart
    defaultFontFamily: GoogleFonts.plusJakartaSans().fontFamily!,
```
Field `colors:` yang memetakan ke `AppColors.primary` dkk TIDAK perlu diubah kodenya — nilai barunya otomatis terpakai karena sudah diganti di Langkah 1 (referensi ke `AppColors.primary`, bukan hardcode hex).

- [ ] **Langkah 3: Update `lib/main.dart`**

Baris 61 (`ThemeData.light().textTheme` — verifikasi konteks persis dari file, argumen mungkin berbeda):
```dart
            textTheme: GoogleFonts.poppinsTextTheme(
```
→
```dart
            textTheme: GoogleFonts.plusJakartaSansTextTheme(
```

Baris 84:
```dart
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
```
→
```dart
            textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
```

- [ ] **Langkah 4: Update dokumentasi konvensi di `AGENTS.md`**

Cari baris di bagian **Conventions**:
```
- **Font:** `google_fonts` Poppins (`GoogleFonts.poppinsTextTheme(...)`),
  applied once in `main.dart`'s `ThemeData.textTheme`.
```
Ganti jadi:
```
- **Font:** `google_fonts` Plus Jakarta Sans
  (`GoogleFonts.plusJakartaSansTextTheme(...)`), applied once in
  `main.dart`'s `ThemeData.textTheme` (light & dark), and mapped into
  `appForuiTheme`'s typography for forui widgets.
```
Juga cari baris warna di bagian yang sama (kalau ada referensi ke warna lama seperti "Dark Blue Grey") dan sesuaikan supaya tidak menyesatkan agent berikutnya — cek isi `AGENTS.md` saat ini dulu, sesuaikan deskripsi warna agar mencerminkan identitas hijau baru.

- [ ] **Langkah 5: Verifikasi**

Jalankan:
```bash
flutter analyze
```
Ekspektasi: tidak ada error baru. Font/warna adalah perubahan tipe/nilai konstanta sederhana — risiko compile error rendah, tapi tetap wajib dicek.

- [ ] **Langkah 6: Commit**

```bash
git add lib/core/colors.dart lib/theme/app_forui_theme.dart lib/main.dart AGENTS.md
git commit -m "feat(theme): switch to green palette and Plus Jakarta Sans font"
```

---

## Task 2: Komponen `AppBottomNav` (floating pill bottom nav)

**Files:**
- Create: `lib/widgets/app_bottom_nav.dart`
- Create: `test/widgets/app_bottom_nav_test.dart`

**Interfaces:**
- Konsumsi: `AppColors` (Task 1, sudah dengan nilai hijau baru).
- Menghasilkan: `AppBottomNavItem` (data class: `icon`, `activeIcon` opsional, `activeColor` opsional) dan `AppBottomNav` widget (`items`, `selectedIndex`, `onChanged`). Dipakai Task 3 menggantikan `BottomAppBar` di `home_screen.dart`.

- [ ] **Langkah 1: Tulis widget test yang gagal**

Buat `test/widgets/app_bottom_nav_test.dart`:

```dart
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  final items = const [
    AppBottomNavItem(icon: PhosphorIconsRegular.house, activeIcon: PhosphorIconsFill.house),
    AppBottomNavItem(icon: PhosphorIconsRegular.wallet, activeIcon: PhosphorIconsFill.wallet),
  ];

  testWidgets('AppBottomNav menampilkan semua item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(items: items, selectedIndex: 0, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.house), findsOneWidget); // item aktif pakai activeIcon
    expect(find.byIcon(PhosphorIconsRegular.wallet), findsOneWidget); // item tidak aktif pakai icon biasa
  });

  testWidgets('AppBottomNav memanggil onChanged dengan index yang benar saat item ditap', (tester) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(
            items: items,
            selectedIndex: 0,
            onChanged: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(PhosphorIconsRegular.wallet));
    await tester.pump();

    expect(tappedIndex, 1);
  });

  testWidgets('AppBottomNav memakai activeColor kustom untuk item aktif jika diberikan', (tester) async {
    final coloredItems = const [
      AppBottomNavItem(icon: PhosphorIconsRegular.house),
      AppBottomNavItem(icon: PhosphorIconsRegular.wallet, activeColor: Colors.red),
    ];

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(items: coloredItems, selectedIndex: 1, onChanged: (_) {}),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.wallet));
    expect(icon.color, Colors.red);
  });
}
```

- [ ] **Langkah 2: Jalankan test, pastikan gagal**

Jalankan:
```bash
flutter test test/widgets/app_bottom_nav_test.dart
```
Ekspektasi: GAGAL — `app_bottom_nav.dart` belum ada.

- [ ] **Langkah 3: Buat implementasi**

Buat `lib/widgets/app_bottom_nav.dart`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';

/// Satu item navigasi di [AppBottomNav].
///
/// [activeIcon] opsional — dipakai saat item ini aktif, biasanya varian
/// "fill" dari [icon] (mengikuti pola PhosphorIcons regular/fill yang
/// sudah dipakai di project ini). Kalau tidak diberikan, [icon] dipakai
/// terus baik aktif maupun tidak.
///
/// [activeColor] opsional — override warna saat item ini aktif. Dipakai
/// untuk mempertahankan pewarnaan semantik per-tab yang sudah ada di
/// bottom nav lama (misal tab "Pemasukan" berwarna hijau/income, tab
/// "Pengeluaran" berwarna merah/expense), bukan warna primary yang sama
/// untuk semua tab.
class AppBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final Color? activeColor;

  const AppBottomNavItem({required this.icon, this.activeIcon, this.activeColor});
}

/// Floating pill bottom navigation standar aplikasi.
///
/// Beda dari AppCard/AppButton/dll, widget ini TIDAK membungkus primitive
/// forui tertentu — dibangun dari widget Flutter dasar (Container + Row),
/// karena forui 0.17.0 tidak punya primitive floating-bottom-nav siap
/// pakai (diverifikasi terhadap source forui yang terpasang saat komponen
/// ini pertama dibuat). Warna non-aktif & background pill mengikuti
/// [AppColors]; warna aktif per-item bisa di-override lewat
/// [AppBottomNavItem.activeColor].
class AppBottomNav extends StatelessWidget {
  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++) _buildItem(context, i),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = items[index];
    final isSelected = index == selectedIndex;
    final activeColor = item.activeColor ?? AppColors.primary;

    return GestureDetector(
      onTap: () => onChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? (item.activeIcon ?? item.icon) : item.icon,
          color: isSelected ? activeColor : AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
```

- [ ] **Langkah 4: Jalankan test, pastikan lulus**

Jalankan:
```bash
flutter test test/widgets/app_bottom_nav_test.dart
```
Ekspektasi: LULUS (3/3 test).

- [ ] **Langkah 5: `flutter analyze`**

Jalankan:
```bash
flutter analyze lib/widgets/app_bottom_nav.dart test/widgets/app_bottom_nav_test.dart
```
Ekspektasi: bersih.

- [ ] **Langkah 6: Commit**

```bash
git add lib/widgets/app_bottom_nav.dart test/widgets/app_bottom_nav_test.dart
git commit -m "feat(widgets): add AppBottomNav floating pill navigation component"
```

---

## Task 3: Redesign layout mobile `home_screen.dart`

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

**Interfaces:**
- Konsumsi: `AppBottomNav`/`AppBottomNavItem` (Task 2), `AppColors` (Task 1, nilai baru).
- Tidak ada perubahan ke `homeProvider`, `ref.watch(homeProvider)`, atau signature method manapun yang dipanggil dari luar file ini.

Baca `lib/screens/home/home_screen.dart` secara penuh dulu (1237 baris) sebelum mengedit, supaya konteks persis di sekitar tiap perubahan di bawah ini cocok dengan isi file saat ini (nomor baris berikut adalah referensi saat plan ini ditulis, bisa sedikit bergeser).

- [ ] **Langkah 1: Restyle hero balance card (baris ~230-327, di dalam `_buildMobileHomeContent`)**

Ganti `Color(0xFF2C3E50)` (2 kemunculan di card ini — background & shadow color) jadi `AppColors.primary`. Ganti `BorderRadius.circular(25)` jadi `BorderRadius.circular(28)` (sedikit lebih rounded, sesuai arah referensi). Konten di dalam card (Row judul + icon wallet, angka saldo, 4 `_buildCardStatItem`) TIDAK berubah strukturnya — hanya warna container luar.

Sebelum:
```dart
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2C3E50).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
```
Sesudah:
```dart
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
```

- [ ] **Langkah 2: Restyle `_buildFeatureButton` (baris ~109-152) — quick action grid**

Perbesar radius dan perhalus shadow supaya konsisten dengan arah desain baru (card putih rounded, referensi Quick Action). Data/label/icon/onTap 12 tombol grid TIDAK berubah — hanya method styling-nya.

Sebelum:
```dart
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
```
Sesudah:
```dart
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
```

- [ ] **Langkah 3: Restyle card dompet horizontal (baris ~416-469, di dalam `_buildMobileHomeContent`)**

Perbesar radius dari `15` ke `20` supaya konsisten dengan hero card yang lebih rounded. Tidak ada perubahan lain pada card ini (masih pakai `walletColor` per-dompet, itu data asli, bukan bagian dari desain sistem — dipertahankan).

Cari:
```dart
                          decoration: BoxDecoration(
                            color: walletColor,
                            borderRadius: BorderRadius.circular(15),
```
(di dalam `itemBuilder` list dompet mobile)
Ganti `BorderRadius.circular(15)` → `BorderRadius.circular(20)`.

- [ ] **Langkah 4: Ganti bottom nav + reposisi FAB di `_buildMobileLayout` (baris ~1036-1127)**

Ganti seluruh isi method `_buildMobileLayout()`. Item nav mengikuti urutan & pewarnaan semantik yang SAMA PERSIS dengan `BottomAppBar` lama (index 0=Home/primary, 1=Pemasukan/income hijau, 2=Pengeluaran/expense merah, 3=Statistik/primary) — hanya bungkusnya yang berganti dari `BottomAppBar` manual ke `AppBottomNav`. FAB dipindah dari `centerDocked` (butuh notch dari `BottomAppBar`) ke `centerFloat` dengan padding tambahan supaya melayang di atas pill nav yang baru (pill nav tidak py Container biasa, bukan `Scaffold.bottomNavigationBar` dengan notch geometry, jadi FAB tidak bisa "masuk" ke notch seperti sebelumnya — ini penyesuaian struktural yang disengaja, dicatat di sini supaya bukan penyimpangan diam-diam).

```dart
  Widget _buildMobileLayout() {
    final List<Widget> pages = [
      _buildMobileHomeContent(),
      TransactionHistoryScreen(
        key: ValueKey('pemasukan_$_refreshCounter'),
        isExpense: false,
      ),
      TransactionHistoryScreen(
        key: ValueKey('pengeluaran_$_refreshCounter'),
        isExpense: true,
      ),
      StatsScreen(key: ValueKey('stats_$_refreshCounter')),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_selectedIndex],
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          onPressed: () async {
            bool isPengeluaran = _selectedIndex == 2;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    InputTransactionScreen(initialIsExpense: isPengeluaran),
              ),
            );
            ref.read(homeProvider.notifier).refreshData();
            _bumpRefreshCounter();
          },
          backgroundColor: AppColors.primary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: AppBottomNav(
        items: [
          const AppBottomNavItem(
            icon: PhosphorIconsRegular.house,
            activeIcon: PhosphorIconsFill.house,
          ),
          AppBottomNavItem(
            icon: PhosphorIconsRegular.wallet,
            activeIcon: PhosphorIconsFill.wallet,
            activeColor: AppColors.income,
          ),
          AppBottomNavItem(
            icon: PhosphorIconsRegular.receipt,
            activeIcon: PhosphorIconsFill.receipt,
            activeColor: AppColors.expense,
          ),
          const AppBottomNavItem(
            icon: PhosphorIconsRegular.chartPieSlice,
            activeIcon: PhosphorIconsFill.chartPieSlice,
          ),
        ],
        selectedIndex: _selectedIndex,
        onChanged: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
```

Tambah import di bagian atas file:
```dart
import 'package:catat_uang_app/widgets/app_bottom_nav.dart';
```

- [ ] **Langkah 5: `flutter analyze`**

Jalankan:
```bash
flutter analyze lib/screens/home/home_screen.dart
```
Ekspektasi: tidak ada error baru. Perbaiki kalau ada import yang belum lengkap atau nama parameter yang meleset dari kode `AppBottomNav` di Task 2.

- [ ] **Langkah 6: `flutter test` (full suite, pastikan tidak ada regresi)**

Jalankan:
```bash
flutter test
```
Ekspektasi: semua test dari Task 2 lulus, kegagalan `test/widget_test.dart` tetap ada seperti biasa (pre-existing, tidak terkait).

- [ ] **Langkah 7: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(home): redesign mobile layout with new hero card, quick actions, and floating pill nav"
```

---

## Task 4: Redesign layout web/desktop `home_screen.dart`

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

**Interfaces:**
- Konsumsi: `AppColors` (Task 1). Web layout TIDAK memakai `AppBottomNav` — tetap `NavigationRail`, hanya direstyle warnanya (lihat Global Constraints).

- [ ] **Langkah 1: Restyle hero balance card web (baris ~769-834, di dalam `_buildWebHomeContent`)**

Sama seperti Task 3 Langkah 1, tapi untuk versi web (2 kemunculan `Color(0xFF2C3E50)`, radius `30`→`32`).

Sebelum:
```dart
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2C3E50).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
```
Sesudah:
```dart
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
```

- [ ] **Langkah 2: Restyle `_buildWebFeatureButton` (baris ~655-699)**

Sama pola dengan Task 3 Langkah 2, versi web (radius `20`→`24`).

Sebelum:
```dart
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 32),
            ),
```
Sesudah:
```dart
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 30),
            ),
```

- [ ] **Langkah 3: Restyle card dompet grid web (baris ~904-916)**

Radius `20` (sudah cukup rounded) — TIDAK perlu diubah. Tidak ada langkah di sini; dicek dan dikonfirmasi sudah sesuai arah desain baru.

- [ ] **Langkah 4: Restyle `NavigationRail` di `_buildWebLayout` (baris ~1149-1192)**

`activeColor`/`inactiveColor` di awal method (baris ~1130-1131) sudah otomatis memakai `AppColors.primary` (nilai baru dari Task 1) — TIDAK perlu diubah kodenya. Cukup ubah judul aplikasi di `leading` supaya tetap konsisten (opsional, cek isi `leading` saat ini — kalau sudah pakai `activeColor` untuk teks "DompetKu", tidak ada perubahan kode diperlukan di sini juga, karena warnanya otomatis ikut Task 1).

Tidak ada kode tambahan di langkah ini — ini langkah verifikasi bahwa `NavigationRail` sudah otomatis konsisten lewat variabel `activeColor`/`inactiveColor` yang sudah ada, bukan tempat baru untuk diedit. Implementer konfirmasi ini di laporan (baca method-nya, pastikan tidak ada hardcoded hex color selain lewat `activeColor`/`inactiveColor`/`AppColors.*`).

- [ ] **Langkah 5: `flutter analyze`**

Jalankan:
```bash
flutter analyze lib/screens/home/home_screen.dart
```
Ekspektasi: tidak ada error baru.

- [ ] **Langkah 6: `flutter test` (full suite)**

Jalankan:
```bash
flutter test
```
Ekspektasi: sama seperti Task 3 Langkah 6 — tidak ada regresi baru.

- [ ] **Langkah 7: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(home): redesign web layout hero card and quick actions to match new palette"
```

---

## Task 5: Verifikasi akhir

**Files:** tidak ada (hanya verifikasi)

- [ ] **Langkah 1: `flutter analyze` penuh**

Jalankan:
```bash
flutter analyze
```
Ekspektasi: tidak ada error baru dibanding baseline sebelum Fase A (205 issues, 0 error, dari akhir Fase 2).

- [ ] **Langkah 2: `flutter test` penuh**

Jalankan:
```bash
flutter test
```
Ekspektasi: semua test baru dari Task 2 (3 test `AppBottomNav`) lulus. Satu kegagalan pre-existing (`test/widget_test.dart`) tetap ada, sudah didokumentasikan sebagai di luar cakupan sejak Fase 1.

- [ ] **Langkah 3: Konfirmasi tidak ada `Color(0xFF2C3E50)` hardcode tersisa**

Jalankan:
```bash
grep -rn "0xFF2C3E50" lib/screens/home/home_screen.dart
```
Ekspektasi: tidak ada hasil (semua sudah diganti `AppColors.primary` di Task 3 & 4).

- [ ] **Langkah 4: Verifikasi visual manual oleh user (WAJIB)**

Jalankan aplikasi (`flutter run -d chrome`), buka Home:
- Cek hero card warna hijau baru, angka saldo & 4 stat item (Masuk/Keluar/Tabungan/Investasi) masih tampil benar dengan data yang sama seperti sebelumnya.
- Cek quick action grid (12 tombol) semua masih bisa ditap dan mengarah ke screen yang benar.
- Cek list dompet horizontal masih tampil dan bisa di-scroll.
- Cek bottom nav baru (floating pill) — tap tiap tab (Home/Pemasukan/Pengeluaran/Statistik), pastikan warna aktif sesuai (hijau untuk Pemasukan, merah untuk Pengeluaran), dan isi tab masih benar (data yang sama seperti sebelum redesign).
- Cek FAB (tombol tambah) masih bisa ditekan dan tidak tertutup/tertimpa bottom nav baru.
- Kalau ada layar lebar (resize browser >800px atau buka di `-d windows`), cek `NavigationRail` web juga sudah warna hijau baru.

Laporkan temuan apa adanya — kalau ada yang terlihat rusak/aneh, itu jadi temuan untuk diperbaiki, bukan dilaporkan selesai begitu saja.

- [ ] **Langkah 5: Status git bersih**

Jalankan:
```bash
git status
git log --oneline -6
```
Ekspektasi: working tree bersih, terlihat 4 commit baru (Task 1-4) dengan pesan Conventional Commits.
