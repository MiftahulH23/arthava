# Phase B3b — Satu bentuk untuk semua modal (pemilih tanggal & loading) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Semua modal di app punya bentuk yang sama (keputusan user 2026-09-26): konfirmasi/pilihan = dialog iOS `app_dialogs.dart`; form, daftar, dan **semua pemilih tanggal/bulan/tahun/periode** = sheet bawah `showAppFormSheet` (Batal · judul, isi, tombol "Pilih" penuh). Tambah komponen pemilih + loading bersama, pindahkan layar yang sudah didesain ulang (Utang) ke komponen itu, dan kunci aturannya dengan test arsitektur.

**Architecture:** Satu file baru `lib/widgets/app_pickers.dart` berisi empat fungsi `showApp*Picker` yang semuanya dibangun di atas `showAppFormSheet` (kalender memakai `CalendarDatePicker` bawaan Flutter di dalam kartu putih, jadi lokal `id_ID` otomatis dari `MaterialApp`). `runWithAppLoading` ditambahkan ke `app_dialogs.dart`: HUD iOS (kotak putih + `CupertinoActivityIndicator`) lewat `CupertinoDialogRoute` yang dilepas dengan `removeRoute`, jadi tidak pernah "nyangkut" walau tugasnya selesai sebelum frame pertama. `test/architecture/modal_consistency_test.dart` (sudah ada, commit `934bc30`) diperluas dengan larangan `showDatePicker`/`showDateRangePicker`/`showTimePicker`.

**Tech Stack:** Flutter (`CalendarDatePicker`, `CupertinoDialogRoute`, `CupertinoActivityIndicator`), intl, komponen B1 (`showAppFormSheet`, `AppPrimaryButton`, `AppGroupedSection`, `AppListRow`, `AppTextStyles`, `AppColors`).

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` — aturan G4 (form = sheet), G12 (dialog iOS), G17 (baru, ditambah Task 4), §6 kontrak komponen, §6.1 (baris B3b ditambah Task 4), §9 aturan engineering.

## Global Constraints

Sama dengan Plan B3 (spec §9), terutama:

1. **Jangan jalankan `dart format` ke seluruh file.** Edit terarah saja.
2. Setelah `await` (termasuk `await showApp*Picker(...)`), cek `if (!mounted) return;` / `if (!context.mounted) return;` sebelum `setState`/`context`.
3. Tidak ada hex/`Colors.<warna>` — semua dari `AppColors` (kecuali `Colors.white`, `Colors.transparent`).
4. Commit Conventional Commits, diakhiri dua baris atribusi:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
    ```

Lain-lain:
- Branch: `redesign/phase-b3b-modals` dari `main` setelah Plan B3 di-merge.
- Label UI baru (persis): "Pilih Tanggal", "Pilih Bulan", "Pilih Tahun", "Pilih Periode", "Pilih", "Dari", "Sampai".
- **Keputusan perilaku (ruling koordinator):** semua pemilih memakai tombol "Pilih" (sesuai pratinjau yang disetujui user). Dialog bulan/tahun lama menutup langsung saat item diketuk; sekarang item diketuk = ditandai, "Pilih" = simpan. Satu ketukan tambahan, bentuk seragam.
- Batas tanggal: bila `initialDate` di luar `[firstDate, lastDate]`, dijepit ke batas terdekat (bukan assertion). Ini menggantikan penjepitan manual yang tersebar (mis. `debt_form_sheet.dart`, B5 Task 4 "Edit Target").

## Review Focus

