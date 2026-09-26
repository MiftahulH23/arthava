# Phase B6 — Alat & Aset (Investasi, Zakat & Sedekah, Kalender, Kelola Kategori, Export, AI Advisor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mendesain ulang enam screen fitur pendukung (Investasi, Zakat & Sedekah, Kalender, Kelola Kategori, Export Laporan, AI Advisor) ke gaya iOS sesuai mockup yang disetujui, tanpa mengubah fitur/data.

**Architecture:** Setiap screen dibangun ulang di atas komponen bersama Plan B1 (`AppPageScaffold`, `AppGroupedSection`, `AppListRow`, `AppHeroCard`, `showAppFormSheet`, dst.). Logika bisnis, query Supabase, dan provider TIDAK diubah; yang berubah hanya pohon widget, gaya teks, dan warna. Tiga screen tanpa provider (Zakat, Export, AI Advisor) mendapat *seam* minimal (field `_supabase` jadi getter) supaya bisa di-test tanpa Supabase. Satu komponen bersama baru dibuat di sini: `AppWalletSelectRow` (pemilih dompet gaya iOS pengganti `DropdownButton`), dipakai Investasi dan Zakat.

**Tech Stack:** Flutter, flutter_riverpod 2.6.1, forui 0.17.0 (lewat komponen B1), phosphor_flutter, table_calendar 3.2.0, flutter_markdown, intl (`id_ID`), google_fonts (Plus Jakarta Sans lewat `AppTextStyles`).

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` — WAJIB dibaca dulu (terutama §3 aturan desain, §4 token, §5 tipografi, §6 kontrak API komponen, §9 aturan engineering, §10 verifikasi). Mockup: `docs/design/dompetku-redesign-mockup.html` (entri `SCREENS` bernama "Investasi", "Zakat & Sedekah", "Kalender", "Kelola Kategori", "Export Laporan", "AI Advisor").

**Branch:** `redesign/phase-b6-tools-assets` dari `main` (setelah B1–B5 di-merge).

## Global Constraints

Diulang dari spec §9 dan §10 — berlaku untuk SETIAP task:

1. Jangan jalankan `dart format` ke seluruh file. Edit terarah saja; diff sebanding dengan perubahan.
2. `Notifier.build()` tidak boleh menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)` (provider di plan ini tidak diubah — jangan rusak pola ini).
3. Refresh provider lewat `ref.invalidate(...)` / method provider, bukan mengganti `ValueKey`.
4. Setelah `await` (terutama `Navigator.push` / pemanggilan service), cek `if (!mounted) return;` (StatefulWidget) atau `if (!context.mounted) return;` (ConsumerWidget/builder) sebelum `setState`/`context`/`ref`.
5. Tab di dalam Home memakai `AppPageScaffold(embedded: true)` — screen di plan ini BUKAN tab, jadi `embedded: false` (default).
6. Jangan menaruh `Center`/`Align`/`Expanded` tanpa batas di slot yang memberi tinggi longgar (mis. `bottomNavigationBar`, `bottomBar`) — pakai `heightFactor: 1` bila perlu.
7. Pertahankan konkurensi fetch asli (`CalendarNotifier._loadAll` tetap `Future.wait`; provider tidak disentuh).
8. Semua `onTap` / navigasi / validasi / toast / pemanggilan provider & service lama dipertahankan persis (lihat tabel preservasi di tiap task). Redesign hanya mengubah tampilan kecuali task menyebut perubahan.
9. Tidak ada hex/`Colors.<warna>` di screen — semua warna dari `AppColors`. Pengecualian: `Colors.white`, `Colors.transparent`, warna dompet dari data. Warna hardcoded lama (`Colors.blue.shade*`, `Colors.green.shade*`, `Colors.indigo`, `Colors.grey*`, `Colors.red/green/greenAccent/redAccent`) diganti sesuai tabel di tiap task (aturan G11: warna fitur → `AppColors.primary`; hijau/merah hanya untuk arti uang → `AppColors.income`/`AppColors.expense`).
10. Commit Conventional Commits (hook `commit-msg`), scope tanpa koma, diakhiri tepat dengan dua baris:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
    ```
11. Tidak ada perubahan skema DB di plan ini.
12. Verifikasi per task (spec §10): `flutter analyze` tanpa error/warning baru (info `withOpacity` lama boleh); `flutter test` hijau; `grep -c "GoogleFonts.poppins" <file screen>` = 0; tidak ada hex/`Colors.<warna>` baru; checklist visual dicocokkan dengan mockup via skill `run-and-screenshot` (bila agent tidak punya otomasi browser, tulis "belum diverifikasi visual" di laporan — koordinator meminta screenshot user di Task 7).
13. Pakai API komponen B1 PERSIS seperti spec §6. Bila butuh parameter baru, tambahkan sebagai parameter opsional di komponennya (dengan test) di task yang membutuhkannya — plan ini sudah menandai semuanya (`AppTextField.autofocus/textCapitalization`, `AppNavAction.icon(tooltip:)`, `AppPageScaffold.scrollController`). Jangan membuat widget kembar di dalam screen.
14. Label UI diambil dari kode lama (spec §2), bukan dari teks contoh mockup. Contoh: judul besar "Kalender Keuangan" (bukan "Kalender"), "Kelola Kategori" (bukan "Kategori").
15. Jangan ubah konstruktor publik keenam screen — semuanya tetap `const XxxScreen({super.key})` karena dipanggil dari `home_screen.dart`/`all_features_screen.dart`.
16. Jangan hapus `.withOpacity` lama di luar baris yang memang ditulis ulang — hanya baris yang Anda tulis ulang yang boleh berubah.

## Review Focus

Lima kondisi yang paling mungkin menggigit pengguna tapi tidak diuji oleh "happy path"; setiap baris punya test di task pemiliknya:

1. **Jual aset melebihi nilai aset / saldo dompet kurang** — provider melempar `Exception`; pengguna harus melihat toast pesan asli dan sheet TIDAK tertutup (Task 1, test `jual gagal tetap di sheet dan menampilkan pesan`).
2. **Bayar Zakat tanpa dompet atau total harta 0** — harus muncul pesan "Anda belum membuat dompet." / "Masukkan total harta yang valid!", tanpa transaksi (Task 2, test `bayar zakat tanpa dompet menampilkan pesan`).
3. **Pindah bulan di Kalender** (chevron di header baru atau swipe) — judul bulan di header harus ikut berubah; tanpa `onPageChanged` header kustom akan macet di bulan awal (Task 3, test `chevron kanan memindah judul bulan`).
4. **Simpan kategori dengan nama kosong** — tidak boleh memanggil provider dan sheet tetap terbuka (Task 4, test `simpan nama kosong tidak memanggil provider`).
5. **Kirim pesan kosong / reset sesi AI** — tidak boleh muncul bubble kosong; reset menampilkan salam Gemi lagi dan toast (Task 6, test `kirim kosong tidak menambah bubble` dan `reset sesi`).

---

## Task 0: Prasyarat & branch

**Files:** tidak ada perubahan kode.

- [ ] **Step 1: Pastikan B1 sudah di-merge dan komponen tersedia**

Run:
```bash
git checkout main && git pull --ff-only 2>/dev/null; git log --oneline -5
ls lib/widgets/app_page_scaffold.dart lib/widgets/app_grouped_section.dart lib/widgets/app_list_row.dart lib/widgets/app_segmented_control.dart lib/widgets/app_hero_card.dart lib/widgets/app_surface_card.dart lib/widgets/app_chip.dart lib/widgets/app_callout.dart lib/widgets/app_buttons.dart lib/widgets/app_sheet.dart lib/widgets/app_amount_display.dart lib/widgets/app_text_field.dart lib/widgets/app_empty_state.dart lib/widgets/app_dialogs.dart lib/core/formatters.dart lib/theme/app_text_styles.dart test/helpers/pump_app.dart
```
Expected: semua file ada. Bila ada yang hilang → STOP, laporkan BLOCKED (Plan B1 belum selesai).

- [ ] **Step 2: Baca kontrak API di spec §6 dan implementasi aktualnya**

Run: `grep -n "const App\|Future<.*> show\|^String \|^int \|class " lib/widgets/app_page_scaffold.dart lib/widgets/app_list_row.dart lib/widgets/app_text_field.dart lib/widgets/app_amount_display.dart lib/widgets/app_sheet.dart`
Expected: nama & parameter cocok dengan spec §6. Catat bila `titleWidget` + `largeTitle: false` menaruh widget di tengah nav bar (dipakai Task 6) dan apakah `backLabel: ''` merender chevron saja.

- [ ] **Step 3: Buat branch**

```bash
git checkout -b redesign/phase-b6-tools-assets
flutter test
```
Expected: semua test hijau (B1 sudah menghapus `test/widget_test.dart`).

---

## Task 1: Komponen `AppWalletSelectRow` + redesign Investasi

**Files:**
- Create: `lib/widgets/app_wallet_select_row.dart`
- Create: `test/widgets/app_wallet_select_row_test.dart`
- Modify: `lib/screens/investment/investment_screen.dart` (seluruh isi class `InvestmentScreen`, baris 13–588)
- Create: `test/screens/investment/investment_screen_test.dart`

**Interfaces:**
- Consumes (B1, spec §6): `AppPageScaffold`, `AppNavAction.add`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppHeroCard`, `AppHeroLabel`, `AppHeroAmount`, `AppEmptyState`, `AppCallout`, `AppPrimaryButton`, `AppAmountField`, `AppTextField`, `showAppFormSheet`, `formatRupiah`, `parseRupiah`, `AppTextStyles`, `AppColors`, `pumpApp`.
- Consumes (provider, TIDAK diubah): `investmentProvider`, `InvestmentNotifier.fetchData()`, `buyInvestment({name, type, amount, walletId})`, `buySellInvestment({inv, isBuy, amount, walletId})`, `updateInvestmentValue(int id, double amount)`, `deleteInvestment(int id)`, `InvestmentState(isLoading, investments, wallets, totalCapital, totalValue)`.
- Produces: `class AppWalletSelectRow extends StatelessWidget { const AppWalletSelectRow({required List<Map<String, dynamic>> wallets, required int? selectedId, required ValueChanged<int> onChanged, String? header, String placeholder = 'Pilih Dompet...', String emptyLabel = 'Belum ada dompet', super.key}); }` dan fungsi `Color walletColorOf(Map<String, dynamic> wallet)` di file yang sama. Dipakai Task 2. (Koordinator: plan lain yang butuh pemilih dompet boleh memakai komponen ini.)

### Tabel preservasi — `lib/screens/investment/investment_screen.dart` (kode lama)

| Baris lama | Perilaku / label | Tetap di kode baru sebagai |
|---|---|---|
| 22–26 | `_inputFormat` (currency tanpa simbol) | tetap dipakai untuk nilai awal sheet Update (baris 338) |
| 32–33 | dompet diambil dari `ref.read(investmentProvider).wallets`, default dompet pertama | sama, di `_showAddInvestmentSheet` & `_showBuySellSheet` |
| 59 | judul sheet "Investasi Baru" | `showAppFormSheet(title: 'Investasi Baru')` |
| 65 | label "Nama Aset (Misal: Saham BBCA, Emas Antam)" | `_FieldLabel` |
| 77 | label "Jenis (Misal: Saham, Reksadana, Kripto)" | `_FieldLabel` |
| 89, 104–112 | "Modal Awal", format ribuan saat mengetik | `AppAmountField(label: 'Modal Awal')` (format ribuan oleh `RupiahInputFormatter`) |
| 116, 125 | "Sumber Dana", item "Nama (Sisa: Rp …)" | `AppWalletSelectRow(header: 'Sumber Dana')` (nama + saldo) |
| 137–140 | validasi kosong → `AppNotification.error(context, "Semua kolom wajib diisi!")` | sama persis |
| 141–144 | dompet null → "Pilih dompet!" | sama persis |
| 145 | parse nominal digit-saja → double | `parseRupiah(amountController.text).toDouble()` |
| 148–153 | `buyInvestment(name: trim, type: trim, amount, walletId)` | sama persis |
| 155–158 | sukses → pop sheet + "Investasi berhasil dibeli!" | sama |
| 159–163 | error → `e.toString().replaceFirst('Exception: ', '')` | sama |
| 165 | tombol "Beli Aset" | `AppPrimaryButton(label: 'Beli Aset')` |
| 188–190 | sheet aksi: judul `inv.name`, sub `inv.type` | `showAppFormSheet(title: inv.name)` + teks `inv.type` |
| 192–199 | "Beli Tambahan (Top Up)" → pop → `_showBuySellSheet(.., true)` | `AppListRow` |
| 200–207 | "Jual Aset (Withdraw)" → pop → `_showBuySellSheet(.., false)` | `AppListRow` |
| 208–216 | "Update Nilai Terkini" + sub "Sesuaikan dengan harga pasar saat ini" → `_showUpdateValueSheet` | `AppListRow` |
| 217–224 | "Hapus Portofolio" (abu) → pop → `await deleteInvestment(inv.id)` **tanpa konfirmasi** | sama, tetap tanpa konfirmasi (lihat catatan akhir task) |
| 253 | judul "Top Up: {name}" / "Jual: {name}" | `showAppFormSheet(title: ...)` |
| 259 | "Nominal (Rp)" | `AppAmountField(label: 'Nominal (Rp)')` |
| 283 | "Sumber Dana" / "Masuk ke Dompet" | `AppWalletSelectRow(header: ...)` |
| 304–305 | nominal kosong / dompet null → return diam | sama |
| 309–314 | `buySellInvestment(inv, isBuy, amount, walletId)` | sama |
| 316–319 | "Top up berhasil!" / "Penjualan berhasil!" + pop | sama |
| 320–323 | error → `replaceFirst('Exception: ', '')` | sama |
| 326 | "Proses Pembelian" / "Proses Penjualan", warna hijau/merah | `AppPrimaryButton(color: income/expense)` |
| 338 | nilai awal `_inputFormat.format(inv.currentValue)` | sama |
| 357 | "Update Nilai: {name}" | judul sheet |
| 363–373 | kotak info biru "Update nilai terkini aset sesuai harga pasar. Ini tidak akan memotong saldo dompetmu." | `AppCallout(tone: info)` |
| 376 | "Nilai Saat Ini (Rp)" | label `AppAmountField` |
| 405, 409 | kosong → return; `updateInvestmentValue(inv.id, amount)` | sama |
| 411–418 | "Nilai berhasil diperbarui!" / "Error: $e" | sama |
| 421 | "Simpan Pembaruan" (biru) | `AppPrimaryButton` warna primary |
| 439–440 | `totalReturn`, `isProfit` | sama |
| 445 | judul "Investasi" | `AppPageScaffold(title: 'Investasi')` |
| 451–452 | loading → spinner di tengah | spinner di children |
| 454 | pull-to-refresh → `fetchData()` | `onRefresh` |
| 473, 483 | "Total Nilai Investasi", "Total Modal" | `AppHeroLabel` |
| 494 | format "+x.xx%" (`toStringAsFixed(2)`) | sama persis |
| 505 | "Daftar Portofolio" | `AppGroupedSection(header:)` |
| 508–519 | kosong → ikon chartLineUp + "Belum ada aset investasi." | `AppEmptyState` |
| 523–524, 569 | return per aset "+x.xx%" hijau/merah | sama, warna `income`/`expense` |
| 526 | tap baris → `_showActionSheet` | `AppListRow.onTap` |
| 560 | "Modal: Rp …" | subtitle `'{type} · Modal: Rp …'` |
| 580–585 | FAB plus → `_showAddInvestmentSheet` | `AppNavAction.add` (aturan G3) |

