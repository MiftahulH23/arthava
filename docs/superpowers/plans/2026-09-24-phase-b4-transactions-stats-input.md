# Phase B4 — Transaksi, Statistik, Tambah Transaksi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mendesain ulang tab Transaksi, tab Statistik, dan halaman Tambah/Edit Transaksi ke gaya iOS sesuai mockup, tanpa mengubah fitur maupun logika provider.

**Architecture:** Presentasi saja. Provider (`transaction_history_provider.dart`, `stats_provider.dart`, `input_transaction_provider.dart`) TIDAK diubah. Screen dibangun ulang dari komponen Plan B1 (spec §6). Logika presentasi yang dipakai dua screen diekstrak ke helper bersama: pemilih periode, sheet filter, pengelompokan transaksi per tanggal, dan ikon/warna kategori. Tab Transaksi dan Statistik tetap tertanam di Home (`extendBody: true`), jadi keduanya memakai `AppPageScaffold(embedded: true)`.

**Tech Stack:** Flutter, flutter_riverpod 2.6.1, forui 0.17.0, fl_chart, phosphor_flutter, intl (id_ID), google_fonts (Plus Jakarta Sans via `AppTextStyles`).

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (baca §3, §4, §5, §6, §7.4, §9, §10). Mockup: `docs/design/dompetku-redesign-mockup.html`, entri `SCREENS` bernama **"Transaksi"**, **"Statistik"**, **"Tambah Transaksi"**.

**Prasyarat:** Plan B1 sudah di-merge ke `main`, sehingga semua komponen spec §6 dan `test/helpers/pump_app.dart` sudah ada. Urutan eksekusi menurut spec §8 adalah B1 → B2 → B3 → B4, jadi B2 (Utang) dan B3 (Beranda/Dompet) semestinya sudah ter-merge juga. Task 4 menangani baris `[DEBT_ID:` dari B2 secara idempoten.

## Global Constraints

Disalin dari spec §9 dan §10. Berlaku untuk setiap task.

1. **Jangan jalankan `dart format` ke seluruh file.** Edit terarah saja. Diff harus sebanding dengan perubahan.
2. `Notifier.build()` tidak boleh menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)`. Plan ini tidak menyentuh `build()` provider.
3. Refresh provider lewat `ref.invalidate(...)`, bukan dengan mengganti `ValueKey`. `ValueKey('pemasukan_$refreshCounter')` / `ValueKey('pengeluaran_$refreshCounter')` yang sudah ada tetap dipertahankan persis.
4. Setelah `await`, terutama `Navigator.push`, cek `if (!mounted) return;` sebelum memakai `setState`, `context`, atau `ref`.
5. Tab di dalam Home (`extendBody: true`) memakai `AppPageScaffold(embedded: true)`, yang sudah menangani `SafeArea(bottom:false)` dan padding bawah.
6. Jangan menaruh `Center`/`Align`/`Expanded` tanpa batas di slot yang memberi tinggi longgar.
7. Pertahankan konkurensi fetch asli. Provider tidak diubah, jadi `Future.wait` di `fetchAll()` tetap sama.
8. Semua `onTap`, navigasi, dan efek samping lama dipertahankan persis. Rinciannya ada di tabel preservasi tiap task.
9. Tidak ada hex di screen; semua warna dari `AppColors`. Pengecualian: `Colors.white`, `Colors.transparent`, dan warna dompet dari data.
10. Commit message memakai Conventional Commits dengan scope tanpa koma, dan diakhiri dua baris atribusi:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
    ```
11. Plan ini tidak mengubah skema DB.
12. Verifikasi per screen (spec §10):
    - `flutter analyze` tanpa error atau warning baru.
    - `flutter test` hijau.
    - `grep -c "GoogleFonts.poppins" <file>` = 0.
    - Tidak ada hex atau `Colors.<warna>` baru.
    - Checklist visual dicocokkan ke mockup dengan skill `run-and-screenshot`, atau lewat screenshot dari user di Task 7.
13. Branch kerja: `redesign/phase-b4-transactions` dari `main`.

## Review Focus

Lima kondisi yang tidak dicakup langsung oleh test fungsional utama tetapi paling mungkin mengganggu pengguna. Masing-masing sudah dipasangi test di task pemiliknya.

1. **Filter aktif menghasilkan 0 transaksi.** Pill tanggal dan pill "Filter" harus tetap terlihat di atas empty state, supaya user bisa mereset filter. Test di Task 4 (`empty state tetap menampilkan pill Filter`).
2. **Transaksi di hari yang sama dengan jam berbeda, atau input yang tidak terurut.** Keduanya harus tetap masuk satu grup tanggal dan urutan kemunculan tidak boleh berubah. Test di Task 1 (`groupTransactionsByDate`).
3. **Nama kategori, catatan, atau nama dompet yang sangat panjang.** Tidak boleh terjadi `RenderFlex overflow`; teks harus terpotong dengan ellipsis. Test di Task 4 (`teks panjang tidak overflow`).
4. **Transaksi otomatis dari Tabungan dalam mode read-only.** Tipe transaksi tidak bisa diganti dan field tidak bisa diedit; tombol bawah berbunyi "Kembali". Test di Task 6 (`read-only mengunci segmented & tombol Kembali`).
5. **Baris mutasi internal (tabungan `[SAVING_ID:` dan utang `[DEBT_ID:`).** Baris ini tidak bisa digeser untuk dihapus, dan nominalnya tampil dicoret. Test di Task 4 (`baris mutasi tidak punya swipe`).

---

## File Structure

| File | Aksi | Tanggung jawab |
|---|---|---|
| `lib/core/category_visuals.dart` | Create | `categoryIcon(String)` dan `categoryColor(String)`. Ikon dipindah dari `_getCategoryIcon` di input screen; warna tint per kategori dipakai list transaksi dan picker. |
| `lib/screens/transaction_history/transaction_grouping.dart` | Create | Fungsi murni `groupTransactionsByDate`. |
| `lib/widgets/app_period_picker.dart` | Create | `kPeriodFilterTypes`, `periodLabel(...)`, dan `showAppPeriodPicker(...)`. Pemilih tanggal per tipe periode, yang sebelumnya diduplikasi di dua screen. |
| `lib/screens/transaction_history/transaction_filter_sheet.dart` | Create | `TransactionFilterData` dan `showTransactionFilterSheet(...)`. Sheet filter kategori/dompet, yang sebelumnya diduplikasi di dua screen. |
| `lib/widgets/app_page_scaffold.dart` | Modify (seam) | Tambah parameter opsional `leading`, dipakai untuk tombol "Batal" di Tambah Transaksi. |
| `lib/widgets/app_swipe_actions.dart` | Modify (seam) | Tambah parameter opsional `deleteConfirmTitle` dan `deleteConfirmMessage`, supaya teks dialog hapus transaksi tetap persis seperti sekarang. |
| `lib/screens/transaction_history/transaction_history_screen.dart` | Modify | Layout baru tab Transaksi. |
| `lib/screens/transaction_history/transactions_tab_screen.dart` | Modify | Segmented Pemasukan/Pengeluaran diteruskan ke screen riwayat. |
| `lib/screens/stats/stats_screen.dart` | Modify | Layout baru tab Statistik. |
| `lib/screens/input_transaction/input_transaction_screen.dart` | Modify | Layout baru bergaya sheet. |
| `test/core/category_visuals_test.dart` | Create | Unit test. |
| `test/screens/transaction_history/transaction_grouping_test.dart` | Create | Unit test. |
| `test/widgets/app_period_picker_test.dart` | Create | Unit test `periodLabel`. |
| `test/screens/transaction_history/transaction_filter_sheet_test.dart` | Create | Widget test sheet filter. |
| `test/widgets/app_page_scaffold_test.dart` / `test/widgets/app_swipe_actions_test.dart` | Modify | Test untuk seam. |
| `test/screens/transaction_history/transaction_history_screen_test.dart` | Create | Widget test tab Transaksi. |
| `test/screens/stats/stats_screen_test.dart` | Create | Widget test Statistik. |
| `test/screens/input_transaction/input_transaction_screen_test.dart` | Create | Widget test Tambah Transaksi. |

---

### Task 1: Helper murni — pengelompokan tanggal, visual kategori, label periode

**Files:**
- Create: `lib/screens/transaction_history/transaction_grouping.dart`
- Create: `lib/core/category_visuals.dart`
- Create: `lib/widgets/app_period_picker.dart` (bagian `kPeriodFilterTypes` + `periodLabel` saja; `showAppPeriodPicker` ditambah di Task 3)
- Test: `test/screens/transaction_history/transaction_grouping_test.dart`, `test/core/category_visuals_test.dart`, `test/widgets/app_period_picker_test.dart`

**Interfaces:**
- Consumes: `TransactionModel` (`lib/models/transaction_model.dart`), `AppColors.tint*`/`AppColors.primary` (Plan B1).
- Produces:
  - `List<(DateTime, List<TransactionModel>)> groupTransactionsByDate(List<TransactionModel> transactions)`. Tanggal kunci dinormalisasi ke jam 00:00. Urutan grup = urutan kemunculan pertama, dan urutan item di dalam grup dipertahankan.
  - `IconData categoryIcon(String categoryName)`
  - `Color categoryColor(String categoryName)`
  - `const List<String> kPeriodFilterTypes = ['Harian', 'Bulanan', 'Tahunan', 'Periode'];`
  - `String periodLabel(String filterType, DateTime selectedDate, DateTimeRange? selectedDateRange)`

- [ ] **Step 1: Buat branch**

```bash
git checkout main && git pull
git checkout -b redesign/phase-b4-transactions
```

- [ ] **Step 2: Tulis test `groupTransactionsByDate` (gagal)**

`test/screens/transaction_history/transaction_grouping_test.dart`:

```dart
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _trx(int id, DateTime date) => TransactionModel(
      id: id,
      userId: 'u',
      categoryId: 1,
      amount: 1000,
      date: date,
    );

void main() {
  test('list kosong menghasilkan list kosong', () {
    expect(groupTransactionsByDate([]), isEmpty);
  });

  test('mengelompokkan per hari dan mempertahankan urutan (desc dari provider)', () {
    final groups = groupTransactionsByDate([
      _trx(3, DateTime(2026, 9, 24)),
      _trx(2, DateTime(2026, 9, 24)),
      _trx(1, DateTime(2026, 9, 23)),
    ]);
    expect(groups.length, 2);
    expect(groups[0].$1, DateTime(2026, 9, 24));
    expect(groups[0].$2.map((t) => t.id), [3, 2]);
    expect(groups[1].$1, DateTime(2026, 9, 23));
    expect(groups[1].$2.map((t) => t.id), [1]);
  });

  test('jam berbeda di hari yang sama masuk satu grup, kunci jam 00:00', () {
    final groups = groupTransactionsByDate([
      _trx(1, DateTime(2026, 9, 24, 23, 59)),
      _trx(2, DateTime(2026, 9, 24, 0, 1)),
    ]);
    expect(groups.length, 1);
    expect(groups.single.$1, DateTime(2026, 9, 24));
  });

  test('input tidak terurut: hari yang sama tetap satu grup, urutan kemunculan pertama', () {
    final groups = groupTransactionsByDate([
      _trx(1, DateTime(2026, 9, 24)),
      _trx(2, DateTime(2026, 9, 20)),
      _trx(3, DateTime(2026, 9, 24)),
    ]);
    expect(groups.map((g) => g.$1), [DateTime(2026, 9, 24), DateTime(2026, 9, 20)]);
    expect(groups[0].$2.map((t) => t.id), [1, 3]);
  });
}
```

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `flutter test test/screens/transaction_history/transaction_grouping_test.dart`
Expected: FAIL, compile error `Target of URI doesn't exist: .../transaction_grouping.dart`.

- [ ] **Step 4: Implementasi**

`lib/screens/transaction_history/transaction_grouping.dart`:

```dart
import 'package:catat_uang_app/models/transaction_model.dart';

/// Mengelompokkan transaksi per hari kalender untuk tampilan list bergrup.
/// Urutan grup mengikuti kemunculan pertama di [transactions] (provider
/// sudah mengurutkan terbaru dulu), urutan item di dalam grup dipertahankan.
List<(DateTime, List<TransactionModel>)> groupTransactionsByDate(
  List<TransactionModel> transactions,
) {
  final groups = <DateTime, List<TransactionModel>>{};
  for (final trx in transactions) {
    final day = DateTime(trx.date.year, trx.date.month, trx.date.day);
    groups.putIfAbsent(day, () => []).add(trx);
  }
  return [for (final entry in groups.entries) (entry.key, entry.value)];
}
```

- [ ] **Step 5: Jalankan, pastikan lulus**

