# Phase B5 — Perencanaan (Anggaran, Target, Tabungan, Rutin) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mendesain ulang 6 screen fitur perencanaan (Anggaran, Detail Anggaran, Target Keuangan, Buku Tabungan, Detail Tabungan, Tagihan & Pemasukan Rutin) beserta semua sheet form-nya ke gaya iOS sesuai mockup, tanpa mengubah fitur/data.

**Architecture:** Setiap screen dibangun ulang dari komponen bersama Plan B1 (`AppPageScaffold`, `AppGroupedSection`, `AppListRow`, `AppHeroCard`, `showAppFormSheet`, dst.). Logika provider dan semua `onTap`/validasi/toast dipertahankan persis. FAB diganti `AppNavAction.add` (G3), form jadi `showAppFormSheet` (G4), warna ungu/teal/hijau fitur diganti `AppColors` (G11). Dua screen yang memanggil Supabase langsung di `State` diberi *seam* minimal supaya bisa dites dengan `pumpApp` + provider palsu.

**Tech Stack:** Flutter, flutter_riverpod 2.6.1, forui 0.17.0 (lewat komponen B1), phosphor_flutter, intl (`id_ID`), google_fonts (hanya lewat `AppTextStyles`).

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (baca §3 aturan desain, §4 token, §5 tipografi, §6 kontrak komponen, §9 aturan engineering, §10 verifikasi). Mockup: `docs/design/dompetku-redesign-mockup.html` — entri `SCREENS` bernama "Anggaran", "Detail Anggaran", "Target Keuangan", "Buku Tabungan", "Detail Tabungan", "Tagihan & Pemasukan Rutin", "Contoh form: Buat Anggaran".

**Prasyarat:** Plan B1 sudah di-merge ke `main` (komponen, `formatters.dart`, `AppTextStyles`, `test/helpers/pump_app.dart` ada). Plan B2–B4 sebaiknya sudah di-merge (urutan eksekusi spec §8), tetapi B5 tidak bergantung pada perubahan B2–B4.

## Global Constraints

Setiap task secara implisit wajib memenuhi semua baris di bawah (disalin dari spec §9 dan §10):

- **§9.1** Jangan jalankan `dart format` ke seluruh file. Edit terarah saja. Diff harus sebanding dengan perubahan. (Screen di plan ini ditulis ulang bagian `build()`/sheet-nya — itu memang perubahannya; jangan memformat ulang bagian yang tidak disentuh seperti provider.)
- **§9.2** `Notifier.build()` tidak boleh menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)`.
- **§9.3** Refresh provider lewat `ref.invalidate(...)`, bukan mengganti `ValueKey`.
- **§9.4** Setelah `await` (terutama `Navigator.push`/sheet/picker), cek `if (!mounted) return;` / `if (!context.mounted) return;` sebelum `setState`/`context`/`ref`.
- **§9.5** Tab di dalam Home memakai `AppPageScaffold(embedded: true)` — screen di plan ini semuanya halaman push, jadi `embedded: false` (default).
- **§9.6** Jangan menaruh `Center`/`Align`/`Expanded` tanpa batas di slot yang memberi tinggi longgar — pakai `heightFactor: 1`.
- **§9.7** Pertahankan konkurensi fetch asli (`Future.wait` / record `.wait` bila kode lama menjalankan fetch paralel).
- **§9.8** Semua `onTap` / navigasi / efek samping lama dipertahankan persis; redesign hanya mengubah tampilan kecuali plan ini menyebut perubahan logika (setiap perubahan logika ditandai **[LOGIKA]**).
- **§9.9** Tidak ada hex di screen — semua warna dari `AppColors`. Pengecualian: `Colors.white`, `Colors.transparent`, warna dompet dari data. `Colors.purple`, `Color(0xFF009688)`, `Colors.green`, `Colors.orange`, `Colors.blue`, `Colors.red`, `Colors.grey`, `Colors.blueGrey`, `Colors.tealAccent`, `Colors.redAccent` semuanya harus hilang dari 6 screen ini.
- **§9.10** Commit message Conventional Commits (hook `commit-msg`), scope tanpa koma. Akhiri dengan baris atribusi:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
  ```
- **§9.11** Tidak ada perubahan skema DB di plan ini.
- **§10.1** `flutter analyze` tidak menambah error/warning baru (info `withOpacity` lama boleh).
- **§10.2** `flutter test` hijau.
- **§10.3** `grep -c "GoogleFonts.poppins" <file screen>` = 0 untuk setiap screen yang disentuh; import `google_fonts` dihapus dari screen.
- **§10.4** Tidak ada hex/`Colors.<warna>` baru di screen (kecuali pengecualian §9.9).
- **§10.5** Checklist visual tiap task dicocokkan dengan mockup memakai skill `run-and-screenshot`. Bila agent tidak punya otomasi browser, koordinator meminta screenshot ke user di Task 8 (akhir plan), bukan per task.
- Setelah setiap `flutter analyze`/`flutter test`, kembalikan file registrant yang berubah hanya line-ending: `git checkout -- linux macos windows`.

## Review Focus

Lima kondisi yang tidak diuji oleh fitur "normal" tetapi paling mungkin menggigit pengguna. Tiap baris punya test di task pemiliknya.

1. **Edit Target dengan deadline yang sudah lewat** — sheet "Edit Target" membuka date picker dengan `initialDate` = deadline lama padahal `firstDate: DateTime.now()`; Flutter melempar assertion dan sheet crash. Harapan: picker terbuka dengan tanggal hari ini. → **[LOGIKA]** perbaikan + test di Task 4.
2. **Nominal kosong di sheet "Edit Setoran/Tarikan"** — kode lama `double.parse("")` di luar `try` → `FormatException` tak tertangani. Harapan: tombol tidak melakukan apa-apa. → **[LOGIKA]** guard + test di Task 6.
3. **Nama sangat panjang** (nama tabungan/target/kategori 60+ karakter) — harus terpotong elipsis, tidak overflow merah. → test di Task 5 (dan `maxLines: 1` di semua judul kartu).
4. **Anggaran melebihi limit (>100%)** — progress bar dijepit penuh, ring menampilkan persen >100, chip berganti "Over Budget:" merah. → test di Task 2 dan Task 3.
5. **Belum ada anggaran sama sekali** — FAB lama disembunyikan saat daftar kosong sehingga anggaran pertama hanya bisa dibuat lewat "Salin Bulan Lalu". Harapan: tombol "+" di nav bar selalu ada. → test di Task 2.

---

## File Structure

| File | Aksi | Tanggung jawab |
|---|---|---|
| `lib/widgets/app_select_row.dart` | Create | Baris grouped list yang membuka menu pilihan (pengganti `DropdownButton` di sheet). |
| `lib/widgets/app_text_field.dart` | Modify | Tambah parameter opsional `focusNode` (dibutuhkan autocomplete lokasi Target). |
| `lib/widgets/app_swipe_actions.dart` | Modify | Tambah parameter opsional `deleteConfirmTitle`/`deleteConfirmMessage` supaya teks dialog hapus lama bisa dipertahankan. |
| `lib/screens/budget/budget_screen.dart` | Rewrite build + sheets | Anggaran + sheet "Buat Anggaran" + sheet "Pilih Periode". |
| `lib/providers/budget_provider.dart` | Modify (tambah di akhir file) | Seam `budgetDetailProvider` (fetch transaksi & dompet Detail Anggaran). |
| `lib/screens/budget/budget_detail_screen.dart` | Rewrite | Detail Anggaran + sheet "Edit Anggaran". |
| `lib/screens/target/target_screen.dart` | Rewrite build + sheets | Target Keuangan + sheet "Target Baru", "Edit Target", "Nabung: …". |
| `lib/screens/savings/savings_screen.dart` | Rewrite build + sheets | Buku Tabungan + sheet "Buat Tabungan", "Edit Tabungan", "Setor ke …/Tarik dari …". |
| `lib/screens/savings/saving_detail_screen.dart` | Rewrite build + sheet, seam getter | Detail Tabungan + sheet "Edit Setoran/Tarikan". |
| `lib/screens/recurring/recurring_screen.dart` | Rewrite build + sheet | Tagihan & Pemasukan Rutin + sheet "Buat/Edit Jadwal Tagihan". |
| `test/widgets/app_select_row_test.dart` | Create | Test komponen baru. |
| `test/screens/budget/budget_screen_test.dart` | Create | |
| `test/screens/budget/budget_detail_screen_test.dart` | Create | |
| `test/screens/target/target_screen_test.dart` | Create | |
| `test/screens/savings/savings_screen_test.dart` | Create | |
| `test/screens/savings/saving_detail_screen_test.dart` | Create | |
| `test/screens/recurring/recurring_screen_test.dart` | Create | |

Branch: `redesign/phase-b5-planning` dari `main`.

---

### Task 0: Branch

- [ ] **Step 1: Buat branch dari main terbaru**

```bash
git checkout main && git pull --ff-only 2>/dev/null; git checkout -b redesign/phase-b5-planning
```

- [ ] **Step 2: Pastikan fondasi B1 ada**

Run: `ls lib/widgets/app_page_scaffold.dart lib/widgets/app_sheet.dart lib/core/formatters.dart lib/theme/app_text_styles.dart test/helpers/pump_app.dart`
Expected: kelima file ada. Bila salah satu tidak ada → STOP, laporkan BLOCKED (Plan B1 belum di-merge).

---

### Task 1: Komponen tambahan untuk B5

Spec §6 tidak punya komponen "pilih dari daftar" untuk menggantikan `DropdownButton` di sheet, `AppTextField` tidak menerima `focusNode` (dibutuhkan `RawAutocomplete`), dan `AppSwipeActions` tidak bisa menerima teks dialog konfirmasi. Sesuai aturan spec §6 ("tambahkan parameter opsional di komponennya … dan catat di laporan"), task ini menambahkannya **sekali** untuk semua screen B5.

**Files:**
- Create: `lib/widgets/app_select_row.dart`
- Modify: `lib/widgets/app_text_field.dart`
- Modify: `lib/widgets/app_swipe_actions.dart`
- Test: `test/widgets/app_select_row_test.dart`, tambahan test di `test/widgets/app_text_field_test.dart` dan `test/widgets/app_swipe_actions_test.dart` (file-file ini dibuat oleh B1; tambahkan `testWidgets` baru di dalam `main()` yang ada).

**Interfaces:**
- Consumes: `AppListRow`, `AppIconTile` (`lib/widgets/app_list_row.dart`), `AppColors`, `AppTextStyles`, `showAppConfirmDialog`.
- Produces:
  ```dart
  class AppSelectOption<T> { const AppSelectOption(this.value, this.label); final T value; final String label; }
  class AppSelectRow<T> extends StatelessWidget {
    const AppSelectRow({required this.title, required this.options, required this.value,
      required this.onChanged, this.placeholder = 'Pilih', this.leading, super.key});
  }
  // AppTextField: tambahan `final FocusNode? focusNode;` (opsional, default null)
  // AppSwipeActions: tambahan `final String deleteConfirmTitle;` (default 'Hapus?')
  //                  dan `final String deleteConfirmMessage;` (default 'Data ini akan dihapus.')
  ```

- [ ] **Step 1: Cek apakah komponen/parameter sudah dibuat plan sebelumnya**

Run:
```bash
grep -rn "class AppSelectRow" lib/widgets/ ; grep -n "focusNode" lib/widgets/app_text_field.dart ; grep -n "deleteConfirmTitle" lib/widgets/app_swipe_actions.dart
```
Untuk setiap item yang SUDAH ada dengan nama & tipe persis seperti di **Interfaces**, lewati langkah pembuatannya di bawah (tetap jalankan test-nya). Bila ada dengan nama berbeda → STOP, laporkan NEEDS_CONTEXT (jangan membuat komponen kembar).

- [ ] **Step 2: Tulis test gagal untuk `AppSelectRow`**

`test/widgets/app_select_row_test.dart`:
```dart
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppSelectRow menampilkan placeholder saat value null', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Kategori',
          placeholder: 'Pilih Kategori Pengeluaran',
          value: null,
          options: const [AppSelectOption(1, 'Makan'), AppSelectOption(2, 'Belanja')],
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Pilih Kategori Pengeluaran'), findsOneWidget);
  });

  testWidgets('AppSelectRow menampilkan label opsi terpilih dan memanggil onChanged', (tester) async {
    int? picked;
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Kategori',
          value: 1,
          options: const [AppSelectOption(1, 'Makan'), AppSelectOption(2, 'Belanja')],
          onChanged: (v) => picked = v,
        ),
      ),
    );
    expect(find.text('Makan'), findsOneWidget);

    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belanja').last);
    await tester.pumpAndSettle();

    expect(picked, 2);
  });

  testWidgets('AppSelectRow tanpa opsi tidak membuka menu', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Dompet',
          placeholder: 'Belum ada dompet',
          value: null,
          options: const [],
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });
}
```

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_select_row_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:catat_uang_app/widgets/app_select_row.dart'`.

- [ ] **Step 4: Implementasi `AppSelectRow`**

`lib/widgets/app_select_row.dart`:
```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Satu opsi untuk [AppSelectRow].
class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label);
  final T value;
  final String label;
}

/// Baris grouped list yang membuka menu pilihan ala pull-down menu iOS.
/// Pengganti `DropdownButton` di dalam sheet form. Label opsi terpilih
/// tampil sebagai `value` abu di kanan; bila belum ada pilihan tampil
/// [placeholder].
class AppSelectRow<T> extends StatelessWidget {
  const AppSelectRow({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Pilih',
    this.leading,
    super.key,
  });

  final String title;
  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String placeholder;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    return PopupMenuButton<T>(
      enabled: options.isNotEmpty,
      color: AppColors.surface,
      elevation: 8,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            child: Row(
              children: [
                Expanded(child: Text(option.label, style: AppTextStyles.body)),
                if (option.value == value)
                  const Icon(PhosphorIconsBold.check, size: 18, color: AppColors.primary),
              ],
            ),
          ),
      ],
      child: AppListRow(
        leading: leading,
        title: title,
        value: selected?.label ?? placeholder,
        showChevron: true,
      ),
    );
  }
}
```

- [ ] **Step 5: Jalankan, pastikan lolos**

Run: `flutter test test/widgets/app_select_row_test.dart`
Expected: PASS (3 test).

- [ ] **Step 6: Tambah test `focusNode` di `test/widgets/app_text_field_test.dart`** (di dalam `main()` yang sudah ada; tambahkan import `package:flutter/material.dart` bila belum)

```dart
  testWidgets('AppTextField meneruskan focusNode ke TextField', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpApp(
      tester,
      Scaffold(body: AppTextField(controller: TextEditingController(), focusNode: node)),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode, same(node));
  });
```

- [ ] **Step 7: Jalankan, pastikan gagal** — `flutter test test/widgets/app_text_field_test.dart` → FAIL `No named parameter with the name 'focusNode'`.

- [ ] **Step 8: Tambah `focusNode` ke `AppTextField`**

Di `lib/widgets/app_text_field.dart`:
1. Di konstruktor, setelah `this.onTap,` tambahkan `this.focusNode,`.
2. Tambahkan field `final FocusNode? focusNode;` di samping field lain.
3. Di `TextField(...)` yang dibangun widget ini, tambahkan argumen `focusNode: focusNode,`.

- [ ] **Step 9: Jalankan, pastikan lolos** — `flutter test test/widgets/app_text_field_test.dart` → PASS.

- [ ] **Step 10: Tambah test teks konfirmasi di `test/widgets/app_swipe_actions_test.dart`**

```dart
  testWidgets('AppSwipeActions memakai deleteConfirmTitle & deleteConfirmMessage kustom', (tester) async {
    var deleted = false;
    await pumpApp(
      tester,
      Scaffold(
        body: AppSwipeActions(
          deleteConfirmTitle: 'Hapus?',
          deleteConfirmMessage: 'Yakin hapus anggaran ini?',
          onDelete: () => deleted = true,
          child: const SizedBox(height: 56, width: 390, child: Text('Makan')),
        ),
      ),
    );
    await tester.drag(find.text('Makan'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(PhosphorIconsRegular.trash).last);
    await tester.pumpAndSettle();

    expect(find.text('Hapus?'), findsOneWidget);
    expect(find.text('Yakin hapus anggaran ini?'), findsOneWidget);

    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
```
(Tambahkan `import 'package:phosphor_flutter/phosphor_flutter.dart';` bila belum ada. Bila B1 memakai ikon hapus lain di `AppSwipeActions`, ganti `PhosphorIconsRegular.trash` pada test ini dengan ikon yang dipakai B1 — lihat `grep -n "Icon(" lib/widgets/app_swipe_actions.dart`.)