### Tabel warna

| Lama | Baru |
|---|---|
| `Colors.grey.shade50` (latar, field) | `AppColors.background` (dari `AppPageScaffold`) / field bawaan `AppTextField` |
| gradien `Colors.blue.shade800 → 600` | `AppHeroCard` (gradien hero standar) |
| `Colors.blue.shade50/700` (tile ikon) | `AppIconTile(color: AppColors.primary)` |
| `Colors.green` / `Colors.red` (top up/jual, return) | `AppColors.income` / `AppColors.expense` |
| `Colors.greenAccent/redAccent` (pill return di hero) | teks & ikon `Colors.white` di pill putih 18% |
| `Colors.blue` / `Colors.blue.shade*` (update nilai) | `AppColors.primary` |
| `Colors.grey` (hapus portofolio) | `AppColors.tintGray` (ikon) / `AppColors.textSecondary` (teks) |

- [ ] **Step 1: Tulis test gagal untuk `AppWalletSelectRow`**

`test/widgets/app_wallet_select_row_test.dart`:

```dart
import 'package:catat_uang_app/widgets/app_wallet_select_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  final wallets = [
    {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#4A6CF7'},
    {'id': 2, 'name': 'GoPay', 'balance': 1850000, 'color': '#F0913A'},
  ];

  testWidgets('menampilkan dompet terpilih beserta saldonya', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: AppWalletSelectRow(header: 'Sumber Dana', wallets: wallets, selectedId: 1, onChanged: (_) {})),
    );
    expect(find.text('SUMBER DANA'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Rp 9.300.000'), findsOneWidget);
  });

  testWidgets('menampilkan label kosong bila belum ada dompet', (tester) async {
    await pumpApp(tester, Scaffold(body: AppWalletSelectRow(wallets: const [], selectedId: null, onChanged: (_) {})));
    expect(find.text('Belum ada dompet'), findsOneWidget);
  });

  testWidgets('ketuk baris membuka pemilih dan memilih dompet lain', (tester) async {
    int? picked;
    await pumpApp(
      tester,
      Scaffold(body: AppWalletSelectRow(wallets: wallets, selectedId: 1, onChanged: (v) => picked = v)),
    );
    await tester.tap(find.text('BCA'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Dompet'), findsOneWidget);
    await tester.tap(find.text('GoPay').last);
    await tester.pumpAndSettle();
    expect(picked, 2);
  });
}
```

Catatan: `AppGroupedSection` menampilkan header dalam HURUF BESAR (spec §6), jadi test mencari `'SUMBER DANA'`. Bila implementasi B1 meng-uppercase lewat `TextStyle` dan bukan string, ganti pencarian menjadi `find.text('Sumber Dana')` dan catat di laporan.

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/widgets/app_wallet_select_row_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:catat_uang_app/widgets/app_wallet_select_row.dart'`.

- [ ] **Step 3: Implementasi `AppWalletSelectRow`**

`lib/widgets/app_wallet_select_row.dart`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Warna dompet dari data (`wallets.color`, format `#RRGGBB`); fallback ke
/// primary bila kosong/rusak.
Color walletColorOf(Map<String, dynamic> wallet) {
  final raw = wallet['color']?.toString();
  if (raw == null || !raw.startsWith('#') || raw.length != 7) return AppColors.primary;
  final parsed = int.tryParse(raw.replaceFirst('#', '0xFF'));
  return parsed == null ? AppColors.primary : Color(parsed);
}

/// Baris pemilih dompet gaya iOS (pengganti DropdownButton): menampilkan
/// dompet terpilih + saldo; ketuk membuka sheet daftar dompet.
class AppWalletSelectRow extends StatelessWidget {
  const AppWalletSelectRow({
    required this.wallets,
    required this.selectedId,
    required this.onChanged,
    this.header,
    this.placeholder = 'Pilih Dompet...',
    this.emptyLabel = 'Belum ada dompet',
    super.key,
  });

  final List<Map<String, dynamic>> wallets;
  final int? selectedId;
  final ValueChanged<int> onChanged;
  final String? header;
  final String placeholder;
  final String emptyLabel;

  Map<String, dynamic>? get _selected {
    for (final w in wallets) {
      if (w['id'] == selectedId) return w;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showAppFormSheet<int>(
      context: context,
      title: 'Pilih Dompet',
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final w in wallets)
            AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: walletColorOf(w), filled: true),
              title: w['name'].toString(),
              value: formatRupiah(w['balance'] as num),
              trailing: w['id'] == selectedId
                  ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(sheetContext, w['id'] as int),
            ),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final isEmpty = wallets.isEmpty;
    return AppGroupedSection(
      header: header,
      children: [
        AppListRow(
          leading: AppIconTile(
            icon: PhosphorIconsFill.wallet,
            color: selected != null ? walletColorOf(selected) : AppColors.tintGray,
            filled: selected != null,
          ),
          title: selected?['name']?.toString() ?? (isEmpty ? emptyLabel : placeholder),
          titleColor: selected == null ? AppColors.textSecondary : null,
          value: selected != null ? formatRupiah(selected['balance'] as num) : null,
          showChevron: !isEmpty,
          onTap: isEmpty ? null : () => _openPicker(context),
        ),
      ],
    );
  }
}
```

Catatan: hapus import `app_text_styles.dart` bila analyzer melaporkan unused.

- [ ] **Step 4: Jalankan test komponen, pastikan lulus**

Run: `flutter test test/widgets/app_wallet_select_row_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Tulis test gagal untuk Investasi**

`test/screens/investment/investment_screen_test.dart`:

```dart
import 'package:catat_uang_app/models/investment_model.dart';
import 'package:catat_uang_app/providers/investment_provider.dart';
import 'package:catat_uang_app/screens/investment/investment_screen.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class FakeInvestmentNotifier extends InvestmentNotifier {
  FakeInvestmentNotifier(this.initial);
  final InvestmentState initial;
  final List<String> calls = [];
  Exception? buySellError;

  @override
  InvestmentState build() => initial;

  @override
  Future<void> fetchData() async => calls.add('fetchData');

  @override
  Future<void> buyInvestment({required String name, required String type, required double amount, required int walletId}) async {
    calls.add('buy:$name:$type:$amount:$walletId');
  }

  @override
  Future<void> buySellInvestment({required InvestmentModel inv, required bool isBuy, required double amount, required int walletId}) async {
    calls.add('buySell:${inv.id}:$isBuy:$amount:$walletId');
    if (buySellError != null) throw buySellError!;
  }
}

InvestmentModel _inv(int id, String name, String type, double cap, double val) => InvestmentModel(
      id: id, userId: 'u1', name: name, type: type, capitalAmount: cap, currentValue: val, createdAt: DateTime(2026, 9, 1));

final _wallets = [
  {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#4A6CF7'},
];

InvestmentState _state({List<InvestmentModel>? investments}) {
  // Nilai dipilih supaya persen tepat di 2 desimal (hindari pembulatan float 18.125).
  final invs = investments ?? [_inv(1, 'Saham BBCA', 'Saham', 8000000, 9440000), _inv(2, 'Bitcoin', 'Kripto', 1200000, 1149600)];
  final cap = invs.fold<double>(0, (s, i) => s + i.capitalAmount);
  final val = invs.fold<double>(0, (s, i) => s + i.currentValue);
  return InvestmentState(isLoading: false, investments: invs, wallets: _wallets, totalCapital: cap, totalValue: val);
}

void main() {
  testWidgets('menampilkan hero, portofolio, dan persentase untung/rugi', (tester) async {
    final fake = FakeInvestmentNotifier(_state());
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Investasi'), findsOneWidget);
    expect(find.text('Total Nilai Investasi'), findsOneWidget);
    expect(find.text('Rp 10.589.600'), findsOneWidget); // total nilai
    expect(find.text('Saham BBCA'), findsOneWidget);
    expect(find.text('+18.00%'), findsOneWidget);
    expect(find.text('-4.20%'), findsOneWidget);
  });

  testWidgets('empty state saat belum ada aset', (tester) async {
    final fake = FakeInvestmentNotifier(_state(investments: const []));
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();
    expect(find.text('Belum ada aset investasi.'), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet Investasi Baru dan validasi kolom kosong', (tester) async {
    final fake = FakeInvestmentNotifier(_state());
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();

    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();
    expect(find.text('Investasi Baru'), findsOneWidget);

    await tester.tap(find.text('Beli Aset'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi!'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('buy:')), isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('jual gagal tetap di sheet dan menampilkan pesan', (tester) async {
    final fake = FakeInvestmentNotifier(_state())
      ..buySellError = Exception('Nominal penarikan melebihi nilai aset saat ini!');
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();

    await tester.tap(find.text('Saham BBCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jual Aset (Withdraw)'));
    await tester.pumpAndSettle();
    expect(find.text('Jual: Saham BBCA'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(AppAmountField), matching: find.byType(EditableText)),
      '20000000',
    );
    await tester.tap(find.text('Proses Penjualan'));
    await tester.pump();

    expect(fake.calls, contains('buySell:1:false:20000000.0:1'));
    expect(find.text('Nominal penarikan melebihi nilai aset saat ini!'), findsOneWidget);
    expect(find.text('Jual: Saham BBCA'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
```