1. **`initialDate` di luar rentang** (deadline lama sudah lewat, tanggal sebelum `firstDate`) — sheet tetap terbuka, tanggal terpilih = batas terdekat, tidak ada assertion. (Task 1 test `menjepit initialDate`)
2. **Periode dengan "Sampai" lebih awal dari "Dari"** — tidak bisa menghasilkan rentang terbalik; "Sampai" ikut digeser ke "Dari". (Task 1 test `rentang`)
3. **Batal / tutup sheet** — semua pemilih mengembalikan `null`, pemanggil tidak mengubah apa pun. (Task 1 test `Batal`)
4. **Loading selesai sebelum HUD sempat tampil / tugas melempar error** — HUD tetap tertutup, error diteruskan ke pemanggil. (Task 2 test)
5. **Pemilih dibuka dari dalam sheet** (form Utang, Cicilan, Target) — sheet pemilih menumpuk di atas sheet form; setelah "Pilih", sheet form tetap terbuka dengan nilai baru. (Task 3 test)

---

## Peta file

| File | Aksi | Tanggung jawab |
|---|---|---|
| `lib/widgets/app_pickers.dart` | Create | `showAppDatePicker`, `showAppMonthPicker`, `showAppYearPicker`, `showAppDateRangePicker` |
| `lib/widgets/app_dialogs.dart` | Modify (aditif) | `runWithAppLoading` + `_AppLoadingHud` |
| `lib/screens/debt/debt_form_sheet.dart` | Modify | 2× `showDatePicker` → `showAppDatePicker` |
| `lib/screens/debt/debt_payment_sheet.dart` | Modify | 1× `showDatePicker` → `showAppDatePicker` |
| `test/widgets/app_pickers_test.dart` | Create | Perilaku keempat pemilih |
| `test/widgets/app_dialogs_loading_test.dart` | Create | `runWithAppLoading` |
| `test/screens/debt/debt_date_picker_test.dart` | Create | Pemilih tanggal dari dalam sheet Utang |
| `test/architecture/modal_consistency_test.dart` | Modify | Larang date/time picker Material; `app_pickers.dart` masuk daftar komponen bersama |
| `test/screenshots/modal_screenshots_test.dart` | Create | 5 screenshot untuk checkpoint user |
| `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` | Modify | G17 + baris §6.1 B3b |
| `AGENTS.md` | Modify | Bullet "Modals" menyebut pemilih & loading |

---

### Task 1: Komponen pemilih tanggal/bulan/tahun/periode

**Files:**
- Create: `lib/widgets/app_pickers.dart`
- Test: `test/widgets/app_pickers_test.dart`

**Interfaces:**
- Consumes: `showAppFormSheet` (`lib/widgets/app_sheet.dart`), `AppPrimaryButton` (`lib/widgets/app_buttons.dart`), `AppGroupedSection`, `AppListRow`, `AppTextStyles`, `AppColors`.
- Produces:
  ```dart
  Future<DateTime?> showAppDatePicker({required BuildContext context, required DateTime initialDate,
      required DateTime firstDate, required DateTime lastDate, String title = 'Pilih Tanggal'});
  Future<DateTime?> showAppMonthPicker({required BuildContext context, required DateTime initialMonth,
      required int firstYear, required int lastYear, String title = 'Pilih Bulan'}); // hasil DateTime(tahun, bulan)
  Future<int?> showAppYearPicker({required BuildContext context, required int initialYear,
      required int firstYear, required int lastYear, String title = 'Pilih Tahun'});
  Future<DateTimeRange?> showAppDateRangePicker({required BuildContext context, DateTimeRange? initialRange,
      required DateTime firstDate, required DateTime lastDate, String title = 'Pilih Periode'});
  ```

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_pickers_test.dart
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Membuka pemilih lewat tombol "buka" lalu menyimpan hasilnya.
Future<void> pumpOpener(WidgetTester tester, Future<Object?> Function(BuildContext) open, void Function(Object?) done) {
  return pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () async => done(await open(context)), child: const Text('buka'))),
      ),
    ),
    size: const Size(390, 900),
  );
}