Run: `flutter test test/screens/transaction_history/transaction_grouping_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Tulis test `categoryIcon` / `categoryColor` (gagal)**

`test/core/category_visuals_test.dart`:

```dart
import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  test('categoryIcon memetakan kata kunci seperti _getCategoryIcon lama', () {
    expect(categoryIcon('Makan Siang'), PhosphorIcons.bowlFood(PhosphorIconsStyle.fill));
    expect(categoryIcon('Kopi'), PhosphorIcons.coffee(PhosphorIconsStyle.fill));
    expect(categoryIcon('Bensin'), PhosphorIcons.bus(PhosphorIconsStyle.fill));
    expect(categoryIcon('Indomart'), PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill));
    expect(categoryIcon('Nonton'), PhosphorIcons.gameController(PhosphorIconsStyle.fill));
    expect(categoryIcon('Obat'), PhosphorIcons.firstAid(PhosphorIconsStyle.fill));
    expect(categoryIcon('Tagihan Listrik'), PhosphorIcons.lightning(PhosphorIconsStyle.fill));
    expect(categoryIcon('Gaji'), PhosphorIcons.money(PhosphorIconsStyle.fill));
    expect(categoryIcon('Bonus'), PhosphorIcons.gift(PhosphorIconsStyle.fill));
    expect(categoryIcon('Tabungan'), PhosphorIcons.bank(PhosphorIconsStyle.fill));
    expect(categoryIcon('Lainnya'), PhosphorIcons.tag(PhosphorIconsStyle.fill));
  });

  test('categoryColor memakai tint AppColors, default primary', () {
    expect(categoryColor('Makan'), AppColors.tintOrange);
    expect(categoryColor('Transportasi'), AppColors.tintBlue);
    expect(categoryColor('Tagihan Listrik'), AppColors.tintAmber);
    expect(categoryColor('Gaji'), AppColors.tintGreen);
    expect(categoryColor('Tabungan'), AppColors.tintTeal);
    expect(categoryColor('Sesuatu Baru'), AppColors.primary);
  });
}
```

- [ ] **Step 7: Implementasi `lib/core/category_visuals.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Ikon kategori berdasarkan kata kunci nama (dipindah dari
/// InputTransactionScreen._getCategoryIcon, perilaku sama persis).
IconData categoryIcon(String categoryName) {
  final name = categoryName.toLowerCase();
  if (name.contains('makan')) return PhosphorIcons.bowlFood(PhosphorIconsStyle.fill);
  if (name.contains('minum') || name.contains('kopi') || name.contains('cafe')) {
    return PhosphorIcons.coffee(PhosphorIconsStyle.fill);
  }
  if (name.contains('transport') || name.contains('bensin')) {
    return PhosphorIcons.bus(PhosphorIconsStyle.fill);
  }
  if (name.contains('belanja') || name.contains('mart')) {
    return PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill);
  }
  if (name.contains('hiburan') || name.contains('nonton')) {
    return PhosphorIcons.gameController(PhosphorIconsStyle.fill);
  }
  if (name.contains('kesehatan') || name.contains('obat')) {
    return PhosphorIcons.firstAid(PhosphorIconsStyle.fill);
  }
  if (name.contains('tagihan') || name.contains('listrik')) {
    return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
  }
  if (name.contains('gaji')) return PhosphorIcons.money(PhosphorIconsStyle.fill);
  if (name.contains('bonus')) return PhosphorIcons.gift(PhosphorIconsStyle.fill);
  if (name.contains('tabung')) return PhosphorIcons.bank(PhosphorIconsStyle.fill);
  return PhosphorIcons.tag(PhosphorIconsStyle.fill);
}

/// Warna tint ikon kategori (spec §4.1). Kategori tak dikenal = primary.
Color categoryColor(String categoryName) {
  final name = categoryName.toLowerCase();
  if (name.contains('makan')) return AppColors.tintOrange;
  if (name.contains('minum') || name.contains('kopi') || name.contains('cafe')) {
    return AppColors.tintBrown;
  }
  if (name.contains('transport') || name.contains('bensin')) return AppColors.tintBlue;
  if (name.contains('belanja') || name.contains('mart')) return AppColors.tintPink;
  if (name.contains('hiburan') || name.contains('nonton')) return AppColors.tintIndigo;
  if (name.contains('kesehatan') || name.contains('obat')) return AppColors.tintRed;
  if (name.contains('tagihan') || name.contains('listrik')) return AppColors.tintAmber;
  if (name.contains('gaji')) return AppColors.tintGreen;
  if (name.contains('bonus')) return AppColors.tintSky;
  if (name.contains('tabung')) return AppColors.tintTeal;
  return AppColors.primary;
}
```

Run: `flutter test test/core/category_visuals_test.dart`
Expected: PASS.

- [ ] **Step 8: Tulis test `periodLabel` (gagal)**

`test/widgets/app_period_picker_test.dart`:

```dart
import 'package:catat_uang_app/widgets/app_period_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  final date = DateTime(2026, 9, 24);

  test('kPeriodFilterTypes urutannya persis seperti tab lama', () {
    expect(kPeriodFilterTypes, ['Harian', 'Bulanan', 'Tahunan', 'Periode']);
  });

  test('label per tipe periode sama seperti dateLabel lama', () {
    expect(periodLabel('Harian', date, null), '24 Sep 2026');
    expect(periodLabel('Bulanan', date, null), 'September 2026');
    expect(periodLabel('Tahunan', date, null), '2026');
    expect(
      periodLabel('Periode', date, DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 24))),
      '01 Sep - 24 Sep 26',
    );
    expect(periodLabel('Periode', date, null), 'Pilih Periode');
  });
}
```

- [ ] **Step 9: Implementasi awal `lib/widgets/app_period_picker.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tipe periode filter transaksi/statistik, urutan sama dengan tab lama.
const List<String> kPeriodFilterTypes = ['Harian', 'Bulanan', 'Tahunan', 'Periode'];

/// Label tombol tanggal sesuai tipe periode (dulu `dateLabel` di build()).
String periodLabel(String filterType, DateTime selectedDate, DateTimeRange? selectedDateRange) {
  switch (filterType) {
    case 'Harian':
      return DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate);
    case 'Tahunan':
      return DateFormat('yyyy', 'id_ID').format(selectedDate);
    case 'Periode':
      return selectedDateRange != null
          ? "${DateFormat('dd MMM', 'id_ID').format(selectedDateRange.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(selectedDateRange.end)}"
          : "Pilih Periode";
    default:
      return DateFormat('MMMM yyyy', 'id_ID').format(selectedDate);
  }
}
```

Run: `flutter test test/widgets/app_period_picker_test.dart`
Expected: PASS. Kalau hasil `DateFormat` id_ID berbeda (misalnya "Sep" vs "Sep."), sesuaikan string harapan di test dengan keluaran `DateFormat` yang sebenarnya. Implementasinya tidak perlu diubah, karena format ini identik dengan kode lama.

- [ ] **Step 10: Commit**

```bash
git add lib/screens/transaction_history/transaction_grouping.dart lib/core/category_visuals.dart lib/widgets/app_period_picker.dart test/screens/transaction_history/transaction_grouping_test.dart test/core/category_visuals_test.dart test/widgets/app_period_picker_test.dart
git commit -m "$(cat <<'EOF'
feat(transactions): add date grouping, category visuals and period label helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: Seam komponen — `AppPageScaffold.leading` dan teks konfirmasi `AppSwipeActions`

Spec §6 memperbolehkan penambahan parameter opsional di komponen bila sebuah screen membutuhkannya. Task ini menambah dua parameter tersebut dan melaporkannya di ringkasan akhir.

**Files:**
- Modify: `lib/widgets/app_page_scaffold.dart`
- Modify: `lib/widgets/app_swipe_actions.dart`
- Test: `test/widgets/app_page_scaffold_test.dart`, `test/widgets/app_swipe_actions_test.dart` (tambah test ke file B1 yang sudah ada)

**Interfaces:**
- Produces:
  - `AppPageScaffold({..., Widget? leading})`. Bila `leading != null`, widget itu dipakai di sisi kiri nav bar dan menggantikan tombol kembali, apa pun nilai `backLabel`.
  - `AppSwipeActions(deleteConfirmTitle:, deleteConfirmMessage:)` — SUDAH ADA di B1 (String non-null, default "Hapus?" / "Data ini akan dihapus permanen."). Jangan tambah field; lewati Step 4–5.

- [ ] **Step 1: Baca implementasi B1**

Baca `lib/widgets/app_page_scaffold.dart` dan `lib/widgets/app_swipe_actions.dart` beserta test B1-nya. **Bila B1 sudah punya parameter setara** (nama lain, fungsi sama), pakai parameter itu di Task 4–6, lewati step penambahan parameternya, dan catat pemetaan namanya di laporan. Finder tombol Hapus di test B1 `app_swipe_actions_test.dart` (mis. `find.byIcon(...)`) dipakai ulang di test Task 4.

- [ ] **Step 2: Tulis test gagal untuk `leading`**

Tambahkan ke `test/widgets/app_page_scaffold_test.dart`:

```dart
testWidgets('leading menggantikan tombol kembali', (tester) async {
  var tapped = false;
  await pumpApp(
    tester,
    AppPageScaffold(
      title: 'Tambah Transaksi',
      largeTitle: false,
      backLabel: 'Beranda',
      leading: AppNavAction.text('Batal', onPressed: () => tapped = true),
      children: const [SizedBox.shrink()],
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Beranda'), findsNothing);
  await tester.tap(find.text('Batal'));
  expect(tapped, isTrue);
});
```

- [ ] **Step 3: Implementasi `leading`**

Di `AppPageScaffold`, tambah field `final Widget? leading;` dan parameter konstruktor `this.leading`. Di tempat nav bar membangun sisi kiri, tambahkan kondisi `leading ?? <tombol kembali lama>`:

```dart
final Widget? navLeading = leading ??
    (backLabel != null ? /* widget tombol kembali B1 yang sudah ada */ : null);
```

Jangan ubah perilaku lain.

> **Catatan koordinator (penyelarasan antar-plan):** Plan B1 sudah menyediakan `AppSwipeActions.deleteConfirmTitle` / `deleteConfirmMessage` (tipe `String` non-null dengan default `'Hapus?'` / `'Data ini akan dihapus permanen.'`). **Jangan tambah field baru** — lewati Step 5, dan di Step 4 cukup pastikan test dengan kedua parameter ini lolos terhadap implementasi B1. Semua pemakaian di Task 4–6 memakai nama B1 ini.

- [ ] **Step 4: Tulis test gagal untuk teks konfirmasi**

Tambahkan ke `test/widgets/app_swipe_actions_test.dart`. Pakai finder tombol Hapus yang sama dengan test B1 (lihat Step 1); di contoh ini ditulis `deleteButtonFinder`:

```dart
testWidgets('deleteConfirmTitle & deleteConfirmMessage tampil di dialog hapus', (tester) async {
  var deleted = false;
  await pumpApp(
    tester,
    Scaffold(
      body: AppSwipeActions(
        deleteConfirmTitle: 'Hapus Transaksi?',
        deleteConfirmMessage: 'Data ini akan dihapus permanen.',
        onDelete: () => deleted = true,
        child: const SizedBox(height: 56, width: 390, child: Text('Makan')),
      ),
    ),
  );
  await tester.drag(find.text('Makan'), const Offset(-200, 0));
  await tester.pumpAndSettle();
  await tester.tap(deleteButtonFinder);
  await tester.pumpAndSettle();
  expect(find.text('Hapus Transaksi?'), findsOneWidget);
  expect(find.text('Data ini akan dihapus permanen.'), findsOneWidget);
  await tester.tap(find.text('Hapus').last);
  await tester.pumpAndSettle();
  expect(deleted, isTrue);
});
```

- [ ] **Step 5: Implementasi**

Tambah `final String? deleteConfirmTitle; final String? deleteConfirmMessage;` beserta parameter konstruktornya, lalu pakai keduanya di pemanggilan `showAppConfirmDialog`:

```dart
final confirmed = await showAppConfirmDialog(
  context: context,
  title: widget.deleteConfirmTitle ?? /* judul default B1 */,
  message: widget.deleteConfirmMessage ?? /* pesan default B1 */,
);
```

- [ ] **Step 6: Jalankan test widget**

Run: `flutter test test/widgets/app_page_scaffold_test.dart test/widgets/app_swipe_actions_test.dart`
Expected: PASS (test B1 lama + 2 test baru).

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/app_page_scaffold.dart lib/widgets/app_swipe_actions.dart test/widgets/app_page_scaffold_test.dart test/widgets/app_swipe_actions_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add leading slot and custom delete confirm text

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: Pemilih periode & sheet filter bersama

Logika `_pickDate` dan `_showFilterSheet` identik di `transaction_history_screen.dart` (baris 41–237 dan 239–433) dan `stats_screen.dart` (baris 35–231 dan 233–427). Task ini memindahkannya ke helper bersama dengan tampilan baru, tanpa mengubah perilaku.

**Files:**
- Modify: `lib/widgets/app_period_picker.dart` (tambah `showAppPeriodPicker`)
- Create: `lib/screens/transaction_history/transaction_filter_sheet.dart`
- Test: `test/screens/transaction_history/transaction_filter_sheet_test.dart`

**Interfaces:**
- Consumes: `showAppFormSheet`, `AppPillButton`, `AppPrimaryButton`, `AppTextStyles`, `AppColors` (B1).
- Produces:
  ```dart
  Future<void> showAppPeriodPicker({
    required BuildContext context,
    required String filterType,
    required DateTime selectedDate,
    required DateTimeRange? selectedDateRange,
    required ValueChanged<DateTime> onDateSelected,
    required ValueChanged<DateTimeRange> onRangeSelected,
  });

  class TransactionFilterData {
    const TransactionFilterData({required this.categories, required this.walletNames,
      required this.selectedCategoryIds, required this.selectedWalletIds});
    final List<Map<String, dynamic>> categories;
    final Map<int, String> walletNames;
    final List<int> selectedCategoryIds;
    final List<int> selectedWalletIds;
  }

  Future<void> showTransactionFilterSheet({
    required BuildContext context,
    required Color accentColor,
    required TransactionFilterData Function() readData,
    required void Function(int id, bool selected) onToggleCategory,
    required void Function(int id, bool selected) onToggleWallet,
    required VoidCallback onReset,
    required VoidCallback onApply,
  });
  ```