- [ ] **Step 6: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/investment/investment_screen_test.dart`
Expected: FAIL — `find.byType(AppPageScaffold)` tidak ditemukan (screen masih `Scaffold` lama) dan `AppNavAction` tidak ada.

- [ ] **Step 7: Tulis ulang `InvestmentScreen`**

Ganti seluruh isi file `lib/screens/investment/investment_screen.dart` dengan kode berikut (file ini ditulis ulang penuh karena seluruh isinya UI; logika pemanggilan provider disalin persis dari tabel preservasi):

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/investment_model.dart';
import 'package:catat_uang_app/providers/investment_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:catat_uang_app/widgets/app_wallet_select_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InvestmentScreen extends ConsumerWidget {
  const InvestmentScreen({super.key});

  static final _inputFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  void _showAddInvestmentSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final amountController = TextEditingController();
    final wallets = ref.read(investmentProvider).wallets;
    int? selectedWalletId = wallets.isNotEmpty ? wallets.first['id'] as int : null;
    bool isSubmitting = false;

    showAppFormSheet(
      context: context,
      title: 'Investasi Baru',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppAmountField(controller: amountController, label: 'Modal Awal', color: AppColors.primary),
            const SizedBox(height: 14),
            const _FieldLabel('Nama Aset (Misal: Saham BBCA, Emas Antam)'),
            AppTextField(controller: nameController, hint: 'Saham BBCA'),
            const SizedBox(height: 14),
            const _FieldLabel('Jenis (Misal: Saham, Reksadana, Kripto)'),
            AppTextField(controller: typeController, hint: 'Saham'),
            const SizedBox(height: 14),
            AppWalletSelectRow(
              header: 'Sumber Dana',
              wallets: wallets,
              selectedId: selectedWalletId,
              onChanged: (v) => setSheetState(() => selectedWalletId = v),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Beli Aset',
              loading: isSubmitting,
              onPressed: () async {
                if (nameController.text.isEmpty || typeController.text.isEmpty || amountController.text.isEmpty) {
                  AppNotification.error(sheetContext, "Semua kolom wajib diisi!");
                  return;
                }
                if (selectedWalletId == null) {
                  AppNotification.error(sheetContext, "Pilih dompet!");
                  return;
                }
                final amount = parseRupiah(amountController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  await ref.read(investmentProvider.notifier).buyInvestment(
                        name: nameController.text.trim(),
                        type: typeController.text.trim(),
                        amount: amount,
                        walletId: selectedWalletId!,
                      );
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    AppNotification.success(sheetContext, "Investasi berhasil dibeli!");
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, e.toString().replaceFirst('Exception: ', ''));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, InvestmentModel inv) {
    showAppFormSheet(
      context: context,
      title: inv.name,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(inv.type, style: AppTextStyles.subhead, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          AppGroupedSection(
            children: [
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.plusCircle, color: AppColors.income),
                title: "Beli Tambahan (Top Up)",
                showChevron: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBuySellSheet(context, ref, inv, true);
                },
              ),
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.minusCircle, color: AppColors.expense),
                title: "Jual Aset (Withdraw)",
                showChevron: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBuySellSheet(context, ref, inv, false);
                },
              ),
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.arrowsClockwise, color: AppColors.primary),
                title: "Update Nilai Terkini",
                subtitle: "Sesuaikan dengan harga pasar saat ini",
                showChevron: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showUpdateValueSheet(context, ref, inv);
                },
              ),
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.trash, color: AppColors.tintGray),
                title: "Hapus Portofolio",
                titleColor: AppColors.textSecondary,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(investmentProvider.notifier).deleteInvestment(inv.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBuySellSheet(BuildContext context, WidgetRef ref, InvestmentModel inv, bool isBuy) {
    final amountController = TextEditingController();
    final wallets = ref.read(investmentProvider).wallets;
    int? selectedWalletId = wallets.isNotEmpty ? wallets.first['id'] as int : null;
    bool isSubmitting = false;
    final color = isBuy ? AppColors.income : AppColors.expense;

    showAppFormSheet(
      context: context,
      title: isBuy ? "Top Up: ${inv.name}" : "Jual: ${inv.name}",
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppAmountField(controller: amountController, label: 'Nominal (Rp)', color: color, autofocus: true),
            const SizedBox(height: 14),
            AppWalletSelectRow(
              header: isBuy ? "Sumber Dana" : "Masuk ke Dompet",
              wallets: wallets,
              selectedId: selectedWalletId,
              onChanged: (v) => setSheetState(() => selectedWalletId = v),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: isBuy ? "Proses Pembelian" : "Proses Penjualan",
              color: color,
              loading: isSubmitting,
              onPressed: () async {
                if (amountController.text.isEmpty) return;
                if (selectedWalletId == null) return;
                final amount = parseRupiah(amountController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  await ref.read(investmentProvider.notifier).buySellInvestment(
                        inv: inv,
                        isBuy: isBuy,
                        amount: amount,
                        walletId: selectedWalletId!,
                      );
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    AppNotification.success(sheetContext, isBuy ? "Top up berhasil!" : "Penjualan berhasil!");
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, e.toString().replaceFirst('Exception: ', ''));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateValueSheet(BuildContext context, WidgetRef ref, InvestmentModel inv) {
    final amountController = TextEditingController(text: _inputFormat.format(inv.currentValue).trim());
    bool isSubmitting = false;

    showAppFormSheet(
      context: context,
      title: "Update Nilai: ${inv.name}",
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                "Update nilai terkini aset sesuai harga pasar. Ini tidak akan memotong saldo dompetmu.",
                style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 14),
            AppAmountField(controller: amountController, label: 'Nilai Saat Ini (Rp)', color: AppColors.primary),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: "Simpan Pembaruan",
              loading: isSubmitting,
              onPressed: () async {
                if (amountController.text.isEmpty) return;
                final amount = parseRupiah(amountController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  await ref.read(investmentProvider.notifier).updateInvestmentValue(inv.id, amount);
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    AppNotification.success(sheetContext, "Nilai berhasil diperbarui!");
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, "Error: $e");
                  }
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
    final invState = ref.watch(investmentProvider);
    final totalCapital = invState.totalCapital;
    final totalValue = invState.totalValue;
    final investments = invState.investments;

    final double totalReturn = totalCapital > 0 ? ((totalValue - totalCapital) / totalCapital) * 100 : 0;
    final bool isProfit = totalValue >= totalCapital;

    return AppPageScaffold(
      title: 'Investasi',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: () => _showAddInvestmentSheet(context, ref))],
      onRefresh: () => ref.read(investmentProvider.notifier).fetchData(),
      children: invState.isLoading
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ]
          : [
              AppHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppHeroLabel('Total Nilai Investasi'),
                    const SizedBox(height: 4),
                    AppHeroAmount(formatRupiah(totalValue)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppHeroLabel('Total Modal'),
                              const SizedBox(height: 2),
                              Text(
                                formatRupiah(totalCapital),
                                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        _ReturnPill(percent: totalReturn, isProfit: isProfit),
                      ],
                    ),
                  ],
                ),
              ),
              if (investments.isEmpty)
                const AppEmptyState(icon: PhosphorIconsRegular.chartLineUp, title: 'Belum ada aset investasi.')
              else
                AppGroupedSection(
                  header: 'Daftar Portofolio',
                  children: [
                    for (final inv in investments)
                      _InvestmentRow(inv: inv, onTap: () => _showActionSheet(context, ref, inv)),
                  ],
                ),
            ],
    );
  }
}

class _ReturnPill extends StatelessWidget {
  const _ReturnPill({required this.percent, required this.isProfit});

  final double percent;
  final bool isProfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isProfit ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            "${isProfit ? '+' : ''}${percent.toStringAsFixed(2)}%",
            style: AppTextStyles.subhead.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InvestmentRow extends StatelessWidget {
  const _InvestmentRow({required this.inv, required this.onTap});

  final InvestmentModel inv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double ret = inv.capitalAmount > 0 ? ((inv.currentValue - inv.capitalAmount) / inv.capitalAmount) * 100 : 0;
    final bool profit = inv.currentValue >= inv.capitalAmount;
    return AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsFill.chartLineUp, color: AppColors.primary),
      title: inv.name,
      subtitle: '${inv.type} · Modal: ${formatRupiah(inv.capitalAmount)}',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatRupiah(inv.currentValue), style: AppTextStyles.amountRow),
          const SizedBox(height: 2),
          Text(
            "${profit ? '+' : ''}${ret.toStringAsFixed(2)}%",
            style: AppTextStyles.caption.copyWith(
              color: profit ? AppColors.income : AppColors.expense,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text, style: AppTextStyles.subhead),
    );
  }
}
```

Catatan perubahan perilaku yang disengaja (catat di laporan):
- Guard `isSubmitting` pada tiga tombol simpan sheet (mencegah dobel tap = dobel beli — kelas bug yang tercatat di reviewer). Tidak ada pesan/validasi yang hilang.
- `AppNotification` dipanggil dengan `sheetContext` (overlay sama) — pesan identik.
- `_inputFormat.format(...).trim()` — `NumberFormat.currency(symbol: '')` bisa menyisakan spasi non-breaking di depan/belakang; `trim()` mencegah `RupiahInputFormatter` menolak karakter itu. Bila formatter B1 sudah membuang non-digit, `trim()` tetap aman.

- [ ] **Step 8: Jalankan test Investasi**

Run: `flutter test test/screens/investment/investment_screen_test.dart test/widgets/app_wallet_select_row_test.dart`
Expected: PASS (4 + 3 test). Bila `find.text('+18.00%')` gagal karena B1 `AppListRow` memotong trailing, periksa layout — jangan ubah string format.

- [ ] **Step 9: Cek Poppins, hex, analyze**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/investment/investment_screen.dart
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange|greenAccent|redAccent)" lib/screens/investment/investment_screen.dart lib/widgets/app_wallet_select_row.dart
flutter analyze lib/screens/investment lib/widgets/app_wallet_select_row.dart
```
Expected: `0`; grep warna tidak menghasilkan baris; analyze tanpa error/warning baru.

- [ ] **Step 10: Checklist visual vs mockup "Investasi"** (skill `run-and-screenshot`)

- [ ] Nav bar: `‹ Beranda` kiri (primary), `+` kanan; tidak ada FAB.
- [ ] Judul besar "Investasi" rata kiri.
- [ ] Kartu hero gradien biru: "Total Nilai Investasi", nominal besar putih, baris "Total Modal" + pill putih transparan berisi ikon tren + persen.
- [ ] Label grup "DAFTAR PORTOFOLIO" lalu grouped list putih: tile ikon chart biru muda, nama tebal, subjudul "Saham · Modal: Rp …", kanan nominal tebal + persen hijau/merah kecil.
- [ ] Ketuk baris → sheet (grabber, "Batal" kiri, judul nama aset) berisi 4 baris aksi grouped list.
- [ ] Sheet Top Up/Jual/Update: nominal besar di tengah, pemilih dompet grouped list, tombol penuh di bawah (hijau untuk top up, merah untuk jual, biru untuk update).
- [ ] Empty state: ikon abu besar + "Belum ada aset investasi."

- [ ] **Step 11: Commit**

```bash
git add lib/widgets/app_wallet_select_row.dart test/widgets/app_wallet_select_row_test.dart lib/screens/investment/investment_screen.dart test/screens/investment/investment_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(investment): redesign investment screen to iOS layout

Adds AppWalletSelectRow, an iOS-style wallet picker used in place of
dropdowns, and a submit guard on the buy/sell/update sheets.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

Catatan untuk koordinator (bukan bagian task): "Hapus Portofolio" tetap tanpa dialog konfirmasi seperti kode lama. Bila user ingin konfirmasi (sesuai semangat G12), itu perubahan perilaku kecil yang perlu persetujuan.

---

## Task 2: Redesign Zakat & Sedekah

**Files:**
- Modify: `lib/screens/zakat_sedekah/zakat_sedekah_screen.dart` (baris 1–596; logika `_fetchWallets`, `_getOrCreateCategory`, `_processPayment` dipertahankan)
- Create: `test/screens/zakat_sedekah/zakat_sedekah_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold`, `AppSegmentedControl`, `AppCallout`, `AppSurfaceCard`, `AppAmountField`, `AppHeroCard`, `AppHeroLabel`, `AppHeroAmount`, `AppGroupedSection`, `AppTextField`, `AppPrimaryButton`, `AppWalletSelectRow` (Task 1), `formatRupiah`, `AppTextStyles`, `AppColors`, `pumpApp`.
- Produces: tidak ada API baru. Seam: `SupabaseClient get _supabase => Supabase.instance.client;` (sebelumnya field yang dievaluasi saat State dibuat — membuat widget test crash).

### Tabel preservasi — `lib/screens/zakat_sedekah/zakat_sedekah_screen.dart`

| Baris lama | Perilaku / label | Kode baru |
|---|---|---|
| 18 | `_isZakat = true` default | sama |
| 19 | `final SupabaseClient _supabase = Supabase.instance.client;` | **getter** `SupabaseClient get _supabase => Supabase.instance.client;` (seam test) |
| 45 | `_fetchWallets()` di `initState` | sama |
| 47–59 | listener harta → `_calculatedZakat = amount * 0.025` (2.5% zakat maal) | sama persis |
| 62–68 | dispose tiga controller | sama |
| 70–90 | ambil dompet (order name), default dompet pertama bila belum dipilih, `mounted` check | sama persis |
| 92–118 | `_getOrCreateCategory` (is_expense true, ilike, insert icon) | sama persis |
| 121–124 | tanpa dompet → "Anda belum membuat dompet." | sama |
| 125–128 | dompet null → "Pilih dompet sumber dana!" | sama |
| 136–139 | zakat ≤ 0 → "Masukkan total harta yang valid!" | sama |
| 140–143 | note "Pembayaran Zakat Maal (2.5% dari harta)", kategori "Zakat", ikon "hand-heart" | sama |
| 145–153 | sedekah kosong/≤0 → "Masukkan nominal sedekah yang valid!"; note default "Sedekah"; kategori "Sedekah", ikon "hand-coins" | sama |
| 157–162 | saldo kurang → "Saldo dompet tidak mencukupi!" | sama |
| 164–194 | loading, insert transaksi, update saldo, sukses "$categoryName berhasil dibayarkan! Semoga berkah." + `Navigator.pop(context, true)`, error "Gagal memproses pembayaran: $e", finally loading false | sama persis |
| 203 | judul "Zakat & Sedekah" | `AppPageScaffold(title:)` |
| 230–231, 244–283 | toggle "Zakat" / "Sedekah" (hijau/biru) | `AppSegmentedControl` (teks terpilih `textPrimary`, aturan G11) |
| 304 | info zakat (hijau) | `AppCallout(tone: info)` teks sama persis |
| 314 | "Total Harta Anda (Rp)" | label `AppAmountField` |
| 343–354 | hint "0", format ribuan saat mengetik | `AppAmountField` (placeholder & `RupiahInputFormatter` dari B1) |
| 379, 384 | "Zakat yang Harus Dibayar" + nominal | `AppHeroCard` |
| 392, 511, 534–595 | pemilih dompet: label "Pilih Dompet Sumber Dana", hint "Belum ada dompet"/"Pilih Dompet...", ikon dompet warna data, saldo di kanan | `AppWalletSelectRow(header: 'Pilih Dompet Sumber Dana')` |
| 395–409, 514–528 | tombol "Bayar Zakat"/"Bayar Sedekah"; spinner saat `_isLoading` | `AppPrimaryButton(loading: _isLoading)` di `bottomBar` |
| 434 | info sedekah (biru, ikon handHeart) | `AppCallout` ikon `PhosphorIconsFill.handHeart` |
| 444 | "Nominal Sedekah (Rp)" | label `AppAmountField` |
| 489, 500 | "Catatan / Niat (Opsional)", hint "Misal: Sedekah Jumat, Untuk Masjid, dll", 2 baris | `AppGroupedSection(header:)` + `AppTextField(maxLines: 2)` |