void main() {
  testWidgets('tanggal: judul, ketuk hari, Pilih mengembalikan tanggal itu', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 9, 26), firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tanggal'), findsOneWidget);
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 15));
  });

  testWidgets('tanggal: Batal mengembalikan null', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 9, 26), firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('tanggal: menjepit initialDate di luar rentang tanpa assertion', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 1, 1), firstDate: DateTime(2026, 9, 26), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 26));
  });

  testWidgets('bulan: ganti tahun, ketuk bulan, Pilih', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppMonthPicker(context: c, initialMonth: DateTime(2026, 9), firstYear: 2021, lastYear: 2031),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Bulan'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Tahun sebelumnya'));
    await tester.pump();
    expect(find.text('2025'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2025, 3));
  });

  testWidgets('bulan: tombol tahun nonaktif di batas', (tester) async {
    await pumpOpener(
      tester,
      (c) => showAppMonthPicker(context: c, initialMonth: DateTime(2021, 5), firstYear: 2021, lastYear: 2031),
      (_) {},
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final prev = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left));
    expect(prev.onPressed, isNull);
  });

  testWidgets('tahun: ketuk tahun, Pilih', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppYearPicker(context: c, initialYear: 2026, firstYear: 2020, lastYear: 2030),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tahun'), findsOneWidget);
    await tester.tap(find.text('2023'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, 2023);
  });

  testWidgets('rentang: pilih Dari lalu Sampai; Sampai lebih awal digeser ke Dari', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDateRangePicker(
        context: c,
        initialRange: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 10)),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      ),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Periode'), findsOneWidget);
    expect(find.text('Dari'), findsOneWidget);
    expect(find.text('Sampai'), findsOneWidget);
    // Baris "Dari" aktif: ketuk 20 -> Dari = 20, otomatis pindah ke "Sampai",
    // dan Sampai (10) yang lebih awal ikut digeser ke 20.
    await tester.tap(find.text('20'));
    await tester.pump();
    await tester.tap(find.text('25'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTimeRange(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 25)));
  });

  testWidgets('rentang: tanpa initialRange, Sampai = Dari bila hanya Dari yang diketuk', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDateRangePicker(context: c, firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    final range = result! as DateTimeRange;
    expect(range.start, range.end);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_pickers_test.dart`
Expected: FAIL (compile error: `app_pickers.dart` belum ada).

- [ ] **Step 3: Buat `lib/widgets/app_pickers.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pemilih tanggal/bulan/tahun/periode bersama (spec G17): semuanya sheet bawah
/// `showAppFormSheet` (Batal · judul) dengan tombol "Pilih" penuh. `null` = batal.

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clamp(DateTime d, DateTime first, DateTime last) {
  final day = _dateOnly(d);
  if (day.isBefore(_dateOnly(first))) return _dateOnly(first);
  if (day.isAfter(_dateOnly(last))) return _dateOnly(last);
  return day;
}

/// Kalender di kartu putih; warna aksen primary.
Widget _calendarCard(BuildContext context, Widget calendar) {
  return Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.surface),
    ),
    child: Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: calendar,
    ),
  );
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pilih Tanggal',
}) {
  var selected = _clamp(initialDate, firstDate, lastDate);
  return showAppFormSheet<DateTime>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _calendarCard(
            sheetContext,
            CalendarDatePicker(
              initialDate: selected,
              firstDate: _dateOnly(firstDate),
              lastDate: _dateOnly(lastDate),
              onDateChanged: (d) => setSheetState(() => selected = d),
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Pilih', onPressed: () => Navigator.of(sheetContext).pop(selected)),
        ],
      ),
    ),
  );
}