- [ ] **Step 1: Tambah `showAppPeriodPicker` ke `lib/widgets/app_period_picker.dart`**

Tambahkan import `package:catat_uang_app/core/colors.dart` dan `package:catat_uang_app/theme/app_text_styles.dart`, lalu fungsi berikut. Isinya menyalin percabangan lama persis; hanya gaya teks dan warna yang diganti.

```dart
/// Menampilkan pemilih tanggal sesuai [filterType]. Perilaku identik dengan
/// `_pickDate` lama di TransactionHistoryScreen & StatsScreen:
/// Harian = date picker, Tahunan = dialog YearPicker, Periode = date range
/// picker, lainnya (Bulanan) = dialog grid 12 bulan + dropdown tahun.
Future<void> showAppPeriodPicker({
  required BuildContext context,
  required String filterType,
  required DateTime selectedDate,
  required DateTimeRange? selectedDateRange,
  required ValueChanged<DateTime> onDateSelected,
  required ValueChanged<DateTimeRange> onRangeSelected,
}) async {
  Widget themed(BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      );

  if (filterType == 'Harian') {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: themed,
    );
    if (picked != null) onDateSelected(picked);
  } else if (filterType == 'Tahunan') {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Pilih Tahun", style: AppTextStyles.headline),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            selectedDate: selectedDate,
            onChanged: (DateTime val) {
              Navigator.pop(dialogContext);
              onDateSelected(val);
            },
          ),
        ),
      ),
    );
  } else if (filterType == 'Periode') {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: themed,
    );
    if (picked != null) onRangeSelected(picked);
  } else {
    final currentYear = DateTime.now().year;
    final years = List.generate(11, (i) => (currentYear - 5) + i);
    int tempYear = selectedDate.year;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Pilih Bulan", style: AppTextStyles.headline),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.track,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: tempYear,
                    dropdownColor: AppColors.surface,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: years
                        .map((year) => DropdownMenuItem<int>(
                              value: year,
                              child: Text("$year", style: AppTextStyles.bodyStrong),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => tempYear = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final int monthIndex = index + 1;
                final bool isSelected =
                    selectedDate.month == monthIndex && selectedDate.year == tempYear;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    onDateSelected(DateTime(tempYear, monthIndex));
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.separator,
                      ),
                    ),
                    child: Text(
                      DateFormat('MMM', 'id_ID').format(DateTime(2024, monthIndex)),
                      style: AppTextStyles.body.copyWith(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

Catatan: dialog bulan lama punya `Divider` + `SizedBox(height: 10)` di atas grid. Dua elemen dekoratif ini sengaja dibuang supaya tampilan lebih bersih ala iOS; perilakunya tidak berubah.

- [ ] **Step 2: Tulis test sheet filter (gagal)**

`test/screens/transaction_history/transaction_filter_sheet_test.dart`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('toggle kategori/dompet, reset, lalu terapkan', (tester) async {
    final selectedCats = <int>[];
    final selectedWallets = <int>[];
    var resetCount = 0;
    var applyCount = 0;

    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showTransactionFilterSheet(
                context: context,
                accentColor: AppColors.expense,
                readData: () => TransactionFilterData(
                  categories: const [
                    {'id': 1, 'name': 'Makan'},
                    {'id': 2, 'name': 'Transportasi'},
                  ],
                  walletNames: const {10: 'BCA', 11: 'GoPay'},
                  selectedCategoryIds: List.of(selectedCats),
                  selectedWalletIds: List.of(selectedWallets),
                ),
                onToggleCategory: (id, sel) => sel ? selectedCats.add(id) : selectedCats.remove(id),
                onToggleWallet: (id, sel) => sel ? selectedWallets.add(id) : selectedWallets.remove(id),
                onReset: () {
                  resetCount++;
                  selectedCats.clear();
                  selectedWallets.clear();
                },
                onApply: () => applyCount++,
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Filter Transaksi'), findsOneWidget);
    expect(find.text('KATEGORI'), findsOneWidget);
    expect(find.text('DOMPET'), findsOneWidget);

    await tester.tap(find.text('Makan'));
    await tester.pumpAndSettle();
    expect(selectedCats, [1]);

    await tester.tap(find.text('GoPay'));
    await tester.pumpAndSettle();
    expect(selectedWallets, [11]);

    await tester.tap(find.text('Makan'));
    await tester.pumpAndSettle();
    expect(selectedCats, isEmpty);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
    expect(selectedWallets, isEmpty);

    await tester.tap(find.text('Terapkan Filter'));
    await tester.pumpAndSettle();
    expect(applyCount, 1);
    expect(find.text('Filter Transaksi'), findsNothing);
  });
}
```

Run: `flutter test test/screens/transaction_history/transaction_filter_sheet_test.dart`
Expected: FAIL (file belum ada).

- [ ] **Step 3: Implementasi `lib/screens/transaction_history/transaction_filter_sheet.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';

/// Snapshot data filter yang dibaca ulang setiap kali sheet rebuild
/// (sama seperti `ref.read(provider)` di dalam StatefulBuilder lama).
class TransactionFilterData {
  const TransactionFilterData({
    required this.categories,
    required this.walletNames,
    required this.selectedCategoryIds,
    required this.selectedWalletIds,
  });

  final List<Map<String, dynamic>> categories;
  final Map<int, String> walletNames;
  final List<int> selectedCategoryIds;
  final List<int> selectedWalletIds;
}

/// Sheet "Filter Transaksi" dipakai tab Transaksi & Statistik. Perilaku
/// identik dengan `_showFilterSheet` lama: toggle langsung memanggil
/// notifier (tanpa fetch), "Reset" mengosongkan pilihan, "Terapkan Filter"
/// menutup sheet lalu memanggil applyFilters (fetch).
Future<void> showTransactionFilterSheet({
  required BuildContext context,
  required Color accentColor,
  required TransactionFilterData Function() readData,
  required void Function(int id, bool selected) onToggleCategory,
  required void Function(int id, bool selected) onToggleWallet,
  required VoidCallback onReset,
  required VoidCallback onApply,
}) {
  return showAppFormSheet<void>(
    context: context,
    title: 'Filter Transaksi',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final data = readData();

        Widget toggle({required String label, required bool selected, required VoidCallback onTap}) {
          return AppPillButton(
            label: label,
            color: selected ? accentColor : AppColors.textSecondary,
            filled: selected,
            onPressed: onTap,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AppPillButton(
                label: 'Reset',
                color: AppColors.expense,
                onPressed: () {
                  onReset();
                  setSheetState(() {});
                },
              ),
            ),
            const SizedBox(height: 14),
            Text('Kategori'.toUpperCase(), style: AppTextStyles.groupLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in data.categories)
                  toggle(
                    label: c['name'].toString(),
                    selected: data.selectedCategoryIds.contains(c['id'] as int),
                    onTap: () {
                      final id = c['id'] as int;
                      onToggleCategory(id, !data.selectedCategoryIds.contains(id));
                      setSheetState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Dompet'.toUpperCase(), style: AppTextStyles.groupLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in data.walletNames.entries)
                  toggle(
                    label: e.value,
                    selected: data.selectedWalletIds.contains(e.key),
                    onTap: () {
                      onToggleWallet(e.key, !data.selectedWalletIds.contains(e.key));
                      setSheetState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Terapkan Filter',
              color: accentColor,
              onPressed: () {
                Navigator.pop(sheetContext);
                onApply();
              },
            ),
          ],
        );
      },
    ),
  );
}
```

Catatan nama file: kalau B1 menaruh `AppPillButton`/`AppPrimaryButton` atau `showAppFormSheet` di file lain, sesuaikan import dengan lokasi yang ada di spec §6 (`app_buttons.dart`, `app_sheet.dart`).

- [ ] **Step 4: Jalankan test**