### Tabel warna

| Lama | Baru |
|---|---|
| `Colors.grey.shade50` (latar) | `AppColors.background` (`AppPageScaffold`) |
| `Colors.green.shade50/600/900`, `Colors.blue.shade50/600/900` (kotak info) | `AppCallout(tone: AppCalloutTone.info)` |
| gradien `Colors.green.shade600 → 400` | `AppHeroCard` |
| `Colors.green.shade600` / `Colors.blue.shade600` (tombol) | `AppPrimaryButton` (primary) |
| `Colors.green.shade700` / `Colors.blue.shade700` (teks toggle) | `AppColors.textPrimary` (default `AppSegmentedControl`) |
| `Colors.grey*` (label) | `AppTextStyles.subhead` / `groupLabel` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/zakat_sedekah/zakat_sedekah_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

// Supabase tidak diinisialisasi di test: _fetchWallets gagal di dalam
// try/catch-nya sendiri (seam: _supabase adalah getter), jadi daftar
// dompet kosong — cukup untuk menguji kalkulasi & validasi di layar.
void main() {
  testWidgets('zakat 2.5% dihitung dari total harta', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Zakat & Sedekah'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(AppAmountField), matching: find.byType(EditableText)),
      '100000000',
    );
    await tester.pump();

    expect(find.text('Zakat yang Harus Dibayar'), findsOneWidget);
    expect(find.text('Rp 2.500.000'), findsOneWidget);
  });

  testWidgets('pindah ke tab Sedekah mengganti isi dan tombol', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();

    await tester.tap(find.text('Sedekah'));
    await tester.pump();

    expect(find.text('Nominal Sedekah (Rp)'), findsOneWidget);
    expect(find.text('Misal: Sedekah Jumat, Untuk Masjid, dll'), findsOneWidget);
    expect(find.text('Bayar Sedekah'), findsOneWidget);
    expect(find.text('Zakat yang Harus Dibayar'), findsNothing);
  });

  testWidgets('bayar zakat tanpa dompet menampilkan pesan', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();

    expect(find.text('Belum ada dompet'), findsOneWidget);
    await tester.tap(find.text('Bayar Zakat'));
    await tester.pump();

    expect(find.text('Anda belum membuat dompet.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/zakat_sedekah/zakat_sedekah_screen_test.dart`
Expected: FAIL — error Supabase belum diinisialisasi saat membuat State (field `_supabase`), dan/atau `AppPageScaffold` tidak ditemukan.

- [ ] **Step 3: Terapkan seam dan tulis ulang UI**

1. Ganti import di baris 1–8 menjadi:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:catat_uang_app/widgets/app_wallet_select_row.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

2. Baris 19: ganti `final SupabaseClient _supabase = Supabase.instance.client;` dengan
```dart
  SupabaseClient get _supabase => Supabase.instance.client;
```

3. Hapus field `_currencyFormat` (baris 25–29) dan `_plainCurrencyFormat` (baris 31–35) — diganti `formatRupiah` dan formatter `AppAmountField`. `DateFormat` di `_processPayment` tetap memakai `intl`.

4. Metode `_fetchWallets`, `_getOrCreateCategory`, `_processPayment` (baris 70–195) **tidak diubah sama sekali**.

5. Ganti `build`, `_buildToggleBtn`, `_buildZakatTab`, `_buildSedekahTab`, `_buildWalletSelector` (baris 197–595) dengan:

```dart
  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Zakat & Sedekah',
      backLabel: 'Beranda',
      bottomBar: AppPrimaryButton(
        label: _isZakat ? 'Bayar Zakat' : 'Bayar Sedekah',
        loading: _isLoading,
        onPressed: () => _processPayment(isZakat: _isZakat),
      ),
      children: [
        AppSegmentedControl(
          labels: const ['Zakat', 'Sedekah'],
          selectedIndex: _isZakat ? 0 : 1,
          onChanged: (index) {
            final wantZakat = index == 0;
            if (_isZakat != wantZakat) {
              setState(() => _isZakat = wantZakat);
            }
          },
        ),
        if (_isZakat) ..._buildZakatSection() else ..._buildSedekahSection(),
        AppWalletSelectRow(
          header: 'Pilih Dompet Sumber Dana',
          wallets: _wallets,
          selectedId: _selectedWalletId,
          onChanged: (val) => setState(() => _selectedWalletId = val),
        ),
      ],
    );
  }

  List<Widget> _buildZakatSection() {
    return [
      AppCallout(
        icon: PhosphorIconsFill.info,
        child: Text(
          "Kalkulator Zakat Maal secara otomatis menghitung 2.5% dari total harta (emas, perak, uang tunai, tabungan) yang telah mencapai nisab.",
          style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, height: 1.5),
        ),
      ),
      AppSurfaceCard(
        child: AppAmountField(controller: _zakatWealthController, label: 'Total Harta Anda (Rp)'),
      ),
      AppHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeroLabel('Zakat yang Harus Dibayar'),
            const SizedBox(height: 6),
            AppHeroAmount(formatRupiah(_calculatedZakat)),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSedekahSection() {
    return [
      AppCallout(
        icon: PhosphorIconsFill.handHeart,
        child: Text(
          "Sedekah tidak akan mengurangi harta, melainkan menambah keberkahannya. Yuk sedekah hari ini!",
          style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, height: 1.5),
        ),
      ),
      AppSurfaceCard(
        child: AppAmountField(controller: _sedekahAmountController, label: 'Nominal Sedekah (Rp)'),
      ),
      AppGroupedSection(
        header: 'Catatan / Niat (Opsional)',
        children: [
          AppTextField(
            controller: _sedekahNoteController,
            hint: 'Misal: Sedekah Jumat, Untuk Masjid, dll',
            maxLines: 2,
          ),
        ],
      ),
    ];
  }
}
```

Catatan: tombol di `bottomBar` sekarang satu untuk kedua tab (labelnya mengikuti tab) — setara dengan dua tombol lama karena hanya satu tab tampil sekaligus. `_processPayment(isZakat: _isZakat)` sama dengan pemanggilan lama per tab.

- [ ] **Step 4: Jalankan test**

Run: `flutter test test/screens/zakat_sedekah/zakat_sedekah_screen_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Cek Poppins, hex, analyze**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/zakat_sedekah/zakat_sedekah_screen.dart
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange)" lib/screens/zakat_sedekah/zakat_sedekah_screen.dart
flutter analyze lib/screens/zakat_sedekah
```
Expected: `0`; tidak ada baris; tanpa error/warning baru (import `colors.dart` dipakai oleh `AppColors.textPrimary`).

- [ ] **Step 6: Checklist visual vs mockup "Zakat & Sedekah"**

- [ ] Nav `‹ Beranda`, judul besar "Zakat & Sedekah".
- [ ] Segmented iOS "Zakat | Sedekah" (track abu, pill putih).
- [ ] Callout info biru muda dengan ikon info.
- [ ] Kartu putih berisi nominal besar ("Total Harta Anda (Rp)").
- [ ] Kartu hero gradien biru "Zakat yang Harus Dibayar" + nominal besar putih.
- [ ] Label grup "PILIH DOMPET SUMBER DANA" + satu baris dompet (ikon filled warna dompet, nama, saldo abu, chevron).
- [ ] Tombol penuh "Bayar Zakat"/"Bayar Sedekah" menempel di bawah; spinner saat memproses.
- [ ] Tab Sedekah: callout hati, nominal, grup catatan 2 baris.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/zakat_sedekah/zakat_sedekah_screen.dart test/screens/zakat_sedekah/zakat_sedekah_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(zakat): redesign zakat and sedekah screen to iOS layout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

## Task 3: Redesign Kalender

**Files:**
- Modify: `lib/screens/calendar/calendar_screen.dart` (method `build`, baris 45–457; `_getCategoryIcon` baris 28–43 tetap)
- Create: `test/screens/calendar/calendar_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold`, `AppSurfaceCard`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppChip`, `AppEmptyState`, `formatRupiah`, `AppTextStyles`, `AppColors` (`primary`, `primarySoft`, `expense`, `income`, `tintGray`, `textSecondary`), `pumpApp`.
- Consumes (provider, TIDAK diubah): `calendarProvider`, `CalendarState(groupedTransactions, savingNames, walletNames, walletColors, isLoading)`, `CalendarState.eventsForDay`, `normalizeCalendarDate`.
- Produces: tidak ada.

### Tabel preservasi — `lib/screens/calendar/calendar_screen.dart`

| Baris lama | Perilaku / label | Kode baru |
|---|---|---|
| 19–26 | `_focusedDay = now`, `_selectedDay = _focusedDay` | sama |
| 28–43 | `_getCategoryIcon` (makan, minum/kopi, transport/bensin, belanja, hiburan, kesehatan, tagihan/listrik, gaji, bonus, default tag) | tidak diubah |
| 47–48 | watch provider, `eventsForDay(_selectedDay!)` | sama |
| 56–64 | total harian income/expense (`category?.isExpense ?? true`) | sama |
| 70 | judul "Kalender Keuangan" | `AppPageScaffold(title: 'Kalender Keuangan')` |
| 84–85 | loading → spinner | spinner di children |
| 102–107 | rentang 2020-01-01 s/d 2030-12-31 (UTC), `selectedDayPredicate`, mulai Senin | sama |
| 108–123 | today = lingkaran primary 20%, selected = lingkaran primary, weekend merah | today `primarySoft`, selected `primary`, weekend `expense` |
| 124–139 | header bawaan (judul tengah, chevron kiri/kanan primary) | header kustom (judul bulan kiri, dua chevron kanan) + `headerVisible: false` |
| 140 | `eventLoader: state.eventsForDay` | sama |
| 141–148 | `onDaySelected` hanya bila hari berbeda: set selected & focused | sama persis |
| 150–191 | marker: titik hijau (ada pemasukan) & merah (ada pengeluaran) 5px | sama (posisi `bottom: 4`) |
| — (baru) | `onPageChanged` → `_focusedDay` | **tambahan wajib**: header kustom harus mengikuti swipe halaman |
| 208–211 | tanggal terpilih `'EEEE, d MMM yyyy', 'id_ID'` | sama, gaya `headline` |
| 237, 268 | kotak "Masuk" (hijau) & "Keluar" (merah) + nominal | `_DailyTotalTile` |
| 295–315 | kosong → ikon coffee + "Tidak ada transaksi hari ini" | `AppEmptyState` |
| 327–344 | ganti `[SAVING_ID:x]` jadi "(Sumber: nama)", kosong → "Tanpa catatan" | sama persis |
| 347–351 | badge dompet: nama atau "Kas Utama", warna dompet atau abu | `AppChip(color: wColor ?? AppColors.tintGray)` |
| 396 | nama kategori atau "Umum" | sama |
| 437–439 | "- Rp …" / "+ Rp …" merah/hijau | sama (format `formatRupiah`) |

### Tabel warna

| Lama | Baru |
|---|---|
| `Colors.grey.shade50` (latar) | `AppColors.background` |
| `Colors.white` + bayangan (kalender, kartu) | `AppSurfaceCard` / `AppGroupedSection` |
| `AppColors.primary.withOpacity(0.2)` (today) | `AppColors.primarySoft` |
| `Colors.red` (weekend) | `AppColors.expense` |
| `Colors.grey` (badge dompet fallback) | `AppColors.tintGray` |
| `Colors.grey.shade300` (ikon empty) | `AppEmptyState` |

- [ ] **Step 1: Tulis test gagal**

`test/screens/calendar/calendar_screen_test.dart`:

```dart
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/calendar_provider.dart';
import 'package:catat_uang_app/screens/calendar/calendar_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class FakeCalendarNotifier extends CalendarNotifier {
  FakeCalendarNotifier(this.initial);
  final CalendarState initial;

  @override
  CalendarState build() => initial;
}

TransactionModel _trx({required int id, required String cat, required bool isExpense, required double amount, String? note}) {
  return TransactionModel(
    id: id,
    userId: 'u1',
    categoryId: id,
    amount: amount,
    date: DateTime.now(),
    note: note,
    category: CategoryModel(id: id, name: cat, isExpense: isExpense, iconName: 'tag'),
    walletId: 1,
  );
}

CalendarState _state(List<TransactionModel> today) => CalendarState(
      isLoading: false,
      groupedTransactions: {normalizeCalendarDate(DateTime.now()): today},
      walletNames: const {1: 'BCA'},
      walletColors: const {1: Color(0xFF4A6CF7)},
    );

void main() {
  testWidgets('menampilkan kalender, total harian, dan transaksi hari ini', (tester) async {
    final fake = FakeCalendarNotifier(_state([
      _trx(id: 1, cat: 'Makan', isExpense: true, amount: 45000, note: 'Nasi Padang'),
      _trx(id: 2, cat: 'Gaji', isExpense: false, amount: 8000000),
    ]));
    await pumpApp(tester, const CalendarScreen(), overrides: [calendarProvider.overrideWith(() => fake)]);
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Kalender Keuangan'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.now())), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('- Rp 45.000'), findsOneWidget);
    expect(find.text('+ Rp 8.000.000'), findsOneWidget);
    expect(find.text('Tanpa catatan'), findsOneWidget);
    expect(find.text('BCA'), findsNWidgets(2));
  });

  testWidgets('empty state saat hari terpilih tanpa transaksi', (tester) async {
    final fake = FakeCalendarNotifier(_state(const []));
    await pumpApp(tester, const CalendarScreen(), overrides: [calendarProvider.overrideWith(() => fake)]);
    await tester.pump();
    expect(find.text('Tidak ada transaksi hari ini'), findsOneWidget);
  });

  testWidgets('chevron kanan memindah judul bulan', (tester) async {
    final fake = FakeCalendarNotifier(_state(const []));
    await pumpApp(tester, const CalendarScreen(), overrides: [calendarProvider.overrideWith(() => fake)]);
    await tester.pump();

    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, 1);
    await tester.tap(find.byIcon(PhosphorIconsBold.caretRight));
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(next)), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/calendar/calendar_screen_test.dart`
Expected: FAIL — `AppPageScaffold` tidak ditemukan; ikon `caretRight` tidak ada.

- [ ] **Step 3: Tulis ulang `build` + helper**

Ganti import baris 1–9 dengan:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/calendar_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
```

Ganti `build` (baris 45–457) dengan kode berikut dan tambahkan method/kelas helper di bawahnya:

```dart
  static final DateTime _firstDay = DateTime.utc(2020, 1, 1);
  static final DateTime _lastDay = DateTime.utc(2030, 12, 31);

  void _goToMonth(int delta) {
    final target = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
    final lastOfTarget = DateTime(target.year, target.month + 1, 0);
    if (lastOfTarget.isBefore(_firstDay) || target.isAfter(_lastDay)) return;
    setState(() => _focusedDay = target);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final selectedTransactions = state.eventsForDay(_selectedDay!);

    double dailyIncome = 0;
    double dailyExpense = 0;
    for (var trx in selectedTransactions) {
      if (trx.category?.isExpense ?? true) {
        dailyExpense += trx.amount;
      } else {
        dailyIncome += trx.amount;
      }
    }

    return AppPageScaffold(
      title: 'Kalender Keuangan',
      backLabel: 'Beranda',
      children: state.isLoading
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ]
          : [
              AppSurfaceCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
                            style: AppTextStyles.headline,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bulan sebelumnya',
                          icon: const Icon(PhosphorIconsBold.caretLeft, color: AppColors.primary, size: 20),
                          onPressed: () => _goToMonth(-1),
                        ),
                        IconButton(
                          tooltip: 'Bulan berikutnya',
                          icon: const Icon(PhosphorIconsBold.caretRight, color: AppColors.primary, size: 20),
                          onPressed: () => _goToMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildCalendar(state),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_selectedDay!),
                  style: AppTextStyles.headline,
                ),
              ),
              Row(
                children: [
                  Expanded(child: _DailyTotalTile(label: 'Masuk', amount: dailyIncome, color: AppColors.income)),
                  const SizedBox(width: 10),
                  Expanded(child: _DailyTotalTile(label: 'Keluar', amount: dailyExpense, color: AppColors.expense)),
                ],
              ),
              if (selectedTransactions.isEmpty)
                const AppEmptyState(icon: PhosphorIconsRegular.coffee, title: 'Tidak ada transaksi hari ini')
              else
                AppGroupedSection(
                  children: [for (final trx in selectedTransactions) _buildTransactionRow(state, trx)],
                ),
            ],
    );
  }

  Widget _buildCalendar(CalendarState state) {
    final dayStyle = AppTextStyles.body.copyWith(fontSize: 15);
    return TableCalendar<TransactionModel>(
      locale: 'id_ID',
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      headerVisible: false,
      daysOfWeekHeight: 24,
      rowHeight: 44,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        weekendStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: dayStyle,
        weekendTextStyle: dayStyle.copyWith(color: AppColors.expense),
        outsideTextStyle: dayStyle.copyWith(color: AppColors.textSecondary.withOpacity(0.5)),
        todayDecoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
        todayTextStyle: dayStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        selectedTextStyle: dayStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      eventLoader: state.eventsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        }
      },
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return const SizedBox();
          final bool hasIncome = events.any((ev) => !(ev.category?.isExpense ?? true));
          final bool hasExpense = events.any((ev) => (ev.category?.isExpense ?? true));
          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIncome) const _MarkerDot(color: AppColors.income),
                if (hasExpense) const _MarkerDot(color: AppColors.expense),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionRow(CalendarState state, TransactionModel trx) {
    final isExpense = trx.category?.isExpense ?? true;

    // Logika Bersihin Saving ID (sama persis dengan versi lama)
    String displayNote = trx.note ?? '';
    final match = RegExp(r'\[SAVING_ID:(\d+)\]').firstMatch(displayNote);
    if (match != null) {
      String sId = match.group(1)!;
      String sName = state.savingNames[sId] ?? 'Tabungan';
      displayNote = displayNote.replaceAll(match.group(0)!, '(Sumber: $sName)').trim();
    }
    if (displayNote.isEmpty) displayNote = "Tanpa catatan";

    final wId = trx.walletId;
    final wName = state.walletNames[wId] ?? 'Kas Utama';
    final wColor = state.walletColors[wId] ?? AppColors.tintGray;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return AppListRow(
      leading: AppIconTile(icon: _getCategoryIcon(trx.category?.name ?? ''), color: color, round: true),
      title: trx.category?.name ?? "Umum",
      subtitleWidget: Row(
        children: [
          Flexible(
            child: Text(displayNote, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          AppChip(label: wName, color: wColor, icon: PhosphorIconsFill.wallet),
        ],
      ),
      trailing: Text(
        (isExpense ? "- " : "+ ") + formatRupiah(trx.amount),
        style: AppTextStyles.amountRow.copyWith(color: color),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DailyTotalTile extends StatelessWidget {
  const _DailyTotalTile({required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      color: color.withOpacity(0.10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(formatRupiah(amount), style: AppTextStyles.amountRow.copyWith(color: color)),
        ],
      ),
    );
  }
}
```

Perhatikan: kurung kurawal penutup class `_CalendarScreenState` sekarang ada di akhir `_buildTransactionRow` (baris `}` sebelum `class _MarkerDot`). Pastikan tidak ada `}` ganda sisa kode lama.

Catatan perubahan perilaku (catat di laporan):
- `onPageChanged` ditambahkan — tanpanya judul bulan di header kustom tidak ikut berubah saat pengguna swipe. Ini tidak mengubah data yang dipilih.
- `locale: 'id_ID'` pada `TableCalendar` membuat nama hari jadi "Sen … Min" seperti mockup (sebelumnya bahasa Inggris). `initializeDateFormatting('id_ID')` sudah dipanggil di `main.dart` dan `pumpApp`.
- Bila Plan B2 menambah tag `[DEBT_ID:x]` di catatan transaksi, penggantian teks catatan untuk tag itu adalah wewenang B2 — jangan tambahkan di sini.

- [ ] **Step 4: Jalankan test**

Run: `flutter test test/screens/calendar/calendar_screen_test.dart`
Expected: PASS (3 test). Bila test ke-1 menemukan 'BCA' lebih/kurang dari 2, periksa bahwa dua transaksi memakai `walletId: 1` — jangan ubah logika badge.

- [ ] **Step 5: Cek Poppins, hex, analyze**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/calendar/calendar_screen.dart
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange)" lib/screens/calendar/calendar_screen.dart
flutter analyze lib/screens/calendar
```
Expected: `0`; tidak ada baris; tanpa error/warning baru.

- [ ] **Step 6: Checklist visual vs mockup "Kalender"**

- [ ] Nav `‹ Beranda`, judul besar "Kalender Keuangan".
- [ ] Kartu putih kalender: judul bulan tebal kiri, dua chevron biru di kanan; nama hari "Sen … Min" abu kecil.
- [ ] Hari terpilih = lingkaran biru solid teks putih; hari ini = lingkaran biru muda; Sabtu/Minggu merah; titik hijau/merah di bawah tanggal yang punya transaksi.
- [ ] Tanggal terpilih tebal ("Kamis, 24 Sep 2026").
- [ ] Dua kartu berdampingan "Masuk" (latar hijau muda) dan "Keluar" (latar merah muda).
- [ ] Grouped list transaksi: ikon bulat bertinta, kategori, catatan + chip dompet, nominal berwarna di kanan.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/calendar/calendar_screen.dart test/screens/calendar/calendar_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): redesign calendar screen to iOS layout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

## Task 4: Redesign Kelola Kategori (+ parameter `AppTextField.autofocus/textCapitalization`)

**Files:**
- Modify: `lib/widgets/app_text_field.dart` (tambah dua parameter opsional)
- Modify: test komponen `AppTextField` dari B1 (mis. `test/widgets/app_text_field_test.dart`; buat bila belum ada)
- Modify: `lib/screens/manage_category/manage_category_screen.dart` (method `_showInputDialog` → `_showInputSheet`, `build`, `_buildToggleBtn` dihapus; baris 70–475)
- Create: `test/screens/manage_category/manage_category_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold`, `AppNavAction.add`, `AppSegmentedControl(selectedLabelColors:)`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppEmptyState`, `AppTextField`, `AppPrimaryButton`, `showAppFormSheet`, `showAppConfirmDialog`, `AppTextStyles`, `AppColors`, `pumpApp`.
- Consumes (provider, TIDAK diubah): `categoryProvider`, `CategoryNotifier.fetchCategories({bool? isExpense})`, `addCategory(String)`, `editCategory(int, String)`, `deleteCategory(int)`, `CategoryState(categories, isExpense, isLoading)`, `CategoryModel(id, name, isExpense, iconName, userId)`.
- Produces: `AppTextField` mendapat parameter opsional `bool autofocus = false` dan `TextCapitalization textCapitalization = TextCapitalization.none` (diteruskan ke `TextField` di dalamnya).

### Tabel preservasi — `lib/screens/manage_category/manage_category_screen.dart`

| Baris lama | Perilaku / label | Kode baru |
|---|---|---|
| 14–54 | `_getCategoryIcon(name, iconName)` | tidak diubah |
| 56–68 | `_deleteCategory`: sukses "Kategori berhasil dihapus!", gagal "Gagal hapus. Kategori sedang digunakan." | tidak diubah |
| 75–79 | `isEditing`, `isExpense` dari provider, controller berisi nama lama saat edit | sama |
| 81–84 | `showDialog(barrierDismissible: false)` | `showAppFormSheet` (aturan G4) |
| 99–103 | judul "Edit Kategori" / "Tambah Pengeluaran" / "Tambah Pemasukan" | judul sheet sama persis |
| 121 | hint "Nama Kategori (Contoh: Bensin)" | `AppTextField(hint:)` |
| 148–150 | kapitalisasi kalimat, autofocus, field nonaktif saat menyimpan | `textCapitalization: sentences`, `autofocus: true`, `readOnly: isSaving` |
| 160, 168 | tombol "Batal" (nonaktif saat menyimpan) | tombol "Batal" di header sheet (lihat catatan) |
| 183 | nama kosong (trim) → return diam | sama persis |
| 184–211 | `isSaving = true` → `editCategory(id, trim)` / `addCategory(trim)` → pop + "Berhasil diubah!" / "Berhasil ditambah!"; error → `isSaving=false` + "Error: $e" | sama persis |
| 222–236 | spinner putih di tombol saat menyimpan; label "Simpan" | `AppPrimaryButton(label: 'Simpan', loading: isSaving)` |
| 258 | judul "Kelola Kategori" | `AppPageScaffold(title:)` |
| 285–286, 430–474 | toggle "Pengeluaran" / "Pemasukan" (merah/hijau), tap → `fetchCategories(isExpense:)` hanya bila berbeda | `AppSegmentedControl(selectedLabelColors: [expense, income])`, logika sama |
| 292–293 | loading → spinner | sama |
| 294–300 | kosong → "Belum ada kategori" | `AppEmptyState` |
| 306 | `isSystem = cat.userId == null` | sama |
| 322–334 | ikon bertinta merah/hijau sesuai tab | `AppIconTile(color: expense/income)` |
| 349–356 | "Bawaan Aplikasi" untuk kategori sistem | `subtitle` |
| 360–372 | pensil biru (hanya kategori user) → dialog edit | `IconButton` pensil `tintBlue` → `_showInputSheet(categoryToEdit:)` |
| 373–411 | sampah merah → dialog "Hapus Kategori?" / "Yakin mau hapus '{name}'?" / "Batal" / "Hapus" → `_deleteCategory` | `showAppConfirmDialog(...)` teks sama → `_deleteCategory` |
| 421–426 | FAB + → dialog tambah | `AppNavAction.add` |

### Tabel warna

| Lama | Baru |
|---|---|
| `Colors.blue` (pensil) | `AppColors.tintBlue` |
| `Colors.red` (sampah, teks Hapus) | `AppColors.expense` (ikon); dialog destructive bawaan `showAppConfirmDialog` |
| `Colors.grey`, `Colors.grey.shade400` | `AppTextStyles.caption/subhead` / komponen |
| `Colors.white` kartu | `AppGroupedSection` |

- [ ] **Step 1: Test gagal untuk parameter baru `AppTextField`**

Tambahkan ke `test/widgets/app_text_field_test.dart` (buat file bila B1 belum membuatnya — sertakan import di bawah):

```dart
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppTextField meneruskan autofocus dan textCapitalization', (tester) async {
    final controller = TextEditingController();
    await pumpApp(
      tester,
      Scaffold(
        body: AppTextField(
          controller: controller,
          hint: 'Nama',
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.textCapitalization, TextCapitalization.sentences);
  });
}
```

Bila file sudah ada, tambahkan hanya `testWidgets(...)` di dalam `main()` yang sudah ada.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_text_field_test.dart`
Expected: FAIL — `No named parameter with the name 'autofocus'`.

- [ ] **Step 3: Tambah parameter di `AppTextField`**

Di `lib/widgets/app_text_field.dart`:
- tambahkan ke konstruktor: `this.autofocus = false, this.textCapitalization = TextCapitalization.none,`
- tambahkan field: `final bool autofocus;` dan `final TextCapitalization textCapitalization;`
- teruskan ke `TextField` di `build`: `autofocus: autofocus, textCapitalization: textCapitalization,`

Jangan ubah perilaku parameter lain.

- [ ] **Step 4: Jalankan test komponen**

Run: `flutter test test/widgets/app_text_field_test.dart`
Expected: PASS.

- [ ] **Step 5: Tulis test gagal untuk Kelola Kategori**

`test/screens/manage_category/manage_category_screen_test.dart`:

```dart
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/category_provider.dart';
import 'package:catat_uang_app/screens/manage_category/manage_category_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class FakeCategoryNotifier extends CategoryNotifier {
  FakeCategoryNotifier(this.initial);
  final CategoryState initial;
  final List<String> calls = [];

  @override
  CategoryState build() => initial;

  @override
  Future<void> fetchCategories({bool? isExpense}) async {
    calls.add('fetch:$isExpense');
    state = state.copyWith(isExpense: isExpense ?? state.isExpense, isLoading: false);
  }

  @override
  Future<void> addCategory(String name) async => calls.add('add:$name');

  @override
  Future<void> editCategory(int id, String newName) async => calls.add('edit:$id:$newName');

  @override
  Future<void> deleteCategory(int id) async => calls.add('delete:$id');
}

CategoryState _state() => CategoryState(
      isLoading: false,
      isExpense: true,
      categories: [
        CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'food'),
        CategoryModel(id: 5, name: 'Bensin', isExpense: true, iconName: 'tag', userId: 'u1'),
      ],
    );