> **Catatan koordinator (penyelarasan antar-plan):** Plan B1 sudah membuat `deleteConfirmTitle` / `deleteConfirmMessage` di `AppSwipeActions` (default `'Hapus?'` / `'Data ini akan dihapus permanen.'`). Test di atas seharusnya langsung **PASS** terhadap B1 — lewati Step 11 dan Step 12, jangan menambah field kembar. Screen B5 selalu mengirim teks dialog aslinya secara eksplisit, jadi perbedaan default tidak berpengaruh.

- [ ] **Step 11: Jalankan, pastikan gagal** — `flutter test test/widgets/app_swipe_actions_test.dart` → FAIL `No named parameter with the name 'deleteConfirmTitle'`.

- [ ] **Step 12: Tambah parameter ke `AppSwipeActions`**

Di `lib/widgets/app_swipe_actions.dart`:
1. Konstruktor: tambahkan `this.deleteConfirmTitle = 'Hapus?', this.deleteConfirmMessage = 'Data ini akan dihapus.',`.
2. Field: `final String deleteConfirmTitle;` dan `final String deleteConfirmMessage;`.
3. Di pemanggilan `showAppConfirmDialog(...)` di dalam widget, ganti argumen `title:` dan `message:` menjadi `title: widget.deleteConfirmTitle, message: widget.deleteConfirmMessage,` (atau tanpa `widget.` bila dipanggil dari class widget itu sendiri).

- [ ] **Step 13: Jalankan seluruh test widget** — `flutter test test/widgets/` → PASS semua.

- [ ] **Step 14: Analyze** — `flutter analyze lib/widgets/` → tidak ada error/warning baru.

- [ ] **Step 15: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/widgets/app_select_row.dart lib/widgets/app_text_field.dart lib/widgets/app_swipe_actions.dart test/widgets/app_select_row_test.dart test/widgets/app_text_field_test.dart test/widgets/app_swipe_actions_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add AppSelectRow and focus/confirm options for planning screens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: Anggaran (`BudgetScreen`) + sheet "Buat Anggaran" + sheet "Pilih Periode"

**Files:**
- Modify (tulis ulang isi class): `lib/screens/budget/budget_screen.dart`
- Test: `test/screens/budget/budget_screen_test.dart`

**Interfaces:**
- Consumes: `budgetProvider`, `BudgetState`, `BudgetNotifier` (`changeMonth`, `setMonth`, `copyFromLastMonth`, `deleteBudget`, `addBudget`) — tidak berubah. `BudgetDetailScreen(budget:)`. Komponen B1 + `AppSelectRow` (Task 1).
- Produces: `BudgetScreen` (const, ConsumerWidget) — API tidak berubah. Helper statis `BudgetScreen.statusColor(double progress)` dipakai Task 3.

**Mockup:** entri "Anggaran" dan "Contoh form: Buat Anggaran".

#### Tabel preservasi (kode lama → layout baru)

| # | Kode lama (`budget_screen.dart`) | Perilaku | Di layout baru |
|---|---|---|---|
| 1 | :17-19 `_changeMonth(ref, offset)` | `ref.read(budgetProvider.notifier).changeMonth(offset)` | Pill chevron kiri (-1) / kanan (+1) di baris pemilih bulan |
| 2 | :21-91 `_showMonthYearPicker` dialog "Pilih Periode" (dropdown bulan `MMMM id_ID`, dropdown tahun now-5..now+5, tombol "Tampilkan" → `setMonth(DateTime(tempYear, tempMonth))` lalu pop) | ganti periode | Pill tengah (kalender + "MMMM yyyy" + caret) → `_pickPeriod` = `showAppMonthPicker(title: 'Pilih Periode')` (Plan B3b): tahun ‹ › + grid 12 bulan + tombol "Pilih"; hasil → `setMonth` |
| 3 | :93-104 `_copyFromLastMonth` | toast error "Tidak ada data anggaran bulan lalu." / sukses "Berhasil menyalin anggaran!" / error "Gagal menyalin: $e" | Sama persis, dipanggil dari tombol "Salin Bulan Lalu" di empty state |
| 4 | :106-108 `_deleteBudget` | `deleteBudget(id)` tanpa toast | `AppSwipeActions.onDelete` pada baris anggaran |
| 5 | :409-418 dialog "Hapus?" / "Yakin hapus anggaran ini?" (Batal / Hapus merah) | konfirmasi hapus | `AppSwipeActions(deleteConfirmTitle: 'Hapus?', deleteConfirmMessage: 'Yakin hapus anggaran ini?')` |
| 6 | :111-256 sheet "Buat Anggaran": label "Periode Anggaran" (bulan+tahun), "Pilih Kategori" (hint "Pilih Kategori Pengeluaran", opsi `allCategories`), "Batas Maksimal (Limit)" (Rp, titik ribuan), tombol "Simpan Anggaran" | `if (selectedCatId == null \|\| amount kosong) return;` → `addBudget(...)` → pop → toast "Berhasil ditambahkan!"; catch → toast `e.toString()` | `showAppFormSheet(title: 'Buat Anggaran')`: grup berisi baris "Periode Anggaran" (membuka `_pickPeriod`) dan `AppSelectRow` "Kategori" (placeholder "Pilih Kategori Pengeluaran"), kartu `AppAmountField` "Batas Maksimal (Limit)", tombol "Simpan Anggaran". Validasi & toast sama. |
| 7 | :260-263 `totalProgress = totalBudget == 0 ? 0 : totalSpent / totalBudget` | | Sama; `AppProgressBar` di hero |
| 8 | :324-333 hero "Terpakai Bulan Ini" + total spent, "Total Anggaran" + total budget | | `AppHeroCard` dengan dua kolom yang sama |
| 9 | :343 progress hero `redAccent` bila over, selain itu `tealAccent` | | over → `AppColors.expense`, selain itu `AppColors.white` (`onDark: true`) |
| 10 | :355-357 loading | spinner | spinner di dalam children |
| 11 | :358-373 empty: ikon `chartDonut`, "Belum ada anggaran", tombol "Salin Bulan Lalu" (ikon copy) | | `AppEmptyState(icon: PhosphorIconsFill.chartDonut, title: 'Belum ada anggaran', action: AppPillButton('Salin Bulan Lalu'))` |
| 12 | :378-381 per anggaran: `spent = spendingMap[categoryId] ?? 0`, `progress = amount == 0 ? 0 : spent/amount`, warna `>1` merah, `>0.8` oranye, selain itu ungu | | `BudgetScreen.statusColor(progress)`: `>1` → `AppColors.expense`, `>0.8` → `AppColors.tintOrange`, selain itu `AppColors.primary` (threshold persis sama) |
| 13 | :383-386 tap kartu → `Navigator.push(BudgetDetailScreen(budget: budget))` | | `AppListRow.onTap` sama persis |
| 14 | :400-403 ikon `tag` bertinta warna status + nama kategori (`budget.category?.name ?? "-"`) | | `AppIconTile(PhosphorIconsFill.tag, color: status)` + judul |
| 15 | :427-428 "Rp spent" warna status + " / Rp limit" abu | | `trailing` Text.rich yang sama |
| 16 | :447-454 FAB "+ Anggaran" hanya saat `budgets.isNotEmpty` → `_showFormSheet(...)` | | **[LOGIKA]** `AppNavAction.add` selalu tampil (Review Focus #5) → `_showFormSheet` sama |
| 17 | :267-271 AppBar "Anggaran" + back | | `AppPageScaffold(title: 'Anggaran', backLabel: 'Beranda')` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/budget/budget_screen_test.dart`:
```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeBudgetNotifier extends BudgetNotifier {
  _FakeBudgetNotifier(this._initial);
  final BudgetState _initial;
  @override
  BudgetState build() => _initial;
}

final _food = CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'tag');
final _shop = CategoryModel(id: 2, name: 'Belanja', isExpense: true, iconName: 'tag');
final _fun = CategoryModel(id: 3, name: 'Hiburan', isExpense: true, iconName: 'tag');

BudgetState _filledState() => BudgetState(
      isLoading: false,
      selectedMonth: DateTime(2026, 9),
      budgets: [
        BudgetModel(id: 10, categoryId: 1, amount: 1500000, month: 9, year: 2026, category: _food),
        BudgetModel(id: 11, categoryId: 2, amount: 1500000, month: 9, year: 2026, category: _shop),
        BudgetModel(id: 12, categoryId: 3, amount: 1000000, month: 9, year: 2026, category: _fun),
      ],
      spendingMap: {1: 1230000, 2: 1690000, 3: 100000},
      allCategories: [_food, _shop, _fun],
      totalBudget: 4000000,
      totalSpent: 3020000,
    );