Run: `flutter test test/screens/transaction_history/transaction_filter_sheet_test.dart test/widgets/app_period_picker_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/app_period_picker.dart lib/screens/transaction_history/transaction_filter_sheet.dart test/screens/transaction_history/transaction_filter_sheet_test.dart
git commit -m "$(cat <<'EOF'
feat(transactions): extract shared period picker and filter sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: Tab Transaksi (`transaction_history_screen.dart` + `transactions_tab_screen.dart`)

**Files:**
- Modify: `lib/screens/transaction_history/transaction_history_screen.dart` (ganti seluruh isi class state kecuali `_deleteTransaction`)
- Modify: `lib/screens/transaction_history/transactions_tab_screen.dart`
- Test: `test/screens/transaction_history/transaction_history_screen_test.dart`

**Interfaces:**
- Consumes (Task 1–3): `groupTransactionsByDate`, `categoryIcon`, `categoryColor`, `kPeriodFilterTypes`, `periodLabel`, `showAppPeriodPicker`, `showTransactionFilterSheet`, `TransactionFilterData`, `AppSwipeActions(deleteConfirmTitle:, deleteConfirmMessage:)`.
- Consumes (B1): `AppPageScaffold(embedded: true)`, `AppSegmentedControl`, `AppChipTabs`, `AppPill`, `AppSurfaceCard`, `AppIconTile`, `AppGroupedSection`, `AppListRow`, `AppChip`, `AppEmptyState`, `formatRupiah`, `formatRupiahSigned`, `AppTextStyles`.
- Produces:
  - `TransactionHistoryScreen({Key? key, required bool isExpense, Widget? typeSwitcher})`. Parameter `typeSwitcher` baru; widget ini ditampilkan tepat di bawah judul besar.
  - `TransactionsTabScreen` publik tidak berubah: `refreshCounter`, `initialIsExpense`, `onActiveTabChanged`.

**Tabel preservasi.** Kolom kiri menunjuk baris di kode SAAT INI (`transaction_history_screen.dart` = THS, `transactions_tab_screen.dart` = TTS).

| # | Perilaku lama (file:baris) | Di layout baru |
|---|---|---|
| 1 | TTS:48–55. `AppTabSelector` Pemasukan/Pengeluaran; `onChanged` men-set `_tabIndex` lalu memanggil `onActiveTabChanged(i == 1)` | `AppSegmentedControl` di TTS, diteruskan sebagai `typeSwitcher` dan tampil di bawah judul "Transaksi". Logika `onChanged` sama. |
| 2 | TTS:33–38. `initState` postFrame memanggil `onActiveTabChanged(initialIsExpense)` | Tetap, tidak disentuh. |
| 3 | TTS:57–66. Anak berganti dengan key `ValueKey('pemasukan_${refreshCounter}')` / `ValueKey('pengeluaran_${refreshCounter}')` | Tetap, key persis sama. |
| 4 | THS:469–478. Judul "Riwayat Pemasukan"/"Riwayat Pengeluaran" berwarna semantik | Diganti judul besar **"Transaksi"** (spec §7.4). Warna semantik tetap dipakai di segmented terpilih dan di angka total. |
| 5 | THS:481–490. `AppTabSelector` Harian/Bulanan/Tahunan/Periode lalu `_notifier.setFilterType(type)` | `AppChipTabs(labels: kPeriodFilterTypes)`, `onChanged` memanggil `_notifier.setFilterType(...)`. |
| 6 | THS:500, 41–237. Tombol tanggal memanggil `_pickDate(state)`: Harian = DatePicker, Tahunan = "Pilih Tahun", Periode = RangePicker, Bulanan = dialog "Pilih Bulan" | `AppPill(expand: true, icon: calendarBlank, label: periodLabel(...))` memanggil `showAppPeriodPicker(...)` dengan `onDateSelected: _notifier.setSelectedDate` dan `onRangeSelected: _notifier.setSelectedDateRange`. |
| 7 | THS:543–597. Tombol "Filter" dengan warna aktif + badge jumlah filter | `AppPill(label: 'Filter', icon: funnel, badgeCount: kategori + dompet terpilih)`. |
| 8 | THS:239–433. Sheet "Filter Transaksi": "Reset" (`resetFilters`), chip "Kategori" (`toggleCategoryFilter`), chip "Dompet" (`toggleWalletFilter`), "Terapkan Filter" (pop + `applyFilters`) | `showTransactionFilterSheet(...)` dengan callback yang sama. |
| 9 | THS:603–659. Kotak "Total Real" + ikon trendUp/trendDown + `totalAmount` | `AppSurfaceCard` berisi "Total Real" (caption), `formatRupiah(totalAmount)` warna semantik, dan `AppIconTile` round trendUp/trendDown. |
| 10 | THS:667. Loading berupa spinner | Spinner primary di bawah kartu total. |
| 11 | THS:670–674. Empty state "Tidak ada transaksi" | `AppEmptyState(icon: receipt, title: 'Tidak ada transaksi')` di bawah kartu total. Pill filter tetap terlihat. |
| 12 | THS:690–691. `isPureMutation` = note mengandung `[SAVING_ID:` dan kategori berisi "tabung"/"cair" | Rumus sama. |
| 13 | THS:699–713. Tap baris: push `InputTransactionScreen(initialIsExpense: isExpense, transactionToEdit: trx)`; bila result `true`, panggil `fetchWallets()` + `fetchTransactions()` | Sama, di `_openTransaction`, ditambah `if (!mounted) return;` sesudah `await` (spec §9.4). |
| 14 | THS:725–756. Baris mutasi: latar abu, border teal, ikon bank, badge "Mutasi Internal", nominal dicoret, tanpa Dismissible | `AppListRow` dengan tile bank `tintGray`, judul abu, `AppChip('Mutasi Internal', tintTeal)`, nominal dicoret abu. Tidak dibungkus `AppSwipeActions`. |
| 15 | THS:767, 779–820. Judul `category?.name ?? "Umum"` + chip dompet berwarna (hanya bila bukan mutasi dan nama dompet ada) | Judul sama; `AppChip(walletName, color: walletColor, icon: wallet)` di subtitle. |
| 16 | THS:823–841. Catatan dengan marker `[SAVING_ID:n]` dibersihkan | Sama. Regex diperluas menjadi `\[(SAVING|DEBT)_ID:\d+\]` untuk baris utang dari B2. |
| 17 | THS:873–893. Nominal warna semantik + tanggal `dd MMM yyyy` per baris | Nominal `formatRupiahSigned(amount, isIncome: !isExpense)` warna semantik. Tanggal pindah ke **header grup** `EEEE, d MMM` (spec §7.4: list dikelompokkan per tanggal). |
| 18 | THS:906–965. Dismissible endToStart + dialog "Hapus Transaksi?" / "Data ini akan dihapus permanen." Batal/Hapus, lalu `_deleteTransaction(trx)` | `AppSwipeActions(deleteConfirmTitle: 'Hapus Transaksi?', deleteConfirmMessage: 'Data ini akan dihapus permanen.', onDelete: () => _deleteTransaction(trx))`. |
| 19 | THS:28–39. `_deleteTransaction`: `AppNotification.success(message)` / `.error("Gagal menghapus transaksi.")` | Tetap persis, tidak disentuh. |
| 20 | (B2) Baris bertanda `[DEBT_ID:` | Tampil seperti mutasi: abu, `AppChip('Utang/Piutang', tintSky)`, nominal dicoret, tanpa swipe, dan `onTap: null` (spec §7.1.2: tidak bisa diedit dari Riwayat). Total tidak dihitung ulang di screen karena pengecualiannya tanggung jawab provider (B2). |

- [ ] **Step 1: Cek integrasi B2**

Run: `grep -n "DEBT_ID" lib/providers/transaction_history_provider.dart lib/screens/transaction_history/transaction_history_screen.dart`

Bila B2 sudah menambah penanganan tampilan `[DEBT_ID:` di screen, bandingkan dengan baris #20. Kode di Step 3 sudah mencakupnya; hapus duplikasi dari B2 saat mengganti `build()`. Bila provider belum mengecualikan `[DEBT_ID:` dari `totalAmount`, JANGAN menambahkannya di plan ini; catat sebagai temuan untuk B2.

- [ ] **Step 2: Tulis widget test (gagal)**

`test/screens/transaction_history/transaction_history_screen_test.dart`:

```dart
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/transaction_history_provider.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_history_screen.dart';
import 'package:catat_uang_app/screens/transaction_history/transactions_tab_screen.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/pump_app.dart';

final _createdFakes = <FakeTransactionHistoryNotifier>[];

class FakeTransactionHistoryNotifier extends TransactionHistoryNotifier {
  FakeTransactionHistoryNotifier(this.seed) {
    _createdFakes.add(this);
  }

  final TransactionHistoryState seed;
  final deleted = <TransactionModel>[];

  @override
  TransactionHistoryState build(bool isExpense) => seed;

  @override
  Future<String> deleteTransaction(TransactionModel trx) async {
    deleted.add(trx);
    return 'Data dihapus & saldo dompet disesuaikan!';
  }

  @override
  void setFilterType(String type) => state = state.copyWith(filterType: type);
}

TransactionModel _trx(
  int id,
  DateTime date, {
  String category = 'Makan',
  String? note,
  double amount = 45000,
  int? walletId = 1,
}) =>
    TransactionModel(
      id: id,
      userId: 'u',
      categoryId: 1,
      amount: amount,
      date: date,
      note: note,
      walletId: walletId,
      category: CategoryModel(id: 1, name: category, isExpense: true, iconName: 'tag'),
    );

TransactionHistoryState _state(List<TransactionModel> trxs, {bool isLoading = false}) =>
    TransactionHistoryState(
      isLoading: isLoading,
      transactions: trxs,
      totalAmount: trxs.fold(0, (s, t) => s + t.amount),
      selectedDate: DateTime(2026, 9, 24),
      walletNames: const {1: 'BCA'},
      walletColors: const {1: Color(0xFF4A6CF7)},
    );

Future<void> _pump(WidgetTester tester, Widget child, TransactionHistoryState seed) async {
  _createdFakes.clear();
  await pumpApp(
    tester,
    child,
    overrides: [
      transactionHistoryProvider.overrideWith(() => FakeTransactionHistoryNotifier(seed)),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  final sep24 = DateTime(2026, 9, 24);
  final sep23 = DateTime(2026, 9, 23);

  testWidgets('judul, chip periode, pill, total, dan grup tanggal', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([
        _trx(2, sep24, note: 'Nasi Padang'),
        _trx(1, sep23, category: 'Transportasi', note: 'Grab'),
      ]),
    );

    expect(find.text('Transaksi'), findsOneWidget);
    for (final label in ['Harian', 'Bulanan', 'Tahunan', 'Periode']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Total Real'), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMM', 'id_ID').format(sep24).toUpperCase()), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMM', 'id_ID').format(sep23).toUpperCase()), findsOneWidget);
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('BCA'), findsNWidgets(2));
  });

  testWidgets('empty state tetap menampilkan pill Filter', (tester) async {
    await _pump(tester, const TransactionHistoryScreen(isExpense: true), _state([]));
    expect(find.text('Tidak ada transaksi'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('loading menampilkan spinner', (tester) async {
    await pumpApp(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      overrides: [
        transactionHistoryProvider.overrideWith(
          () => FakeTransactionHistoryNotifier(_state([], isLoading: true)),
        ),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('baris mutasi tidak punya swipe dan menampilkan chip', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([_trx(5, sep24, category: 'Tabungan', note: 'Setor [SAVING_ID:9]')]),
    );
    expect(find.text('Mutasi Internal'), findsOneWidget);
    expect(find.text('Setor'), findsOneWidget);
    expect(find.textContaining('SAVING_ID'), findsNothing);
    expect(find.byType(AppSwipeActions), findsNothing);
  });

  testWidgets('swipe hapus memanggil notifier setelah konfirmasi', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([_trx(7, sep24, note: 'Nasi Padang')]),
    );
    await tester.drag(find.text('Nasi Padang'), const Offset(-240, 0));
    await tester.pumpAndSettle();
    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(_createdFakes.single.deleted.map((t) => t.id), [7]);
    await tester.pump(const Duration(seconds: 4)); // tunggu timer toast AppNotification (3 detik)
  });

  testWidgets('teks panjang tidak overflow', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([
        _trx(8, sep24,
            category: 'Kategori Dengan Nama Yang Sangat Sangat Panjang Sekali',
            note: 'Catatan yang juga sangat panjang sampai tidak muat di satu baris layar HP',
            amount: 123456789),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TransactionsTabScreen: segmented memanggil onActiveTabChanged', (tester) async {
    final values = <bool>[];
    await _pump(
      tester,
      TransactionsTabScreen(refreshCounter: 0, onActiveTabChanged: values.add),
      _state([]),
    );
    expect(values, [false]); // dari postFrameCallback initState
    expect(find.text('Transaksi'), findsOneWidget);
    await tester.tap(find.text('Pengeluaran'));
    await tester.pumpAndSettle();
    expect(values.last, isTrue);
    expect(find.text('Transaksi'), findsOneWidget);
  });
}
```

**Penyesuaian wajib sebelum menjalankan test:**
- `deleteButtonFinder`: salin finder tombol Hapus dari `test/widgets/app_swipe_actions_test.dart` (B1).
- Import `app_swipe_actions.dart` sudah ada di header test.

Run: `flutter test test/screens/transaction_history/transaction_history_screen_test.dart`
Expected: FAIL. Judul "Transaksi" belum ada, dan konstruktor `typeSwitcher` belum dikenal.

- [ ] **Step 3: Ganti isi `transaction_history_screen.dart`**

Ganti import dan seluruh class. `_deleteTransaction` tetap persis seperti baris 28–39.

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/transaction_history_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_filter_sheet.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_grouping.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_period_picker.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final bool isExpense;

  /// Widget pemilih Pemasukan/Pengeluaran dari [TransactionsTabScreen],
  /// ditampilkan tepat di bawah judul besar.
  final Widget? typeSwitcher;

  const TransactionHistoryScreen({super.key, required this.isExpense, this.typeSwitcher});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  // Tag [SAVING_ID:..] / [DEBT_ID:..] dibersihkan lewat stripTransactionTags (lib/core/transaction_tags.dart, Plan B2).

  TransactionHistoryNotifier get _notifier =>
      ref.read(transactionHistoryProvider(widget.isExpense).notifier);

  Color get _semanticColor => widget.isExpense ? AppColors.expense : AppColors.income;

  Future<void> _deleteTransaction(TransactionModel trx) async {
    try {
      final message = await _notifier.deleteTransaction(trx);
      if (mounted) {
        AppNotification.success(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, "Gagal menghapus transaksi.");
      }
    }
  }

  void _pickDate(TransactionHistoryState state) {
    showAppPeriodPicker(
      context: context,
      filterType: state.filterType,
      selectedDate: state.selectedDate,
      selectedDateRange: state.selectedDateRange,
      onDateSelected: _notifier.setSelectedDate,
      onRangeSelected: _notifier.setSelectedDateRange,
    );
  }

  void _showFilterSheet() {
    showTransactionFilterSheet(
      context: context,
      accentColor: _semanticColor,
      readData: () {
        final s = ref.read(transactionHistoryProvider(widget.isExpense));
        return TransactionFilterData(
          categories: s.categories,
          walletNames: s.walletNames,
          selectedCategoryIds: s.selectedCategoryIds,
          selectedWalletIds: s.selectedWalletIds,
        );
      },
      onToggleCategory: _notifier.toggleCategoryFilter,
      onToggleWallet: _notifier.toggleWalletFilter,
      onReset: _notifier.resetFilters,
      onApply: _notifier.applyFilters,
    );
  }

  Future<void> _openTransaction(TransactionModel trx) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InputTransactionScreen(
          initialIsExpense: widget.isExpense,
          transactionToEdit: trx,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _notifier.fetchWallets();
      _notifier.fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider(widget.isExpense));
    final color = _semanticColor;
    final activeFilterCount = state.selectedCategoryIds.length + state.selectedWalletIds.length;

    return AppPageScaffold(
      embedded: true,
      title: 'Transaksi',
      children: [
        if (widget.typeSwitcher != null) widget.typeSwitcher!,
        AppChipTabs(
          labels: kPeriodFilterTypes,
          selectedIndex: kPeriodFilterTypes.indexOf(state.filterType),
          onChanged: (index) => _notifier.setFilterType(kPeriodFilterTypes[index]),
        ),
        Row(
          children: [
            Expanded(
              child: AppPill(
                expand: true,
                icon: PhosphorIconsRegular.calendarBlank,
                label: periodLabel(state.filterType, state.selectedDate, state.selectedDateRange),
                trailing: const Icon(PhosphorIconsRegular.caretDown, size: 14, color: AppColors.textSecondary),
                onTap: () => _pickDate(state),
              ),
            ),
            const SizedBox(width: 8),
            AppPill(
              icon: PhosphorIconsRegular.funnel,
              label: 'Filter',
              badgeCount: activeFilterCount,
              onTap: _showFilterSheet,
            ),
          ],
        ),
        AppSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Real", style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(state.totalAmount),
                      style: AppTextStyles.title.copyWith(color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppIconTile(
                icon: widget.isExpense ? PhosphorIconsBold.trendDown : PhosphorIconsBold.trendUp,
                color: color,
                round: true,
              ),
            ],
          ),
        ),
        ..._buildTransactionList(state),
      ],
    );
  }

  List<Widget> _buildTransactionList(TransactionHistoryState state) {
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    if (state.transactions.isEmpty) {
      return const [
        AppEmptyState(icon: PhosphorIconsRegular.receipt, title: 'Tidak ada transaksi'),
      ];
    }
    return [
      for (final (day, items) in groupTransactionsByDate(state.transactions))
        AppGroupedSection(
          header: DateFormat('EEEE, d MMM', 'id_ID').format(day),
          children: [for (final trx in items) _buildTransactionRow(trx, state)],
        ),
    ];
  }

  Widget _buildTransactionRow(TransactionModel trx, TransactionHistoryState state) {
    // Deteksi tag memakai helper bersama Plan B2 (lib/core/transaction_tags.dart),
    // supaya aturan "mutasi internal" identik di provider dan layar.
    final noteStr = trx.note?.toString() ?? '';
    final isSavingRow = isSavingMutation(trx.note, trx.category?.name);
    final isDebtRow = isDebtMutation(trx.note);
    final isMutation = isSavingRow || isDebtRow;

    final cleanNote = stripTransactionTags(trx.note);
    final categoryName = trx.category?.name ?? "Umum";
    final walletName = state.walletNames[trx.walletId];
    final walletColor = state.walletColors[trx.walletId] ?? AppColors.tintGray;

    Widget? badge;
    if (isSavingRow) {
      badge = const AppChip(label: 'Mutasi Internal', color: AppColors.tintTeal);
    } else if (isDebtRow) {
      badge = const AppChip(label: 'Utang/Piutang', color: AppColors.tintSky);
    } else if (walletName != null) {
      badge = AppChip(label: walletName, color: walletColor, icon: PhosphorIconsFill.wallet);
    }

    final subtitle = Row(
      children: [
        if (cleanNote.isNotEmpty)
          Flexible(
            child: Text(
              cleanNote,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (cleanNote.isNotEmpty && badge != null) const SizedBox(width: 6),
        ?badge,
      ],
    );

    final row = AppListRow(
      leading: AppIconTile(
        icon: isSavingRow
            ? PhosphorIconsFill.bank
            : (isDebtRow ? PhosphorIconsFill.handCoins : categoryIcon(categoryName)),
        color: isMutation ? AppColors.tintGray : categoryColor(categoryName),
      ),
      title: categoryName,
      titleColor: isMutation ? AppColors.textSecondary : null,
      subtitleWidget: subtitle,
      trailing: Text(
        isMutation
            ? formatRupiah(trx.amount)
            : formatRupiahSigned(trx.amount, isIncome: !widget.isExpense),
        style: AppTextStyles.amountRow.copyWith(
          color: isMutation ? AppColors.textSecondary : _semanticColor,
          decoration: isMutation ? TextDecoration.lineThrough : null,
        ),
      ),
      onTap: isDebtRow ? null : () => _openTransaction(trx),
    );

    if (isMutation) return row;

    return AppSwipeActions(
      key: ValueKey(trx.id),
      deleteConfirmTitle: 'Hapus Transaksi?',
      deleteConfirmMessage: 'Data ini akan dihapus permanen.',
      onDelete: () => _deleteTransaction(trx),
      child: row,
    );
  }
}
```

Catatan: `?badge` memakai *null-aware element* (Dart ≥ 3.8; SDK project ^3.10.4). Bila analyzer menolak, ganti dengan `if (badge != null) badge,`.

- [ ] **Step 4: Ganti `build()` + import di `transactions_tab_screen.dart`**

Hapus import `app_tab_selector.dart`, lalu tambahkan import `package:catat_uang_app/core/colors.dart` dan `package:catat_uang_app/widgets/app_segmented_control.dart`. Ganti `build()`:

```dart
  @override
  Widget build(BuildContext context) {
    final switcher = AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: _tabIndex,
      selectedLabelColors: const [AppColors.income, AppColors.expense],
      onChanged: (i) {
        if (i == _tabIndex) return;
        setState(() => _tabIndex = i);
        widget.onActiveTabChanged?.call(i == 1);
      },
    );

    return _tabIndex == 0
        ? TransactionHistoryScreen(
            key: ValueKey('pemasukan_${widget.refreshCounter}'),
            isExpense: false,
            typeSwitcher: switcher,
          )
        : TransactionHistoryScreen(
            key: ValueKey('pengeluaran_${widget.refreshCounter}'),
            isExpense: true,
            typeSwitcher: switcher,
          );
  }
```

Doc comment class boleh diperbarui satu baris saja: "Menaruh AppSegmentedControl di bawah judul TransactionHistoryScreen".

- [ ] **Step 5: Jalankan test**

Run: `flutter test test/screens/transaction_history/`
Expected: PASS semua.

- [ ] **Step 6: Cek aturan**

```bash
grep -c "GoogleFonts.poppins" lib/screens/transaction_history/transaction_history_screen.dart lib/screens/transaction_history/transactions_tab_screen.dart
grep -nE "Colors\.(red|green|grey|teal|black|blue|purple|orange)|0xFF" lib/screens/transaction_history/*.dart
flutter analyze lib/screens/transaction_history lib/widgets lib/core
```

Expected:
- `grep -c` mengeluarkan `0` untuk kedua file.
- `grep -nE` tidak menemukan apa pun.
- Analyze tanpa error atau warning baru.

- [ ] **Step 7: Checklist visual vs mockup "Transaksi"**

- [ ] Urutan: judul besar "Transaksi" → segmented Pemasukan/Pengeluaran → chip tabs periode → baris pill (tanggal melebar + Filter) → kartu Total Real → grup per tanggal.
- [ ] Segmented: track `track`, pill putih; teks terpilih hijau (Pemasukan) atau merah (Pengeluaran).
- [ ] Chip tab terpilih berisi `textPrimary` dengan teks putih.
- [ ] Pill tanggal dan Filter berwarna putih; badge merah muncul hanya bila ada filter aktif.
- [ ] Kartu total putih radius 24 tanpa gradasi. Angka memakai warna semantik, tile trend bulat di kanan.
- [ ] Header grup HURUF BESAR abu, misalnya "KAMIS, 24 SEP".
- [ ] Baris: tile kategori berwarna tint, judul, catatan + chip dompet, dan nominal bertanda ± di kanan. Pemisah menjorok setelah tile.
- [ ] Geser kiri memunculkan tombol Hapus merah, lalu dialog iOS "Hapus Transaksi?".
- [ ] Baris mutasi tampil abu dengan chip "Mutasi Internal" teal dan nominal dicoret.
- [ ] Empty: ikon struk abu + "Tidak ada transaksi". Loading: spinner biru.
- [ ] Konten terakhir bisa di-scroll sampai di atas navbar melayang, dan terlihat lewat di belakangnya.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/transaction_history/ test/screens/transaction_history/transaction_history_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(transactions): redesign transactions tab with date-grouped iOS list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 5: Tab Statistik (`stats_screen.dart`)

**Files:**
- Modify: `lib/screens/stats/stats_screen.dart` (ganti seluruh isi)
- Test: `test/screens/stats/stats_screen_test.dart`

**Interfaces:**
- Consumes: `showAppPeriodPicker`, `periodLabel`, `kPeriodFilterTypes`, `showTransactionFilterSheet`, `TransactionFilterData` (Task 1/3).
- Consumes (B1): `AppPageScaffold(embedded: true)`, `AppSegmentedControl`, `AppChipTabs`, `AppPill`, `AppSurfaceCard`, `AppGroupedSection`, `AppListRow`, `AppChip`, `AppProgressBar`, `AppEmptyState`, `formatRupiah`, `formatRupiahCompact`, `AppTextStyles`.
- Consumes: provider `statsProvider`/`StatsNotifier` apa adanya.
- Produces: `StatsScreen({Key? key})`, konstruktor tidak berubah.

**Tabel preservasi** (`stats_screen.dart` = SS):

| # | Perilaku lama (SS:baris) | Di layout baru |
|---|---|---|
| 1 | SS:461–467. Judul "Laporan Keuangan" | Judul besar **"Statistik"** (keputusan user 2026-09-24: samakan dengan nama tab navbar dan mockup). |
| 2 | SS:470–544. Toggle Pemasukan/Pengeluaran memanggil `_notifier.setIsExpense(false/true)` | `AppSegmentedControl`, `onChanged` memanggil `_notifier.setIsExpense(i == 1)`. Teks terpilih hijau/merah. |
| 3 | SS:547–556. `AppTabSelector` periode memanggil `setFilterType` | `AppChipTabs(labels: kPeriodFilterTypes)`. |
| 4 | SS:562–600, 35–231. Tombol tanggal memanggil `_pickDate` (4 jenis picker) | `AppPill` memanggil `showAppPeriodPicker(onDateSelected: setSelectedDate, onRangeSelected: setSelectedDateRange)`. |
| 5 | SS:604–659, 233–427. Tombol "Filter" + badge, lalu sheet "Filter Transaksi" | `AppPill(badgeCount)` memanggil `showTransactionFilterSheet(...)` dengan `accentColor` semantik. |
| 6 | SS:668–676. Loading spinner / empty "Tidak ada data" | Spinner primary / `AppEmptyState(icon: chartPieSlice, title: 'Tidak ada data')`. |
| 7 | SS:690–763. PieChart: tap section men-toggle `_touchedIndex` (tap ulang untuk menutup); maks 5 slice ≥2%; sisanya digabung "Gabungan\n(n)" abu; judul slice menampilkan persen, atau nama+persen saat disentuh | Logika sama persis di `_buildSections`. Ukuran donut disesuaikan dengan kartu. Warna diambil dari `_chartColors` AppColors, bukan `Colors.*`. Gabungan memakai `tintGray`. |
| 8 | SS:764–784. Tengah donut "Total" + nominal | "Total" + `formatRupiahCompact(totalAmount)` (donut lebih kecil). |
| 9 | SS:790–885. Kartu ringkasan: "Total Pengeluaran"/"Total Pemasukan" + nominal; bila total > 0: "Rata-rata harian" + "Terbesar (note)" berwarna semantik | Kolom kanan di kartu donut dengan tiga baris `_StatLine`: label dan kondisinya sama. |
| 10 | SS:888–1157. Daftar kategori `ExpansionTile`: peringkat (medali untuk 1–3, "#n" setelahnya), nama, nominal, "N Transaksi", persen berwarna, progress 6px | `AppGroupedSection(header: 'Kategori')` dengan `_CategoryRankRow`: badge nomor berwarna slice (mengikuti mockup), judul, "N Transaksi · x.x%", `AppProgressBar(height: 6)`, dan nominal. Ketuk untuk expand/collapse. |
| 11 | SS:1025–1152. Isi expand: note bersih dari marker, atau "Tanpa catatan"; tanggal `dd MMM yyyy`; chip dompet (fallback "Kas Utama"); nominal | Sama, di area `background` di bawah baris. Regex marker `\[(SAVING|DEBT)_ID:\d+\]`. |
| 12 | SS:20–29. `_chartColors` = `Colors.blue/red/green/...` | `AppColors.primary, accent, tintSky, tintPink, tintIndigo, tintTeal, tintAmber, tintBrown`. Tanpa merah/hijau semantik (G11). |

- [ ] **Step 1: Tulis widget test (gagal)**

`test/screens/stats/stats_screen_test.dart`:

```dart
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/screens/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _fakes = <FakeStatsNotifier>[];

class FakeStatsNotifier extends StatsNotifier {
  FakeStatsNotifier(this.seed) {
    _fakes.add(this);
  }

  final StatsState seed;
  final isExpenseCalls = <bool>[];

  @override
  StatsState build() => seed;

  @override
  void setIsExpense(bool isExpense) {
    isExpenseCalls.add(isExpense);
    state = state.copyWith(isExpense: isExpense);
  }
}

StatsState _seed({bool isLoading = false, List<Map<String, dynamic>>? data}) => StatsState(
      isLoading: isLoading,
      isExpense: true,
      selectedDate: DateTime(2026, 9, 24),
      totalAmount: 1000000,
      dailyAverage: 130000,
      highestTransaction: const {'amount': 500000.0, 'name': 'Kos', 'note': 'Bayar kos', 'date': '2026-09-01'},
      walletNames: const {1: 'BCA'},
      walletColors: const {1: Color(0xFF4A6CF7)},
      categoryData: data ??
          [
            {
              'name': 'Tempat Tinggal',
              'amount': 500000.0,
              'count': 1,
              'transactions': [
                {'note': 'Bayar kos', 'date': '2026-09-01', 'wallet_id': 1, 'amount': 500000},
              ],
            },
            {
              'name': 'Makan',
              'amount': 300000.0,
              'count': 2,
              'transactions': [
                {'note': 'Nasi Padang [SAVING_ID:3]', 'date': '2026-09-24', 'wallet_id': 1, 'amount': 150000},
                {'note': '', 'date': '2026-09-23', 'wallet_id': 99, 'amount': 150000},
              ],
            },
            {'name': 'Transportasi', 'amount': 200000.0, 'count': 3, 'transactions': []},
          ],
    );

Future<void> _pump(WidgetTester tester, StatsState seed) async {
  _fakes.clear();
  await pumpApp(tester, const StatsScreen(),
      overrides: [statsProvider.overrideWith(() => FakeStatsNotifier(seed))]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan judul, kontrol, ringkasan, dan grup kategori', (tester) async {
    await _pump(tester, _seed());
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Total Pengeluaran'), findsOneWidget);
    expect(find.text('Rata-rata harian'), findsOneWidget);
    expect(find.text('Terbesar (Bayar kos)'), findsOneWidget);
    expect(find.text('KATEGORI'), findsOneWidget);
    expect(find.text('Tempat Tinggal'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // badge peringkat
  });

  testWidgets('baris kategori bisa di-expand menampilkan transaksi', (tester) async {
    await _pump(tester, _seed());
    expect(find.text('Nasi Padang'), findsNothing);
    await tester.tap(find.text('Makan'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('Tanpa catatan'), findsOneWidget);
    expect(find.text('Kas Utama'), findsOneWidget);
    expect(find.textContaining('SAVING_ID'), findsNothing);
  });

  testWidgets('segmented memanggil setIsExpense', (tester) async {
    await _pump(tester, _seed());
    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(_fakes.single.isExpenseCalls, [false]);
  });

  testWidgets('empty dan loading', (tester) async {
    await _pump(tester, _seed(data: []));
    expect(find.text('Tidak ada data'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);

    await pumpApp(tester, const StatsScreen(),
        overrides: [statsProvider.overrideWith(() => FakeStatsNotifier(_seed(isLoading: true)))]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

Run: `flutter test test/screens/stats/stats_screen_test.dart`
Expected: FAIL. Label seperti "KATEGORI" belum ada.

- [ ] **Step 2: Ganti seluruh isi `lib/screens/stats/stats_screen.dart`**

```dart
import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_filter_sheet.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_period_picker.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  static const List<Color> _chartColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.tintSky,
    AppColors.tintPink,
    AppColors.tintIndigo,
    AppColors.tintTeal,
    AppColors.tintAmber,
    AppColors.tintBrown,
  ];

  int _touchedIndex = -1;

  StatsNotifier get _notifier => ref.read(statsProvider.notifier);

  void _pickDate(StatsState state) {
    showAppPeriodPicker(
      context: context,
      filterType: state.filterType,
      selectedDate: state.selectedDate,
      selectedDateRange: state.selectedDateRange,
      onDateSelected: _notifier.setSelectedDate,
      onRangeSelected: _notifier.setSelectedDateRange,
    );
  }

  void _showFilterSheet() {
    final isExpense = ref.read(statsProvider).isExpense;
    showTransactionFilterSheet(
      context: context,
      accentColor: isExpense ? AppColors.expense : AppColors.income,
      readData: () {
        final s = ref.read(statsProvider);
        return TransactionFilterData(
          categories: s.categories,
          walletNames: s.walletNames,
          selectedCategoryIds: s.selectedCategoryIds,
          selectedWalletIds: s.selectedWalletIds,
        );
      },
      onToggleCategory: _notifier.toggleCategoryFilter,
      onToggleWallet: _notifier.toggleWalletFilter,
      onReset: _notifier.resetFilters,
      onApply: _notifier.applyFilters,
    );
  }

  List<PieChartSectionData> _buildSections(StatsState state) {
    final sections = <PieChartSectionData>[];
    double otherAmount = 0;
    int currentIndex = 0;
    for (int i = 0; i < state.categoryData.length; i++) {
      final item = state.categoryData[i];
      final percentage = (item['amount'] / state.totalAmount) * 100;

      if (i < 5 && percentage >= 2) {
        final isTouched = currentIndex == _touchedIndex;
        sections.add(PieChartSectionData(
          color: _chartColors[i % _chartColors.length],
          value: item['amount'],
          title: isTouched
              ? '${item['name']}\n${percentage.toStringAsFixed(1)}%'
              : '${percentage.toStringAsFixed(0)}%',
          radius: isTouched ? 40 : 32,
          titleStyle: AppTextStyles.caption.copyWith(
            fontSize: isTouched ? 11 : 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: isTouched ? const [Shadow(color: Colors.black45, blurRadius: 2)] : null,
          ),
        ));
        currentIndex++;
      } else {
        otherAmount += (item['amount'] as num).toDouble();
      }
    }

    if (otherAmount > 0) {
      final otherPercentage = (otherAmount / state.totalAmount) * 100;
      final isTouched = currentIndex == _touchedIndex;
      final remainingCount = state.categoryData.length - currentIndex;
      final labelText = "Gabungan\n($remainingCount)";
      sections.add(PieChartSectionData(
        color: AppColors.tintGray,
        value: otherAmount,
        title: isTouched
            ? '$labelText\n${otherPercentage.toStringAsFixed(1)}%'
            : '${otherPercentage.toStringAsFixed(0)}%\n$labelText',
        radius: isTouched ? 40 : 32,
        titleStyle: AppTextStyles.caption.copyWith(
          fontSize: isTouched ? 10 : 8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: isTouched ? const [Shadow(color: Colors.black45, blurRadius: 2)] : null,
        ),
      ));
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsProvider);
    final activeColor = state.isExpense ? AppColors.expense : AppColors.income;
    final activeFilterCount = state.selectedCategoryIds.length + state.selectedWalletIds.length;

    return AppPageScaffold(
      embedded: true,
      title: 'Statistik',
      children: [
        AppSegmentedControl(
          labels: const ['Pemasukan', 'Pengeluaran'],
          selectedIndex: state.isExpense ? 1 : 0,
          selectedLabelColors: const [AppColors.income, AppColors.expense],
          onChanged: (i) => _notifier.setIsExpense(i == 1),
        ),
        AppChipTabs(
          labels: kPeriodFilterTypes,
          selectedIndex: kPeriodFilterTypes.indexOf(state.filterType),
          onChanged: (index) => _notifier.setFilterType(kPeriodFilterTypes[index]),
        ),
        Row(
          children: [
            Expanded(
              child: AppPill(
                expand: true,
                icon: PhosphorIconsRegular.calendarBlank,
                label: periodLabel(state.filterType, state.selectedDate, state.selectedDateRange),
                trailing: const Icon(PhosphorIconsRegular.caretDown, size: 14, color: AppColors.textSecondary),
                onTap: () => _pickDate(state),
              ),
            ),
            const SizedBox(width: 8),
            AppPill(
              icon: PhosphorIconsRegular.funnel,
              label: 'Filter',
              badgeCount: activeFilterCount,
              onTap: _showFilterSheet,
            ),
          ],
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (state.categoryData.isEmpty)
          const AppEmptyState(icon: PhosphorIconsRegular.chartPieSlice, title: 'Tidak ada data')
        else ...[
          AppSurfaceCard(
            child: Row(
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (event is FlTapUpEvent) {
                                  if (pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null ||
                                      pieTouchResponse.touchedSection!.touchedSectionIndex == -1) {
                                    _touchedIndex = -1;
                                  } else {
                                    final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    _touchedIndex = _touchedIndex == newIndex ? -1 : newIndex;
                                  }
                                }
                              });
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildSections(state),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Total", style: AppTextStyles.caption),
                          Text(
                            formatRupiahCompact(state.totalAmount),
                            style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatLine(
                        label: "Total ${state.isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                        value: formatRupiah(state.totalAmount),
                        valueColor: activeColor,
                      ),
                      if (state.totalAmount > 0) ...[
                        const SizedBox(height: 12),
                        _StatLine(label: "Rata-rata harian", value: formatRupiah(state.dailyAverage)),
                        if (state.highestTransaction != null) ...[
                          const SizedBox(height: 12),
                          _StatLine(
                            label: "Terbesar (${state.highestTransaction!['note']})",
                            value: formatRupiah(state.highestTransaction!['amount'] as num),
                            valueColor: activeColor,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppGroupedSection(
            header: 'Kategori',
            children: [
              for (var i = 0; i < state.categoryData.length; i++)
                _CategoryRankRow(
                  rank: i + 1,
                  color: _chartColors[i % _chartColors.length],
                  item: state.categoryData[i],
                  totalAmount: state.totalAmount,
                  walletNames: state.walletNames,
                  walletColors: state.walletColors,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.amountRow.copyWith(color: valueColor ?? AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.14), AppColors.surface),
        shape: BoxShape.circle,
      ),
      child: Text('$rank', style: AppTextStyles.bodyStrong.copyWith(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

class _CategoryRankRow extends StatefulWidget {
  const _CategoryRankRow({
    required this.rank,
    required this.color,
    required this.item,
    required this.totalAmount,
    required this.walletNames,
    required this.walletColors,
  });

  final int rank;
  final Color color;
  final Map<String, dynamic> item;
  final double totalAmount;
  final Map<int, String> walletNames;
  final Map<int, Color> walletColors;

  @override
  State<_CategoryRankRow> createState() => _CategoryRankRowState();
}

class _CategoryRankRowState extends State<_CategoryRankRow> {
  // Tag [SAVING_ID:..] / [DEBT_ID:..] dibersihkan lewat stripTransactionTags (lib/core/transaction_tags.dart, Plan B2).
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amount = (item['amount'] as num).toDouble();
    final percentage = widget.totalAmount == 0 ? 0.0 : (amount / widget.totalAmount) * 100;
    final transactions = item['transactions'] as List;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListRow(
          leading: _RankBadge(rank: widget.rank, color: widget.color),
          title: item['name'].toString(),
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: "${item['count']} Transaksi · "),
                    TextSpan(
                      text: "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(color: widget.color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 6),
              AppProgressBar(value: percentage / 100, color: widget.color, height: 6),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatRupiah(amount), style: AppTextStyles.amountRow),
              const SizedBox(width: 4),
              Icon(
                _expanded ? PhosphorIconsRegular.caretUp : PhosphorIconsRegular.caretDown,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                for (final t in transactions) _buildTransactionLine(t as Map<String, dynamic>),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionLine(Map<String, dynamic> t) {
    final wId = t['wallet_id'];
    final wName = widget.walletNames[wId] ?? 'Kas Utama';
    final wColor = widget.walletColors[wId] ?? AppColors.tintGray;
    final cleanNote = stripTransactionTags(t['note']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanNote.isNotEmpty ? cleanNote : 'Tanpa catatan',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(DateTime.parse(t['date'])),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: 8),
                    AppChip(label: wName, color: wColor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Text(formatRupiah((t['amount'] as num).toDouble()), style: AppTextStyles.amountRow),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Jalankan test**

Run: `flutter test test/screens/stats/stats_screen_test.dart`
Expected: PASS. Kalau `find.text('1')` bentrok dengan teks lain, ganti dengan `find.widgetWithText(Container, '1')`.

- [ ] **Step 4: Cek aturan**

```bash
grep -c "GoogleFonts.poppins" lib/screens/stats/stats_screen.dart
grep -nE "Colors\.(red|green|grey|teal|black87|blue|purple|orange|amber|pink|brown)|0xFF" lib/screens/stats/stats_screen.dart
flutter analyze lib/screens/stats
```

Expected:
- `grep -c` mengeluarkan `0`.
- `grep -nE` tidak menemukan apa pun. `Colors.black45` pada shadow teks donut boleh dibiarkan, karena itu bayangan dan bukan warna UI; `Colors.white` juga boleh.
- Analyze tanpa error atau warning baru.

- [ ] **Step 5: Checklist visual vs mockup "Statistik"**

- [ ] Urutan: judul besar → segmented → chip tabs → baris pill → kartu donut+ringkasan → grup "KATEGORI".
- [ ] Donut di kiri kartu putih: slice berwarna primary/aksen/tint (tanpa merah/hijau), tengahnya "Total" + angka ringkas.
- [ ] Kolom kanan kartu: "Total Pengeluaran" (merah) atau "Total Pemasukan" (hijau), "Rata-rata harian", "Terbesar (…)".
- [ ] Baris kategori: badge nomor bulat berwarna slice, judul, "N Transaksi · x.x%" (persen berwarna), progress tipis, nominal, dan caret.
- [ ] Ketuk baris membuka daftar transaksi berlatar abu muda; ketuk sekali lagi menutupnya.
- [ ] Ketuk slice donut memperbesar slice dan menampilkan nama + persen; ketuk slice yang sama lagi mengembalikannya.
- [ ] Empty: ikon chart abu + "Tidak ada data". Loading: spinner.
- [ ] Konten bisa di-scroll sampai di belakang navbar melayang.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/stats/stats_screen.dart test/screens/stats/stats_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(stats): redesign stats tab with donut card and ranked category list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 6: Tambah/Edit Transaksi (`input_transaction_screen.dart`)

**Files:**
- Modify: `lib/screens/input_transaction/input_transaction_screen.dart`
- Test: `test/screens/input_transaction/input_transaction_screen_test.dart`

**Interfaces:**
- Consumes: `categoryIcon`, `categoryColor` (Task 1), `AppPageScaffold.leading` (Task 2).
- Consumes (B1): `AppPageScaffold(largeTitle: false, leading:, bottomBar:)`, `AppNavAction.text`, `AppSegmentedControl`, `AppAmountField`, `AppAmountDisplay`, `AppPillButton`, `AppCallout`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppTextField`, `AppPrimaryButton`, `showAppFormSheet`, `formatRupiah`, `AppTextStyles`.
- Consumes: `inputTransactionProvider` apa adanya, termasuk `saveTransaction(...)` dengan argumen yang sama.
- Produces: `InputTransactionScreen({Key? key, TransactionModel? transactionToEdit, bool initialIsExpense = false})`, konstruktor tidak berubah. Pemanggilnya ada di `home_screen.dart:1100`, `:1207` dan `transaction_history_screen.dart`.

> **Catatan koordinator — perilaku dari plan sebelumnya yang WAJIB dipertahankan** (baris di tabel di bawah dihitung dari kode `main` saat plan ini ditulis; B2 dan B3 sudah mengubah file ini, jadi baca `git log -p` file ini sejak B1 dan cocokkan):
> - **B3 Task 8 — peringatan saldo minimal:** sebelum menyimpan pengeluaran dari dompet, bila `minBalanceWarningMessage(...)` (`lib/core/wallet_rules.dart`) mengembalikan teks, tampilkan `showAppConfirmDialog(destructive: false, ...)`; lanjut simpan hanya bila dikonfirmasi. Pindahkan logika ini apa adanya ke `build()`/handler simpan yang baru.
> - **B2 Task 4 — transaksi utang read-only:** transaksi bertanda `[DEBT_ID:` (`isDebtMutation(note)` dari `lib/core/transaction_tags.dart`) dibuka dalam mode read-only dengan callout "Transaksi ini dikelola dari halaman Utang & Piutang" (teks persis mengikuti B2); tombol simpan tidak ada.
> - Test Task 6 menambah dua kasus untuk dua perilaku ini.

**Tabel preservasi** (`input_transaction_screen.dart` = ITS):

| # | Perilaku lama (ITS:baris) | Di layout baru |
|---|---|---|
| 1 | ITS:333–350. AppBar judul "Detail Transaksi"/"Tambah Transaksi"/"Edit Transaksi", tombol back memanggil `Navigator.pop` | `AppPageScaffold(largeTitle: false, title: <sama>)`. `leading: AppNavAction.text('Batal')` memanggil `Navigator.pop(context)`. |
| 2 | ITS:55–77. `initState`: mode edit mengisi nominal/catatan/tanggal/kategori/dompet; marker `[SAVING_ID:` disimpan di `_hiddenSavingMarker` dan mengaktifkan `_isReadOnly` | Tidak diubah. |
| 3 | ITS:303–324. `ref.listen`: dompet pertama otomatis dipilih saat daftar dompet tiba; saat edit, `_isExpense` di-set dari kategori | Tidak diubah. |
| 4 | ITS:357–382. Banner read-only "Ini adalah catatan otomatis dari fitur Tabungan…" | `AppCallout(icon: info)` dengan teks persis sama. |
| 5 | ITS:384–396, 987–1026. Toggle Pemasukan/Pengeluaran; nonaktif saat read-only; memilih mereset kategori; memilih Pemasukan mematikan `_isFromSaving`, mengosongkan saving, dan memilih dompet pertama | `AppSegmentedControl`, `onChanged` memanggil `_onTypeSelected(i == 1)` dengan isi logika yang sama. |
| 6 | ITS:401–407. Label "Sumber Dana" (pengeluaran) / "Simpan Ke" (pemasukan), hanya untuk transaksi baru dan bukan read-only | Header `AppGroupedSection` dengan kondisi sama. |
| 7 | ITS:409–526. Pilihan Dompet/Tabungan (hanya pengeluaran). Dompet: `_isFromSaving=false`, saving null, dompet pertama. Tabungan: `_isFromSaving=true`, wallet null, saving pertama bila belum ada | `AppSegmentedControl(['Dompet','Tabungan'])` di dalam grup; `_useWallet` / `_useSaving` dengan logika yang sama. |
| 8 | ITS:528–640. Dropdown tabungan: item "nama (Sisa: Rp…)", hint "Belum ada tabungan"/"Pilih Tabungan...", nonaktif bila kosong. Dropdown dompet: item "nama (Rp…)" dengan ikon warna dompet, hint "Buat dompet di menu utama!"/"Pilih Dompet...", nonaktif bila kosong | Baris `AppListRow` "Tabungan"/"Dompet". Nilainya nama terpilih atau hint yang sama. Tap membuka sheet pilihan "Pilih Tabungan"/"Pilih Dompet" berisi nama + saldo dengan centang. Nonaktif (`onTap: null`) bila daftar kosong. |
| 9 | ITS:645–700. Mode edit: "Transaksi ini tercatat di dompet X" ("Memuat..."/"Telah Dihapus") | `AppCallout(icon: wallet)` dengan teks yang sama. |
| 10 | ITS:702–743. Pill "Scan Struk AI" hanya bila pengeluaran dan bukan read-only, membuka `_showImageSourceBottomSheet` | `AppPillButton('Scan Struk AI', icon: sparkle)` di bawah nominal, kondisi sama. |
| 11 | ITS:130–230. Sheet "Pilih Metode Scan": Kamera "(1 Struk)" memanggil `pickImage(camera, 80)`; Galeri "(Banyak Struk)" memanggil `pickMultiImage(80)`; lalu `_processScanReceipts` | `showAppFormSheet(title: 'Pilih Metode Scan')` dengan dua `AppListRow`. Callback sama; ikon diganti Phosphor (camera/images). |
| 12 | ITS:79–128. `_processScanReceipts`: dialog spinner, isi nominal/kategori/catatan, toast "Berhasil menjumlahkan N struk! 🚀" / "AI gagal membaca struk." | Tidak diubah. |
| 13 | ITS:745–795. Field nominal besar "Rp", hint 0, format ribuan saat mengetik, nonaktif saat read-only | Mode normal: `AppAmountField(label: 'Nominal')`; `RupiahInputFormatter` menggantikan `onChanged` manual. Read-only: `AppAmountDisplay(label: 'Nominal', amountText: 'Rp …')`. |
| 14 | ITS:798–856. Dropdown "Kategori" (hint "Memuat..."/"Pilih Kategori") dengan ikon kategori; kategori difilter per `_isExpense`; nonaktif saat read-only | Baris "Kategori" yang nilainya nama terpilih atau hint sama. Tap membuka sheet "Pilih Kategori" berisi ikon dari `categoryIcon` dan warna `categoryColor`. Nonaktif saat read-only atau daftar kosong. |
| 15 | ITS:859–897, 284–294. Tanggal `EEEE, d MMMM yyyy`, tap memanggil `_pickDate` (nonaktif saat read-only; locale id) | Baris "Tanggal" dengan nilai `EEE, d MMM yyyy` (mengikuti mockup) yang memanggil `_pickDate`. Isi `_pickDate` sama, ditambah `mounted`. |
| 16 | ITS:900–936. Catatan dengan hint "Contoh: Beli Nasi Padang / Bayar Bengkel", nonaktif saat read-only | `AppGroupedSection(header: 'Catatan (Opsional)')` + `AppTextField(readOnly: _isReadOnly)`. |
| 17 | ITS:942–983. Tombol bawah: read-only = "Kembali" (pop), selain itu "Simpan Transaksi" yang memanggil `_saveTransaction`; nonaktif + spinner saat `isSaving` | `bottomBar: AppPrimaryButton(label/onPressed sama, loading: state.isSaving)`. Read-only memakai `color: AppColors.textSecondary`. |
| 18 | ITS:259–282. `_saveTransaction` (argumen ke notifier, toast sukses/gagal, `pop(context, true)`) | Tidak diubah. |
| 19 | ITS:232–257. `_getCategoryIcon` | Dihapus; diganti `categoryIcon` di `lib/core/category_visuals.dart` (Task 1, isi sama). |

- [ ] **Step 1: Tulis widget test (gagal)**

`test/screens/input_transaction/input_transaction_screen_test.dart`:

```dart
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _fakes = <FakeInputTransactionNotifier>[];

class FakeInputTransactionNotifier extends InputTransactionNotifier {
  FakeInputTransactionNotifier() {
    _fakes.add(this);
  }

  final saveCalls = <Map<String, Object?>>[];

  @override
  InputTransactionState build() => const InputTransactionState(
        wallets: [
          {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#4A6CF7'},
        ],
        categories: [
          {'id': 1, 'name': 'Makan', 'is_expense': true},
          {'id': 2, 'name': 'Gaji', 'is_expense': false},
        ],
        savingNamesList: ['Dana Darurat'],
        savingsBalances: {'Dana Darurat': 18000000},
      );

  @override
  Future<TransactionSaveResult> saveTransaction({
    required String amountText,
    required String noteText,
    required int? selectedCategoryId,
    required int? selectedWalletId,
    required bool isExpense,
    required bool isFromSaving,
    required String? selectedSavingName,
    required DateTime selectedDate,
    required String? hiddenSavingMarker,
    required bool isReadOnly,
    required TransactionModel? transactionToEdit,
    required bool initialIsExpense,
  }) async {
    saveCalls.add({'amountText': amountText, 'isExpense': isExpense, 'categoryId': selectedCategoryId});
    return const TransactionSaveResult(false, "Jumlah dan Kategori wajib diisi!");
  }
}

Future<void> _pump(WidgetTester tester, InputTransactionScreen screen) async {
  _fakes.clear();
  await pumpApp(tester, screen,
      overrides: [inputTransactionProvider.overrideWith(FakeInputTransactionNotifier.new)]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tambah pengeluaran: header, nominal, scan, sumber dana, simpan', (tester) async {
    await _pump(tester, const InputTransactionScreen(initialIsExpense: true));
    expect(find.text('Tambah Transaksi'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Nominal'), findsOneWidget);
    expect(find.text('Scan Struk AI'), findsOneWidget);
    expect(find.text('SUMBER DANA'), findsOneWidget);
    expect(find.text('Tabungan'), findsWidgets);
    expect(find.text('Pilih Dompet...'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('CATATAN (OPSIONAL)'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsOneWidget);
  });

  testWidgets('pemasukan: tanpa Scan Struk, header Simpan Ke', (tester) async {
    await _pump(tester, const InputTransactionScreen());
    expect(find.text('Scan Struk AI'), findsNothing);
    expect(find.text('SIMPAN KE'), findsOneWidget);
  });

  testWidgets('pilih dompet dan kategori lewat sheet', (tester) async {
    await _pump(tester, const InputTransactionScreen(initialIsExpense: true));
    await tester.tap(find.text('Pilih Dompet...'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Dompet'), findsOneWidget);
    await tester.tap(find.text('BCA').last);
    await tester.pumpAndSettle();
    expect(find.text('BCA'), findsOneWidget);

    await tester.tap(find.text('Pilih Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan').last);
    await tester.pumpAndSettle();
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Gaji'), findsNothing); // kategori difilter per tipe
  });

  testWidgets('simpan memanggil notifier dengan argumen dari form', (tester) async {
    await _pump(tester, const InputTransactionScreen(initialIsExpense: true));
    await tester.enterText(find.byType(EditableText).first, '45000');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(_fakes.single.saveCalls.single['isExpense'], isTrue);
    expect(_fakes.single.saveCalls.single['amountText'], '45.000');
    await tester.pump(const Duration(seconds: 4)); // timer toast AppNotification
  });

  testWidgets('read-only mengunci segmented & tombol Kembali', (tester) async {
    await _pump(
      tester,
      InputTransactionScreen(
        initialIsExpense: true,
        transactionToEdit: TransactionModel(
          id: 1,
          userId: 'u',
          categoryId: 1,
          amount: 45000,
          date: DateTime(2026, 9, 24),
          note: 'Pakai tabungan [SAVING_ID:3]',
          walletId: 1,
        ),
      ),
    );
    expect(find.text('Detail Transaksi'), findsOneWidget);
    expect(find.textContaining('catatan otomatis dari fitur Tabungan'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Scan Struk AI'), findsNothing);
    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Struk AI'), findsNothing); // tetap pengeluaran, toggle terkunci
  });
}
```

**Penyesuaian:** `find.byType(EditableText).first` menunjuk field nominal (`AppAmountField`) karena field itu muncul sebelum field catatan. Nilai `'45.000'` adalah hasil `RupiahInputFormatter` dari B1; sesuaikan bila B1 memformat berbeda.

Run: `flutter test test/screens/input_transaction/input_transaction_screen_test.dart`
Expected: FAIL. Teks "Batal" dan "SUMBER DANA" belum ada.

- [ ] **Step 2: Ganti import dan method presentasi di `input_transaction_screen.dart`**

Import baru. Hapus `google_fonts`, `app_bottom_sheet`, dan `flutter/services`:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
```

Pertahankan tanpa perubahan: semua field state, `initState`, `_processScanReceipts`, dan `_saveTransaction`.

Hapus `_getCategoryIcon` dan `_buildToggleBtn`.

Ganti `_showImageSourceBottomSheet` dan `_pickDate`, lalu tambahkan method baru berikut di dalam class state:

```dart
  void _showImageSourceBottomSheet() {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Metode Scan",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsFill.camera, color: AppColors.primary),
            title: "Kamera",
            subtitle: "(1 Struk)",
            showChevron: true,
            onTap: () async {
              Navigator.pop(sheetContext);
              final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (image != null) _processScanReceipts([image]);
            },
          ),
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsFill.images, color: AppColors.tintIndigo),
            title: "Galeri",
            subtitle: "(Banyak Struk)",
            showChevron: true,
            onTap: () async {
              Navigator.pop(sheetContext);
              final images = await _picker.pickMultiImage(imageQuality: 80);
              if (images.isNotEmpty) _processScanReceipts(images);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    if (_isReadOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Color _walletColor(Map<String, dynamic> wallet) {
    final colorHex = (wallet['color'] ?? '#1E3A8A').toString();
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  }

  static const Widget _checkIcon = Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 20);

  void _onTypeSelected(bool isExpenseBtn) {
    if (_isReadOnly) return;
    final wallets = ref.read(inputTransactionProvider).wallets;
    setState(() {
      _isExpense = isExpenseBtn;
      _selectedCategoryId = null;
      if (!isExpenseBtn) {
        _isFromSaving = false;
        _selectedSavingName = null;
        if (wallets.isNotEmpty) _selectedWalletId = wallets.first['id'];
      }
    });
  }

  void _useWallet(InputTransactionState state) {
    setState(() {
      _isFromSaving = false;
      _selectedSavingName = null;
      if (state.wallets.isNotEmpty) _selectedWalletId = state.wallets.first['id'];
    });
  }

  void _useSaving(InputTransactionState state) {
    setState(() {
      _isFromSaving = true;
      _selectedWalletId = null;
      if (state.savingNamesList.isNotEmpty && _selectedSavingName == null) {
        _selectedSavingName = state.savingNamesList.first;
      }
    });
  }

  void _showWalletPicker(List<Map<String, dynamic>> wallets) {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Dompet",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final wallet in wallets)
            AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: _walletColor(wallet), filled: true),
              title: wallet['name'].toString(),
              value: formatRupiah(wallet['balance'] as num),
              trailing: wallet['id'] == _selectedWalletId ? _checkIcon : null,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedWalletId = wallet['id'] as int);
              },
            ),
        ],
      ),
    );
  }

  void _showSavingPicker(InputTransactionState state) {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Tabungan",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final savingName in state.savingNamesList)
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsFill.piggyBank, color: AppColors.primary),
              title: savingName,
              value: "Sisa: ${formatRupiah(state.savingsBalances[savingName] ?? 0)}",
              trailing: savingName == _selectedSavingName ? _checkIcon : null,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedSavingName = savingName);
              },
            ),
        ],
      ),
    );
  }

  void _showCategoryPicker(List<Map<String, dynamic>> categories) {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Kategori",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final cat in categories)
            AppListRow(
              leading: AppIconTile(
                icon: categoryIcon(cat['name'].toString()),
                color: categoryColor(cat['name'].toString()),
              ),
              title: cat['name'].toString(),
              trailing: cat['id'] == _selectedCategoryId ? _checkIcon : null,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedCategoryId = cat['id'] as int);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFundSourceSection(InputTransactionState state) {
    final Widget sourceRow;
    if (_isFromSaving) {
      final selected = state.savingNamesList.contains(_selectedSavingName) ? _selectedSavingName : null;
      sourceRow = AppListRow(
        leading: const AppIconTile(icon: PhosphorIconsFill.piggyBank, color: AppColors.primary),
        title: "Tabungan",
        value: selected ?? (state.savingNamesList.isEmpty ? "Belum ada tabungan" : "Pilih Tabungan..."),
        showChevron: state.savingNamesList.isNotEmpty,
        onTap: state.savingNamesList.isEmpty ? null : () => _showSavingPicker(state),
      );
    } else {
      final selected = state.wallets.where((w) => w['id'] == _selectedWalletId).firstOrNull;
      sourceRow = AppListRow(
        leading: AppIconTile(
          icon: PhosphorIconsFill.wallet,
          color: selected != null ? _walletColor(selected) : AppColors.tintGray,
          filled: true,
        ),
        title: "Dompet",
        value: selected != null
            ? selected['name'].toString()
            : (state.wallets.isEmpty ? "Buat dompet di menu utama!" : "Pilih Dompet..."),
        showChevron: state.wallets.isNotEmpty,
        onTap: state.wallets.isEmpty ? null : () => _showWalletPicker(state.wallets),
      );
    }

    return AppGroupedSection(
      header: _isExpense ? "Sumber Dana" : "Simpan Ke",
      children: [
        if (_isExpense)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: AppSegmentedControl(
              labels: const ['Dompet', 'Tabungan'],
              selectedIndex: _isFromSaving ? 1 : 0,
              onChanged: (i) => i == 0 ? _useWallet(state) : _useSaving(state),
            ),
          ),
        sourceRow,
      ],
    );
  }

  Widget _buildEditWalletNote(InputTransactionState state) {
    String wName = "Memuat...";
    if (state.wallets.isNotEmpty) {
      final w = state.wallets.firstWhere((e) => e['id'] == _selectedWalletId, orElse: () => {});
      wName = w.isNotEmpty ? w['name'] : "Telah Dihapus";
    }
    return AppCallout(
      icon: PhosphorIconsFill.wallet,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "Transaksi ini tercatat di dompet "),
            TextSpan(text: wName, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: Ganti `build()`**

Blok `ref.listen` (ITS:303–324) disalin **persis** di awal `build()`:

```dart
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inputTransactionProvider);

    // (salin persis blok ref.listen<InputTransactionState>(...) dari ITS:300-324)

    final filteredCategories = state.categories.where((c) => c['is_expense'] == _isExpense).toList();
    final selectedCategory = filteredCategories.where((c) => c['id'] == _selectedCategoryId).firstOrNull;
    final isNewTransaction = !_isReadOnly && widget.transactionToEdit == null;

    return AppPageScaffold(
      title: _isReadOnly
          ? "Detail Transaksi"
          : (widget.transactionToEdit == null ? "Tambah Transaksi" : "Edit Transaksi"),
      largeTitle: false,
      leading: AppNavAction.text('Batal', onPressed: () => Navigator.pop(context)),
      bottomBar: AppPrimaryButton(
        label: _isReadOnly ? "Kembali" : "Simpan Transaksi",
        color: _isReadOnly ? AppColors.textSecondary : null,
        loading: state.isSaving,
        onPressed: _isReadOnly
            ? () => Navigator.pop(context)
            : (state.isSaving ? null : _saveTransaction),
      ),
      children: [
        if (_isReadOnly)
          const AppCallout(
            icon: PhosphorIconsFill.info,
            child: Text(
              "Ini adalah catatan otomatis dari fitur Tabungan. Silakan gunakan Menu Tabungan di Beranda untuk mengedit/menghapus data ini.",
            ),
          ),
        AppSegmentedControl(
          labels: const ['Pemasukan', 'Pengeluaran'],
          selectedIndex: _isExpense ? 1 : 0,
          selectedLabelColors: const [AppColors.income, AppColors.expense],
          onChanged: (i) => _onTypeSelected(i == 1),
        ),
        if (_isReadOnly)
          AppAmountDisplay(label: "Nominal", amountText: "Rp ${_amountController.text}")
        else
          AppAmountField(controller: _amountController, label: "Nominal"),
        if (_isExpense && !_isReadOnly)
          Center(
            child: AppPillButton(
              label: "Scan Struk AI",
              icon: PhosphorIconsFill.sparkle,
              onPressed: _showImageSourceBottomSheet,
            ),
          ),
        if (isNewTransaction) _buildFundSourceSection(state),
        if (widget.transactionToEdit != null && _selectedWalletId != null) _buildEditWalletNote(state),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: AppIconTile(
                icon: selectedCategory != null
                    ? categoryIcon(selectedCategory['name'].toString())
                    : PhosphorIconsFill.tag,
                color: selectedCategory != null
                    ? categoryColor(selectedCategory['name'].toString())
                    : AppColors.tintOrange,
              ),
              title: "Kategori",
              value: selectedCategory != null
                  ? selectedCategory['name'].toString()
                  : (state.categories.isEmpty ? "Memuat..." : "Pilih Kategori"),
              showChevron: !_isReadOnly,
              onTap: (_isReadOnly || filteredCategories.isEmpty)
                  ? null
                  : () => _showCategoryPicker(filteredCategories),
            ),
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.tintRed),
              title: "Tanggal",
              value: DateFormat('EEE, d MMM yyyy', 'id_ID').format(_selectedDate),
              showChevron: !_isReadOnly,
              onTap: _isReadOnly ? null : _pickDate,
            ),
          ],
        ),
        AppGroupedSection(
          header: "Catatan (Opsional)",
          children: [
            AppTextField(
              controller: _noteController,
              hint: "Contoh: Beli Nasi Padang / Bayar Bengkel",
              readOnly: _isReadOnly,
            ),
          ],
        ),
      ],
    );
  }
```

Catatan: `_currencyFormat` tetap dipakai di `initState` dan `_processScanReceipts`. `AppAmountField` memakai `RupiahInputFormatter`, jadi `onChanged` format manual yang lama (ITS:782–794) dibuang. Provider tetap mem-parse dengan menghapus semua non-digit, sehingga hasil simpan identik.

- [ ] **Step 4: Jalankan test**

Run: `flutter test test/screens/input_transaction/input_transaction_screen_test.dart`
Expected: PASS. Bila test "pilih dompet" gagal karena `find.text('BCA')` muncul dua kali (sheet belum tertutup), tambahkan `await tester.pumpAndSettle()` kedua.

- [ ] **Step 5: Cek aturan**

```bash
grep -c "GoogleFonts.poppins" lib/screens/input_transaction/input_transaction_screen.dart
grep -nE "Colors\.(red|green|grey|teal|black|blue|purple|orange)|0xFF[0-9A-F]{6}\)" lib/screens/input_transaction/input_transaction_screen.dart
flutter analyze lib/screens/input_transaction
```

Expected:
- `grep -c` mengeluarkan `0`.
- `grep -nE` tidak menemukan apa pun. `'0xFF'` di `_walletColor` adalah warna data dompet, jadi dikecualikan (spec §9.9).
- Analyze tanpa error atau warning baru.

- [ ] **Step 6: Checklist visual vs mockup "Tambah Transaksi"**

- [ ] Latar `background` abu iOS. Header kecil di tengah: "Tambah Transaksi"; kiri "Batal" biru; tanpa judul besar.
- [ ] Urutan: segmented Pemasukan/Pengeluaran → nominal besar di tengah dengan label "Nominal" → pill "Scan Struk AI" biru muda (hanya pengeluaran) → grup "SUMBER DANA"/"SIMPAN KE" (segmented Dompet/Tabungan + baris pilihan) → grup Kategori + Tanggal → grup "CATATAN (OPSIONAL)" → tombol biru "Simpan Transaksi" menempel di bawah.
- [ ] Baris punya tile ikon bertinta, nilai abu di kanan, dan chevron.
- [ ] Tap baris Dompet, Tabungan, atau Kategori membuka sheet dengan header "Batal · Pilih …" dan centang biru pada pilihan aktif.
- [ ] Mode edit: judul "Edit Transaksi", callout "Transaksi ini tercatat di dompet …", tanpa grup Sumber Dana.
- [ ] Mode read-only (transaksi dari Tabungan): callout info, nominal tampil statis, baris tanpa chevron, tombol abu "Kembali".
- [ ] Keyboard terbuka: tombol simpan tidak menutupi field catatan (AppPageScaffold `bottomBar`).

- [ ] **Step 7: Commit**

```bash
git add lib/screens/input_transaction/input_transaction_screen.dart test/screens/input_transaction/input_transaction_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(input): restyle add-transaction page as iOS sheet with picker rows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 7: Verifikasi penuh & checkpoint screenshot user

**Files:** tidak ada perubahan kode, kecuali perbaikan dari temuan verifikasi.

- [ ] **Step 1: Analyze & test penuh**

```bash
flutter analyze
flutter test
```

Expected:
- Analyze: 0 error; tidak ada warning baru dibanding `main` (bandingkan jumlah issue dengan `git stash; flutter analyze; git stash pop` bila ragu).
- Test: semua hijau. `widget_test.dart` sudah dihapus di B1.

- [ ] **Step 2: Cek konsistensi seluruh file yang disentuh**

```bash
grep -c "GoogleFonts.poppins" lib/screens/transaction_history/*.dart lib/screens/stats/stats_screen.dart lib/screens/input_transaction/input_transaction_screen.dart
grep -rn "AppTabSelector" lib/screens/transaction_history lib/screens/stats
git diff --stat main...HEAD
```

Expected:
- Semua hitungan `grep -c` = 0.
- `AppTabSelector` tidak lagi dipakai di file-file ini.
- Diff hanya berisi file dari tabel File Structure.

- [ ] **Step 3: Cek wiring Home tetap utuh**

Baca `lib/screens/home/home_screen.dart`. Pastikan kedua pemakaian `TransactionsTabScreen(... initialIsExpense: _transactionsIsExpense, onActiveTabChanged: (v) => _transactionsIsExpense = v)` (mobile dan web) tidak berubah, dan `bool isPengeluaran = _selectedIndex == 1 && _transactionsIsExpense;` masih ada. Plan ini tidak menyentuh `home_screen.dart`, jadi `git diff main...HEAD -- lib/screens/home/home_screen.dart` harus kosong.

- [ ] **Step 4: Jalankan app & checkpoint screenshot**

Pakai skill `run-and-screenshot`:

```bash
flutter run -d chrome --web-port=8765 > /tmp/flutter_run.log 2>&1 &
until grep -q "Debug service listening" /tmp/flutter_run.log; do sleep 3; done
```

Lalu cocokkan tiga screen dengan mockup memakai checklist Task 4, 5, dan 6. Bila tidak ada otomasi browser, minta user mengirim screenshot untuk:
1. Tab Transaksi (Pengeluaran, bulan berjalan), termasuk satu baris yang digeser.
2. Tab Statistik dengan satu kategori di-expand.
3. Halaman Tambah Transaksi (pengeluaran) dan sheet "Pilih Dompet".
4. Satu transaksi Tabungan yang dibuka (mode read-only).

Laporkan setiap perbedaan dengan mockup dan jangan klaim "sesuai" sebelum dilihat. Selesai: matikan server (`netstat -ano | grep :8765`, lalu `taskkill //F //PID <pid>`) dan `git checkout -- linux macos windows`.

- [ ] **Step 5: Merge setelah user menyetujui visual**

Pakai skill `superpowers:finishing-a-development-branch` (merge ke `main`).

---

## Catatan untuk koordinator (gap/seam yang ditemukan saat menulis plan)

1. **Seam komponen (Task 2):**
   - `AppPageScaffold.leading`: dipakai untuk tombol "Batal" tanpa chevron, sesuai mockup.
   - `AppSwipeActions.deleteConfirmTitle` / `deleteConfirmMessage`: supaya teks "Hapus Transaksi?" / "Data ini akan dihapus permanen." tetap sama.
   - Keduanya tidak ada di kontrak spec §6. Bila B1 sudah menyediakan yang setara, pakai itu saja.
2. **Helper bersama baru di luar spec §6:**
   - `lib/widgets/app_period_picker.dart` (`showAppPeriodPicker`, `periodLabel`, `kPeriodFilterTypes`).
   - `lib/screens/transaction_history/transaction_filter_sheet.dart`.
   - `lib/core/category_visuals.dart`.
   - Tujuannya menghapus duplikasi dua screen. Plan B6 (Kalender) sebaiknya memakai `categoryIcon`/`categoryColor` juga.
3. **Label judul Statistik:** sudah diputuskan user (2026-09-24): judul besar "Statistik", menggantikan "Laporan Keuangan".
4. **`[DEBT_ID:`:** tampilan baris utang di Riwayat ditangani di sini (Task 4, #20). Pengecualian dari `totalAmount` di `transaction_history_provider.dart` dan `stats_provider.dart` adalah tanggung jawab B2. Plan ini tidak mengubah provider.
5. **Tanggal per baris** di list Transaksi dipindah ke header grup (spec §7.4). Tanggal lengkap tetap terlihat di halaman edit.