Future<FakeCategoryNotifier> _pump(WidgetTester tester) async {
  final fake = FakeCategoryNotifier(_state());
  await pumpApp(tester, const ManageCategoryScreen(), overrides: [categoryProvider.overrideWith(() => fake)]);
  await tester.pump();
  return fake;
}

void main() {
  testWidgets('menampilkan kategori bawaan dan buatan user', (tester) async {
    await _pump(tester);
    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Kelola Kategori'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Bawaan Aplikasi'), findsOneWidget);
    expect(find.text('Bensin'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.pencilSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.trash), findsOneWidget);
  });

  testWidgets('segmented Pemasukan memanggil fetchCategories(isExpense: false)', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Pemasukan'));
    await tester.pump();
    expect(fake.calls, contains('fetch:false'));
  });

  testWidgets('simpan nama kosong tidak memanggil provider', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Pengeluaran'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(fake.calls.where((c) => c.startsWith('add:')), isEmpty);
    expect(find.text('Tambah Pengeluaran'), findsOneWidget);
  });

  testWidgets('tambah kategori baru', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Parkir');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('add:Parkir'));
    expect(find.text('Berhasil ditambah!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('hapus kategori lewat dialog konfirmasi', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byIcon(PhosphorIconsFill.trash));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Kategori?'), findsOneWidget);
    expect(find.text("Yakin mau hapus 'Bensin'?"), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('delete:5'));
    await tester.pump(const Duration(seconds: 4));
  });
}
```

- [ ] **Step 6: Jalankan, pastikan gagal**

Run: `flutter test test/screens/manage_category/manage_category_screen_test.dart`
Expected: FAIL — `AppPageScaffold`/`AppNavAction` tidak ditemukan.

- [ ] **Step 7: Tulis ulang UI**

Ganti import baris 1–8 dengan:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/category_provider.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
```