/// Grid pilihan (bulan/tahun): pill putih, terpilih = primary penuh.
Widget _choiceGrid({required List<String> labels, required int selectedIndex, required ValueChanged<int> onTap}) {
  return Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.all(12),
    child: GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            button: true,
            selected: i == selectedIndex,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selectedIndex ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[i],
                  style: AppTextStyles.bodyStrong.copyWith(color: i == selectedIndex ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<DateTime?> showAppMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  required int firstYear,
  required int lastYear,
  String title = 'Pilih Bulan',
}) {
  var year = initialMonth.year.clamp(firstYear, lastYear);
  var month = initialMonth.month;
  final labels = [for (var m = 1; m <= 12; m++) DateFormat('MMM', 'id_ID').format(DateTime(2024, m))];
  return showAppFormSheet<DateTime>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Tahun sebelumnya',
                color: AppColors.primary,
                icon: const Icon(Icons.chevron_left),
                onPressed: year > firstYear ? () => setSheetState(() => year--) : null,
              ),
              SizedBox(width: 88, child: Text('$year', textAlign: TextAlign.center, style: AppTextStyles.headline)),
              IconButton(
                tooltip: 'Tahun berikutnya',
                color: AppColors.primary,
                icon: const Icon(Icons.chevron_right),
                onPressed: year < lastYear ? () => setSheetState(() => year++) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _choiceGrid(labels: labels, selectedIndex: month - 1, onTap: (i) => setSheetState(() => month = i + 1)),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Pilih', onPressed: () => Navigator.of(sheetContext).pop(DateTime(year, month))),
        ],
      ),
    ),
  );
}

Future<int?> showAppYearPicker({
  required BuildContext context,
  required int initialYear,
  required int firstYear,
  required int lastYear,
  String title = 'Pilih Tahun',
}) {
  final years = [for (var y = firstYear; y <= lastYear; y++) y];
  var index = years.indexOf(initialYear.clamp(firstYear, lastYear));
  return showAppFormSheet<int>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _choiceGrid(labels: [for (final y in years) '$y'], selectedIndex: index, onTap: (i) => setSheetState(() => index = i)),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Pilih', onPressed: () => Navigator.of(sheetContext).pop(years[index])),
        ],
      ),
    ),
  );
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pilih Periode',
}) {
  final today = _clamp(DateTime.now(), firstDate, lastDate);
  var start = initialRange == null ? today : _clamp(initialRange.start, firstDate, lastDate);
  var end = initialRange == null ? start : _clamp(initialRange.end, firstDate, lastDate);
  if (end.isBefore(start)) end = start;
  var editingStart = true;
  final fmt = DateFormat('d MMM yyyy', 'id_ID');
  return showAppFormSheet<DateTimeRange>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Widget row(String label, DateTime value, bool active) => AppListRow(
              title: label,
              value: fmt.format(value),
              valueColor: active ? AppColors.primary : null,
              onTap: () => setSheetState(() => editingStart = label == 'Dari'),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroupedSection(children: [row('Dari', start, editingStart), row('Sampai', end, !editingStart)]),
            const SizedBox(height: 12),
            _calendarCard(
              sheetContext,
              CalendarDatePicker(
                // Key per baris: kalender pindah ke tanggal baris yang sedang diedit.
                key: ValueKey(editingStart),
                initialDate: editingStart ? start : end,
                firstDate: _dateOnly(editingStart ? firstDate : start),
                lastDate: _dateOnly(lastDate),
                onDateChanged: (d) => setSheetState(() {
                  if (editingStart) {
                    start = d;
                    if (end.isBefore(start)) end = start;
                    editingStart = false;
                  } else {
                    end = d;
                  }
                }),
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Pilih',
              onPressed: () => Navigator.of(sheetContext).pop(DateTimeRange(start: start, end: end)),
            ),
          ],
        );
      },
    ),
  );
}
```

Catatan untuk executor: cek dulu `AppListRow` punya parameter `valueColor`. Bila belum, tambahkan secara **aditif** (`final Color? valueColor;`, dipakai sebagai warna teks value, default perilaku lama) dan catat di ledger sebagai ruling + baris §6.1 B3b (Task 4). Jangan ubah `ValueKey` untuk refresh data — di sini `ValueKey` hanya memilih kalender mana yang tampil (bukan refresh provider, spec §9 tidak dilanggar).

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/widgets/app_pickers_test.dart`
Expected: PASS (8 test). Bila `find.text('15')` ambigu (angka muncul di bulan lain), pakai `find.text('15').last` — kalender hanya menampilkan satu bulan, jadi seharusnya tunggal.