Future<void> _pump(WidgetTester tester, BudgetState state) async {
  await pumpApp(
    tester,
    const BudgetScreen(),
    overrides: [budgetProvider.overrideWith(() => _FakeBudgetNotifier(state))],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan judul besar, hero, pemilih bulan, dan baris anggaran', (tester) async {
    await _pump(tester, _filledState());

    expect(find.text('Anggaran'), findsWidgets);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Terpakai Bulan Ini'), findsOneWidget);
    expect(find.text('Total Anggaran'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Belanja'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(AppNavAction), findsOneWidget);
  });

  testWidgets('warna status mengikuti threshold 80% dan 100% (Review Focus #4)', (tester) async {
    await _pump(tester, _filledState());

    final colors = tester
        .widgetList<AppProgressBar>(find.byType(AppProgressBar))
        .map((bar) => bar.color)
        .toList();
    // hero (putih) + Makan 82% (oranye) + Belanja 113% (merah) + Hiburan 10% (primary)
    expect(colors, containsAll([AppColors.tintOrange, AppColors.expense, AppColors.primary]));
  });

  testWidgets('empty state tetap punya tombol + dan "Salin Bulan Lalu" (Review Focus #5)', (tester) async {
    await _pump(tester, BudgetState(isLoading: false, selectedMonth: DateTime(2026, 9)));

    expect(find.text('Belum ada anggaran'), findsOneWidget);
    expect(find.text('Salin Bulan Lalu'), findsOneWidget);
    expect(find.byType(AppNavAction), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet "Buat Anggaran" dengan field lengkap', (tester) async {
    await _pump(tester, _filledState());

    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();

    expect(find.text('Buat Anggaran'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Periode Anggaran'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Pilih Kategori Pengeluaran'), findsOneWidget);
    expect(find.text('Batas Maksimal (Limit)'), findsOneWidget);
    expect(find.text('Simpan Anggaran'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/budget/budget_screen_test.dart`
Expected: FAIL (mis. `find.byType(AppNavAction)` findsNothing / `FloatingActionButton` ditemukan / teks "September 2026" tidak ditemukan karena layout lama).

- [ ] **Step 3: Tulis ulang `lib/screens/budget/budget_screen.dart`**

Ganti seluruh isi file dengan:
```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_detail_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  /// Warna status anggaran. Threshold sama persis dengan versi lama:
  /// > 100% merah, > 80% oranye, selain itu warna utama.
  static Color statusColor(double progress) {
    if (progress > 1) return AppColors.expense;
    if (progress > 0.8) return AppColors.tintOrange;
    return AppColors.primary;
  }

  void _changeMonth(WidgetRef ref, int offset) {
    ref.read(budgetProvider.notifier).changeMonth(offset);
  }

  // Catatan executor (B3b): bila `AppSelectRow`/`AppGroupedSection` tidak lagi
  // dipakai di file ini setelah _pickPeriod memakai showAppMonthPicker, hapus import-nya.
  /// Sheet "Pilih Periode" (dulu AlertDialog) — pemilih bulan bersama
  /// (Plan B3b, spec G17). Mengembalikan bulan terpilih atau null bila batal.
  /// Dipakai pill bulan di header dan baris "Periode Anggaran" di sheet "Buat Anggaran".
  static Future<DateTime?> _pickPeriod(BuildContext context, DateTime initial) {
    final currentYear = DateTime.now().year;
    return showAppMonthPicker(
      context: context,
      title: 'Pilih Periode',
      initialMonth: initial,
      firstYear: currentYear - 5,
      lastYear: currentYear + 5,
    );
  }

  Future<void> _openMonthPicker(BuildContext context, WidgetRef ref, DateTime selectedMonth) async {
    final picked = await _pickPeriod(context, selectedMonth);
    if (!context.mounted || picked == null) return;
    ref.read(budgetProvider.notifier).setMonth(picked);
  }

  Future<void> _copyFromLastMonth(BuildContext context, WidgetRef ref) async {
    try {
      final copied = await ref.read(budgetProvider.notifier).copyFromLastMonth();
      if (!copied) {
        if (context.mounted) AppNotification.error(context, "Tidak ada data anggaran bulan lalu.");
        return;
      }
      if (context.mounted) AppNotification.success(context, "Berhasil menyalin anggaran!");
    } catch (e) {
      if (context.mounted) AppNotification.error(context, "Gagal menyalin: $e");
    }
  }

  Future<void> _deleteBudget(WidgetRef ref, int id) async {
    await ref.read(budgetProvider.notifier).deleteBudget(id);
  }

  void _showFormSheet(BuildContext context, WidgetRef ref, DateTime selectedMonth, List<CategoryModel> allCategories) {
    int? selectedCatId;
    DateTime period = DateTime(selectedMonth.year, selectedMonth.month);
    final amountController = TextEditingController();

    showAppFormSheet<void>(
      context: context,
      title: 'Buat Anggaran',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroupedSection(
              children: [
                AppListRow(
                  leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.primary),
                  title: 'Periode Anggaran',
                  value: DateFormat('MMM yyyy', 'id_ID').format(period),
                  showChevron: true,
                  onTap: () async {
                    final picked = await _pickPeriod(context, period);
                    if (picked != null) setSheetState(() => period = picked);
                  },
                ),
                AppSelectRow<int>(
                  leading: const AppIconTile(icon: PhosphorIconsFill.tag, color: AppColors.expense),
                  title: 'Kategori',
                  placeholder: 'Pilih Kategori Pengeluaran',
                  value: selectedCatId,
                  options: [for (final c in allCategories) AppSelectOption(c.id, c.name)],
                  onChanged: (v) => setSheetState(() => selectedCatId = v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              child: AppAmountField(
                controller: amountController,
                label: 'Batas Maksimal (Limit)',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Simpan Anggaran',
              onPressed: () async {
                if (selectedCatId == null || amountController.text.isEmpty) return;
                try {
                  await ref.read(budgetProvider.notifier).addBudget(
                        categoryId: selectedCatId!,
                        month: period.month,
                        year: period.year,
                        amount: parseRupiah(amountController.text).toDouble(),
                      );
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) AppNotification.success(context, "Berhasil ditambahkan!");
                } catch (e) {
                  if (context.mounted) AppNotification.error(context, e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetProvider);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(state.selectedMonth);
    final double totalProgress = state.totalBudget == 0 ? 0 : state.totalSpent / state.totalBudget;

    return AppPageScaffold(
      title: 'Anggaran',
      backLabel: 'Beranda',
      actions: [
        AppNavAction.add(
          onPressed: () => _showFormSheet(context, ref, state.selectedMonth, state.allCategories),
        ),
      ],
      children: [
        Row(
          children: [
            AppPill(label: '', icon: PhosphorIconsBold.caretLeft, onTap: () => _changeMonth(ref, -1)),
            const SizedBox(width: 8),
            Expanded(
              child: AppPill(
                label: monthLabel,
                icon: PhosphorIconsFill.calendarBlank,
                trailing: const Icon(PhosphorIconsRegular.caretDown, size: 16, color: AppColors.textSecondary),
                expand: true,
                onTap: () => _openMonthPicker(context, ref, state.selectedMonth),
              ),
            ),
            const SizedBox(width: 8),
            AppPill(label: '', icon: PhosphorIconsBold.caretRight, onTap: () => _changeMonth(ref, 1)),
          ],
        ),
        AppHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppHeroLabel('Terpakai Bulan Ini'),
                        const SizedBox(height: 4),
                        AppHeroAmount(formatRupiah(state.totalSpent), fontSize: 26),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppHeroLabel('Total Anggaran'),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(state.totalBudget),
                        style: AppTextStyles.headline.copyWith(color: AppColors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppProgressBar(
                value: totalProgress,
                color: state.totalSpent > state.totalBudget ? AppColors.expense : AppColors.white,
                onDark: true,
              ),
            ],
          ),
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (state.budgets.isEmpty)
          AppEmptyState(
            icon: PhosphorIconsFill.chartDonut,
            title: 'Belum ada anggaran',
            action: AppPillButton(
              label: 'Salin Bulan Lalu',
              icon: PhosphorIconsBold.copy,
              onPressed: () => _copyFromLastMonth(context, ref),
            ),
          )
        else
          AppGroupedSection(
            children: [
              for (final budget in state.budgets)
                Builder(
                  builder: (context) {
                    final spent = state.spendingMap[budget.categoryId] ?? 0;
                    final progress = budget.amount == 0 ? 0.0 : spent / budget.amount;
                    final color = statusColor(progress);
                    return AppSwipeActions(
                      key: ValueKey(budget.id),
                      deleteConfirmTitle: 'Hapus?',
                      deleteConfirmMessage: 'Yakin hapus anggaran ini?',
                      onDelete: () => _deleteBudget(ref, budget.id),
                      child: AppListRow(
                        leading: AppIconTile(icon: PhosphorIconsFill.tag, color: color),
                        title: budget.category?.name ?? "-",
                        trailing: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: formatRupiah(spent),
                                style: AppTextStyles.amountRow.copyWith(color: color),
                              ),
                              TextSpan(
                                text: " / ${formatRupiah(budget.amount)}",
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        subtitleWidget: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AppProgressBar(value: progress, color: color, height: 6),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget)),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lolos**

Run: `flutter test test/screens/budget/budget_screen_test.dart`
Expected: PASS (4 test). Bila `AppPill(label: '')` menambah jarak kosong setelah ikon sehingga chevron terlihat tidak di tengah, catat di laporan (gap komponen B1) — jangan membuat tombol chevron manual.

- [ ] **Step 5: Bersihkan Poppins & hex**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/budget/budget_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|tealAccent|redAccent)" lib/screens/budget/budget_screen.dart
```
Expected: `0` dan tidak ada baris.

- [ ] **Step 6: Analyze** — `flutter analyze lib/screens/budget/budget_screen.dart` → 0 error/warning baru.

- [ ] **Step 7: Checklist visual (vs mockup "Anggaran" & "Contoh form: Buat Anggaran")**

Jalankan skill `run-and-screenshot`, buka Beranda → Anggaran, cocokkan:
- [ ] Nav bar: `‹ Beranda` kiri (biru), `+` kanan. Tidak ada FAB di bawah.
- [ ] Judul besar "Anggaran" rata kiri.
- [ ] Baris pemilih: pill chevron kiri · pill lebar (ikon kalender + "September 2026" + caret) · pill chevron kanan.
- [ ] Kartu hero gradasi biru: kiri "Terpakai Bulan Ini" + angka besar, kanan "Total Anggaran" + angka; progress bar putih di bawah (merah bila total terpakai > total anggaran).
- [ ] Satu grouped list putih; tiap baris: tile ikon tag berwarna status, nama kategori, kanan "Rp terpakai" berwarna + " / Rp limit" abu, progress tipis di bawah nama. Tidak ada warna ungu di mana pun.
- [ ] Geser baris ke kiri → tombol hapus merah → dialog iOS "Hapus?" / "Yakin hapus anggaran ini?".
- [ ] Empty state: ikon donut abu + "Belum ada anggaran" + tombol pill "Salin Bulan Lalu".
- [ ] Tekan `+` → sheet dengan grabber, header "Batal · Buat Anggaran", grup "Periode Anggaran ›" + "Kategori ›", kartu nominal besar biru "Batas Maksimal (Limit)", tombol biru "Simpan Anggaran".
- [ ] Pill bulan → sheet "Pilih Periode" (pemilih bulan bersama): tahun ‹ 2026 ›, grid 12 bulan, tombol "Pilih".

- [ ] **Step 8: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/budget/budget_screen.dart test/screens/budget/budget_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(budget): redesign budget list with iOS layout and form sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: Detail Anggaran (`BudgetDetailScreen`) + seam `budgetDetailProvider` + sheet "Edit Anggaran"

`BudgetDetailScreen` lama memanggil Supabase langsung dari `State` (`final SupabaseClient _supabase = Supabase.instance.client;` sebagai field initializer) sehingga tidak bisa di-pump di test. Seam minimal: pindahkan dua fetch-nya **tanpa mengubah query/filter** ke `FutureProvider.autoDispose.family` di `budget_provider.dart`. Konkurensi dipertahankan: kode lama memanggil `_fetchWallets()` dan `_fetchTransactions()` bersamaan dari `initState` tanpa saling menunggu → di provider dijalankan paralel lewat record `.wait`.

**Files:**
- Modify: `lib/providers/budget_provider.dart` (tambah di akhir file; jangan menyentuh `BudgetNotifier`)
- Modify (tulis ulang): `lib/screens/budget/budget_detail_screen.dart`
- Test: `test/screens/budget/budget_detail_screen_test.dart`

**Interfaces:**
- Consumes: `budgetProvider` (`updateBudgetAmount`), `BudgetModel`, `BudgetScreen.statusColor` (Task 2), komponen B1.
- Produces:
  ```dart
  typedef BudgetDetailKey = ({int categoryId, int month, int year});
  class BudgetDetailData {
    const BudgetDetailData({this.transactions = const [], this.totalSpent = 0,
      this.walletNames = const {}, this.walletColors = const {}});
    final List<Map<String, dynamic>> transactions;
    final double totalSpent;
    final Map<int, String> walletNames;
    final Map<int, Color> walletColors;
  }
  final budgetDetailProvider =
      FutureProvider.autoDispose.family<BudgetDetailData, BudgetDetailKey>(...);
  ```
  `BudgetDetailScreen({super.key, required BudgetModel budget})` — konstruktor tidak berubah (dipanggil `BudgetScreen`).

**Mockup:** entri "Detail Anggaran".

#### Tabel preservasi

| # | Kode lama (`budget_detail_screen.dart`) | Perilaku | Di layout baru |
|---|---|---|---|
| 1 | :41-62 `_fetchWallets` (select wallets user; nama; warna dari `color` hex, default `#1E3A8A`; error → debugPrint) | | `budgetDetailProvider` fungsi `wallets()` — query & fallback sama |
| 2 | :64-110 `_fetchTransactions` (transactions bulan budget, `order date desc`, skip `[SAVING_ID:`, filter `category_id == budget.categoryId`, jumlahkan `spent`; error → kosong) | | `budgetDetailProvider` fungsi `transactions()` — sama persis |
| 3 | :34-38 dua fetch dipanggil tanpa `await` di `initState` | paralel | `(wallets(), transactions()).wait` |
| 4 | :304-308 `currentBudget` = versi terkini dari `budgetProvider` (fallback `widget.budget`) | edit limit langsung tampil | Sama persis |
| 5 | :315-322 `progress`, `isOver`, warna (redAccent / orange >0.8 / tealAccent), `sisa` | | `BudgetScreen.statusColor(progress)` (expense / tintOrange / primary) |
| 6 | :327-349 AppBar judul `category?.name ?? "Detail Anggaran"`, back, aksi pensil ungu → `_showEditSheet` | | `AppPageScaffold(title: …, backLabel: 'Anggaran', actions: [AppNavAction.text('Edit', …)])` |
| 7 | :351-352 spinner saat `_isLoading` | | spinner saat `AsyncValue.isLoading` |
| 8 | :386-427 hero "Terpakai" + total, "Limit Anggaran" + limit | | Kartu putih: `AppProgressRing` (persen di tengah) + kolom "Terpakai" / "Limit Anggaran" |
| 9 | :441-471 "Sisa Anggaran:" / "Over Budget:" + nominal `abs()` (teal / merah) | | `AppChip(label: 'Sisa Anggaran: Rp …' / 'Over Budget: Rp …', color: income / expense)` |
| 10 | :483 judul "Riwayat Pengeluaran" | | `AppGroupedSection(header: 'Riwayat Pengeluaran')` |
| 11 | :494-511 empty: ikon receipt, "Belum ada transaksi di kategori ini" | | `AppEmptyState(icon: PhosphorIconsRegular.receipt, title: 'Belum ada transaksi di kategori ini')` |
| 12 | :520-529 baris: note atau "Tanpa catatan", tanggal `DateFormat('dd MMM yyyy')`, badge dompet (`walletNames[id] ?? 'Kas Utama'`, warna dompet `?? Colors.grey`), nominal merah | | `AppListRow`: tile receipt primary, judul catatan, subtitle tanggal + `AppChip` dompet (fallback warna `AppColors.tintGray`), trailing nominal `-Rp …` merah |
| 13 | :113-295 sheet "Edit Anggaran": subjudul "Ubah limit untuk kategori ${name}", label "Batas Maksimal (Limit)", tombol "Simpan Perubahan"; `if (text.isEmpty) return;` → `updateBudgetAmount` → pop → toast "Limit berhasil diperbarui!"; catch → "Gagal update limit" | | `showAppFormSheet(title: 'Edit Anggaran')` dengan isi & logika yang sama |

- [ ] **Step 1: Tulis test gagal**

`test/screens/budget/budget_detail_screen_test.dart`:
```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_detail_screen.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeBudgetNotifier extends BudgetNotifier {
  _FakeBudgetNotifier(this._initial);
  final BudgetState _initial;
  @override
  BudgetState build() => _initial;
}

final _food = CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'tag');
final _budget = BudgetModel(id: 10, categoryId: 1, amount: 1500000, month: 9, year: 2026, category: _food);
const BudgetDetailKey _key = (categoryId: 1, month: 9, year: 2026);

Future<void> _pump(WidgetTester tester, BudgetDetailData data) async {
  await pumpApp(
    tester,
    BudgetDetailScreen(budget: _budget),
    overrides: [
      budgetProvider.overrideWith(
        () => _FakeBudgetNotifier(BudgetState(isLoading: false, budgets: [_budget])),
      ),
      budgetDetailProvider(_key).overrideWith((ref) async => data),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan ring, ringkasan, chip sisa, dan riwayat', (tester) async {
    await _pump(
      tester,
      BudgetDetailData(
        transactions: [
          {'id': 1, 'amount': 45000, 'note': 'Nasi Padang', 'date': '2026-09-24', 'category_id': 1, 'wallet_id': 7},
          {'id': 2, 'amount': 120000, 'note': '', 'date': '2026-09-22', 'category_id': 1, 'wallet_id': null},
        ],
        totalSpent: 1230000,
        walletNames: {7: 'BCA'},
        walletColors: {7: const Color(0xFF4A6CF7)},
      ),
    );

    expect(find.text('Makan'), findsWidgets);
    expect(find.text('Terpakai'), findsOneWidget);
    expect(find.text('Limit Anggaran'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.textContaining('Sisa Anggaran:'), findsOneWidget);
    expect(find.text('Riwayat Pengeluaran'.toUpperCase()), findsOneWidget);
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('Tanpa catatan'), findsOneWidget);
    expect(find.text('Kas Utama'), findsOneWidget);
    expect(find.byType(AppNavAction), findsOneWidget);
  });

  testWidgets('over budget menampilkan chip "Over Budget:" merah (Review Focus #4)', (tester) async {
    await _pump(tester, const BudgetDetailData(totalSpent: 1700000));

    expect(find.text('113%'), findsOneWidget);
    final chip = tester.widget<AppChip>(find.byWidgetPredicate((w) => w is AppChip && w.label.startsWith('Over Budget:')));
    expect(chip.color, AppColors.expense);
  });

  testWidgets('tanpa transaksi menampilkan empty state', (tester) async {
    await _pump(tester, const BudgetDetailData());
    expect(find.text('Belum ada transaksi di kategori ini'), findsOneWidget);
  });

  testWidgets('tombol Edit membuka sheet "Edit Anggaran"', (tester) async {
    await _pump(tester, const BudgetDetailData());
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Anggaran'), findsOneWidget);
    expect(find.text('Ubah limit untuk kategori Makan'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });
}
```
Catatan: bila `AppGroupedSection` B1 menulis header persis seperti input (bukan uppercase), ganti `'Riwayat Pengeluaran'.toUpperCase()` dengan `'Riwayat Pengeluaran'`. Periksa dengan `grep -n "toUpperCase" lib/widgets/app_grouped_section.dart`.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/budget/budget_detail_screen_test.dart`
Expected: FAIL — `Undefined name 'budgetDetailProvider'` / `BudgetDetailKey`.

- [ ] **Step 3: Tambah seam di akhir `lib/providers/budget_provider.dart`**

Tambahkan import di atas file: `import 'dart:ui' show Color;`. Lalu tempel di akhir file (setelah deklarasi `budgetProvider`):
```dart
/// Kunci [budgetDetailProvider]: kategori + bulan + tahun anggaran yang dibuka.
/// Record punya equality berbasis nilai, jadi layar yang sama memakai
/// instance provider yang sama.
typedef BudgetDetailKey = ({int categoryId, int month, int year});

/// Data layar Detail Anggaran. Dipindahkan dari `_BudgetDetailScreenState`
/// (_fetchWallets & _fetchTransactions) tanpa mengubah query/filter, supaya
/// layar itu bisa dites dengan override provider.
class BudgetDetailData {
  const BudgetDetailData({
    this.transactions = const [],
    this.totalSpent = 0,
    this.walletNames = const {},
    this.walletColors = const {},
  });

  final List<Map<String, dynamic>> transactions;
  final double totalSpent;
  final Map<int, String> walletNames;
  final Map<int, Color> walletColors;
}

final budgetDetailProvider =
    FutureProvider.autoDispose.family<BudgetDetailData, BudgetDetailKey>((ref, key) async {
  final supabase = Supabase.instance.client;

  Future<(Map<int, String>, Map<int, Color>)> wallets() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final res = await supabase.from('wallets').select().eq('user_id', userId);
      final names = <int, String>{};
      final colors = <int, Color>{};
      for (var w in res as List) {
        names[w['id']] = w['name'].toString();
        final colorHex = w['color']?.toString() ?? '#1E3A8A';
        colors[w['id']] = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      }
      return (names, colors);
    } catch (e) {
      debugPrint("Error wallets: $e");
      return (<int, String>{}, <int, Color>{});
    }
  }

  Future<(List<Map<String, dynamic>>, double)> transactions() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final startMonth = DateFormat('yyyy-MM-01').format(DateTime(key.year, key.month));
      final nextMonth = DateFormat('yyyy-MM-01').format(DateTime(key.year, key.month + 1));

      final res = await supabase
          .from('transactions')
          .select('id, amount, note, date, category_id, wallet_id')
          .eq('user_id', userId)
          .gte('date', startMonth)
          .lt('date', nextMonth)
          .order('date', ascending: false);

      double spent = 0;
      final List<Map<String, dynamic>> filteredData = [];
      for (var item in res) {
        final catId = item['category_id'] as int;
        final noteStr = item['note']?.toString() ?? '';
        if (noteStr.contains('[SAVING_ID:')) continue;
        if (catId == key.categoryId) {
          spent += (item['amount'] as num).toDouble();
          filteredData.add(item);
        }
      }
      return (filteredData, spent);
    } catch (e) {
      return (<Map<String, dynamic>>[], 0.0);
    }
  }

  // Dulu kedua fetch dipanggil dari initState tanpa saling menunggu —
  // tetap paralel di sini.
  final (walletData, trxData) = await (wallets(), transactions()).wait;
  return BudgetDetailData(
    transactions: trxData.$1,
    totalSpent: trxData.$2,
    walletNames: walletData.$1,
    walletColors: walletData.$2,
  );
});
```
Catatan: bila Plan B2 sudah menambah pengecualian `[DEBT_ID:` di filter anggaran (`grep -n "DEBT_ID" lib/providers/budget_provider.dart`), tambahkan pengecualian yang sama di loop `transactions()` di atas supaya Detail konsisten dengan daftar Anggaran.

- [ ] **Step 4: Tulis ulang `lib/screens/budget/budget_detail_screen.dart`**

Ganti seluruh isi file dengan:
```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BudgetDetailScreen extends ConsumerWidget {
  final BudgetModel budget;

  const BudgetDetailScreen({super.key, required this.budget});

  void _showEditSheet(BuildContext context, WidgetRef ref, BudgetModel currentBudget) {
    final amountController = TextEditingController(
      text: NumberFormat.decimalPattern('id_ID').format(currentBudget.amount.round()),
    );

    showAppFormSheet<void>(
      context: context,
      title: 'Edit Anggaran',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Ubah limit untuk kategori ${currentBudget.category?.name}",
            style: AppTextStyles.subhead,
          ),
          const SizedBox(height: 14),
          AppSurfaceCard(
            child: AppAmountField(
              controller: amountController,
              label: 'Batas Maksimal (Limit)',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'Simpan Perubahan',
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              final cleanAmount = parseRupiah(amountController.text).toDouble();
              try {
                await ref.read(budgetProvider.notifier).updateBudgetAmount(currentBudget.id, cleanAmount);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) AppNotification.success(context, "Limit berhasil diperbarui!");
              } catch (e) {
                if (context.mounted) AppNotification.error(context, "Gagal update limit");
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Versi terkini dari budgetProvider supaya edit limit langsung tampil;
    // fallback ke budget awal bila item sudah tidak ada di state.
    final budgetState = ref.watch(budgetProvider);
    final currentBudget = budgetState.budgets.firstWhere(
      (b) => b.id == budget.id,
      orElse: () => budget,
    );

    final detailAsync = ref.watch(
      budgetDetailProvider((categoryId: budget.categoryId, month: budget.month, year: budget.year)),
    );
    final detail = detailAsync.valueOrNull ?? const BudgetDetailData();
    final totalSpent = detail.totalSpent;

    final progress = currentBudget.amount == 0 ? 0.0 : totalSpent / currentBudget.amount;
    final color = BudgetScreen.statusColor(progress);
    final sisa = currentBudget.amount - totalSpent;

    return AppPageScaffold(
      title: currentBudget.category?.name ?? "Detail Anggaran",
      backLabel: 'Anggaran',
      actions: [
        AppNavAction.text('Edit', onPressed: () => _showEditSheet(context, ref, currentBudget)),
      ],
      children: detailAsync.isLoading
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ]
          : [
              AppSurfaceCard(
                child: Row(
                  children: [
                    AppProgressRing(
                      value: progress,
                      color: color,
                      center: Text('${(progress * 100).round()}%', style: AppTextStyles.title),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terpakai', style: AppTextStyles.caption),
                          Text(formatRupiah(totalSpent), style: AppTextStyles.headline),
                          const SizedBox(height: 8),
                          Text('Limit Anggaran', style: AppTextStyles.caption),
                          Text(formatRupiah(currentBudget.amount), style: AppTextStyles.headline),
                          const SizedBox(height: 10),
                          AppChip(
                            label: "${sisa >= 0 ? "Sisa Anggaran:" : "Over Budget:"} ${formatRupiah(sisa.abs())}",
                            color: sisa >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.transactions.isEmpty)
                const AppEmptyState(
                  icon: PhosphorIconsRegular.receipt,
                  title: 'Belum ada transaksi di kategori ini',
                )
              else
                AppGroupedSection(
                  header: 'Riwayat Pengeluaran',
                  children: [
                    for (final trx in detail.transactions)
                      Builder(
                        builder: (context) {
                          final rawNote = trx['note']?.toString() ?? '';
                          final cleanNote = rawNote.isNotEmpty ? rawNote : "Tanpa catatan";
                          final wId = trx['wallet_id'];
                          final wName = detail.walletNames[wId] ?? 'Kas Utama';
                          final wColor = detail.walletColors[wId] ?? AppColors.tintGray;
                          return AppListRow(
                            leading: const AppIconTile(icon: PhosphorIconsFill.receipt, color: AppColors.primary),
                            title: cleanNote,
                            subtitleWidget: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(DateTime.parse(trx['date'])),
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: AppChip(label: wName, color: wColor, icon: PhosphorIconsFill.wallet),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              formatRupiahSigned(trx['amount'] as num, isIncome: false),
                              style: AppTextStyles.amountRow.copyWith(color: AppColors.expense),
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
    );
  }
}
```

- [ ] **Step 5: Jalankan test** — `flutter test test/screens/budget/` → PASS (Task 2 + Task 3).

- [ ] **Step 6: Poppins, hex, Supabase langsung**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/budget/budget_detail_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|tealAccent|redAccent)|Supabase" lib/screens/budget/budget_detail_screen.dart
```
Expected: `0` dan tidak ada baris (termasuk tidak ada lagi referensi `Supabase` di screen).

- [ ] **Step 7: Analyze** — `flutter analyze lib/screens/budget lib/providers/budget_provider.dart` → 0 error/warning baru.

- [ ] **Step 8: Checklist visual (vs mockup "Detail Anggaran")**
- [ ] Nav: `‹ Anggaran` kiri, teks "Edit" kanan (biru). Judul besar = nama kategori.
- [ ] Kartu putih: ring progress kiri (warna status, persen tebal di tengah), kanan "Terpakai" + angka, "Limit Anggaran" + angka, chip hijau "Sisa Anggaran: Rp …" (merah "Over Budget: Rp …" bila lewat).
- [ ] Label grup "RIWAYAT PENGELUARAN", list putih: tile receipt biru, catatan tebal, tanggal + chip dompet berwarna, nominal "-Rp …" merah di kanan.
- [ ] Tidak ada gradasi ungu.
- [ ] "Edit" → sheet "Batal · Edit Anggaran", subjudul "Ubah limit untuk kategori …", nominal besar terisi limit lama, tombol "Simpan Perubahan".

- [ ] **Step 9: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/providers/budget_provider.dart lib/screens/budget/budget_detail_screen.dart test/screens/budget/budget_detail_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(budget): redesign budget detail with progress ring and testable data provider

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: Target Keuangan (`TargetScreen`) + sheet "Target Baru", "Edit Target", "Nabung: …"

**Files:**
- Modify (tulis ulang): `lib/screens/target/target_screen.dart`
- Test: `test/screens/target/target_screen_test.dart`

**Interfaces:**
- Consumes: `targetProvider`, `TargetState`, `TargetNotifier` (`addTarget`, `editTarget`, `depositToTarget`, `deleteTarget`) — tidak berubah. `TargetModel`. `AppSelectRow`, `AppTextField(focusNode:)` (Task 1). Komponen B1.
- Produces: `TargetScreen` (const) — API tidak berubah.

**Mockup:** entri "Target Keuangan".

#### Tabel preservasi

| # | Kode lama (`target_screen.dart`) | Perilaku | Di layout baru |
|---|---|---|---|
| 1 | :22-48 `_getRecommendation` (tercapai / tanpa deadline / lewat / <60 hari per hari / per bulan) | teks rekomendasi | Sama persis; `NumberFormat.currency('Rp ')` diganti `formatRupiah` (output sama "Rp 84.000") |
| 2 | :50-412 sheet "Target Baru": "Nama Target" (hint "Misal: Beli iPhone 15", ikon target), "Target Dana" (Rp), "Lokasi Penyimpanan Sementara" (autocomplete `savingNames`, hint "Pilih / Ketik Nama Tabungan", ikon link), "Tenggat Waktu (Opsional)" (picker firstDate now, lastDate 2030, "Pilih Tanggal" / `dd MMMM yyyy id_ID`), tombol "Simpan Target" | `if (nama kosong \|\| target kosong) return;` → `addTarget(storageLocation: text kosong → null)` → pop + toast "Target berhasil dibuat!"; catch → debugPrint | `showAppFormSheet(title: 'Target Baru')` dengan field & logika sama; autocomplete memakai `RawAutocomplete` dengan controller + focusNode eksternal (menggantikan listener yang dulu ditambahkan ulang setiap rebuild) |
| 3 | :414-892 sheet "Edit Target": "Nama Target", "Target Dana" + "Terkumpul" (Rp, terisi), "Lokasi Penyimpanan" (autocomplete, terisi), "Tenggat Waktu" (picker initialDate `selectedDate ?? now`, firstDate now), tombol "Simpan Perubahan" | `if (nama kosong \|\| target kosong) return;` → `editTarget(...)` → pop + toast "Target berhasil diupdate!" | `showAppFormSheet(title: 'Edit Target')`, dua `AppAmountField` (Target Dana, Terkumpul). **[LOGIKA]** `initialDate` dijepit ke hari ini bila deadline sudah lewat (Review Focus #1) |
| 4 | :894-1169 sheet "Nabung: ${name}": info hijau "Disimpan di: …" / "Lokasi penyimpanan belum ditentukan.", "Tarik Dana Dari Dompet Mana?" (default dompet pertama; hint "Belum ada dompet"/"Pilih Dompet"; item "Nama (Sisa: Rp …)"), "Mau nabung berapa hari ini?" (Rp), tombol hijau "Setor Tabungan" | `if (nominal kosong \|\| dompet null) return;` → `depositToTarget` → pesan error dari provider → toast error & tetap di sheet; sukses → pop + toast "Berhasil nabung Rp ${text}!"; catch → debugPrint | `showAppFormSheet(title: 'Nabung: ${name}')`: `AppCallout(info)`, `AppSelectRow` dompet, `AppAmountField(color: income)`, `AppPrimaryButton(color: income)`; logika & teks sama |
| 5 | :1171-1202 dialog "Hapus Target?" / "Anda yakin ingin menghapus target '$name'? Saldo di target ini akan hilang (Catatan: Saldo dompet Anda TIDAK akan dikembalikan otomatis karena ini dihapus paksa)." | Hapus → `deleteTarget(id)` → toast "Target dihapus" | `showAppConfirmDialog` dengan teks sama |
| 6 | :1219-1233 AppBar "Target Keuangan" + back | | `AppPageScaffold(title: 'Target Keuangan', backLabel: 'Beranda')` |
| 7 | :1237-1282 header "Total Semua Target" + total (teal) + ikon target | | `AppSurfaceCard`: label + angka `AppColors.primary` + `AppIconTile(target, round)` |
| 8 | :1285-1304 loading spinner; empty ikon target + "Belum ada target" | | spinner; `AppEmptyState(icon: PhosphorIconsFill.target, title: 'Belum ada target')` |
| 9 | :1311-1316 `progress`, `percent = clamp 0..100`, `remaining`, rekomendasi | | Sama |
| 10 | :1344-1398 nama; lokasi (ikon wallet) bila ada; "Deadline: dd MMM yyyy" bila ada | | Sama, warna abu `AppColors.textSecondary` |
| 11 | :1405-1427 tombol edit (→ `_showEditSheet(item)`) & hapus (→ `_confirmDelete(item.id, item.name)`) | | `AppNavAction.icon` pensil & sampah abu di kanan atas kartu |
| 12 | :1448-1476 progress hijau tinggi 12 + "Rp saved / Rp target" + "percent%" hijau | | `AppProgressBar(color: income)` + baris teks sama |
| 13 | :1479-1511 kotak oranye lampu + rekomendasi, hanya bila `remaining > 0 && deadline != null` | | `AppCallout(icon: lightbulb, tone: accent)` dengan kondisi sama |
| 14 | :1516-1549 "Tercapai! 🎉" / "Kurang Rp …" + tombol "Nabung" (disabled bila `remaining <= 0`) → `_showDepositSheet(item)` | | Teks sama; `AppPillButton(label: 'Nabung', filled: true, onPressed: null bila tercapai)` |
| 15 | :1562-1574 FAB "Buat Target" → `_showAddSheet` | | `AppNavAction.add(onPressed: _showAddSheet)` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/target/target_screen_test.dart`:
```dart
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/target_provider.dart';
import 'package:catat_uang_app/screens/target/target_screen.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeTargetNotifier extends TargetNotifier {
  _FakeTargetNotifier(this._initial);
  final TargetState _initial;
  @override
  TargetState build() => _initial;
}

TargetState _state({DateTime? pastDeadline}) => TargetState(
      isLoading: false,
      totalSavings: 7300000,
      savingNames: const ['Dana Darurat'],
      wallets: const [
        {'id': 1, 'name': 'BCA', 'balance': 9300000},
      ],
      targets: [
        TargetModel(
          id: 1,
          name: 'Beli iPhone 15',
          targetAmount: 15000000,
          savedAmount: 6750000,
          deadline: pastDeadline ?? DateTime.now().add(const Duration(days: 30)),
          storageLocation: 'Dana Darurat',
        ),
        TargetModel(id: 2, name: 'Liburan Bali', targetAmount: 550000, savedAmount: 550000),
      ],
    );

Future<void> _pump(WidgetTester tester, TargetState state) async {
  await pumpApp(
    tester,
    const TargetScreen(),
    overrides: [targetProvider.overrideWith(() => _FakeTargetNotifier(state))],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan ringkasan, kartu target, rekomendasi, dan tombol +', (tester) async {
    await _pump(tester, _state());

    expect(find.text('Target Keuangan'), findsWidgets);
    expect(find.text('Total Semua Target'), findsOneWidget);
    expect(find.text('Beli iPhone 15'), findsOneWidget);
    expect(find.text('Dana Darurat'), findsOneWidget);
    expect(find.textContaining('/ hari agar tercapai.'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('Tercapai! 🎉'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tombol Nabung nonaktif untuk target yang sudah tercapai', (tester) async {
    await _pump(tester, _state());

    final buttons = tester.widgetList<AppPillButton>(
      find.byWidgetPredicate((w) => w is AppPillButton && w.label == 'Nabung'),
    ).toList();
    expect(buttons, hasLength(2));
    expect(buttons.where((b) => b.onPressed == null), hasLength(1));
  });

  testWidgets('tombol + membuka sheet "Target Baru"', (tester) async {
    await _pump(tester, _state());
    await tester.tap(find.byWidgetPredicate((w) => w is AppNavAction).last);
    await tester.pumpAndSettle();

    expect(find.text('Target Baru'), findsOneWidget);
    expect(find.text('Misal: Beli iPhone 15'), findsOneWidget);
    expect(find.text('Pilih / Ketik Nama Tabungan'), findsOneWidget);
    expect(find.text('Tenggat Waktu (Opsional)'), findsOneWidget);
    expect(find.text('Simpan Target'), findsOneWidget);
  });

  testWidgets('Edit Target dengan deadline lewat tidak crash saat buka date picker (Review Focus #1)', (tester) async {
    await _pump(tester, _state(pastDeadline: DateTime.now().subtract(const Duration(days: 10))));

    await tester.tap(find.byIcon(PhosphorIconsRegular.pencilSimple).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Target'), findsOneWidget);

    await tester.tap(find.text('Tenggat Waktu'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Pemilih tanggal bersama (Plan B3b), bukan DatePickerDialog Material.
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Pilih Tanggal'), findsOneWidget);
  });

  testWidgets('Nabung membuka sheet dengan info lokasi dan dompet default', (tester) async {
    await _pump(tester, _state());
    await tester.tap(find.byWidgetPredicate((w) => w is AppPillButton && w.label == 'Nabung' && w.onPressed != null));
    await tester.pumpAndSettle();

    expect(find.text('Nabung: Beli iPhone 15'), findsOneWidget);
    expect(find.text('Disimpan di: Dana Darurat'), findsOneWidget);
    expect(find.textContaining('BCA (Sisa:'), findsOneWidget);
    expect(find.text('Setor Tabungan'), findsOneWidget);
  });
}
```
Catatan: tombol `+` dicari lewat `.last` karena `AppNavAction.icon` di kartu juga bertipe `AppNavAction`; bila B1 mengimplementasikan varian sebagai subclass berbeda, pakai `find.byTooltip`/ikon plus yang dipakai B1 (lihat `lib/widgets/app_page_scaffold.dart`).

- [ ] **Step 2: Jalankan, pastikan gagal** — `flutter test test/screens/target/target_screen_test.dart` → FAIL (FAB masih ada, `AppPillButton` tidak ditemukan, dst.).

- [ ] **Step 3: Tulis ulang `lib/screens/target/target_screen.dart`**

Ganti seluruh isi file dengan:
```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/target_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: AppTextStyles.groupLabel),
    );

String _plainAmount(num value) => NumberFormat.decimalPattern('id_ID').format(value.round());

class TargetScreen extends ConsumerStatefulWidget {
  const TargetScreen({super.key});

  @override
  ConsumerState<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends ConsumerState<TargetScreen> {
  String _getRecommendation(TargetModel target) {
    if (target.savedAmount >= target.targetAmount) return "Target tercapai! Mantap! 🎉";
    if (target.deadline == null) return "Set deadline agar dapat rekomendasi nabung.";

    final now = DateTime.now();
    final difference = target.deadline!.difference(now).inDays;
    final remainingAmount = target.targetAmount - target.savedAmount;

    if (difference <= 0) return "Deadline sudah terlewat!";

    if (difference < 60) {
      final double dailySave = remainingAmount / difference;
      return "Nabung ${formatRupiah(dailySave)} / hari agar tercapai.";
    } else {
      final double months = difference / 30;
      final double monthlySave = remainingAmount / months;
      return "Nabung ${formatRupiah(monthlySave)} / bulan agar tercapai.";
    }
  }

  /// Field lokasi dengan saran nama tabungan. Controller & focusNode eksternal
  /// supaya teks langsung tersimpan di [controller] tanpa listener tambahan.
  Widget _locationField(TextEditingController controller, FocusNode focusNode, List<String> savingNames) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return savingNames;
        return savingNames.where(
          (option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selection) => controller.text = selection,
      fieldViewBuilder: (context, textController, fieldFocus, onFieldSubmitted) => AppTextField(
        controller: textController,
        focusNode: fieldFocus,
        hint: "Pilih / Ketik Nama Tabungan",
        icon: PhosphorIconsFill.link,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: AppColors.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options) AppListRow(title: option, onTap: () => onSelected(option)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSheet() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final locationController = TextEditingController();
    final locationFocus = FocusNode();
    DateTime? selectedDate;

    showAppFormSheet<void>(
      context: context,
      title: 'Target Baru',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final savingNames = ref.read(targetProvider).savingNames;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel("Nama Target"),
              AppTextField(controller: nameController, hint: "Misal: Beli iPhone 15", icon: PhosphorIconsFill.target),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(controller: targetController, label: "Target Dana", color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              _fieldLabel("Lokasi Penyimpanan Sementara"),
              _locationField(locationController, locationFocus, savingNames),
              const SizedBox(height: 14),
              AppGroupedSection(
                children: [
                  AppListRow(
                    leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.primary),
                    title: "Tenggat Waktu (Opsional)",
                    value: selectedDate == null
                        ? "Pilih Tanggal"
                        : DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate!),
                    showChevron: true,
                    onTap: () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: "Simpan Target",
                onPressed: () async {
                  if (nameController.text.isEmpty || targetController.text.isEmpty) return;
                  try {
                    await ref.read(targetProvider.notifier).addTarget(
                          name: nameController.text,
                          targetAmount: parseRupiah(targetController.text).toDouble(),
                          storageLocation: locationController.text.isNotEmpty ? locationController.text : null,
                          deadline: selectedDate,
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.success(context, "Target berhasil dibuat!");
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSheet(TargetModel target) {
    final nameController = TextEditingController(text: target.name);
    final targetController = TextEditingController(text: _plainAmount(target.targetAmount));
    final savedController = TextEditingController(text: _plainAmount(target.savedAmount));
    final locationController = TextEditingController(text: target.storageLocation ?? "");
    final locationFocus = FocusNode();
    DateTime? selectedDate = target.deadline;

    showAppFormSheet<void>(
      context: context,
      title: 'Edit Target',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final savingNames = ref.read(targetProvider).savingNames;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel("Nama Target"),
              AppTextField(controller: nameController),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(controller: targetController, label: "Target Dana", color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              AppSurfaceCard(
                child: AppAmountField(controller: savedController, label: "Terkumpul", color: AppColors.income),
              ),
              const SizedBox(height: 14),
              _fieldLabel("Lokasi Penyimpanan"),
              _locationField(locationController, locationFocus, savingNames),
              const SizedBox(height: 14),
              AppGroupedSection(
                children: [
                  AppListRow(
                    leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.primary),
                    title: "Tenggat Waktu",
                    value: selectedDate == null
                        ? "Pilih Tanggal"
                        : DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate!),
                    showChevron: true,
                    onTap: () async {
                      final now = DateTime.now();
                      // [LOGIKA] Deadline lama bisa sudah lewat; initialDate tidak
                      // boleh sebelum firstDate (showAppDatePicker juga menjepit, tapi nilai tampilan tetap dijaga di sini).
                      final initial = (selectedDate != null && selectedDate!.isAfter(now)) ? selectedDate! : now;
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: now,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: "Simpan Perubahan",
                onPressed: () async {
                  if (nameController.text.isEmpty || targetController.text.isEmpty) return;
                  try {
                    await ref.read(targetProvider.notifier).editTarget(
                          id: target.id,
                          name: nameController.text,
                          targetAmount: parseRupiah(targetController.text).toDouble(),
                          savedAmount: parseRupiah(savedController.text).toDouble(),
                          storageLocation: locationController.text.isNotEmpty ? locationController.text : null,
                          deadline: selectedDate,
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.success(context, "Target berhasil diupdate!");
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDepositSheet(TargetModel target) {
    final amountController = TextEditingController();
    final wallets = ref.read(targetProvider).wallets;
    int? selectedWalletId = wallets.isNotEmpty ? wallets.first['id'] as int : null;

    showAppFormSheet<void>(
      context: context,
      title: "Nabung: ${target.name}",
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                target.storageLocation != null
                    ? "Disimpan di: ${target.storageLocation}"
                    : "Lokasi penyimpanan belum ditentukan.",
                style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 14),
            AppGroupedSection(
              header: "Tarik Dana Dari Dompet Mana?",
              children: [
                AppSelectRow<int>(
                  leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                  title: "Dompet",
                  placeholder: wallets.isEmpty ? "Belum ada dompet" : "Pilih Dompet",
                  value: selectedWalletId,
                  options: [
                    for (final w in wallets)
                      AppSelectOption(w['id'] as int, "${w['name']} (Sisa: ${formatRupiah(w['balance'] as num)})"),
                  ],
                  onChanged: (val) => setSheetState(() => selectedWalletId = val),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              child: AppAmountField(
                controller: amountController,
                label: "Mau nabung berapa hari ini?",
                color: AppColors.income,
              ),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: "Setor Tabungan",
              color: AppColors.income,
              onPressed: () async {
                if (amountController.text.isEmpty || selectedWalletId == null) return;
                try {
                  final rawAmount = parseRupiah(amountController.text).toDouble();
                  final result = await ref.read(targetProvider.notifier).depositToTarget(
                        target: target,
                        rawAmount: rawAmount,
                        walletId: selectedWalletId!,
                      );
                  if (result != null) {
                    if (context.mounted) AppNotification.error(context, result);
                    return;
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppNotification.success(context, "Berhasil nabung Rp ${amountController.text}!");
                  }
                } catch (e) {
                  debugPrint(e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int id, String name) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Target?",
      message:
          "Anda yakin ingin menghapus target '$name'? Saldo di target ini akan hilang (Catatan: Saldo dompet Anda TIDAK akan dikembalikan otomatis karena ini dihapus paksa).",
    );
    if (!confirmed || !mounted) return;
    await ref.read(targetProvider.notifier).deleteTarget(id);
    if (mounted) AppNotification.success(context, "Target dihapus");
  }

  Widget _buildTargetCard(TargetModel item) {
    final progress = item.targetAmount == 0 ? 0.0 : item.savedAmount / item.targetAmount;
    final percent = (progress * 100).clamp(0, 100).toInt();
    final remaining = item.targetAmount - item.savedAmount;
    final recommendation = _getRecommendation(item);

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (item.storageLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsFill.wallet, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                item.storageLocation!,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (item.deadline != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsRegular.calendarBlank, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              "Deadline: ${DateFormat('dd MMM yyyy').format(item.deadline!)}",
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              AppNavAction.icon(
                PhosphorIconsRegular.pencilSimple,
                color: AppColors.textSecondary,
                onPressed: () => _showEditSheet(item),
              ),
              AppNavAction.icon(
                PhosphorIconsRegular.trash,
                color: AppColors.textSecondary,
                onPressed: () => _confirmDelete(item.id, item.name),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(value: progress, color: AppColors.income),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "${formatRupiah(item.savedAmount)} / ${formatRupiah(item.targetAmount)}",
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              Text("$percent%", style: AppTextStyles.bodyStrong.copyWith(color: AppColors.income)),
            ],
          ),
          if (remaining > 0 && item.deadline != null) ...[
            const SizedBox(height: 12),
            AppCallout(
              icon: PhosphorIconsFill.lightbulb,
              tone: AppCalloutTone.accent,
              child: Text(recommendation, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  remaining <= 0 ? "Tercapai! 🎉" : "Kurang ${formatRupiah(remaining)}",
                  style: remaining <= 0
                      ? AppTextStyles.bodyStrong.copyWith(color: AppColors.income)
                      : AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              AppPillButton(
                label: "Nabung",
                icon: PhosphorIconsBold.plus,
                filled: true,
                onPressed: remaining <= 0 ? null : () => _showDepositSheet(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetState = ref.watch(targetProvider);
    final isLoading = targetState.isLoading;
    final targets = targetState.targets;
    final totalSavings = targetState.totalSavings;

    return AppPageScaffold(
      title: 'Target Keuangan',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: _showAddSheet)],
      children: [
        AppSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Semua Target", style: AppTextStyles.subhead),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(totalSavings),
                      style: AppTextStyles.title.copyWith(fontSize: 26, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const AppIconTile(icon: PhosphorIconsFill.target, color: AppColors.primary, round: true, size: 52),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (targets.isEmpty)
          const AppEmptyState(icon: PhosphorIconsFill.target, title: "Belum ada target")
        else
          for (final item in targets) _buildTargetCard(item),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test** — `flutter test test/screens/target/target_screen_test.dart` → PASS (5 test). Bila `AppPillButton.onPressed` di B1 bertipe non-nullable, ubah field-nya menjadi `VoidCallback?` (disabled saat null, warna 45% opacity) di `lib/widgets/app_buttons.dart` beserta test B1-nya, dan catat di laporan.

- [ ] **Step 5: Poppins & hex**

```bash
grep -c "GoogleFonts.poppins" lib/screens/target/target_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|blueGrey)" lib/screens/target/target_screen.dart
```
Expected: `0` dan tidak ada baris. Pastikan juga import `app_button.dart` (AppButton lama) sudah tidak ada: `grep -n "app_button.dart" lib/screens/target/target_screen.dart` → kosong.

- [ ] **Step 6: Analyze** — `flutter analyze lib/screens/target` → 0 error/warning baru.

- [ ] **Step 7: Checklist visual (vs mockup "Target Keuangan")**
- [ ] Nav `‹ Beranda` + `+`, judul besar "Target Keuangan", tidak ada FAB teal.
- [ ] Kartu putih ringkasan: "Total Semua Target" abu + angka biru besar, tile target bulat biru di kanan.
- [ ] Kartu target: nama tebal, baris lokasi (ikon dompet) dan "Deadline: …" abu, pensil & sampah abu di kanan atas.
- [ ] Progress hijau, "Rp x / Rp y" tebal + persen hijau.
- [ ] Catatan rekomendasi berlatar krem (aksen) dengan ikon lampu — hanya bila belum tercapai & ada deadline.
- [ ] Baris bawah: "Kurang Rp …" miring abu (atau "Tercapai! 🎉" hijau) + pill biru "+ Nabung" (redup/nonaktif bila tercapai).
- [ ] Sheet "Target Baru" / "Edit Target" / "Nabung: …" memakai header "Batal · Judul", nominal besar di kartu putih, baris tanggal ›, tombol penuh di bawah.

- [ ] **Step 8: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/target/target_screen.dart test/screens/target/target_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(target): redesign target screen with iOS cards and form sheets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 5: Buku Tabungan (`SavingsScreen`) + sheet "Buat Tabungan", "Edit Tabungan", "Setor/Tarik"

**Files:**
- Modify (tulis ulang): `lib/screens/savings/savings_screen.dart`
- Test: `test/screens/savings/savings_screen_test.dart`

**Interfaces:**
- Consumes: `savingsProvider`, `SavingsState`, `SavingsNotifier` (`processSavingTransaction`, `addEmptyGroup`, `renameGroup`, `deleteGroup`) — tidak berubah. `SavingModel`, `SavingDetailScreen(savingName:)`. `AppSelectRow` (Task 1), komponen B1.
- Produces: `SavingsScreen` (const) — API tidak berubah.

**Mockup:** entri "Buku Tabungan".

#### Tabel preservasi

| # | Kode lama (`savings_screen.dart`) | Perilaku | Di layout baru |
|---|---|---|---|
| 1 | :23-432 sheet "Buat Tabungan": "Nama Tabungan" (hint "Contoh: Dana Darurat"), "Tempat Simpan (Opsional)" (hint "Contoh: Bank BCA"), "Catatan (Opsional)" (hint "Tulis catatan singkat..."), "Tarik Dari Dompet Mana?" (default dompet pertama; item "Nama (Sisa: 9.300.000)" tanpa "Rp"), "Setoran Awal (Opsional)" (Rp), tombol "Simpan Tabungan" | nama kosong → toast "Nama tabungan tidak boleh kosong!"; `amt > 0 && dompet null` → "Pilih dompet untuk setoran awal!"; `amt > 0` → `processSavingTransaction(isDeposit: true, …, location/notes trim)` → toast error/“Berhasil Menabung!”; selain itu `addEmptyGroup` → "Tabungan berhasil dibuat!"; lalu pop; catch → "Gagal membuat tabungan." | `showAppFormSheet(title: 'Buat Tabungan')` dengan field, urutan validasi, dan toast identik |
| 2 | :435-641 sheet "Edit Tabungan": "Nama Tabungan", "Tempat Simpan", "Catatan", tombol "Simpan Perubahan" | `if (nama kosong) return;` → `renameGroup(oldName, trim…)` → pop + "Berhasil diupdate!"; catch → "Gagal update tabungan." | `showAppFormSheet(title: 'Edit Tabungan')` identik |
| 3 | :643-674 dialog "Hapus Tabungan?" / "Anda yakin ingin menghapus '$groupName'? Semua riwayat di tabungan ini akan hilang (Saldo dompet TIDAK akan dikembalikan otomatis)." | → `deleteGroup` → toast "Tabungan dihapus" | `showAppConfirmDialog` teks sama |
| 4 | :677-910 sheet setor/tarik: judul "Setor ke $groupName" / "Tarik dari $groupName", label "Tarik dari Dompet" / "Simpan ke Dompet", "Nominal", tombol teal "Konfirmasi Setoran" / oranye "Konfirmasi Penarikan" | nominal kosong / dompet null → toast "Isi nominal dengan benar!"; `processSavingTransaction(...)` **tidak di-await**, `.then` toast error / "Berhasil Menabung!" / "Berhasil Dicairkan!", lalu `Navigator.pop` segera | Sama persis (fire-and-forget + pop); warna tombol `AppColors.primary` / `AppColors.tintOrange` |
| 5 | :927-942 AppBar "Buku Tabungan" + back | | `AppPageScaffold(title: 'Buku Tabungan', backLabel: 'Beranda')` |
| 6 | :945-1002 hero teal "Total Semua Tabungan" + total + ikon piggyBank | | `AppHeroCard` (gradasi biru) dengan isi sama |
| 7 | :1005-1027 spinner; empty ikon vault + "Belum ada tabungan" | | spinner; `AppEmptyState(icon: PhosphorIconsFill.vault, title: 'Belum ada tabungan')` |
| 8 | :1036-1044 per grup: `groupTotal` = jumlah `amount`, `loc`/`note` dari `items.last` | | Sama |
| 9 | :1062-1069 tap area atas kartu → `Navigator.push(SavingDetailScreen(savingName: groupName))` | | Sama (GestureDetector di baris atas kartu) |
| 10 | :1073-1132 tile vault teal, nama, total teal, lokasi (ikon bank) bila tidak kosong | | `AppIconTile(vault, primary)`, nama `maxLines: 1`, lokasi; total besar biru di bawah baris (sesuai mockup) |
| 11 | :1136-1179 edit (→ `_showEditSheet(groupName, loc, note)`) & hapus (→ `_confirmDelete(groupName)`) | | `AppNavAction.icon` pensil & sampah abu |
| 12 | :1187-1240 tombol "Setor" (downloadSimple) → `_showTransactionSheet(groupName, true)`; "Tarik" (uploadSimple) → `(…, false)` | | `AppPillButton` "Setor" (primary) & "Tarik" (`tintOrange`), ikon sama |
| 13 | :1249-1261 FAB "Buat Tabungan" (heroTag add_new_saving) → `_showAddTitleSheet()` | | `AppNavAction.add(onPressed: _showAddTitleSheet)` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/savings/savings_screen_test.dart`:
```dart
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/screens/savings/savings_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeSavingsNotifier extends SavingsNotifier {
  _FakeSavingsNotifier(this._initial);
  final SavingsState _initial;
  @override
  SavingsState build() => _initial;
}

SavingModel _saving(int id, String name, double amount, {String? location}) => SavingModel(
      id: id,
      userId: 'u1',
      name: name,
      amount: amount,
      location: location,
      createdAt: DateTime(2026, 9, 24, 9, 12),
    );

Future<void> _pump(WidgetTester tester, SavingsState state) async {
  await pumpApp(
    tester,
    const SavingsScreen(),
    overrides: [savingsProvider.overrideWith(() => _FakeSavingsNotifier(state))],
  );
  await tester.pumpAndSettle();
}

void main() {
  const longName = 'Tabungan Untuk Pernikahan Adik Bungsu Tahun Depan Di Gedung Serbaguna';

  SavingsState filled() => SavingsState(
        isLoading: false,
        totalSavings: 24500000,
        wallets: const [
          {'id': 1, 'name': 'BCA', 'balance': 9300000},
        ],
        groupedSavings: {
          'Dana Darurat': [_saving(1, 'Dana Darurat', 18000000, location: 'Bank BCA')],
          longName: [_saving(2, longName, 6500000)],
        },
      );

  testWidgets('menampilkan hero, kartu tabungan, tombol Setor/Tarik, dan +', (tester) async {
    await _pump(tester, filled());

    expect(find.text('Buku Tabungan'), findsWidgets);
    expect(find.text('Total Semua Tabungan'), findsOneWidget);
    expect(find.text('Dana Darurat'), findsOneWidget);
    expect(find.text('Bank BCA'), findsOneWidget);
    expect(find.text('Setor'), findsNWidgets(2));
    expect(find.text('Tarik'), findsNWidgets(2));
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('nama tabungan sangat panjang tidak overflow (Review Focus #3)', (tester) async {
    await _pump(tester, filled());
    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, const SavingsState(isLoading: false));
    expect(find.text('Belum ada tabungan'), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet "Buat Tabungan" dengan field lengkap', (tester) async {
    await _pump(tester, filled());
    await tester.tap(find.byWidgetPredicate((w) => w is AppNavAction).first);
    await tester.pumpAndSettle();

    expect(find.text('Buat Tabungan'), findsOneWidget);
    expect(find.text('Contoh: Dana Darurat'), findsOneWidget);
    expect(find.text('Contoh: Bank BCA'), findsOneWidget);
    expect(find.text('Tulis catatan singkat...'), findsOneWidget);
    expect(find.textContaining('BCA (Sisa:'), findsOneWidget);
    expect(find.text('Setoran Awal (Opsional)'), findsOneWidget);
    expect(find.text('Simpan Tabungan'), findsOneWidget);
  });

  testWidgets('Setor membuka sheet "Setor ke …"', (tester) async {
    await _pump(tester, filled());
    await tester.tap(find.text('Setor').first);
    await tester.pumpAndSettle();
    expect(find.text('Setor ke Dana Darurat'), findsOneWidget);
    expect(find.text('Konfirmasi Setoran'), findsOneWidget);
  });
}
```
Catatan: `AppNavAction.add` adalah `AppNavAction` pertama di pohon widget (nav bar dirender sebelum kartu). Bila urutan B1 berbeda, cari tombol tambah lewat ikon plus yang dipakai `AppNavAction.add` di B1.

- [ ] **Step 2: Jalankan, pastikan gagal** — `flutter test test/screens/savings/savings_screen_test.dart` → FAIL.

- [ ] **Step 3: Tulis ulang `lib/screens/savings/savings_screen.dart`**

Ganti seluruh isi file dengan:
```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/screens/savings/saving_detail_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: AppTextStyles.groupLabel),
    );

/// Label dompet sama persis dengan versi lama: "Nama (Sisa: 9.300.000)" tanpa "Rp".
String _walletOptionLabel(Map<String, dynamic> w) =>
    "${w['name']} (Sisa: ${NumberFormat.decimalPattern('id_ID').format((w['balance'] as num).round())})";

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  void _showAddTitleSheet() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();
    final amountController = TextEditingController();
    final initialWallets = ref.read(savingsProvider).wallets;
    int? selectedWalletId = initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null;

    showAppFormSheet<void>(
      context: context,
      title: 'Buat Tabungan',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final wallets = ref.read(savingsProvider).wallets;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel("Nama Tabungan"),
              AppTextField(controller: nameController, hint: "Contoh: Dana Darurat", icon: PhosphorIconsFill.vault),
              const SizedBox(height: 14),
              _fieldLabel("Tempat Simpan (Opsional)"),
              AppTextField(controller: locationController, hint: "Contoh: Bank BCA", icon: PhosphorIconsFill.bank),
              const SizedBox(height: 14),
              _fieldLabel("Catatan (Opsional)"),
              AppTextField(controller: notesController, hint: "Tulis catatan singkat...", maxLines: 2),
              const SizedBox(height: 14),
              AppGroupedSection(
                header: "Tarik Dari Dompet Mana?",
                children: [
                  AppSelectRow<int>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                    title: "Dompet",
                    placeholder: "Pilih Dompet",
                    value: selectedWalletId,
                    options: [for (final w in wallets) AppSelectOption(w['id'] as int, _walletOptionLabel(w))],
                    onChanged: (v) => setSheetState(() => selectedWalletId = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(
                  controller: amountController,
                  label: "Setoran Awal (Opsional)",
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: "Simpan Tabungan",
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    AppNotification.error(context, "Nama tabungan tidak boleh kosong!");
                    return;
                  }

                  double amt = 0;
                  if (amountController.text.isNotEmpty) {
                    amt = parseRupiah(amountController.text).toDouble();
                  }

                  if (amt > 0 && selectedWalletId == null) {
                    AppNotification.error(context, "Pilih dompet untuk setoran awal!");
                    return;
                  }

                  try {
                    if (amt > 0) {
                      final error = await ref.read(savingsProvider.notifier).processSavingTransaction(
                            isDeposit: true,
                            savingName: nameController.text.trim(),
                            amount: amt,
                            walletId: selectedWalletId!,
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                          );
                      if (context.mounted) {
                        if (error != null) {
                          AppNotification.error(context, error);
                        } else {
                          AppNotification.success(context, "Berhasil Menabung!");
                        }
                      }
                    } else {
                      await ref.read(savingsProvider.notifier).addEmptyGroup(
                            name: nameController.text.trim(),
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                          );
                      if (context.mounted) {
                        AppNotification.success(context, "Tabungan berhasil dibuat!");
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) AppNotification.error(context, "Gagal membuat tabungan.");
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSheet(String oldName, String oldLocation, String oldNotes) {
    final nameController = TextEditingController(text: oldName);
    final locationController = TextEditingController(text: oldLocation);
    final notesController = TextEditingController(text: oldNotes);

    showAppFormSheet<void>(
      context: context,
      title: 'Edit Tabungan',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel("Nama Tabungan"),
          AppTextField(controller: nameController, icon: PhosphorIconsFill.vault),
          const SizedBox(height: 14),
          _fieldLabel("Tempat Simpan"),
          AppTextField(controller: locationController, icon: PhosphorIconsFill.bank),
          const SizedBox(height: 14),
          _fieldLabel("Catatan"),
          AppTextField(controller: notesController, maxLines: 2),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: "Simpan Perubahan",
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                await ref.read(savingsProvider.notifier).renameGroup(
                      oldName: oldName,
                      newName: nameController.text.trim(),
                      location: locationController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  AppNotification.success(context, "Berhasil diupdate!");
                }
              } catch (e) {
                if (context.mounted) AppNotification.error(context, "Gagal update tabungan.");
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String groupName) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Tabungan?",
      message:
          "Anda yakin ingin menghapus '$groupName'? Semua riwayat di tabungan ini akan hilang (Saldo dompet TIDAK akan dikembalikan otomatis).",
    );
    if (!confirmed || !mounted) return;
    await ref.read(savingsProvider.notifier).deleteGroup(groupName);
    if (mounted) AppNotification.success(context, "Tabungan dihapus");
  }

  void _showTransactionSheet(String groupName, bool isDeposit) {
    final amountController = TextEditingController();
    final initialWallets = ref.read(savingsProvider).wallets;
    int? selectedWalletId = initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null;
    final actionColor = isDeposit ? AppColors.primary : AppColors.tintOrange;

    showAppFormSheet<void>(
      context: context,
      title: isDeposit ? "Setor ke $groupName" : "Tarik dari $groupName",
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final wallets = ref.read(savingsProvider).wallets;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGroupedSection(
                header: isDeposit ? "Tarik dari Dompet" : "Simpan ke Dompet",
                children: [
                  AppSelectRow<int>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                    title: "Dompet",
                    placeholder: "Pilih Dompet",
                    value: selectedWalletId,
                    options: [for (final w in wallets) AppSelectOption(w['id'] as int, _walletOptionLabel(w))],
                    onChanged: (v) => setSheetState(() => selectedWalletId = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(controller: amountController, label: "Nominal", color: actionColor),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: isDeposit ? "Konfirmasi Setoran" : "Konfirmasi Penarikan",
                color: actionColor,
                onPressed: () {
                  if (amountController.text.isEmpty || selectedWalletId == null) {
                    AppNotification.error(context, "Isi nominal dengan benar!");
                    return;
                  }
                  final double amt = parseRupiah(amountController.text).toDouble();
                  // Sama seperti sebelumnya: tidak di-await, sheet langsung ditutup.
                  ref
                      .read(savingsProvider.notifier)
                      .processSavingTransaction(
                        isDeposit: isDeposit,
                        savingName: groupName,
                        amount: amt,
                        walletId: selectedWalletId!,
                      )
                      .then((error) {
                    if (!context.mounted) return;
                    if (error != null) {
                      AppNotification.error(context, error);
                    } else {
                      AppNotification.success(context, isDeposit ? "Berhasil Menabung!" : "Berhasil Dicairkan!");
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(String groupName, List<SavingModel> items) {
    final double groupTotal = items.fold(0, (sum, item) => sum + item.amount);
    final String loc = items.last.location ?? '';
    final String note = items.last.notes ?? '';

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SavingDetailScreen(savingName: groupName)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconTile(icon: PhosphorIconsFill.vault, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupName, style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (loc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsFill.bank, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(loc, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.pencilSimple,
                  color: AppColors.textSecondary,
                  onPressed: () => _showEditSheet(groupName, loc, note),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.trash,
                  color: AppColors.textSecondary,
                  onPressed: () => _confirmDelete(groupName),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(formatRupiah(groupTotal), style: AppTextStyles.title.copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppPillButton(
                  label: "Setor",
                  icon: PhosphorIconsFill.downloadSimple,
                  onPressed: () => _showTransactionSheet(groupName, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPillButton(
                  label: "Tarik",
                  icon: PhosphorIconsFill.uploadSimple,
                  color: AppColors.tintOrange,
                  onPressed: () => _showTransactionSheet(groupName, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savingsState = ref.watch(savingsProvider);
    final isLoading = savingsState.isLoading;
    final groupedSavings = savingsState.groupedSavings;
    final totalSavings = savingsState.totalSavings;

    return AppPageScaffold(
      title: 'Buku Tabungan',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: _showAddTitleSheet)],
      children: [
        AppHeroCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppHeroLabel("Total Semua Tabungan"),
                    const SizedBox(height: 6),
                    AppHeroAmount(formatRupiah(totalSavings), fontSize: 28),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                child: const Icon(PhosphorIconsFill.piggyBank, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (groupedSavings.isEmpty)
          const AppEmptyState(icon: PhosphorIconsFill.vault, title: "Belum ada tabungan")
        else
          for (final entry in groupedSavings.entries) _buildGroupCard(entry.key, entry.value),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test** — `flutter test test/screens/savings/savings_screen_test.dart` → PASS (5 test).

- [ ] **Step 5: Poppins & hex**

```bash
grep -c "GoogleFonts.poppins" lib/screens/savings/savings_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|blueGrey)" lib/screens/savings/savings_screen.dart
```
Expected: `0` dan tidak ada baris.

- [ ] **Step 6: Analyze** — `flutter analyze lib/screens/savings/savings_screen.dart` → 0 error/warning baru.

- [ ] **Step 7: Checklist visual (vs mockup "Buku Tabungan")**
- [ ] Nav `‹ Beranda` + `+`, judul besar "Buku Tabungan", tanpa FAB teal.
- [ ] Hero gradasi biru: "Total Semua Tabungan" + angka besar, lingkaran putih transparan berisi ikon celengan.
- [ ] Kartu per tabungan: tile vault biru, nama tebal, baris lokasi (ikon bank) abu, pensil & sampah abu di kanan; angka total biru besar di bawahnya; dua pill "Setor" (biru muda) & "Tarik" (oranye muda) sama lebar.
- [ ] Ketuk baris atas kartu → Detail Tabungan.
- [ ] Sheet "Buat Tabungan" (3 field + grup dompet + nominal besar + tombol), "Edit Tabungan", "Setor ke …"/"Tarik dari …" (tombol oranye untuk tarik).

- [ ] **Step 8: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/savings/savings_screen.dart test/screens/savings/savings_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(savings): redesign savings book with iOS cards and form sheets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 6: Detail Tabungan (`SavingDetailScreen`) + sheet "Edit Setoran/Tarikan"

Seam minimal: field `final SupabaseClient _supabase = Supabase.instance.client;` dijalankan saat `State` dibuat sehingga crash di test. Ubah menjadi getter (`SupabaseClient get _supabase => Supabase.instance.client;`); aksesnya sudah berada di dalam `try` pada `_fetchSavingToWallet`, jadi di test error-nya tertangkap dan layar tetap tampil dengan data dari `savingsProvider` palsu.

**Files:**
- Modify (tulis ulang): `lib/screens/savings/saving_detail_screen.dart`
- Test: `test/screens/savings/saving_detail_screen_test.dart`

**Interfaces:**
- Consumes: `savingsProvider` (`editSavingItem`, `deleteSavingItem`, `groupedSavings`, `wallets`, `isLoading`), `SavingModel`, komponen B1.
- Produces: `SavingDetailScreen({super.key, required String savingName})` — tidak berubah.

**Mockup:** entri "Detail Tabungan".

#### Tabel preservasi

| # | Kode lama (`saving_detail_screen.dart`) | Perilaku | Di layout baru |
|---|---|---|---|
| 1 | :24 field `_supabase` | | getter (seam) |
| 2 | :32-70 `_fetchSavingToWallet` (transactions `ilike note %[SAVING_ID:%`, regex id → wallet_id) | | Sama persis |
| 3 | :73-84 `_deleteSaving` → `deleteSavingItem` → toast "Data dihapus & Saldo Dompet dikembalikan!" / error "Gagal menghapus data." | | Sama |
| 4 | :724-760 dialog "Hapus Histori?" / "Catatan ini dihapus dan saldonya dikembalikan ke dompet." | | `showAppConfirmDialog` teks sama → `_deleteSaving(item)` |
| 5 | :87-401 sheet "Edit Setoran"/"Edit Tarikan": "Nominal" (terisi `abs`), "Tempat Simpan" (hint "Contoh: Bank BCA"), "Catatan" (hint "Tulis catatan..."), tombol "Simpan Perubahan" → `editSavingItem(isDeposit: amount >= 0, trim…)` → pop + "Perubahan disimpan!"; catch → "Gagal update data." | | `showAppFormSheet(title: "Edit ${isDeposit ? 'Setoran' : 'Tarikan'}")`. **[LOGIKA]** nominal kosong/0 → `return` (dulu `double.parse('')` crash — Review Focus #2) |
| 6 | :416-424 `history`, `currentBalance`, `walletNames`, `isLoading = provider.isLoading \|\| _isLoading` | | Sama |
| 7 | :428-442 AppBar judul `savingName`, back `Navigator.pop(context, true)` | | `AppPageScaffold(title: savingName, backLabel: 'Buku Tabungan')`. Nilai `true` dari pop tidak dipakai pemanggil (`SavingsScreen` tidak meng-`await` push) — tidak ada perubahan perilaku. |
| 8 | :446-503 hero teal "Total Saldo Tabungan" + saldo + piggyBank | | `AppHeroCard` gradasi biru, isi sama |
| 9 | :517-527 per item: `isWithdrawal = amount < 0`, warna expense/income, `walletName` | | Sama |
| 10 | :546-574 ikon arrowUpRight / downloadSimple, judul "Penarikan Dana" / "Setoran Tabungan" | | `AppIconTile` + judul sama |
| 11 | :577-663 badge dompet "Ke: X" / "Dari: X" dan lokasi bila ada | | `AppChip` (dompet: primary + ikon wallet; lokasi: abu + ikon mapPin) |
| 12 | :665-676 catatan bila ada; :678-686 tanggal `dd MMM yyyy, HH:mm` | | Sama |
| 13 | :693-701 nominal "- "/"+ " + `abs` berwarna | | Sama |
| 14 | :705-760 tombol edit biru (→ `_showEditSheet(item)`) & hapus merah (→ dialog) | | `AppNavAction.icon` pensil `tintBlue` & sampah `expense` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/savings/saving_detail_screen_test.dart`:
```dart
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/screens/savings/saving_detail_screen.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeSavingsNotifier extends SavingsNotifier {
  _FakeSavingsNotifier(this._initial);
  final SavingsState _initial;
  var editCalls = 0;
  @override
  SavingsState build() => _initial;
  @override
  Future<void> editSavingItem({
    required SavingModel saving,
    required double rawAmount,
    required bool isDeposit,
    required String location,
    required String notes,
  }) async {
    editCalls++;
  }
}

SavingModel _item(int id, double amount, {String? location, String? notes}) => SavingModel(
      id: id,
      userId: 'u1',
      name: 'Dana Darurat',
      amount: amount,
      location: location,
      notes: notes,
      createdAt: DateTime(2026, 9, 24, 9, 12),
    );

void main() {
  late _FakeSavingsNotifier notifier;

  Future<void> pump(WidgetTester tester) async {
    notifier = _FakeSavingsNotifier(
      SavingsState(
        isLoading: false,
        groupedSavings: {
          'Dana Darurat': [
            _item(1, 1000000, location: 'Bank BCA', notes: 'Gaji September'),
            _item(2, -250000),
          ],
        },
        wallets: const [
          {'id': 7, 'name': 'BCA', 'balance': 9300000},
        ],
      ),
    );
    await pumpApp(
      tester,
      const SavingDetailScreen(savingName: 'Dana Darurat'),
      overrides: [savingsProvider.overrideWith(() => notifier)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan hero saldo dan riwayat setor/tarik', (tester) async {
    await pump(tester);

    expect(find.text('Dana Darurat'), findsWidgets);
    expect(find.text('Total Saldo Tabungan'), findsOneWidget);
    expect(find.text('Setoran Tabungan'), findsOneWidget);
    expect(find.text('Penarikan Dana'), findsOneWidget);
    expect(find.text('Bank BCA'), findsOneWidget);
    expect(find.text('Gaji September'), findsOneWidget);
    expect(find.text('24 Sep 2026, 09:12'), findsNWidgets(2));
    expect(find.textContaining('+ Rp'), findsOneWidget);
    expect(find.textContaining('- Rp'), findsOneWidget);
  });

  testWidgets('Edit dengan nominal kosong tidak crash dan tidak menyimpan (Review Focus #2)', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(PhosphorIconsRegular.pencilSimple).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Setoran'), findsOneWidget);

    final amountField = find.descendant(of: find.byType(AppAmountField), matching: find.byType(TextField));
    await tester.enterText(amountField, '');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(notifier.editCalls, 0);
    expect(find.text('Edit Setoran'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal** — `flutter test test/screens/savings/saving_detail_screen_test.dart` → FAIL (State lama crash saat dibuat karena field `_supabase`, atau teks tidak ditemukan).

- [ ] **Step 3: Tulis ulang `lib/screens/savings/saving_detail_screen.dart`**

Ganti seluruh isi file dengan:
```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: AppTextStyles.groupLabel),
    );

class SavingDetailScreen extends ConsumerStatefulWidget {
  final String savingName;
  const SavingDetailScreen({super.key, required this.savingName});

  @override
  ConsumerState<SavingDetailScreen> createState() => _SavingDetailScreenState();
}

class _SavingDetailScreenState extends ConsumerState<SavingDetailScreen> {
  // Getter (bukan field initializer) supaya State bisa dibuat di widget test
  // tanpa Supabase terinisialisasi; aksesnya ada di dalam try di bawah.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = true;
  Map<int, int> _savingToWallet = {};

  @override
  void initState() {
    super.initState();
    _fetchSavingToWallet();
  }

  Future<void> _fetchSavingToWallet() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final trxRes = await _supabase
          .from('transactions')
          .select('note, wallet_id')
          .eq('user_id', userId)
          .ilike('note', '%[SAVING_ID:%');

      final Map<int, int> tempSavingWallet = {};
      for (var t in trxRes) {
        final String note = t['note']?.toString() ?? '';
        final int? wId = t['wallet_id'] as int?;
        if (wId != null) {
          final match = RegExp(r'\[SAVING_ID:(\d+)\]').firstMatch(note);
          if (match != null) {
            final int sId = int.parse(match.group(1)!);
            tempSavingWallet[sId] = wId;
          }
        }
      }

      if (mounted) {
        setState(() {
          _savingToWallet = tempSavingWallet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSaving(SavingModel item) async {
    try {
      await ref.read(savingsProvider.notifier).deleteSavingItem(item);
      if (mounted) AppNotification.success(context, "Data dihapus & Saldo Dompet dikembalikan!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data.");
    }
  }

  Future<void> _confirmDeleteItem(SavingModel item) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Histori?",
      message: "Catatan ini dihapus dan saldonya dikembalikan ke dompet.",
    );
    if (!confirmed || !mounted) return;
    _deleteSaving(item);
  }

  void _showEditSheet(SavingModel saving) {
    final bool isDeposit = saving.amount >= 0;
    final amountController = TextEditingController(
      text: NumberFormat.decimalPattern('id_ID').format(saving.amount.abs().round()),
    );
    final locationController = TextEditingController(text: saving.location ?? '');
    final notesController = TextEditingController(text: saving.notes ?? '');

    showAppFormSheet<void>(
      context: context,
      title: "Edit ${isDeposit ? 'Setoran' : 'Tarikan'}",
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurfaceCard(
            child: AppAmountField(
              controller: amountController,
              label: "Nominal",
              color: isDeposit ? AppColors.income : AppColors.expense,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel("Tempat Simpan"),
          AppTextField(controller: locationController, hint: "Contoh: Bank BCA", icon: PhosphorIconsFill.mapPin),
          const SizedBox(height: 14),
          _fieldLabel("Catatan"),
          AppTextField(controller: notesController, hint: "Tulis catatan...", maxLines: 2),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: "Simpan Perubahan",
            onPressed: () async {
              final double rawAmount = parseRupiah(amountController.text).toDouble();
              // [LOGIKA] Dulu double.parse('') melempar FormatException di luar try.
              if (rawAmount <= 0) return;
              try {
                await ref.read(savingsProvider.notifier).editSavingItem(
                      saving: saving,
                      rawAmount: rawAmount,
                      isDeposit: isDeposit,
                      location: locationController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  AppNotification.success(context, "Perubahan disimpan!");
                }
              } catch (e) {
                if (context.mounted) AppNotification.error(context, "Gagal update data.");
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(SavingModel item, Map<int, String> walletNames) {
    final isWithdrawal = item.amount < 0;
    final Color cardColor = isWithdrawal ? AppColors.expense : AppColors.income;
    final walletId = _savingToWallet[item.id];
    final walletName = walletId != null ? walletNames[walletId] : null;
    final hasLocation = item.location != null && item.location!.isNotEmpty;

    return AppListRow(
      leading: AppIconTile(
        icon: isWithdrawal ? PhosphorIconsFill.arrowUpRight : PhosphorIconsFill.downloadSimple,
        color: cardColor,
      ),
      title: isWithdrawal ? "Penarikan Dana" : "Setoran Tabungan",
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (walletName != null || hasLocation)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (walletName != null)
                    AppChip(
                      label: isWithdrawal ? "Ke: $walletName" : "Dari: $walletName",
                      color: AppColors.primary,
                      icon: PhosphorIconsFill.wallet,
                    ),
                  if (hasLocation) AppChip(label: item.location!, icon: PhosphorIconsFill.mapPin),
                ],
              ),
            ),
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.notes!, style: AppTextStyles.caption),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt),
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            (isWithdrawal ? "- " : "+ ") + formatRupiah(item.amount.abs()),
            style: AppTextStyles.amountRow.copyWith(color: cardColor),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNavAction.icon(
                PhosphorIconsRegular.pencilSimple,
                color: AppColors.tintBlue,
                onPressed: () => _showEditSheet(item),
              ),
              AppNavAction.icon(
                PhosphorIconsRegular.trash,
                color: AppColors.expense,
                onPressed: () => _confirmDeleteItem(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savingsState = ref.watch(savingsProvider);
    final history = savingsState.groupedSavings[widget.savingName] ?? [];
    final currentBalance = history.fold<double>(0, (sum, item) => sum + item.amount);
    final Map<int, String> walletNames = {
      for (final w in savingsState.wallets) w['id'] as int: w['name'].toString(),
    };
    final isLoading = savingsState.isLoading || _isLoading;

    return AppPageScaffold(
      title: widget.savingName,
      backLabel: 'Buku Tabungan',
      children: [
        AppHeroCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppHeroLabel("Total Saldo Tabungan"),
                    const SizedBox(height: 6),
                    AppHeroAmount(formatRupiah(currentBalance), fontSize: 28),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                child: const Icon(PhosphorIconsFill.piggyBank, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (history.isNotEmpty)
          AppGroupedSection(
            header: 'Riwayat',
            children: [for (final item in history) _buildHistoryRow(item, walletNames)],
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test** — `flutter test test/screens/savings/` → PASS (Task 5 + Task 6).

- [ ] **Step 5: Poppins & hex**

```bash
grep -c "GoogleFonts.poppins" lib/screens/savings/saving_detail_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|blueGrey)" lib/screens/savings/saving_detail_screen.dart
```
Expected: `0` dan tidak ada baris.

- [ ] **Step 6: Analyze** — `flutter analyze lib/screens/savings` → 0 error/warning baru.

- [ ] **Step 7: Checklist visual (vs mockup "Detail Tabungan")**
- [ ] Nav `‹ Buku Tabungan`, judul besar = nama tabungan.
- [ ] Hero gradasi biru "Total Saldo Tabungan" + angka + lingkaran celengan.
- [ ] Label "RIWAYAT", list putih: tile hijau (setoran) / merah (penarikan), judul, chip biru "Dari: BCA"/"Ke: BCA", chip abu lokasi dengan ikon pin, catatan abu, tanggal kecil; kanan nominal "+ Rp …"/"- Rp …" berwarna dengan pensil biru & sampah merah kecil di bawahnya.
- [ ] Pensil → sheet "Batal · Edit Setoran" (nominal besar, Tempat Simpan, Catatan, tombol).

- [ ] **Step 8: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/savings/saving_detail_screen.dart test/screens/savings/saving_detail_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(savings): redesign savings detail history and guard empty edit amount

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 7: Tagihan & Pemasukan Rutin (`RecurringScreen`) + sheet "Buat/Edit Jadwal Tagihan"

**Files:**
- Modify (tulis ulang): `lib/screens/recurring/recurring_screen.dart`
- Test: `test/screens/recurring/recurring_screen_test.dart`

**Interfaces:**
- Consumes: `recurringProvider`, `RecurringState` (`walletNames`), `RecurringNotifier` (`toggleActive`, `deleteItem`, `addRecurring`, `updateRecurring`) — tidak berubah. `RecurringTransactionModel`. `AppSelectRow` (Task 1), `AppSwitch`, `AppSegmentedControl`, komponen B1.
- Produces: `RecurringScreen` (const) — API tidak berubah.

**Mockup:** entri "Tagihan & Pemasukan Rutin".

#### Tabel preservasi

| # | Kode lama (`recurring_screen.dart`) | Perilaku | Di layout baru |
|---|---|---|---|
| 1 | :22-28 `_toggleActive` → `toggleActive(item, value)`; error → "Gagal mengubah status" | | `AppSwitch.onChanged` → sama |
| 2 | :30-37 `_deleteItem` → `deleteItem(id)` → "Jadwal otomatis dihapus" / "Gagal menghapus data" | | Sama |
| 3 | :939-980 dialog "Hapus Jadwal?" / "Jadwal otomatis ini akan dihentikan dan dihapus dari daftar." | | `showAppConfirmDialog` teks sama |
| 4 | :40-58 inisialisasi sheet: `isEdit`, `isExpense = category['is_expense'] ?? true` (baru: true), `selectedCatId`, `selectedWalletId` (edit: milik item; baru: dompet pertama), `selectedFreq` (default 'Bulanan'), `selectedDate` (edit: startDate; baru: now), frekuensi Harian/Mingguan/Bulanan/Tahunan | | Sama persis |
| 5 | :95 judul "Edit Jadwal Tagihan" / "Buat Jadwal Tagihan" | | judul `showAppFormSheet` |
| 6 | :116-210 toggle "Pemasukan" (isExpense=false) / "Pengeluaran" (true); keduanya reset `selectedCatId = null` | | `AppSegmentedControl(['Pemasukan','Pengeluaran'], warna [income, expense])` dengan reset yang sama |
| 7 | :218-273 "Potong Dari Dompet Mana?" (pengeluaran) / "Masuk Ke Dompet Mana?" (pemasukan); hint "Belum ada dompet"/"Pilih Dompet"; item nama dompet | | `AppSelectRow` dompet |
| 8 | :277-327 "Kategori" (hint "Pilih Kategori"; opsi disaring `is_expense == isExpense`; value null bila tidak ada di daftar tersaring) | | `AppSelectRow` kategori, aturan value sama |
| 9 | :331-400 "Nominal" (Rp) | | `AppAmountField` |
| 10 | :410-450 "Diulang Setiap" (dropdown frekuensi) | | `AppSelectRow<String>` |
| 11 | :454-481 "Mulai Tanggal (Jatuh Tempo Pertama)" (picker 2020-2030, initialDate selectedDate) | | `AppListRow` + `showAppDatePicker` (Plan B3b) dengan batas sama |
| 12 | :516-527 "Catatan (Cth: Bayar Kos / Tagihan WiFi)" (hint "Tulis catatan...") | | label + `AppTextField` |
| 13 | :572-629 tombol "Perbarui Jadwal"/"Simpan Jadwal": validasi "Nominal, Kategori, dan Dompet wajib diisi!"; data map (user_id dari `Supabase.instance.client.auth`, `note` trim, `start_date` yyyy-MM-dd, `next_run_date` edit = lama `toIso8601String()` / baru = start date) → `updateRecurring`/`addRecurring` → pop + "Jadwal diperbarui!"/"Jadwal berhasil dibuat!"; catch → "Gagal menyimpan jadwal" | | Sama persis |
| 14 | :664-680 AppBar "Tagihan & Pemasukan Rutin" | | `AppPageScaffold(title: 'Tagihan & Pemasukan Rutin', backLabel: 'Beranda')` |
| 15 | :681-700 spinner; empty ikon calendarPlus + "Belum ada jadwal otomatis" | | spinner; `AppEmptyState` |
| 16 | :706-712 `isExpense`, `catName ?? 'Umum'`, warna expense/income, `walletName ?? 'Dompet Dihapus'` | | Sama |
| 17 | :720-753 border berwarna saat aktif, abu saat nonaktif; tile arrowUp/arrowDown berwarna / abu | | Kartu nonaktif `Opacity(0.55)` (mockup); tile `AppColors.tintGray` saat nonaktif |
| 18 | :759-842 nama kategori, catatan (1 baris), chip "Per ${frequency}" biru, chip dompet | | Sama dengan `AppChip` (`tintBlue` / netral + ikon wallet) |
| 19 | :849-865 nominal berwarna (abu nonaktif) + Switch | | `formatRupiahSigned(isIncome: !isExpense)` + `AppSwitch` |
| 20 | :874-918 "Lanjut: " + `dd MMM yyyy id_ID` tebal | | Sama (Text.rich) |
| 21 | :922-936 pensil biru → `_showAddEditSheet(item: item)` | | `AppNavAction.icon(pencilSimple, tintBlue)` |
| 22 | :1004-1016 FAB "Buat Jadwal" → `_showAddEditSheet()` | | `AppNavAction.add` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/recurring/recurring_screen_test.dart`:
```dart
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/providers/recurring_provider.dart';
import 'package:catat_uang_app/screens/recurring/recurring_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeRecurringNotifier extends RecurringNotifier {
  _FakeRecurringNotifier(this._initial);
  final RecurringState _initial;
  @override
  RecurringState build() => _initial;
}

RecurringTransactionModel _item({
  required int id,
  required String category,
  required bool isExpense,
  required double amount,
  required bool active,
  int? walletId,
  String? note,
}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u1',
      categoryId: id,
      amount: amount,
      note: note,
      frequency: 'Bulanan',
      startDate: DateTime(2026, 9, 1),
      nextRunDate: DateTime(2026, 10, 1),
      isActive: active,
      category: {'id': id, 'name': category, 'is_expense': isExpense},
      walletId: walletId,
    );

Future<void> _pump(WidgetTester tester, RecurringState state) async {
  await pumpApp(
    tester,
    const RecurringScreen(),
    overrides: [recurringProvider.overrideWith(() => _FakeRecurringNotifier(state))],
  );
  await tester.pumpAndSettle();
}

void main() {
  RecurringState filled() => RecurringState(
        isLoading: false,
        wallets: const [
          {'id': 1, 'name': 'BCA'},
        ],
        categories: const [
          {'id': 1, 'name': 'Kos', 'is_expense': true},
          {'id': 2, 'name': 'Gaji', 'is_expense': false},
        ],
        recurringList: [
          _item(id: 1, category: 'Kos', isExpense: true, amount: 1500000, active: true, walletId: 1, note: 'Bayar kos bulanan'),
          _item(id: 2, category: 'Gaji', isExpense: false, amount: 8000000, active: true, walletId: 1),
          _item(id: 3, category: 'Hiburan', isExpense: true, amount: 186000, active: false, walletId: 99),
        ],
      );

  testWidgets('menampilkan kartu jadwal dengan chip, nominal bertanda, switch, dan tanggal lanjut', (tester) async {
    await _pump(tester, filled());

    expect(find.text('Tagihan & Pemasukan Rutin'), findsWidgets);
    expect(find.text('Kos'), findsOneWidget);
    expect(find.text('Bayar kos bulanan'), findsOneWidget);
    expect(find.text('Per Bulanan'), findsNWidgets(3));
    expect(find.text('BCA'), findsNWidgets(2));
    expect(find.text('Dompet Dihapus'), findsOneWidget);
    expect(find.text('-Rp 1.500.000'), findsOneWidget);
    expect(find.text('+Rp 8.000.000'), findsOneWidget);
    expect(find.byType(AppSwitch), findsNWidgets(3));
    expect(find.textContaining('Lanjut:'), findsNWidgets(3));
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('jadwal nonaktif diredupkan', (tester) async {
    await _pump(tester, filled());
    expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.55), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, const RecurringState(isLoading: false));
    expect(find.text('Belum ada jadwal otomatis'), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet "Buat Jadwal Tagihan"', (tester) async {
    await _pump(tester, filled());
    await tester.tap(find.byWidgetPredicate((w) => w is AppNavAction).first);
    await tester.pumpAndSettle();

    expect(find.text('Buat Jadwal Tagihan'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Potong Dari Dompet Mana?'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Diulang Setiap'), findsOneWidget);
    expect(find.text('Mulai Tanggal (Jatuh Tempo Pertama)'), findsOneWidget);
    expect(find.text('Simpan Jadwal'), findsOneWidget);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Ke Dompet Mana?'), findsOneWidget);
  });
}
```
Catatan: bila `formatRupiahSigned` B1 menghasilkan spasi setelah tanda (mis. "- Rp"), sesuaikan dua string nominal di test dengan output aktual `formatRupiahSigned` (lihat `test/core/formatters_test.dart` dari B1).

- [ ] **Step 2: Jalankan, pastikan gagal** — `flutter test test/screens/recurring/recurring_screen_test.dart` → FAIL.

- [ ] **Step 3: Tulis ulang `lib/screens/recurring/recurring_screen.dart`**

Ganti seluruh isi file dengan:
```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/providers/recurring_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: AppTextStyles.groupLabel),
    );

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  Future<void> _toggleActive(RecurringTransactionModel item, bool value) async {
    try {
      await ref.read(recurringProvider.notifier).toggleActive(item, value);
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal mengubah status");
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await ref.read(recurringProvider.notifier).deleteItem(id);
      if (mounted) AppNotification.success(context, "Jadwal otomatis dihapus");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data");
    }
  }

  Future<void> _confirmDelete(RecurringTransactionModel item) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Jadwal?",
      message: "Jadwal otomatis ini akan dihentikan dan dihapus dari daftar.",
    );
    if (!confirmed || !mounted) return;
    _deleteItem(item.id);
  }

  void _showAddEditSheet({RecurringTransactionModel? item}) {
    final isEdit = item != null;
    final initialWallets = ref.read(recurringProvider).wallets;
    bool isExpense = isEdit ? (item.category?['is_expense'] ?? true) : true;
    int? selectedCatId = isEdit ? item.categoryId : null;
    int? selectedWalletId = isEdit
        ? item.walletId
        : (initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null);
    String selectedFreq = isEdit ? item.frequency : 'Bulanan';
    DateTime selectedDate = isEdit ? item.startDate : DateTime.now();

    final amountController = TextEditingController(
      text: isEdit ? NumberFormat.decimalPattern('id_ID').format(item.amount.round()) : '',
    );
    final noteController = TextEditingController(text: isEdit ? item.note ?? '' : '');
    final frequencies = ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'];

    showAppFormSheet<void>(
      context: context,
      title: isEdit ? "Edit Jadwal Tagihan" : "Buat Jadwal Tagihan",
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = ref.read(recurringProvider).categories;
          final wallets = ref.read(recurringProvider).wallets;
          final filteredCats = categories.where((c) => c['is_expense'] == isExpense).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmentedControl(
                labels: const ['Pemasukan', 'Pengeluaran'],
                selectedIndex: isExpense ? 1 : 0,
                selectedLabelColors: const [AppColors.income, AppColors.expense],
                onChanged: (index) => setSheetState(() {
                  isExpense = index == 1;
                  selectedCatId = null;
                }),
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(
                  controller: amountController,
                  label: "Nominal",
                  color: isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
              const SizedBox(height: 14),
              AppGroupedSection(
                children: [
                  AppSelectRow<int>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                    title: isExpense ? "Potong Dari Dompet Mana?" : "Masuk Ke Dompet Mana?",
                    placeholder: wallets.isEmpty ? "Belum ada dompet" : "Pilih Dompet",
                    value: selectedWalletId,
                    options: [for (final w in wallets) AppSelectOption(w['id'] as int, "${w['name']}")],
                    onChanged: (val) => setSheetState(() => selectedWalletId = val),
                  ),
                  AppSelectRow<int>(
                    leading: AppIconTile(
                      icon: PhosphorIconsFill.tag,
                      color: isExpense ? AppColors.expense : AppColors.income,
                    ),
                    title: "Kategori",
                    placeholder: "Pilih Kategori",
                    value: filteredCats.any((c) => c['id'] == selectedCatId) ? selectedCatId : null,
                    options: [for (final cat in filteredCats) AppSelectOption(cat['id'] as int, "${cat['name']}")],
                    onChanged: (val) => setSheetState(() => selectedCatId = val),
                  ),
                  AppSelectRow<String>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.repeat, color: AppColors.tintBlue),
                    title: "Diulang Setiap",
                    value: selectedFreq,
                    options: [for (final f in frequencies) AppSelectOption(f, f)],
                    onChanged: (val) => setSheetState(() => selectedFreq = val),
                  ),
                  AppListRow(
                    leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.tintRed),
                    title: "Mulai Tanggal (Jatuh Tempo Pertama)",
                    value: DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate),
                    showChevron: true,
                    onTap: () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _fieldLabel("Catatan (Cth: Bayar Kos / Tagihan WiFi)"),
              AppTextField(controller: noteController, hint: "Tulis catatan..."),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: isEdit ? "Perbarui Jadwal" : "Simpan Jadwal",
                onPressed: () async {
                  if (amountController.text.isEmpty || selectedCatId == null || selectedWalletId == null) {
                    AppNotification.error(context, "Nominal, Kategori, dan Dompet wajib diisi!");
                    return;
                  }

                  final double amount = parseRupiah(amountController.text).toDouble();
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                  try {
                    final data = {
                      'user_id': userId,
                      'category_id': selectedCatId,
                      'wallet_id': selectedWalletId,
                      'amount': amount,
                      'note': noteController.text.trim(),
                      'frequency': selectedFreq,
                      'start_date': dateStr,
                      'next_run_date': isEdit ? item.nextRunDate.toIso8601String() : dateStr,
                    };

                    if (isEdit) {
                      await ref.read(recurringProvider.notifier).updateRecurring(item.id, data);
                    } else {
                      await ref.read(recurringProvider.notifier).addRecurring(data);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.success(context, isEdit ? "Jadwal diperbarui!" : "Jadwal berhasil dibuat!");
                    }
                  } catch (e) {
                    if (context.mounted) AppNotification.error(context, "Gagal menyimpan jadwal");
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(RecurringTransactionModel item, Map<int, String> walletNames) {
    final bool isExpense = item.category?['is_expense'] ?? true;
    final String catName = item.category?['name'] ?? 'Umum';
    final color = isExpense ? AppColors.expense : AppColors.income;
    final walletName = walletNames[item.walletId] ?? 'Dompet Dihapus';

    return Opacity(
      opacity: item.isActive ? 1 : 0.55,
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconTile(
                  icon: isExpense ? PhosphorIcons.arrowUp() : PhosphorIcons.arrowDown(),
                  color: item.isActive ? color : AppColors.tintGray,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catName,
                        style: AppTextStyles.headline.copyWith(
                          color: item.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.note != null && item.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(item.note!, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          AppChip(label: "Per ${item.frequency}", color: AppColors.tintBlue),
                          AppChip(label: walletName, icon: PhosphorIconsFill.wallet),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRupiahSigned(item.amount, isIncome: !isExpense),
                      style: AppTextStyles.amountRow.copyWith(
                        color: item.isActive ? color : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppSwitch(value: item.isActive, onChanged: (val) => _toggleActive(item, val)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5, color: AppColors.separator),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(PhosphorIconsRegular.clock, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: "Lanjut: ", style: AppTextStyles.caption),
                        TextSpan(
                          text: DateFormat('dd MMM yyyy', 'id_ID').format(item.nextRunDate),
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: item.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.pencilSimple,
                  color: AppColors.tintBlue,
                  onPressed: () => _showAddEditSheet(item: item),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.trash,
                  color: AppColors.expense,
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recurringState = ref.watch(recurringProvider);
    final isLoading = recurringState.isLoading;
    final recurringList = recurringState.recurringList;
    final walletNames = recurringState.walletNames;

    return AppPageScaffold(
      title: 'Tagihan & Pemasukan Rutin',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: () => _showAddEditSheet())],
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (recurringList.isEmpty)
          const AppEmptyState(icon: PhosphorIconsFill.calendarPlus, title: "Belum ada jadwal otomatis")
        else
          for (final item in recurringList) _buildCard(item, walletNames),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test** — `flutter test test/screens/recurring/recurring_screen_test.dart` → PASS (4 test).

- [ ] **Step 5: Poppins & hex**

```bash
grep -c "GoogleFonts.poppins" lib/screens/recurring/recurring_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|blueGrey)" lib/screens/recurring/recurring_screen.dart
```
Expected: `0` dan tidak ada baris.

- [ ] **Step 6: Analyze** — `flutter analyze lib/screens/recurring` → 0 error/warning baru.

- [ ] **Step 7: Checklist visual (vs mockup "Tagihan & Pemasukan Rutin")**
- [ ] Nav `‹ Beranda` + `+`, judul besar dua baris rapi, tanpa FAB.
- [ ] Kartu: tile panah (merah pengeluaran / hijau pemasukan), nama tebal, catatan abu, chip biru "Per Bulanan" + chip abu dompet; kanan nominal bertanda berwarna + switch iOS hijau.
- [ ] Garis tipis, lalu "🕒 Lanjut: **01 Okt 2026**" + pensil biru + sampah merah.
- [ ] Jadwal nonaktif: seluruh kartu redup, switch off, tile abu.
- [ ] `+` → sheet "Batal · Buat Jadwal Tagihan": segmented Pemasukan/Pengeluaran, nominal besar, grup 4 baris (dompet, kategori, diulang, tanggal mulai) dengan chevron, field catatan, tombol "Simpan Jadwal".

- [ ] **Step 8: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/recurring/recurring_screen.dart test/screens/recurring/recurring_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(recurring): redesign recurring schedules with iOS switches and form sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 8: Verifikasi akhir + checkpoint screenshot user

**Files:** `test/architecture/modal_consistency_test.dart` (hapus entri `_legacy` B5); selain itu tidak ada perubahan kode (kecuali perbaikan temuan).

- [ ] **Step 0: Kosongkan entri `_legacy` milik B5**

Hapus enam baris `'B5'` (`budget_screen.dart`, `budget_detail_screen.dart`, `recurring_screen.dart`, `saving_detail_screen.dart`, `savings_screen.dart`, `target_screen.dart`) dari `_legacy` di `test/architecture/modal_consistency_test.dart`, lalu:

Run: `flutter test test/architecture/modal_consistency_test.dart`
Expected: PASS. Bila gagal, baris yang disebut masih memanggil modal mentah (`showDialog`, `AlertDialog`, `showDatePicker`, `showAppBottomSheet`, …) — ganti dengan komponen bersama (spec G17): konfirmasi → `showAppConfirmDialog`, form → `showAppFormSheet`, tanggal → `showAppDatePicker`. Jangan kembalikan entri `_legacy`.

- [ ] **Step 1: Seluruh test hijau**

Run: `flutter test`
Expected: semua PASS (setelah B1 tidak ada test yang gagal; bila ada kegagalan di luar file B5, laporkan dan jangan "memperbaiki" file milik plan lain).

- [ ] **Step 2: Analyze seluruh project**

Run: `flutter analyze`
Expected: tidak ada error/warning baru dibanding `main` sebelum branch ini (bandingkan: `git stash; flutter analyze | tail -1; git stash pop` bila perlu). Info `withOpacity` di dua kontainer ikon celengan (Task 5 & 6) mengikuti pola codebase dan boleh.

- [ ] **Step 3: Audit Poppins & warna untuk 6 screen**

```bash
for f in lib/screens/budget/budget_screen.dart lib/screens/budget/budget_detail_screen.dart lib/screens/target/target_screen.dart lib/screens/savings/savings_screen.dart lib/screens/savings/saving_detail_screen.dart lib/screens/recurring/recurring_screen.dart; do
  echo "$f poppins=$(grep -c 'GoogleFonts.poppins' $f) google_fonts_import=$(grep -c 'google_fonts' $f) hex=$(grep -cE 'Color\(0x|Colors\.(purple|teal|green|orange|red|grey|blue|blueGrey|tealAccent|redAccent)' $f) fab=$(grep -c 'FloatingActionButton' $f)"
done
```
Expected: setiap baris `poppins=0 google_fonts_import=0 hex=0 fab=0`.

- [ ] **Step 4: Preservasi — bandingkan string UI dengan main**

```bash
for f in lib/screens/budget/budget_screen.dart lib/screens/budget/budget_detail_screen.dart lib/screens/target/target_screen.dart lib/screens/savings/savings_screen.dart lib/screens/savings/saving_detail_screen.dart lib/screens/recurring/recurring_screen.dart; do
  echo "== $f"
  diff <(git show main:$f | grep -oE '"[A-Z][^"$]{3,}' | sort -u) <(grep -oE '"[A-Z][^"$]{3,}' $f | sort -u) | grep '^<'
done
```
Expected: baris `<` (string yang hilang) hanya berupa label yang sengaja diganti dan tercatat di tabel preservasi (mis. judul "Pilih Kategori" → baris "Kategori"; hint "Pilih Kategori Pengeluaran" tetap ada). Setiap string toast/validasi/dialog di tabel preservasi HARUS masih ada; bila ada yang hilang, kembalikan.

- [ ] **Step 5: Jalankan app untuk user**

Gunakan skill `run-and-screenshot` (web, port 8765). Bila agent tidak bisa melihat UI, minta koordinator mengirim pesan ke user:
> "Phase B5 siap dicek di localhost:8765. Tolong kirim screenshot: (1) Anggaran, (2) Detail Anggaran, (3) sheet Buat Anggaran, (4) Target Keuangan, (5) Buku Tabungan, (6) Detail Tabungan, (7) Tagihan & Pemasukan Rutin, (8) salah satu sheet form lain (mis. Nabung atau Buat Jadwal)."

Cocokkan setiap screenshot dengan checklist visual Task 2–7 dan mockup; perbaiki perbedaan yang user tunjukkan sebelum merge.

- [ ] **Step 6: Laporan akhir** — daftar commit, hasil Step 1–4, perubahan komponen di Task 1 (AppSelectRow, AppTextField.focusNode, AppSwipeActions.deleteConfirmTitle/deleteConfirmMessage) sebagai catatan untuk plan berikutnya, dan temuan visual user.

---

## Self-Review (sudah dijalankan saat menulis plan)

- **Cakupan spec:** G1 (judul besar) semua task; G2/G3 nav + `+` Task 2,4,5,7; G4 sheet semua form (termasuk "Pilih Periode" yang dulu dialog); G5 grouped list Task 2,3,6,7; G6 segmented Task 7; G8 hero Task 2,5,6; G9 kartu putih; G10 tile; G11 warna ungu/teal/hijau/biru dihapus; G12 swipe Task 2 (Anggaran — satu-satunya list tanpa ikon hapus terlihat di mockup); G13 tombol bawah di dalam sheet; G14 Poppins Task 8 Step 3; G16 empty/loading semua screen.
- **Placeholder:** tidak ada TBD; setiap langkah kode berisi kode lengkap.
- **Konsistensi tipe:** `BudgetScreen.statusColor` (Task 2) dipakai Task 3; `BudgetDetailKey`/`BudgetDetailData`/`budgetDetailProvider` konsisten di provider, screen, dan test; `AppSelectOption`/`AppSelectRow` sama di semua task.
- **Review Focus:** #1 Task 4 test ke-4, #2 Task 6 test ke-2, #3 Task 5 test ke-2, #4 Task 2 test ke-2 + Task 3 test ke-2, #5 Task 2 test ke-3.