Ganti `_showInputDialog` (baris 70–247) dengan `_showInputSheet`, ganti `build` (249–428), dan hapus `_buildToggleBtn` (430–474):

```dart
  void _showInputSheet(
    BuildContext context,
    WidgetRef ref, {
    CategoryModel? categoryToEdit,
  }) {
    final isEditing = categoryToEdit != null;
    final isExpense = ref.read(categoryProvider).isExpense;
    final controller = TextEditingController(
      text: isEditing ? categoryToEdit.name : '',
    );
    bool isSaving = false;

    showAppFormSheet(
      context: context,
      title: isEditing
          ? "Edit Kategori"
          : (isExpense ? "Tambah Pengeluaran" : "Tambah Pemasukan"),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: controller,
              hint: "Nama Kategori (Contoh: Bensin)",
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              readOnly: isSaving,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: "Simpan",
              loading: isSaving,
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                setSheetState(() => isSaving = true);
                try {
                  if (isEditing) {
                    await ref
                        .read(categoryProvider.notifier)
                        .editCategory(categoryToEdit.id, controller.text.trim());
                  } else {
                    await ref
                        .read(categoryProvider.notifier)
                        .addCategory(controller.text.trim());
                  }
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                  if (context.mounted) {
                    AppNotification.success(
                      context,
                      isEditing ? "Berhasil diubah!" : "Berhasil ditambah!",
                    );
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSaving = false);
                    AppNotification.error(sheetContext, "Error: $e");
                  }
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
    final state = ref.watch(categoryProvider);
    final isExpense = state.isExpense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return AppPageScaffold(
      title: 'Kelola Kategori',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: () => _showInputSheet(context, ref))],
      children: [
        AppSegmentedControl(
          labels: const ['Pengeluaran', 'Pemasukan'],
          selectedIndex: isExpense ? 0 : 1,
          selectedLabelColors: const [AppColors.expense, AppColors.income],
          onChanged: (index) {
            final wantExpense = index == 0;
            if (isExpense != wantExpense) {
              ref.read(categoryProvider.notifier).fetchCategories(isExpense: wantExpense);
            }
          },
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (state.categories.isEmpty)
          const AppEmptyState(icon: PhosphorIconsRegular.tag, title: 'Belum ada kategori')
        else
          AppGroupedSection(
            children: [
              for (final cat in state.categories) _buildCategoryRow(context, ref, cat, color),
            ],
          ),
      ],
    );
  }

  Widget _buildCategoryRow(BuildContext context, WidgetRef ref, CategoryModel cat, Color color) {
    final isSystem = cat.userId == null;
    return AppListRow(
      leading: AppIconTile(icon: _getCategoryIcon(cat.name, cat.iconName), color: color),
      title: cat.name,
      subtitle: isSystem ? "Bawaan Aplikasi" : null,
      trailing: isSystem
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(PhosphorIconsFill.pencilSimple, color: AppColors.tintBlue, size: 20),
                  onPressed: () => _showInputSheet(context, ref, categoryToEdit: cat),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(PhosphorIconsFill.trash, color: AppColors.expense, size: 20),
                  onPressed: () async {
                    final confirmed = await showAppConfirmDialog(
                      context: context,
                      title: "Hapus Kategori?",
                      message: "Yakin mau hapus '${cat.name}'?",
                    );
                    if (confirmed && context.mounted) {
                      _deleteCategory(context, ref, cat.id);
                    }
                  },
                ),
              ],
            ),
    );
  }
}
```

Catatan perubahan perilaku (catat di laporan): dialog lama `barrierDismissible: false` dan tombol "Batal"-nya nonaktif saat menyimpan; sheet baru bisa ditutup lewat "Batal" di header walau sedang menyimpan. Penyimpanan tetap selesai di provider; toast sukses tetap muncul lewat `context` layar. Test "tambah kategori baru" memverifikasi toast.

- [ ] **Step 8: Jalankan test**

Run: `flutter test test/screens/manage_category/manage_category_screen_test.dart test/widgets/app_text_field_test.dart`
Expected: PASS (5 + 1 test). Bila `find.text('Hapus')` ambigu (tooltip tidak ikut dihitung sebagai `Text`), gunakan `find.widgetWithText(CupertinoDialogAction, 'Hapus')` dan import `package:flutter/cupertino.dart` di test.

- [ ] **Step 9: Cek Poppins, hex, analyze**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/manage_category/manage_category_screen.dart
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange)" lib/screens/manage_category/manage_category_screen.dart
flutter analyze lib/screens/manage_category lib/widgets/app_text_field.dart
```
Expected: `0`; tidak ada baris; tanpa error/warning baru.

- [ ] **Step 10: Checklist visual vs mockup "Kelola Kategori"**

- [ ] Nav `‹ Beranda` + `+` kanan; tanpa FAB.
- [ ] Judul besar "Kelola Kategori".
- [ ] Segmented "Pengeluaran | Pemasukan"; teks terpilih merah/hijau.
- [ ] Satu grouped list putih; setiap baris: tile ikon bertinta merah (pengeluaran) atau hijau (pemasukan), nama, "Bawaan Aplikasi" abu untuk kategori sistem.
- [ ] Kategori buatan user: ikon pensil biru + sampah merah di kanan.
- [ ] `+` membuka sheet (grabber, "Batal", judul "Tambah Pengeluaran"), field putih, tombol "Simpan" penuh.
- [ ] Hapus → dialog gaya iOS "Hapus Kategori?".

- [ ] **Step 11: Commit**

```bash
git add lib/widgets/app_text_field.dart test/widgets/app_text_field_test.dart lib/screens/manage_category/manage_category_screen.dart test/screens/manage_category/manage_category_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(category): redesign manage category screen to iOS layout

Moves the add/edit dialog into a form sheet and adds autofocus and
textCapitalization options to AppTextField.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

## Task 5: Redesign Export Laporan

**Files:**
- Modify: `lib/screens/export/export_screen.dart` (baris 1–10 import, baris 20 seam, `_pickMonth` baris 37–186 → pemilih bulan bersama, `_pickDateRange` baris 189–214 → pemilih periode bersama (Plan B3b, spec G17), `build` baris 372–657; `_generatePdf` TIDAK diubah)
- Create: `test/screens/export/export_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold`, `AppSurfaceCard`, `AppIconTile`, `AppSegmentedControl`, `AppGroupedSection`, `AppListRow`, `AppPrimaryButton(icon:, loading:)`, `AppTextStyles`, `AppColors` (`primary`, `track`, `separator`, `textPrimary`), `pumpApp`.
- Consumes (TIDAK diubah): `PdfService().generateReport(...)`, `Printing.layoutPdf(...)`.
- Produces: seam `SupabaseClient get _supabase => Supabase.instance.client;`.

### Tabel preservasi — `lib/screens/export/export_screen.dart`

| Baris lama | Perilaku / label | Kode baru |
|---|---|---|
| 20 | `final SupabaseClient _supabase = Supabase.instance.client;` | getter (seam test) |
| 22–25 | `_isCustomRange=false`, `_selectedMonth=now`, `_selectedDateRange`, `_isGenerating` | sama |
| 27–35 | range awal: tanggal 1 bulan ini s/d hari ini | sama |
| 37–39 | `_pickMonth`: tahun sekarang ±5 | sama, lewat `showAppMonthPicker` (B3b). Beda perilaku (ruling B3b): dropdown tahun lama langsung mengubah bulan laporan; sekarang perubahan baru berlaku setelah "Pilih" |
| 189–214 | `_pickDateRange`: rentang 2020–2030, awal = `_selectedDateRange` | sama, lewat `showAppDateRangePicker` (B3b) |
| 56 | judul dialog "Pilih Periode" | sama (gaya `AppTextStyles.headline`) |
| 73–109 | dropdown tahun → `setDialogState` + `setState` | tahun ‹ › di `showAppMonthPicker`; berlaku setelah "Pilih" (ruling B3b) |
| 122–176 | grid 3×4 bulan (`'MMM', 'id_ID'`), terpilih = chip primary; tap → set bulan + pop | grid 3×4 bulan yang sama di `showAppMonthPicker`; tap = tandai, "Pilih" = set bulan + tutup (ruling B3b) |
| 215–370 | `_generatePdf` (query, filter mutasi tabungan, info dompet, PDF, `Printing.layoutPdf`, toast "Tidak ada transaksi di periode ini." / "Gagal membuat PDF: $e") | tidak diubah |
| 379 | judul "Export Laporan" | `AppPageScaffold(title:)` |
| 411–415 | ikon filePdf primary | `AppIconTile(size: 72)` |
| 418, 426 | "Cetak Laporan Keuangan", "Pilih mode periode laporan di bawah ini" | sama |
| 443, 455, 468, 481 | toggle "Satu Bulan" / "Pilih Tanggal" | `AppSegmentedControl` |
| 500–501, 526, 533–536 | baris "Bulan Laporan" + `'MMMM yyyy', 'id_ID'` → `_pickMonth` | `AppListRow` |
| 554–555, 583, 590–592 | baris "Rentang Tanggal" + `'dd MMM yy', 'id_ID'` atau "Pilih rentang" → `_pickDateRange` | `AppListRow` |
| 617–652 | tombol bawah "Cetak Laporan PDF" + ikon printer; nonaktif & spinner saat `_isGenerating` | `AppPrimaryButton(icon:, loading:)` di `bottomBar` |