- [ ] **Step 5: Analyze & commit**

```bash
flutter analyze lib/widgets/app_pickers.dart test/widgets/app_pickers_test.dart
git add lib/widgets/app_pickers.dart test/widgets/app_pickers_test.dart lib/widgets/app_list_row.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add shared date, month, year, and range picker sheets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: Loading bersama `runWithAppLoading`

**Files:**
- Modify: `lib/widgets/app_dialogs.dart` (aditif, di akhir file)
- Test: `test/widgets/app_dialogs_loading_test.dart`

**Interfaces:**
- Produces: `Future<T> runWithAppLoading<T>(BuildContext context, Future<T> Function() task, {String? message})` — menampilkan HUD iOS yang tidak bisa ditutup pengguna selama `task` berjalan, lalu menutupnya (juga saat `task` melempar; error diteruskan).
- Dipakai oleh: Plan B4 Task 6 (`_processScanReceipts`, pengganti `showDialog` spinner manual).

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/widgets/app_dialogs_loading_test.dart
import 'dart:async';

import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await pumpApp(tester, Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    }));
    return ctx;
  }

  testWidgets('HUD tampil selama tugas berjalan lalu hilang, hasil diteruskan', (tester) async {
    final ctx = await pumpHost(tester);
    final gate = Completer<int>();
    final result = runWithAppLoading(ctx, () => gate.future, message: 'Membaca struk...');
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('Membaca struk...'), findsOneWidget);
    gate.complete(7);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(await result, 7);
  });

  testWidgets('tugas selesai sebelum frame pertama: HUD tidak nyangkut', (tester) async {
    final ctx = await pumpHost(tester);
    final value = await runWithAppLoading(ctx, () async => 'cepat');
    await tester.pumpAndSettle();
    expect(value, 'cepat');
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('tugas melempar: HUD tertutup dan error diteruskan', (tester) async {
    final ctx = await pumpHost(tester);
    Object? caught;
    try {
      await runWithAppLoading<void>(ctx, () async => throw StateError('gagal'));
    } catch (e) {
      caught = e;
    }
    await tester.pumpAndSettle();
    expect(caught, isA<StateError>());
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('tombol kembali tidak menutup HUD', (tester) async {
    final ctx = await pumpHost(tester);
    final gate = Completer<void>();
    unawaited(runWithAppLoading(ctx, () => gate.future));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_dialogs_loading_test.dart`
Expected: FAIL (`runWithAppLoading` belum ada).

- [ ] **Step 3: Tambahkan di akhir `lib/widgets/app_dialogs.dart`**

```dart
/// Loading gaya iOS (HUD) selama [task] berjalan. Tidak bisa ditutup pengguna;
/// selalu dilepas setelah [task] selesai atau gagal (error diteruskan).
/// Route dilepas lewat `removeRoute`, jadi aman walau [task] selesai sebelum
/// HUD sempat tampil atau ada route lain di atasnya.
Future<T> runWithAppLoading<T>(BuildContext context, Future<T> Function() task, {String? message}) async {
  final navigator = Navigator.of(context);
  final route = CupertinoDialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: _AppLoadingHud(message: message)),
  );
  navigator.push(route);
  try {
    return await task();
  } finally {
    if (route.isActive) navigator.removeRoute(route);
  }
}

class _AppLoadingHud extends StatelessWidget {
  const _AppLoadingHud({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, textAlign: TextAlign.center, style: AppTextStyles.subhead),
            ],
          ],
        ),
      ),
    );
  }
}
```

`app_dialogs.dart` sudah mengimpor `flutter/cupertino.dart`, `AppColors`, dan `AppTextStyles`; `PopScope` & `Navigator` tersedia dari `flutter/widgets.dart` (lewat cupertino). Bila `AppColors.surface` belum diimpor di file itu, tambahkan import-nya.

- [ ] **Step 4: Test & commit**

Run: `flutter test test/widgets/app_dialogs_loading_test.dart test/widgets/app_dialogs_test.dart`
Expected: PASS (4 test baru + test dialog lama).

```bash
git add lib/widgets/app_dialogs.dart test/widgets/app_dialogs_loading_test.dart
git commit -m "$(cat <<'EOF'
feat(widgets): add shared loading HUD for blocking tasks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: Layar Utang memakai pemilih bersama + larangan di test arsitektur

**Files:**
- Modify: `test/architecture/modal_consistency_test.dart`
- Modify: `lib/screens/debt/debt_form_sheet.dart` (`_pickLoanDate` ±baris 101–112, `_pickDueDate` ±baris 114–126)
- Modify: `lib/screens/debt/debt_payment_sheet.dart` (`_pickDate` ±baris 108–120)
- Test: `test/screens/debt/debt_date_picker_test.dart`

**Tabel preservasi**

| # | Perilaku lama | Di kode baru |
|---|---|---|
| 1 | Tanggal pinjam: `initialDate` = `_loanDate` dijepit ke hari ini, `firstDate` 2000, `lastDate` hari ini | `showAppDatePicker(title: 'Tanggal Pinjam', …)` dengan batas sama (penjepitan manual boleh dihapus; komponen menjepit sendiri) |
| 2 | Jatuh tempo: `initialDate` = due/loan date, dijepit ≥ 2000; `firstDate` 2000; `lastDate` = `last` (variabel lama) | `showAppDatePicker(title: 'Jatuh Tempo', …)` dengan `firstDate`/`lastDate` sama |
| 3 | Tanggal cicilan: `initialDate`/`firstDate` = `first`, `lastDate` hari ini | `showAppDatePicker(title: 'Tanggal Bayar', …)` batas sama |
| 4 | `if (picked != null) setState(...)` | Sama, ditambah `if (!mounted) return;` sebelum `setState` |

- [ ] **Step 1: Perluas test arsitektur (gagal)**

Di `test/architecture/modal_consistency_test.dart`:
- Tambah `showDatePicker|showDateRangePicker|showTimePicker` ke kelompok pertama `_forbidden` (sebelum `)\s*[<(]`).
- Tambah `'lib/widgets/app_pickers.dart'` ke set `_shared`.

Run: `flutter test test/architecture/modal_consistency_test.dart`
Expected: FAIL — `offenders` berisi `debt_form_sheet.dart` (2) dan `debt_payment_sheet.dart` (1). File lain yang memakai date picker (`input_transaction`, `stats`, `transaction_history`, `recurring`, `target`) sudah ada di `_legacy`.

- [ ] **Step 2: Tulis test sheet Utang (gagal)**

```dart
// test/screens/debt/debt_date_picker_test.dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/screens/debt/debt_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  testWidgets('tanggal pinjam dibuka sebagai sheet bersama, sheet form tetap terbuka setelah Pilih', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDebtFormSheet(context, initialType: DebtType.payable),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
      overrides: debtOverrides(FakeDebtNotifier(sampleState())),
      size: const Size(390, 1400),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanggal Pinjam'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('Catat Utang'), findsWidgets); // sheet form masih terbuka
  });
}
```

Catatan untuk executor: sesuaikan tiga hal dengan kode B2 yang ada — nama helper state di `debt_test_utils.dart` (`sampleState()` atau konstruksi `DebtState` seperti `test/screenshots/debt_screenshots_test.dart`), label baris tanggal pinjam di `debt_form_sheet.dart`, dan judul sheet form. Catat penyesuaian sebagai ruling.

Run: `flutter test test/screens/debt/debt_date_picker_test.dart`
Expected: FAIL (`DatePickerDialog` masih muncul / `CalendarDatePicker` sheet tidak ada).

- [ ] **Step 3: Ganti pemanggilan di dua file Utang**

Pola (contoh `_pickLoanDate`; dua lainnya sama dengan batas masing-masing dari tabel preservasi):

```dart
  Future<void> _pickLoanDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showAppDatePicker(
      context: context,
      title: 'Tanggal Pinjam',
      initialDate: _loanDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() => _loanDate = picked);
  }