### Tabel warna

| Lama | Baru |
|---|---|
| `Colors.grey.shade100` (track toggle, pill tahun) | `AppColors.track` |
| `Colors.grey.shade300` (border chip bulan, border baris) | `AppColors.separator` |
| `Colors.grey*` (teks sekunder) | `AppTextStyles.caption/subhead` |
| `AppColors.textPrimary` (latar tombol cetak) | `AppColors.primary` (mockup memakai tombol utama biru) |

- [ ] **Step 1: Tulis test gagal**

`test/screens/export/export_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/export/export_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/pump_app.dart';

// Seam: _supabase adalah getter dan hanya dipakai di _generatePdf, jadi
// layar bisa di-render tanpa Supabase. Tombol cetak tidak diketuk di test.
void main() {
  testWidgets('mode Satu Bulan menampilkan bulan berjalan', (tester) async {
    await pumpApp(tester, const ExportScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Export Laporan'), findsOneWidget);
    expect(find.text('Cetak Laporan Keuangan'), findsOneWidget);
    expect(find.text('Bulan Laporan'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())), findsOneWidget);
    expect(find.text('Cetak Laporan PDF'), findsOneWidget);
  });

  testWidgets('mode Pilih Tanggal menampilkan rentang awal bulan s/d hari ini', (tester) async {
    await pumpApp(tester, const ExportScreen());
    await tester.pump();

    await tester.tap(find.text('Pilih Tanggal'));
    await tester.pump();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final label =
        "${DateFormat('dd MMM yy', 'id_ID').format(start)} - ${DateFormat('dd MMM yy', 'id_ID').format(now)}";
    expect(find.text('Rentang Tanggal'), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    expect(find.text('Bulan Laporan'), findsNothing);
  });

  testWidgets('memilih bulan di dialog mengganti nilai baris', (tester) async {
    await pumpApp(tester, const ExportScreen());
    await tester.pump();

    await tester.tap(find.text('Bulan Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Periode'), findsOneWidget);

    await tester.tap(find.text('Jan'));
    await tester.pump();
    await tester.tap(find.text('Pilih')); // pemilih bersama (Plan B3b): ketuk bulan, lalu "Pilih"
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(DateTime(DateTime.now().year, 1))), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/export/export_screen_test.dart`
Expected: FAIL — crash Supabase belum diinisialisasi saat State dibuat (field baris 20) dan/atau `AppPageScaffold` tidak ditemukan.

- [ ] **Step 3: Seam + UI baru**

1. Ganti import baris 1–10 dengan:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/services/pdf_service.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

2. Baris 20 → `SupabaseClient get _supabase => Supabase.instance.client;`

3. Ganti `_pickMonth` (baris 37–186) dan `_pickDateRange` (baris 189–214) dengan pemilih bersama (Plan B3b, spec G17 — `test/architecture/modal_consistency_test.dart` menolak `showDialog`/`AlertDialog`/`showDateRangePicker`):

```dart
  Future<void> _pickMonth() async {
    final currentYear = DateTime.now().year;
    final picked = await showAppMonthPicker(
      context: context,
      title: 'Pilih Periode',
      initialMonth: _selectedMonth,
      firstYear: currentYear - 5,
      lastYear: currentYear + 5,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedMonth = picked);
  }

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      initialRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDateRange = picked);
  }
```

4. `_generatePdf` tidak disentuh.

5. Ganti `build` (baris 372–657) dengan:

```dart
  @override
  Widget build(BuildContext context) {
    final String rangeLabel = _selectedDateRange != null
        ? "${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.end)}"
        : "Pilih rentang";

    return AppPageScaffold(
      title: 'Export Laporan',
      backLabel: 'Beranda',
      bottomBar: AppPrimaryButton(
        label: 'Cetak Laporan PDF',
        icon: PhosphorIconsFill.printer,
        loading: _isGenerating,
        onPressed: _isGenerating ? null : _generatePdf,
      ),
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              const AppIconTile(icon: PhosphorIconsFill.filePdf, color: AppColors.primary, size: 72),
              const SizedBox(height: 12),
              Text('Cetak Laporan Keuangan', style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'Pilih mode periode laporan di bawah ini',
                style: AppTextStyles.subhead,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        AppSegmentedControl(
          labels: const ['Satu Bulan', 'Pilih Tanggal'],
          selectedIndex: _isCustomRange ? 1 : 0,
          onChanged: (index) => setState(() => _isCustomRange = index == 1),
        ),
        AppGroupedSection(
          children: [
            if (!_isCustomRange)
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.primary),
                title: 'Bulan Laporan',
                value: DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                showChevron: true,
                onTap: _pickMonth,
              )
            else
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.calendarPlus, color: AppColors.primary),
                title: 'Rentang Tanggal',
                value: rangeLabel,
                showChevron: true,
                onTap: _pickDateRange,
              ),
          ],
        ),
      ],
    );
  }
```

Catatan: `AnimatedCrossFade` lama diganti kondisi biasa (spec §9.8: hanya tampilan). Import `transaction_model.dart`, `pdf_service.dart`, `printing.dart`, `app_notification.dart` tetap dipakai oleh `_generatePdf`.

Catatan untuk koordinator (JANGAN diubah di task ini): `_generatePdf` hanya mengecualikan mutasi `[SAVING_ID:`. Bila Plan B2 menambah tag `[DEBT_ID:x]` dan tidak memperbarui Export, laporan PDF masih menghitung pinjaman sebagai pemasukan/pengeluaran. Spec §7.1 tidak menyebut Export — laporkan, jangan perbaiki di B6.

- [ ] **Step 4: Jalankan test**

Run: `flutter test test/screens/export/export_screen_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Cek Poppins, hex, analyze**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/export/export_screen.dart
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange)" lib/screens/export/export_screen.dart
flutter analyze lib/screens/export
```
Expected: `0`; grep warna tanpa hasil (`_pickDateRange` kini memakai `showAppDateRangePicker`, `Colors.black` lama ikut hilang); tanpa error/warning baru.

- [ ] **Step 6: Checklist visual vs mockup "Export Laporan"**

- [ ] Nav `‹ Beranda`, judul besar "Export Laporan".
- [ ] Kartu putih di tengah: tile ikon PDF biru muda besar, "Cetak Laporan Keuangan", subjudul abu.
- [ ] Segmented "Satu Bulan | Pilih Tanggal".
- [ ] Satu baris grouped list: ikon kalender bertinta, "Bulan Laporan", nilai abu "September 2026", chevron.
- [ ] Tombol biru penuh "Cetak Laporan PDF" dengan ikon printer menempel di bawah; spinner & nonaktif saat membuat PDF.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/export/export_screen.dart test/screens/export/export_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(export): redesign export report screen to iOS layout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

## Task 6: Redesign AI Advisor (+ `AppPageScaffold.scrollController`, `AppNavAction.icon(tooltip:)`)

> **Catatan koordinator:** `AppNavAction.icon(tooltip:)` kemungkinan sudah ditambahkan Plan B2 (Task 6). Cek dulu `grep -n "tooltip" lib/widgets/app_page_scaffold.dart`; bila sudah ada dengan nama sama, lewati penambahannya dan cukup pakai. Deteksi tag `[DEBT_ID:`/`[SAVING_ID:` (mis. di Export) WAJIB lewat `lib/core/transaction_tags.dart` dari Plan B2 — B2 Task 4 sudah mengecualikan transaksi utang di `pdf_service.dart`, jadi catatan "Export belum mengecualikan `[DEBT_ID:`" di laporan akhir cukup diverifikasi, bukan dikerjakan ulang.

**Files:**
- Modify: `lib/widgets/app_page_scaffold.dart` (tambah `scrollController` opsional; tambah `tooltip` opsional pada `AppNavAction.icon`)
- Modify: test komponen B1 `test/widgets/app_page_scaffold_test.dart` (buat bila belum ada)
- Modify: `lib/screens/ai_advisor/ai_advisor_screen.dart` (baris 1–9 import, 35 seam, 225–252 `_sendMessage` tambah `mounted`, 266–417 `build`)
- Create: `test/screens/ai_advisor/ai_advisor_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold(largeTitle: false, titleWidget:, bottomBar:, actions:)`, `AppNavAction.icon`, `AppIconTile`, `AppTextStyles`, `AppColors` (`primary`, `surface`, `textSecondary`), `AppNotification`, `pumpApp`.
- Consumes (TIDAK diubah): `AiSessionManager` (baris 11–23), `_loadChatSession`, `_fetchFinancialContext`, `_scrollToBottom`, `GeminiService.askFinancialAdvisor(String question, String financialContext)`.
- Produces:
  - `AppPageScaffold({..., ScrollController? scrollController})` — diteruskan ke scrollable utama isi halaman.
  - `AppNavAction.icon(IconData icon, {required VoidCallback onPressed, Color? color, String? tooltip, Key? key})`.

### Tabel preservasi — `lib/screens/ai_advisor/ai_advisor_screen.dart`

| Baris lama | Perilaku / label | Kode baru |
|---|---|---|
| 11–23 | `AiSessionManager` singleton | tidak diubah |
| 33–34 | `_chatController`, `_scrollController` | sama; `_scrollController` diteruskan ke `AppPageScaffold(scrollController:)` |
| 35 | field `_supabase = Supabase.instance.client` | getter (seam test) |
| 43–48 | initState: `_fetchFinancialContext()` + `_loadChatSession()` | sama |
| 50–64 | sesi < 10 menit dipulihkan; selain itu salam Gemi | tidak diubah |
| 68–223 | konteks keuangan (transaksi, tabungan, dompet, 6 bulan) | tidak diubah |
| 225–252 | `_sendMessage`: teks kosong → return; tambah bubble user + loading; simpan sesi; kosongkan field; scroll; `GeminiService.askFinancialAdvisor(text, _financialContext)`; tambah jawaban bila tidak null | sama + `if (!mounted) return;` setelah `await` (spec §9.4) |
| 254–264 | `_scrollToBottom` (delay 100ms, animate 300ms) | tidak diubah |
| 273–276 | avatar robot indigo | `AppIconTile(icon: robot, color: primary, round: true)` |
| 283–284 | "AI Advisor" + "Gemi - Siap bantu atur duitmu!" | judul tengah nav (`titleWidget`) |
| 294–305 | ikon sapu, tooltip "Mulai Chat Baru", reset sesi + `_loadChatSession()` + toast "Sesi chat diulang!" | `AppNavAction.icon(broom, tooltip: 'Mulai Chat Baru')` → `_resetSession()` |
| 319–324 | bubble kanan (user) / kiri (Gemi), lebar maks 85% | `_ChatBubble` |
| 326–332 | radius 20, sudut bawah sisi pengirim 5 | radius 20, sudut 6 |
| 337–349 | user = `Text` putih; Gemi = `MarkdownBody` (p, strong, listBullet) | sama, gaya `AppTextStyles` |
| 356–374 | loading "Gemi sedang menganalisa..." + spinner indigo | `_TypingBubble` spinner primary |
| 383–396 | field: send action, `onSubmitted` → `_sendMessage`, hint "Tanya soal keuanganmu...", pill | `_buildComposer` (field pill) |
| 399–408 | tombol kirim bulat indigo; abu & nonaktif saat loading | tombol bulat primary; `textSecondary` & nonaktif saat loading |

### Tabel warna

| Lama | Baru |
|---|---|
| `Colors.grey.shade50` (latar) | `AppColors.background` |
| `Colors.indigo` (avatar, spinner, tombol kirim) | `AppColors.primary` |
| `Colors.grey` (subjudul, tombol kirim nonaktif, hint) | `AppColors.textSecondary` |
| `Colors.grey.shade100` (isi field) | `AppColors.surface` (field putih di atas latar abu) |
| `Colors.black12` (garis atas input bar) | dihapus (bottomBar `AppPageScaffold`) |
| `Colors.black87`, `Colors.black` (teks markdown) | `AppTextStyles.body` (warna `textPrimary`) |

- [ ] **Step 1: Test gagal untuk parameter baru `AppPageScaffold`**