```

Tambah `import 'package:catat_uang_app/widgets/app_pickers.dart';`. Pertahankan isi `setState` lama persis (mis. penyesuaian jatuh tempo bila ada).

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/architecture/modal_consistency_test.dart test/screens/debt`
Expected: PASS (arsitektur 2/2, semua test Utang lama + test baru).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/debt/debt_form_sheet.dart lib/screens/debt/debt_payment_sheet.dart test/screens/debt/debt_date_picker_test.dart test/architecture/modal_consistency_test.dart
git commit -m "$(cat <<'EOF'
refactor(debt): use shared date picker sheet

Also forbids Material date and time pickers outside the shared widgets.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: Spec & AGENTS.md

**Files:**
- Modify: `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Spec**

1. Tabel §3, tambah baris setelah G16:

```markdown
| G17 | **Semua modal satu bentuk** (keputusan user 2026-09-26): konfirmasi/pilihan = dialog iOS (`showAppConfirmDialog` / `showAppChoiceDialog`); form, daftar, dan pemilih tanggal/bulan/tahun/periode = sheet bawah (`showAppFormSheet`, `showAppDatePicker`, `showAppMonthPicker`, `showAppYearPicker`, `showAppDateRangePicker`) dengan tombol "Pilih"; loading yang memblokir = `runWithAppLoading`. `showDialog`, `AlertDialog`, `showDatePicker`, `showDateRangePicker`, `showModalBottomSheet` dilarang di screen (`test/architecture/modal_consistency_test.dart`). | Hapus Utang, Tanggal Pinjam |
```

2. Tabel §6.1, tambah baris setelah B3:

```markdown
| B3b | `lib/widgets/app_pickers.dart` (`showAppDatePicker`, `showAppMonthPicker`, `showAppYearPicker`, `showAppDateRangePicker`); `runWithAppLoading` di `app_dialogs.dart`; `AppListRow.valueColor` (bila ditambah di Task 1); `test/architecture/modal_consistency_test.dart` (daftar `_legacy` dikosongkan oleh plan B4–B6) |
```

3. Tabel §8, tambah baris setelah B3: `| — pemilih & loading bersama, Utang memakai pemilih baru | lib/widgets/app_pickers.dart, app_dialogs.dart, lib/screens/debt/* | **B3b** |`, dan ubah urutan eksekusi menjadi `B1 → B2 → B3 → B3b → B4 → B5 → B6 → B7`.

- [ ] **Step 2: AGENTS.md**

Ganti bullet **Modals** dengan:

```markdown
- **Modals:** every modal in the app has the same look. Confirmations
  and choices go through `showAppConfirmDialog` / `showAppChoiceDialog`
  (`lib/widgets/app_dialogs.dart`); forms, lists and date/month/year/
  range pickers are bottom sheets (`showAppFormSheet`, `showApp*Picker`
  in `lib/widgets/app_pickers.dart`); blocking loading uses
  `runWithAppLoading`. Never call `showDialog`, `AlertDialog`,
  `showDatePicker`, `showDateRangePicker`, `showModalBottomSheet` or
  `showAppBottomSheet` directly from a screen.
  `test/architecture/modal_consistency_test.dart` enforces this; its
  `_legacy` list names the not-yet-redesigned screens and the plan that
  cleans each one — remove a file's entry when its plan does.
```

Dan di bagian "Known Context", ubah `executed in order B1 → B7` menjadi `executed in order B1 → B2 → B3 → B3b → B4 → B7`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md AGENTS.md
git commit -m "$(cat <<'EOF'
docs(spec): add one-shape rule for every modal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 5: Verifikasi, screenshot, checkpoint user

**Files:**
- Create: `test/screenshots/modal_screenshots_test.dart`

- [ ] **Step 1: Screenshot test**

Pakai `test/screenshots/screenshot_harness.dart` (`loadRealFonts`, `pumpScreen`, `saveScreenshot`) dan pola `_opener` dari `debt_screenshots_test.dart`. Lima gambar (390×844):

1. `b3b_01_date_picker` — `showAppDatePicker(initialDate: 26 Sep 2026, 2020–2030)`.
2. `b3b_02_month_picker` — `showAppMonthPicker(initialMonth: Sep 2026, 2021–2031)`.
3. `b3b_03_year_picker` — `showAppYearPicker(2026, 2020–2030)`.
4. `b3b_04_range_picker` — `showAppDateRangePicker(1–10 Sep 2026)`.
5. `b3b_05_debt_form_date` — sheet Catat Utang lalu ketuk baris tanggal pinjam (sheet pemilih menumpuk di atas form).

Tambahkan `b3b_06_confirm_dialog` — `showAppConfirmDialog(title: 'Hapus Dompet?', message: 'Yakin ingin menghapus BCA?')` di atas halaman Dompet, supaya user melihat dialog & sheet berdampingan.

Run: `flutter test test/screenshots/modal_screenshots_test.dart`
Expected: PASS, 6 PNG di `build/screenshots/b3b_*.png`.

- [ ] **Step 2: Analyze & test penuh**

```bash
flutter analyze 2>&1 | grep -E " error | warning " ; flutter analyze 2>&1 | tail -1
flutter test 2>&1 | tail -1
grep -rn "showDatePicker\|showDateRangePicker\|AlertDialog(" lib/screens/debt lib/widgets | grep -v app_pickers.dart
```

Expected: tanpa error/warning; semua test hijau; grep kosong.

- [ ] **Step 3: Checkpoint**

Kirim 6 screenshot ke user. Merge ke `main` hanya setelah user menyetujui bentuknya (skill `finishing-a-development-branch`).

Laporan akhir ke koordinator: daftar commit; hasil analyze/test; perubahan yang sudah diteruskan ke plan B4 (Task 3 `showAppPeriodPicker` memakai pemilih bersama, Task 6 `_saveTransaction`/`_pickDate`/`_processScanReceipts`), B5 (semua date picker Target & Tagihan Rutin), B6 (Export `_pickMonth`) — lihat bagian "Perubahan plan lain" di bawah.

---

## Perubahan plan lain (diterapkan ke file plan B4–B6 setelah plan ini disetujui user)

Plan B4–B6 akan diperbarui supaya kode barunya memakai komponen di atas dan setiap plan mengosongkan entri `_legacy`-nya:

- **B4 Task 3** — `showAppPeriodPicker` tidak lagi membuat `AlertDialog`/`showDatePicker`/`showDateRangePicker`; ia memanggil `showAppDatePicker` (Harian), `showAppYearPicker` (Tahunan, hasil `DateTime(tahun, bulan lama)` seperti `YearPicker`), `showAppDateRangePicker` (Periode), `showAppMonthPicker` (Bulanan, tahun ±5). Perilaku berubah: item bulan/tahun diketuk lalu "Pilih" (ruling di atas).
- **B4 Task 6** — `_pickDate` Tambah Transaksi memakai `showAppDatePicker`; `_processScanReceipts` memakai `runWithAppLoading(message: 'Membaca struk...')` sebagai pengganti `showDialog` spinner + `Navigator.pop` manual.
- **B5 Task 4 & Task 7** — tiga `showDatePicker` (Target baru, Edit Target, Tagihan Rutin) memakai `showAppDatePicker`; penjepitan manual deadline lama tetap boleh ada tapi tidak wajib.
- **B6 Export** — `_pickMonth` memakai `showAppMonthPicker(title: 'Pilih Periode')`.
- **B4/B5/B6 task verifikasi akhir** — langkah baru: hapus file plan itu dari `_legacy` di `test/architecture/modal_consistency_test.dart`, lalu jalankan test itu (harus lulus). B6 menutup plan dengan `_legacy` kosong.