Tambahkan ke `test/widgets/app_page_scaffold_test.dart` (buat file bila belum ada; sertakan import):

```dart
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('scrollController diteruskan ke scrollable isi halaman', (tester) async {
    final controller = ScrollController();
    await pumpApp(
      tester,
      AppPageScaffold(
        title: 'Uji',
        scrollController: controller,
        children: [for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('Baris $i'))],
      ),
    );
    expect(controller.hasClients, isTrue);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Baris 39'), findsOneWidget);
  });

  testWidgets('AppNavAction.icon menampilkan tooltip', (tester) async {
    var tapped = false;
    await pumpApp(
      tester,
      AppPageScaffold(
        title: 'Uji',
        actions: [AppNavAction.icon(PhosphorIconsRegular.broom, onPressed: () => tapped = true, tooltip: 'Mulai Chat Baru')],
        children: const [SizedBox()],
      ),
    );
    await tester.tap(find.byTooltip('Mulai Chat Baru'));
    expect(tapped, isTrue);
  });
}
```

Bila file sudah ada, tambahkan hanya kedua `testWidgets` ke `main()` yang ada.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_page_scaffold_test.dart`
Expected: FAIL — `No named parameter with the name 'scrollController'` / `'tooltip'`.

- [ ] **Step 3: Tambah parameter di komponen**

Di `lib/widgets/app_page_scaffold.dart`:
- `AppPageScaffold`: tambah `this.scrollController,` di konstruktor, field `final ScrollController? scrollController;`, dan teruskan `controller: scrollController` ke scrollable utama (`ListView`/`CustomScrollView`/`SingleChildScrollView`) yang membungkus `children`.
- `AppNavAction.icon`: tambah parameter bernama opsional `String? tooltip` dan field-nya. Di `build`, bungkus tombol ikon dengan `Tooltip(message: tooltip!)` bila tidak null, atau teruskan ke `IconButton(tooltip: tooltip)` bila implementasi B1 memakai `IconButton`.

- [ ] **Step 4: Jalankan test komponen**

Run: `flutter test test/widgets/app_page_scaffold_test.dart`
Expected: PASS (termasuk test B1 yang sudah ada).

- [ ] **Step 5: Tulis test gagal untuk AI Advisor**

`test/screens/ai_advisor/ai_advisor_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

// Seam: _supabase getter → _fetchFinancialContext gagal di dalam try/catch
// miliknya sendiri. GeminiService tidak dipanggil (tidak ada pesan terkirim).
void main() {
  setUp(() => AiSessionManager().clearSession());

  testWidgets('menampilkan judul tengah dan salam Gemi', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    // `title: 'AI Advisor'` juga bisa dirender AppPageScaffold (mis. semantics),
    // jadi cukup pastikan minimal satu.
    expect(find.text('AI Advisor'), findsAtLeastNWidgets(1));
    expect(find.text('Gemi - Siap bantu atur duitmu!'), findsOneWidget);
    expect(find.textContaining('Aku Gemi', findRichText: true), findsOneWidget);
    expect(find.text('Tanya soal keuanganmu...'), findsOneWidget);
  });

  testWidgets('kirim kosong tidak menambah bubble', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Kirim'));
    await tester.pump();

    expect(find.byType(MarkdownBody), findsOneWidget); // hanya salam
    expect(find.text('Gemi sedang menganalisa...'), findsNothing);
  });

  testWidgets('reset sesi menampilkan salam lagi dan toast', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    await tester.tap(find.byTooltip('Mulai Chat Baru'));
    await tester.pump();

    expect(find.text('Sesi chat diulang!'), findsOneWidget);
    expect(find.textContaining('Aku Gemi', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
```

- [ ] **Step 6: Jalankan, pastikan gagal**

Run: `flutter test test/screens/ai_advisor/ai_advisor_screen_test.dart`
Expected: FAIL — crash Supabase pada field `_supabase` saat State dibuat, dan/atau `AppPageScaffold` tidak ditemukan.

- [ ] **Step 7: Seam, mounted, dan UI baru**

1. Ganti import baris 1–9 dengan:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

2. Baris 35 → `SupabaseClient get _supabase => Supabase.instance.client;`

3. Di `_sendMessage`, tepat setelah baris `final response = await GeminiService.askFinancialAdvisor(text, _financialContext);` tambahkan:
```dart
    if (!mounted) return;
```
Isi method lainnya tidak diubah.

4. Ganti `build` (baris 266–417) dengan kode berikut, lalu tambahkan `_resetSession`, `_buildComposer`, dan kelas helper:

```dart
  void _resetSession() {
    setState(() {
      _session.clearSession();
      _messages.clear();
      _loadChatSession();
    });
    AppNotification.success(context, "Sesi chat diulang!");
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'AI Advisor',
      backLabel: '',
      largeTitle: false,
      titleWidget: const _GemiTitle(),
      scrollController: _scrollController,
      actions: [
        AppNavAction.icon(
          PhosphorIconsRegular.broom,
          onPressed: _resetSession,
          tooltip: "Mulai Chat Baru",
        ),
      ],
      bottomBar: _buildComposer(),
      children: [
        for (final msg in _messages)
          _ChatBubble(text: msg['text'] as String, isUser: msg['isUser'] as bool),
        if (_isLoading) const _TypingBubble(),
      ],
    );
  }

  Widget _buildComposer() {
    return Row(
      children: [
        Expanded(
          // Composer chat khusus layar ini (pill, tombol kirim terpisah) —
          // AppTextField berbentuk kotak radius 16 dan tidak cocok untuk input chat.
          child: TextField(
            controller: _chatController,
            style: AppTextStyles.body.copyWith(fontSize: 15),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: "Tanya soal keuanganmu...",
              hintStyle: AppTextStyles.body.copyWith(fontSize: 15, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Kirim',
          child: GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.textSecondary : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsFill.paperPlaneRight, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _GemiTitle extends StatelessWidget {
  const _GemiTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIconTile(icon: PhosphorIconsFill.robot, color: AppColors.primary, round: true, size: 30),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AI Advisor", style: AppTextStyles.bodyStrong.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
            Text(
              "Gemi - Siap bantu atur duitmu!",
              style: AppTextStyles.caption.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
        ),
        child: isUser
            ? Text(text, style: AppTextStyles.body.copyWith(fontSize: 15, color: Colors.white))
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.body.copyWith(fontSize: 15),
                  strong: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                  listBullet: AppTextStyles.body.copyWith(fontSize: 15),
                ),
              ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text("Gemi sedang menganalisa...", style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
```

Perhatikan: kurung penutup `_AiAdvisorScreenState` sekarang ada di akhir `_buildComposer`. Hapus sisa kode `build` lama sepenuhnya.

Catatan: `backLabel: ''` diharapkan merender chevron saja (mockup). Bila Task 0 Step 2 menemukan `AppPageScaffold` tidak merender tombol kembali untuk string kosong, pakai `backLabel: 'Beranda'` dan catat. Bila `titleWidget` dengan `largeTitle: false` tidak tampil di tengah nav bar, perbaiki di `AppPageScaffold` (bukan di screen) dan tambahkan test komponennya.

Perubahan perilaku kecil (catat di laporan): indikator "Gemi sedang menganalisa..." sekarang menjadi item terakhir list (ikut discroll), bukan baris tetap di atas input. Teks dan kondisi tampil sama.

- [ ] **Step 8: Jalankan test**

Run: `flutter test test/screens/ai_advisor/ai_advisor_screen_test.dart test/widgets/app_page_scaffold_test.dart`
Expected: PASS. Bila `find.bySemanticsLabel('Kirim')` gagal karena semantics tidak aktif, bungkus test dengan `final handle = tester.ensureSemantics();` di awal dan `handle.dispose();` di akhir.

- [ ] **Step 9: Cek Poppins, hex, analyze**

Run:
```bash
grep -c "GoogleFonts.poppins" lib/screens/ai_advisor/ai_advisor_screen.dart
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange|black)" lib/screens/ai_advisor/ai_advisor_screen.dart
flutter analyze lib/screens/ai_advisor lib/widgets/app_page_scaffold.dart
```
Expected: `0`; tidak ada baris; tanpa error/warning baru. `intl` tetap dipakai oleh `_fetchFinancialContext`.

- [ ] **Step 10: Checklist visual vs mockup "AI Advisor"**

- [ ] Nav bar: chevron kembali kiri; tengah avatar robot bulat biru muda + "AI Advisor" tebal + subjudul abu kecil; kanan ikon sapu biru. Tidak ada judul besar.
- [ ] Bubble Gemi putih di kiri (sudut kiri-bawah lebih tajam); bubble user biru di kanan, teks putih (sudut kanan-bawah tajam).
- [ ] Indikator "Gemi sedang menganalisa..." dalam bubble putih dengan spinner biru.
- [ ] Input bar bawah: field pill putih "Tanya soal keuanganmu..." + tombol bulat biru dengan ikon kirim; abu saat loading.
- [ ] Markdown (tebal, bullet) tetap ter-render di jawaban Gemi.

- [ ] **Step 11: Commit**

```bash
git add lib/widgets/app_page_scaffold.dart test/widgets/app_page_scaffold_test.dart lib/screens/ai_advisor/ai_advisor_screen.dart test/screens/ai_advisor/ai_advisor_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(ai-advisor): redesign AI advisor chat to iOS message style

Adds scrollController to AppPageScaffold and a tooltip option to
AppNavAction.icon, and guards the reply setState with a mounted check.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

## Task 7: Verifikasi menyeluruh & checkpoint screenshot user

**Files:** `test/architecture/modal_consistency_test.dart` (hapus entri `_legacy` B6 — daftar jadi kosong); selain itu tidak ada perubahan kode (kecuali perbaikan temuan).

- [ ] **Step 0: Kosongkan `_legacy`**

Hapus tiga baris `'B6'` (`export_screen.dart`, `investment_screen.dart`, `manage_category_screen.dart`). `_legacy` sekarang kosong: ganti isinya menjadi `const _legacy = <String, String>{};` dan biarkan kedua test tetap ada sebagai pengaman.

Run: `flutter test test/architecture/modal_consistency_test.dart`
Expected: PASS. Bila gagal, baris yang disebut masih memanggil modal mentah — ganti dengan komponen bersama (spec G17), jangan kembalikan entri `_legacy`.

- [ ] **Step 1: Analyze & test penuh**

Run:
```bash
flutter analyze
flutter test
```
Expected: tidak ada error/warning baru dibanding `main` (bandingkan jumlah issue dengan menjalankan `git stash; flutter analyze | tail -1; git stash pop` bila perlu — jangan lupa pop); semua test PASS.

- [ ] **Step 2: Sapu Poppins & warna di keenam screen**

Run:
```bash
for f in lib/screens/investment/investment_screen.dart lib/screens/zakat_sedekah/zakat_sedekah_screen.dart lib/screens/calendar/calendar_screen.dart lib/screens/manage_category/manage_category_screen.dart lib/screens/export/export_screen.dart lib/screens/ai_advisor/ai_advisor_screen.dart; do echo "$f $(grep -c 'GoogleFonts.poppins' $f)"; done
grep -nE "Color\(0x|Colors\.(blue|green|red|grey|indigo|purple|teal|orange|greenAccent|redAccent)" lib/screens/investment lib/screens/zakat_sedekah lib/screens/calendar lib/screens/manage_category lib/screens/export lib/screens/ai_advisor -r
```
Expected: semua `0`; grep warna tanpa hasil.

- [ ] **Step 3: Cek diff tetap terarah**

Run: `git diff --stat main...HEAD`
Expected: hanya file yang disebut di plan ini. Tidak ada perubahan di `lib/providers/`, `lib/services/`, `lib/screens/home/`, atau file generated (`linux/`, `macos/`, `windows/` — bila muncul, `git checkout -- linux macos windows`).

- [ ] **Step 4: Jalankan app dan kumpulkan screenshot**

Pakai skill `run-and-screenshot`: `flutter run -d chrome --web-port=8765` (background), buka keenam layar dari Beranda → Semua Fitur. Bila tidak ada otomasi browser, koordinator meminta user mengirim screenshot keenam layar (Investasi dengan dan tanpa aset, Zakat & Sedekah kedua tab, Kalender dengan hari bertransaksi, Kelola Kategori + sheet tambah, Export kedua mode, AI Advisor dengan jawaban Gemi).

- [ ] **Step 5: Cocokkan dengan mockup**

Untuk tiap screenshot, jalankan checklist visual task terkait. Catat setiap perbedaan; perbaiki di commit terpisah `fix(<scope>): ...` lalu ulangi Step 1.

- [ ] **Step 6: Laporan akhir plan**

Laporkan: daftar commit, hasil `flutter analyze`/`flutter test`, perubahan komponen bersama (`AppWalletSelectRow` baru; `AppTextField.autofocus/textCapitalization`; `AppPageScaffold.scrollController`; `AppNavAction.icon(tooltip:)`), perubahan perilaku kecil yang disengaja (guard submit Investasi, `onPageChanged` + locale Kalender, sheet kategori bisa ditutup saat menyimpan, indikator mengetik AI di dalam list), dan catatan koordinator (Hapus Portofolio tanpa konfirmasi; Export belum mengecualikan `[DEBT_ID:`). Merge ke `main` hanya setelah user menyetujui hasil visual.
