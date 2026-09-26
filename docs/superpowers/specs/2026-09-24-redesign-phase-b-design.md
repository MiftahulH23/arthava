# Redesign Phase B — Spec Desain & Keputusan

Tanggal: 2026-09-24. Status: disetujui user (layout, bentuk card, dan palet iOS Blue sudah "deal").

Dokumen ini adalah **satu-satunya sumber kebenaran** untuk Phase B. Setiap plan di
`docs/superpowers/plans/2026-09-24-phase-b*.md` mengacu ke sini. Agent yang mengeksekusi
plan WAJIB membaca dokumen ini dulu, lalu plan-nya, lalu mockup.

---

## 1. Tujuan

Mendesain ulang seluruh 24 screen DompetKu ke gaya iOS (Material yang dibuat terasa iOS,
bukan widget Cupertino penuh), mengikuti mockup yang sudah disetujui, **tanpa mengubah
fitur/data yang sudah ada**, sambil:

1. memperbaiki bug logika Utang & Piutang dan menambah 4 fitur Utang yang disetujui,
2. mengganti Beranda jadi ringkasan (widget) + halaman baru "Semua Fitur",
3. menambah dompet favorit dan saldo minimal per dompet,
4. menyatukan warna fitur ke palet iOS Blue dan menghapus sisa font Poppins.

## 2. Sumber kebenaran visual: mockup

- File: `docs/design/dompetku-redesign-mockup.html` (buka langsung di browser; tidak butuh server).
- Versi online (hanya bisa dibuka user): https://claude.ai/artifact/N3PN14B5qRhYCNN6mgB7hA
- Struktur file: array `SCREENS` di `<script>`. Setiap entri punya `name` (nama screen),
  `note` (apa yang berubah), dan `html()` yang merakit layar dari helper:
  `sb()` status bar, `nb(back, right)` nav bar, `lt(title)` judul besar, `seg()` segmented
  control, `tabs()` chip tabs, `grp()`+`R()` grouped list + row, `tile()` ikon bertinta,
  `gh()` label grup, `prog()` progress bar, `chip()` chip kecil, `fnav()` navbar melayang,
  `.hero` kartu gradasi, `.card` kartu putih, `.sheet` form sheet, `.widget` kartu ringkasan.
- Mockup berskala kecil (layar ±244 px). **Jangan mengukur piksel dari mockup.** Pakai tabel
  token di §4 yang sudah dikonversi ke satuan Flutter (logical pixel).
- Teks, label, dan contoh angka di mockup adalah contoh. Label UI yang sebenarnya diambil dari
  kode screen yang ada sekarang (inventaris di §8), kecuali spec ini menyebut label baru.

## 3. Aturan desain global (berlaku di semua screen)

| # | Aturan | Contoh di mockup |
|---|--------|------------------|
| G1 | **Judul besar** rata kiri di bawah nav bar (bukan AppBar di tengah). | Semua screen "Anggaran", "Investasi", … |
| G2 | **Nav bar tipis**: kiri = chevron + label layar sebelumnya (warna primary), kanan = aksi. | `‹ Beranda` … `+` |
| G3 | **Tombol tambah "+" di kanan atas nav bar**, menggantikan semua FAB di halaman fitur. Pengecualian: navbar melayang di tab utama (tombol "+" bulat untuk tambah transaksi) dan pill "Transfer · Tambah" di halaman Dompet. | Anggaran, Target, Tabungan, Rutin, Investasi, Utang, Kategori |
| G4 | **Form tambah/edit = sheet dari bawah** dengan grabber, header `Batal` (kiri, primary) · judul (tengah, tebal). Tombol simpan penuh di bawah sheet. | "Buat Anggaran", "Catat Utang / Piutang" |
| G5 | **Grouped list** ala Settings iPhone: kartu putih radius besar, baris dengan pemisah tipis yang menjorok (inset) setelah ikon. Label grup kecil HURUF BESAR abu di atasnya. | Pengaturan, Semua Fitur, Kategori |
| G6 | **Segmented control iOS**: track abu, pilihan terpilih = pill putih berbayang. Untuk pilihan 2–3 opsi (Pemasukan/Pengeluaran, Zakat/Sedekah, Utang Saya/Piutang, Satu Bulan/Pilih Tanggal). | |
| G7 | **Chip tabs** untuk filter periode (Harian/Bulanan/Tahunan/Periode): pill kecil, terpilih = isi `textPrimary` + teks putih. | Transaksi, Statistik |
| G8 | **Kartu hero** (gradasi biru) hanya untuk angka ringkasan utama per halaman. Teks putih, label kecil pakai `AppColors.heroLabel`. | Beranda, Anggaran, Tabungan, Investasi, Zakat |
| G9 | **Kartu putih** radius besar tanpa border, bayangan sangat halus atau tanpa bayangan. Latar halaman `AppColors.background` (#F2F2F7). | |
| G10 | **Ikon bertinta**: kotak radius 12, latar = warna 14% di atas putih, ikon = warna penuh. Varian `filled` (latar warna penuh, ikon putih) dipakai di Semua Fitur, Pengaturan, dan list Dompet di Beranda. | |
| G11 | **Hijau/merah hanya untuk arti uang**: `AppColors.income` (masuk/lunas/tercapai) dan `AppColors.expense` (keluar/terlambat/over budget/hapus). Warna utama fitur (ungu Anggaran, teal Tabungan/Target, biru Investasi, hijau/biru Zakat) **dihapus** dan diganti `AppColors.primary`. | |
| G12 | **Hapus/edit baris** lewat geser ke kiri (swipe actions) bila mockup menunjukkan, selalu dengan dialog konfirmasi gaya iOS sebelum hapus. | Transaksi, Detail Utang (cicilan) |
| G13 | **Tombol aksi utama** menempel di bawah layar (bottom bar) untuk halaman yang punya satu aksi utama. | Export, Zakat, Detail Utang, Edit Profil |
| G14 | **Font** Plus Jakarta Sans lewat `AppTextStyles` (§5). Setiap screen yang disentuh WAJIB bersih dari `GoogleFonts.poppins`. | |
| G15 | **Ikon** tetap `phosphor_flutter`: Regular untuk tidak aktif, Fill untuk aktif/emfasis. Jangan ganti library ikon. | |
| G16 | **Empty state**: ikon abu besar + judul + (opsional) subjudul/aksi, di tengah area konten. **Loading**: `CircularProgressIndicator` warna primary di tengah. | |
| G17 | **Semua modal satu bentuk** (keputusan user 2026-09-26): konfirmasi/pilihan = dialog iOS (`showAppConfirmDialog` / `showAppChoiceDialog`); form, daftar, dan pemilih tanggal/bulan/tahun/periode = sheet bawah (`showAppFormSheet`, `showAppDatePicker`, `showAppMonthPicker`, `showAppYearPicker`, `showAppDateRangePicker`) dengan tombol "Pilih"; loading yang memblokir = `runWithAppLoading`. `showDialog`, `AlertDialog`, `showDatePicker`, `showDateRangePicker`, `showModalBottomSheet` dilarang di screen (`test/architecture/modal_consistency_test.dart`). | Hapus Utang, Tanggal Pinjam |

## 4. Token desain (satuan Flutter)

### 4.1 Warna (`lib/core/colors.dart`)

Sudah ada (JANGAN diubah): `primary #007AFF`, `background #F2F2F7`, `white`, `income #2E9E68`,
`expense #E0564F`, `textPrimary #1C1C1E`, `textSecondary #8E8E93`, `accent #FF9500`,
`heroGradientStart #0071E3`, `heroGradientEnd #0047AB`, `heroLabel #E0FFFFFF`.

Ditambahkan di Plan B1:

| Nama | Nilai | Dipakai untuk |
|------|-------|---------------|
| `surface` | `#FFFFFF` | kartu, grouped list, sheet field |
| `track` | `#E5E5EA` | track segmented control, track progress bar, switch off |
| `separator` | `#D8D8DD` | garis pemisah baris grouped list |
| `primarySoft` | `#E5F1FF` | latar tombol soft, tile aktif navbar, callout info |
| `accentSoft` | `#FFF1DC` | callout rekomendasi (Target), chip "Tempo" |
| `tintRed` | `#E0564F` | ikon kategori/fitur |
| `tintOrange` | `#F0913A` | ikon, peringatan >80% anggaran, chip Tempo, tombol Transfer/Tarik |
| `tintAmber` | `#D9A21B` | ikon |
| `tintTeal` | `#2FA39A` | ikon, chip "Mutasi Internal" |
| `tintBlue` | `#4A7FE0` | ikon, tombol edit (pensil) |
| `tintIndigo` | `#6A67CE` | ikon |
| `tintPink` | `#D8578C` | ikon |
| `tintBrown` | `#8A5A44` | ikon |
| `tintGreen` | `#2E9E68` | ikon (= income) |
| `tintSky` | `#3AA6D8` | ikon |
| `tintGray` | `#8E8E93` | ikon netral (mutasi internal, dompet dihapus) |

Warna dompet (dipilih user per dompet) tetap dari data dompet, bukan dari `AppColors`.

### 4.2 Ukuran

| Token | Nilai | Catatan |
|-------|-------|---------|
| Padding horizontal halaman | 18 | semua screen |
| Jarak antar blok vertikal | 14 | antar kartu/grup |
| Radius kartu putih / widget | 24 | |
| Radius grouped list | 20 | |
| Radius hero | 28 | padding 20 |
| Radius sheet (atas) | 28 | grabber 36×5 radius 3, warna `track` |
| Tinggi baris list | min 56 | padding 12 vertikal, 16 horizontal |
| Ikon tile | 40×40, radius 12, ikon 20 | varian round = lingkaran |
| Inset pemisah baris | 68 dari kiri bila ada leading tile; 16 bila tidak | tebal 0.5 |
| Segmented control | tinggi 36, radius 10, padding track 2, radius pill 8 | |
| Chip tabs | tinggi 30, radius 15, padding h 14 | |
| Tombol utama | tinggi 52, radius 16, teks 16 w700 | |
| Tombol kecil (soft/pill) | tinggi 36, radius 12, teks 14 w700 | |
| Progress bar | tinggi 8 (6 di dalam baris list), radius penuh | |
| Nav bar | tinggi 44 | chevron 22 + label 17 w500 |
| Navbar melayang tab | sudah jadi (Phase A) — jangan diubah | |

## 5. Tipografi (`lib/theme/app_text_styles.dart`, dibuat di Plan B1)

Semua memakai `GoogleFonts.plusJakartaSans`. Warna default `AppColors.textPrimary` kecuali disebut.

| Nama | Size | Weight | Lain |
|------|------|--------|------|
| `largeTitle` | 32 | w800 | letterSpacing -0.6, height 1.15 |
| `title` | 20 | w800 | letterSpacing -0.3 |
| `headline` | 17 | w700 | |
| `body` | 16 | w500 | |
| `bodyStrong` | 16 | w600 | |
| `subhead` | 14 | w500 | warna `textSecondary` |
| `caption` | 12 | w500 | warna `textSecondary` |
| `groupLabel` | 12 | w700 | UPPERCASE oleh widget, letterSpacing 0.8, `textSecondary` |
| `navLabel` | 17 | w500 | warna `primary` |
| `amountHero` | 32 | w800 | letterSpacing -0.8, tabular figures, putih |
| `amountLarge` | 40 | w800 | letterSpacing -1, tabular figures |
| `amountRow` | 15 | w700 | tabular figures |
| `button` | 16 | w700 | putih |

Aturan migrasi Poppins: saat sebuah screen dikerjakan, setiap `GoogleFonts.poppins(...)` diganti
`AppTextStyles.x.copyWith(...)` yang paling dekat ukurannya. `grep -c "GoogleFonts.poppins" <file>`
harus 0 di akhir task screen itu. Import `google_fonts` dihapus dari screen bila tidak terpakai.

## 6. Komponen bersama (dibuat di Plan B1) — KONTRAK API

Plan B2–B7 hanya boleh memakai API di bawah ini (nama & parameter persis). Bila sebuah screen
butuh varian yang tidak ada, tambahkan parameter opsional di komponennya dalam task screen itu dan
catat di laporan — jangan membuat widget kembar di dalam screen.

```dart
// lib/core/formatters.dart
String formatRupiah(num value);                 // "Rp 1.250.000"; negatif -> "-Rp 1.250.000"
String formatRupiahSigned(num value, {required bool isIncome}); // "+Rp 45.000" / "-Rp 45.000"
String formatRupiahCompact(num value);          // "Rp 8,2 jt", "Rp 742 rb", "Rp 950"
int parseRupiah(String text);                   // "1.250.000" / "Rp 1.250.000" -> 1250000; kosong -> 0
class RupiahInputFormatter extends TextInputFormatter; // hanya digit, sisip titik ribuan, maks 15 digit

// lib/theme/app_text_styles.dart
abstract final class AppTextStyles { static final TextStyle largeTitle, title, headline, body,
  bodyStrong, subhead, caption, groupLabel, navLabel, amountHero, amountLarge, amountRow, button; }

// lib/widgets/app_page_scaffold.dart
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,            // judul besar
    this.backLabel,                 // null = tidak ada tombol kembali
    this.actions = const [],        // widget di kanan nav bar (pakai AppNavAction)
    required this.children,         // isi yang discroll di bawah judul
    this.bottomBar,                 // widget menempel di bawah (mis. AppPrimaryButton)
    this.onRefresh,                 // pull-to-refresh opsional
    this.embedded = false,          // true = dipakai di dalam tab Home (tanpa Scaffold, SafeArea(bottom:false), padding bawah + MediaQuery.padding.bottom)
    this.largeTitle = true,         // false = judul kecil di tengah nav bar (mis. AI Advisor, Detail Utang)
    this.titleWidget,               // pengganti judul teks (mis. header avatar di Detail Utang)
    super.key,
  });
}
class AppNavAction extends StatelessWidget {
  const AppNavAction.add({required VoidCallback onPressed, Key? key});            // ikon plus 24, primary
  const AppNavAction.text(String label, {required VoidCallback onPressed, Key? key}); // "Edit"
  const AppNavAction.icon(IconData icon, {required VoidCallback onPressed, Color? color, Key? key});
}

// lib/widgets/app_grouped_section.dart
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({this.header, this.headerAction, this.onHeaderAction,
    required this.children, this.insetSeparators = true, super.key});
  // header: label HURUF BESAR di atas grup; headerAction: teks kanan (mis. "Kelola"), primary.
}

// lib/widgets/app_list_row.dart
class AppListRow extends StatelessWidget {
  const AppListRow({this.leading, required this.title, this.titleColor, this.subtitle,
    this.subtitleWidget, this.trailing, this.value, this.showChevron = false, this.onTap, super.key});
  // value: teks abu di kanan sebelum chevron (mis. "September 2026").
}
class AppIconTile extends StatelessWidget {
  const AppIconTile({required this.icon, required this.color, this.filled = false,
    this.round = false, this.size = 40, super.key});
}

// lib/widgets/app_segmented_control.dart
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({required this.labels, required this.selectedIndex,
    required this.onChanged, this.selectedLabelColors, super.key});
  // selectedLabelColors: warna teks per index saat terpilih (mis. [income, expense]); default textPrimary.
}
// lib/widgets/app_chip_tabs.dart
class AppChipTabs extends StatelessWidget {
  const AppChipTabs({required this.labels, required this.selectedIndex, required this.onChanged, super.key});
}

// lib/widgets/app_hero_card.dart
class AppHeroCard extends StatelessWidget { const AppHeroCard({required this.child, super.key}); }
class AppHeroLabel extends StatelessWidget { const AppHeroLabel(this.text, {super.key}); }   // caption heroLabel
class AppHeroAmount extends StatelessWidget { const AppHeroAmount(this.text, {this.fontSize = 32, super.key}); }

// lib/widgets/app_surface_card.dart
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({required this.child, this.padding = const EdgeInsets.all(16),
    this.color, this.onTap, super.key});
}

// lib/widgets/app_summary_widget.dart   (kartu ringkasan ala widget iPhone, Beranda)
class AppSummaryWidget extends StatelessWidget {
  const AppSummaryWidget({required this.icon, required this.label, required this.color,
    required this.children, this.onTap, super.key});
}

// lib/widgets/app_progress.dart
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({required this.value, required this.color, this.height = 8,
    this.onDark = false, super.key}); // value dijepit 0..1; onDark = track putih 22%
}
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({required this.value, required this.color, this.size = 110,
    this.strokeWidth = 11, this.center, super.key});
}

// lib/widgets/app_chip.dart
class AppChip extends StatelessWidget {
  const AppChip({required this.label, this.color, this.icon, super.key});
  // latar color 13% di atas putih, teks+ikon color; color null = textSecondary.
}
class AppCountBadge extends StatelessWidget { const AppCountBadge(this.count, {super.key}); }

// lib/widgets/app_callout.dart
enum AppCalloutTone { info, accent }
class AppCallout extends StatelessWidget {
  const AppCallout({required this.icon, required this.child, this.tone = AppCalloutTone.info, super.key});
}

// lib/widgets/app_buttons.dart
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({required this.label, required this.onPressed, this.icon,
    this.color, this.loading = false, super.key}); // full width, tinggi 52; onPressed null / loading = disabled
}
class AppPillButton extends StatelessWidget {
  const AppPillButton({required this.label, required this.onPressed, this.icon,
    this.color, this.filled = false, super.key});
  // tinggi 36; filled=false: latar color 13% + teks color (default primary); filled=true: latar color + teks putih
}
class AppPill extends StatelessWidget {   // tombol pill putih: pemilih tanggal, "Filter"
  const AppPill({required this.label, this.icon, this.trailing, this.badgeCount = 0,
    this.expand = false, this.onTap, super.key});
}

// lib/widgets/app_switch.dart
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key}); // CupertinoSwitch, aktif = income
}

// lib/widgets/app_swipe_actions.dart
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({required this.child, this.onEdit, this.onDelete, super.key});
  // geser kiri membuka tombol Edit (tintBlue, pensil) dan/atau Hapus (expense, sampah), lebar 72 per tombol.
  // onDelete dipanggil SETELAH user konfirmasi lewat showAppConfirmDialog di dalam widget ini.
}

// lib/widgets/app_sheet.dart
Future<T?> showAppFormSheet<T>({required BuildContext context, required String title,
  String cancelLabel = 'Batal', required WidgetBuilder builder});
// Membungkus showAppBottomSheet: latar background, radius atas 28, grabber, header Batal·Judul,
// padding 18, dan padding bawah mengikuti keyboard. builder mengembalikan isi form (Column).

// lib/widgets/app_amount_display.dart
class AppAmountDisplay extends StatelessWidget {   // nominal besar di tengah (read-only)
  const AppAmountDisplay({required this.label, required this.amountText, this.color, this.below, super.key});
}
class AppAmountField extends StatelessWidget {     // input nominal besar di tengah
  const AppAmountField({required this.controller, required this.label, this.color,
    this.autofocus = false, this.onChanged, super.key}); // pakai RupiahInputFormatter, prefix "Rp"
}

// lib/widgets/app_text_field.dart
class AppTextField extends StatelessWidget {       // field putih radius 16 tanpa border (gaya iOS)
  const AppTextField({required this.controller, this.hint, this.icon, this.obscure = false,
    this.suffix, this.keyboardType, this.readOnly = false, this.maxLines = 1, this.onTap, super.key});
}

// lib/widgets/app_empty_state.dart
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({required this.icon, required this.title, this.subtitle, this.action, super.key});
}

// lib/widgets/app_dialogs.dart
Future<bool> showAppConfirmDialog({required BuildContext context, required String title,
  required String message, String confirmLabel = 'Hapus', String cancelLabel = 'Batal',
  bool destructive = true}); // CupertinoAlertDialog; true = dikonfirmasi
```

Helper test (dibuat di Plan B1, dipakai semua plan screen):

```dart
// test/helpers/pump_app.dart
Future<void> pumpApp(WidgetTester tester, Widget child,
    {List<Override> overrides = const [], Size size = const Size(390, 844)});
// Membungkus child dengan ProviderScope(overrides) + MaterialApp(theme ringan, locale id_ID,
// builder FTheme(appForuiTheme)), mengatur ukuran layar HP, initializeDateFormatting('id_ID').
```

Pola test screen: override provider fitur dengan notifier palsu yang `build()`-nya mengembalikan
state tetap tanpa fetch, contoh:

```dart
class FakeBudgetNotifier extends BudgetNotifier {
  @override
  BudgetState build() => BudgetState(/* data contoh */);
}
await pumpApp(tester, const BudgetScreen(),
    overrides: [budgetProvider.overrideWith(FakeBudgetNotifier.new)]);
expect(find.text('Anggaran'), findsOneWidget);
```

Bila class notifier/state sebuah fitur tidak bisa di-extend (mis. constructor privat), task
screen tersebut menambahkan konstruktor/seam minimal di provider dan mencatatnya.

### 6.1 Tambahan kontrak dari plan (disetujui koordinator)

Parameter/komponen di bawah ditambahkan oleh plan tertentu. Semuanya opsional atau aditif, dan plan
dieksekusi berurutan, jadi plan berikutnya boleh mengandalkannya.

| Dibuat di | Tambahan |
|---|---|
| B1 | `AppNavAction.icon(tooltip:)` (polish B1 — B2/B6 cukup memakainya); `AppAmountField` mengecil untuk nominal panjang; `AppTextField.onChanged`, `AppTextField.inputFormatters`; `AppSwipeActions.deleteConfirmTitle` / `deleteConfirmMessage` (String, default `'Hapus?'` / `'Data ini akan dihapus permanen.'`); tooltip "Tambah" di `AppNavAction.add`; konstanta publik `AppPageScaffold.horizontalPadding` / `blockGap`; `AppProgressRingPainter` publik |
| B2 | `showAppChoiceDialog` + `AppDialogChoice` (dialog iOS beberapa pilihan) dan teks semua dialog memakai `AppTextStyles`; `AppListRow` judul 2 baris (porsi 3:2), nilai rata kanan; `AppAmountField` "Rp" + angka dipusatkan bersama; harness screenshot `test/screenshots/` + `tool/screenshots/fetch_fonts.sh`; E2E `tool/e2e/debt_rpc_e2e.dart`; `lib/core/transaction_tags.dart` (`isSavingMutation`, `isDebtMutation`, `isInternalMutation`, `stripDebtTag`, `stripTransactionTags`, `debtTag`) — **satu-satunya** tempat deteksi tag; `lib/models/debt_model.dart` (`DebtType`, `DebtModel`, `DebtBadgeKind`), `debt_payment_model.dart`; `DebtApi` seam; `AppNavAction.icon(tooltip:)` (bila B1 belum punya) |
| B3 | `AppPillButton.large` (tinggi 44, bulat penuh; pill Transfer · Tambah di Dompet — pilihan user 2026-09-26); `lib/core/wallet_rules.dart` (`homeWallets`, `spendableOf`, `spendableTotal`, `wouldBreachMinBalance`, `minBalanceWarningMessage`); `initialsOf` di `formatters.dart`; `AppColors.walletColorChoices` (List<String> hex) + `AppColors.fromWalletHex` + `heroStat*`; `userSettingsProvider`; `lib/providers/home_summary.dart`; `IncludeMinBalanceRow` |
| B3b | `lib/widgets/app_pickers.dart` (`showAppDatePicker`, `showAppMonthPicker`, `showAppYearPicker`, `showAppDateRangePicker`); `runWithAppLoading` di `app_dialogs.dart`; `AppListRow.valueColor`; `test/architecture/modal_consistency_test.dart` (daftar `_legacy` dikosongkan oleh plan B4–B6) |
| B4 | `AppPageScaffold.leading` (mengganti tombol kembali, mis. "Batal"); `lib/widgets/app_period_picker.dart` (`showAppPeriodPicker`); `lib/core/category_visuals.dart` (`categoryIcon`, `categoryColor`); `lib/screens/transaction_history/transaction_filter_sheet.dart` |
| B5 | `AppSelectOption<T>` + `AppSelectRow<T>` (`lib/widgets/app_select_row.dart`); `AppTextField.focusNode` |
| B6 | `AppWalletSelectRow` (`lib/widgets/app_wallet_select_row.dart`); `AppTextField.autofocus` / `textCapitalization`; `AppPageScaffold.scrollController`; `AppNavAction.icon(tooltip:)` |
| B7 | `AppTextField.label`; `AppColors.incomeSoft` / `expenseSoft` (palet dompet memakai `walletColorChoices` dari B3, bukan konstanta baru); inisial avatar memakai `initialsOf` dari B3; `lib/screens/login/auth_brand.dart`; `lib/core/lock_policy.dart`; `lib/screens/lock/app_entry_gate.dart` |

Aturan: plan yang menambah parameter mengubah file komponen **secara aditif** (tambah field +
parameter), tidak menulis ulang seluruh file, supaya tambahan plan sebelumnya tidak hilang.

Komponen lama:
- `AppBottomNav` (Phase A) — tetap, jangan diubah.
- `showAppBottomSheet` — tetap; `showAppFormSheet` dibangun di atasnya.
- `AppTabSelector`, `AppCard`, `AppButton` — tidak dipakai di desain baru. Dihapus di Plan B7
  (task pembersihan) setelah tidak ada pemakai lagi, beserta test-nya.

## 7. Keputusan fitur & logika

### 7.1 Utang & Piutang (Plan B2)

Bug yang WAJIB diperbaiki (hasil audit, file `lib/providers/debt_provider.dart` dan dua screen debt):

1. Kategori transaksi utang dicari hanya berdasarkan nama → piutang tercatat sebagai pemasukan. Perbaiki: kategori dibedakan arah (`is_expense`).
2. **Transaksi dari utang/piutang TIDAK dihitung sebagai pemasukan/pengeluaran** (keputusan user). Saldo dompet tetap berubah. Ditandai di `note` dengan tag `[DEBT_ID:<id>]` dan dikecualikan dari total Beranda, Statistik, Riwayat total, Anggaran, dan Kalender — pola sama dengan `[SAVING_ID:` yang sudah ada. Di list Riwayat Transaksi baris ini tampil seperti "Mutasi Internal" (abu, chip "Utang/Piutang", nominal dicoret) dan **tidak bisa dihapus/diedit dari Riwayat** (harus dari halaman Utang).
3. Semua tulis-data (buat utang, bayar cicilan, edit/hapus cicilan, hapus utang) dijalankan **atomik lewat fungsi Postgres (RPC)** yang dijalankan user di SQL Editor Supabase. Saldo dompet diubah di server (`balance = balance ± x`), bukan dari cache klien.
4. Tombol simpan punya guard `isSubmitting` (tidak bisa dobel tap).
5. Nominal ≤ 0 ditolak dengan notifikasi; nominal cicilan > sisa ditolak (dicek ulang di server).
6. `wallet_id` cicilan = null bila switch "Catat ke Dompet?" mati.
7. Setelah kembali dari halaman Utang, Beranda memanggil `refreshData()` + `_bumpRefreshCounter()`.
8. Hapus utang yang gagal menampilkan notifikasi error. Hapus utang menghapus cicilannya dan transaksi yang tertaut. **Keputusan user 2026-09-26:** bila utang tertaut ke dompet, dialog memberi dua pilihan — "Hapus & kembalikan saldo" (default; pinjaman & setiap cicilan dibalik ke dompetnya, ditolak utuh bila saldo tidak cukup) dan "Hapus saja" (saldo tetap). Utang tanpa tautan dompet: dialog biasa, saldo tidak berubah. RPC `delete_debt(p_debt_id, p_refund)`.
9. `payments` dipegang provider; menambah cicilan tidak menampilkan spinner layar penuh.

Fitur baru yang disetujui:
- **Edit utang**: nama, jumlah total, tanggal pinjam, jatuh tempo, catatan. Jumlah total baru ≥ total yang sudah dibayar; sisa dihitung ulang; status LUNAS/aktif disesuaikan.
- **Edit/hapus cicilan**: lewat swipe di Detail. Edit nominal/tanggal; hapus mengembalikan efek saldo dompet dan menambah sisa tagihan; status LUNAS dibuka kembali bila sisa > 0.
- **Tanda Terlambat + total**: badge merah "Terlambat N hari" bila jatuh tempo < hari ini dan belum lunas; badge oranye "Tempo: dd MMM yyyy" bila belum lewat; badge hijau "LUNAS". Ringkasan dua kartu di atas daftar: Total Utang (sisa semua utang aktif, merah) dan Total Piutang (sisa semua piutang aktif, hijau). Urutan: terlambat → jatuh tempo terdekat → tanpa jatuh tempo → lunas.
- **Tanggal pinjam & catatan**: kolom baru; tanggal pinjam default hari ini, dipakai sebagai tanggal transaksi dompet.

### 7.2 Beranda & Semua Fitur (Plan B3)

- Kartu hero tetap (Total Saldo + 4 statistik).
- **Dompet di Beranda**: grouped list sederhana (ikon dompet filled warna dompet, nama, saldo). Aturan tampil: bila user punya dompet favorit → tampilkan semua favorit (maks 5); bila tidak → 3 dompet saldo terbesar. Bila jumlah dompet > yang ditampilkan → baris terakhir "Lihat semua (N dompet)" menuju halaman Dompet. Header grup "DOMPET" dengan aksi kanan "Kelola".
- **Empat kartu ringkasan** (grid 2×2, `AppSummaryWidget`), ketuk = buka fiturnya:
  - *Anggaran*: total terpakai bulan berjalan dari total anggaran bulan berjalan + progress bar. Kosong → "Belum ada anggaran" + "Buat".
  - *Target*: target belum tercapai dengan deadline terdekat (bila tidak ada deadline, progres tertinggi). Nama, "Rp terkumpul / Rp target", progress. Kosong → "Belum ada target".
  - *Tagihan*: jadwal rutin aktif pengeluaran dengan tanggal berikutnya terdekat. Nama kategori/catatan, tanggal, nominal merah. Kosong → "Tidak ada tagihan".
  - *Utang*: utang saya (bukan piutang) aktif yang terlambat, atau jatuh tempo terdekat. Nama, "Terlambat N hari"/tanggal tempo, sisa. Kosong → "Bebas utang".
- **Baris "Semua Fitur"** (ikon grid filled primary, subjudul "Anggaran, target, tabungan, dan 9 lainnya") → halaman baru.
- **Halaman Semua Fitur** (`lib/screens/all_features/all_features_screen.dart`): judul besar "Semua Fitur", kolom cari (filter baris berdasarkan nama, tanpa huruf besar/kecil), grup: HARIAN (Dompet, Kalender, Kategori), PERENCANAAN (Anggaran, Target Keuangan, Buku Tabungan, Tagihan & Pemasukan Rutin), ASET & KEWAJIBAN (Investasi, Utang & Piutang, Zakat & Sedekah), ALAT (AI Advisor, Export Laporan). Setiap navigasi melakukan refresh Beranda yang sama seperti tombol grid lama.
- Grid 12 ikon di Beranda mobile **dihapus**. Layout web (`_buildWebLayout`) ikut: grid fitur web diganti grouped list Semua Fitur selebar konten di bawah kartu Ringkasan (kolom kanan sudah dipakai list Dompet; keputusan user 2026-09-26: "yang penting rapi").

### 7.3 Dompet (Plan B3)

- Tampilan kartu bertumpuk ala Apple Wallet (mockup "Dompet"). Ketuk kartu = buka sheet aksi (Edit, Jadikan Favorit/Hapus dari Favorit, Hapus). Pill melayang bawah: "Transfer" (bila ≥2 dompet) · "Tambah".
- **Favorit**: kolom `is_favorite boolean default false` di tabel dompet. Toggle dari sheet aksi; kartu favorit menampilkan ikon bintang kecil.
- **Saldo minimal** (masalah user: bank menahan saldo minimal, user ingin tahu uang yang benar-benar bisa dipakai):
  - Kolom `min_balance numeric default 0` per dompet, diisi di sheet Tambah/Edit Dompet ("Saldo Minimal (Opsional)").
  - Pengaturan global "Hitung saldo minimal di total saldo" (default **aktif** = perilaku sekarang). Disimpan di kolom `include_min_balance boolean default true` pada tabel profil user (lihat skema di Plan B3; bila tabel profil tidak punya tempat, plan membuat tabel `user_settings`). Diatur di halaman Pengaturan (baris switch baru, grup "Umum").
  - Bila **nonaktif**: Total Saldo di Beranda = Σ max(0, saldo − saldo_minimal); di kartu dompet dan list dompet Beranda tampil teks kecil "Bisa dipakai Rp …".
  - Transaksi pengeluaran/transfer yang membuat saldo dompet < saldo minimal → dialog peringatan "Saldo BCA akan di bawah saldo minimal (Rp 50.000). Lanjutkan?" (boleh lanjut).

### 7.4 Transaksi, Statistik, Tambah Transaksi (Plan B4)

- Transaksi: judul besar "Transaksi", segmented Pemasukan/Pengeluaran (sudah ada di `TransactionsTabScreen`, dipindah jadi `AppSegmentedControl`), chip tabs periode, pill tanggal + pill Filter (badge jumlah filter), kartu Total Real, **list dikelompokkan per tanggal** (label grup "KAMIS, 24 SEP"), baris dengan tile kategori, catatan + chip dompet, nominal. Swipe kiri = Hapus (dengan konfirmasi). Baris mutasi internal (tabungan/utang) abu, chip, dicoret, tanpa swipe.
- Statistik: sesuai mockup; donut di dalam kartu + ringkasan (Rata-rata harian, Terbesar); daftar kategori dalam grouped list dengan nomor peringkat berwarna, progress tipis, jumlah transaksi dan persen; baris bisa diekspansi menampilkan transaksi (fitur yang sudah ada).
- Tambah Transaksi: tetap halaman terpisah (push) tetapi tampil seperti sheet: header Batal · judul, segmented, nominal besar di tengah (`AppAmountField`), pill "Scan Struk AI" (hanya pengeluaran), grup Sumber Dana (segmented Dompet/Tabungan + baris pilih dompet/tabungan), grup Kategori + Tanggal, field Catatan, tombol "Simpan Transaksi" di bawah. Mode edit dan read-only tetap ada.

### 7.5 Lain-lain

- Test `test/widget_test.dart` (template counter, selalu gagal) **dihapus** di Plan B1.
- Dark mode: tidak didesain ulang di Phase B. Screen tetap harus bisa dibuka di dark mode tanpa crash; warna boleh tetap terang.
- Tidak ada perubahan library ikon, state management, atau struktur folder di luar yang disebut.

## 8. Peta screen → plan

| Screen (nama di mockup) | File | Plan |
|---|---|---|
| — komponen bersama, formatter, text styles, hapus widget_test | `lib/widgets/*`, `lib/core/formatters.dart`, `lib/theme/app_text_styles.dart` | **B1** |
| Utang & Piutang, Detail Utang, Form Catat Utang | `lib/screens/debt/*`, `lib/providers/debt_provider.dart`, SQL | **B2** |
| Beranda (usulan baru), Semua Fitur, Dompet | `lib/screens/home/*`, `lib/screens/all_features/*` (baru), `lib/screens/wallet/*`, providers terkait, SQL | **B3** |
| — pemilih & loading bersama, Utang memakai pemilih baru | `lib/widgets/app_pickers.dart`, `app_dialogs.dart`, `lib/screens/debt/*` | **B3b** |
| Transaksi, Statistik, Tambah Transaksi | `lib/screens/transaction_history/*`, `lib/screens/stats/*`, `lib/screens/input_transaction/*` | **B4** |
| Anggaran, Detail Anggaran, Target Keuangan, Buku Tabungan, Detail Tabungan, Tagihan & Pemasukan Rutin, Form Buat Anggaran | `lib/screens/budget/*`, `target/*`, `savings/*`, `recurring/*` | **B5** |
| Investasi, Zakat & Sedekah, Kalender, Kelola Kategori, Export Laporan, AI Advisor | `investment/*`, `zakat_sedekah/*`, `calendar/*`, `manage_category/*`, `export/*`, `ai_advisor/*` | **B6** |
| Login, Daftar Akun, Kunci Aplikasi, Pengaturan, Edit Profil + pembersihan akhir | `login/*`, `register/*`, `lock/*`, `settings/*`, `edit_profile/*` | **B7** |

Urutan eksekusi: **B1 → B2 → B3 → B3b → B4 → B5 → B6 → B7.** B1 wajib selesai dulu (semua plan lain
bergantung padanya). B2 didahulukan karena bug uang. B3 butuh B2 (widget Utang di Beranda).
B4–B7 saling independen setelah B1 tetapi dijalankan berurutan supaya review mudah.
Satu branch per plan: `redesign/phase-b1-components`, `redesign/phase-b2-debt`, dst., merge ke `main`
setelah plan selesai dan user menyetujui hasil visualnya.

## 9. Aturan engineering (wajib, hasil pelajaran Phase A)

1. **Jangan jalankan `dart format` ke seluruh file.** Edit terarah saja. Diff harus sebanding dengan perubahan.
2. `Notifier.build()` tidak boleh menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)`.
3. Refresh provider lewat `ref.invalidate(...)`, bukan mengganti `ValueKey`.
4. Setelah `await` (terutama `Navigator.push`), cek `if (!mounted) return;` sebelum `setState`/`ref`.
5. Tab di dalam Home (`extendBody: true`): konten pakai `SafeArea(bottom: false)` + padding bawah `+ MediaQuery.of(context).padding.bottom`. `AppPageScaffold(embedded: true)` sudah menangani ini.
6. Jangan menaruh `Center`/`Align`/`Expanded` tanpa batas di slot yang memberi tinggi longgar (mis. `bottomNavigationBar`) — pakai `heightFactor: 1`.
7. Pertahankan konkurensi fetch asli (bila kode lama menjalankan dua fetch paralel, tetap paralel lewat `Future.wait`).
8. Semua `onTap` / navigasi / efek samping lama dipertahankan persis; redesign hanya mengubah tampilan kecuali spec ini menyebut perubahan logika.
9. Tidak ada hex di screen — semua warna dari `AppColors` (termasuk warna yang sebelumnya hardcoded: `Colors.purple`, `Color(0xFF009688)`, `Colors.blue.shade800`, dst.). Pengecualian: `Colors.white`, `Colors.transparent`, dan warna dompet dari data.
10. Commit message Conventional Commits (hook `commit-msg`), scope tanpa koma. Akhiri dengan baris atribusi yang diberikan sesi.
11. Perubahan skema DB: tulis file SQL di `supabase/migrations/<timestamp>_<nama>.sql`, jalankan lewat skill `supabase-schema-change`; user yang mengeksekusi SQL di dashboard. Kode Dart yang bergantung pada kolom baru tidak di-merge sebelum user konfirmasi SQL sudah dijalankan.

## 10. Verifikasi per screen

Setiap task screen selesai bila:
1. `flutter analyze` tidak menambah error/warning baru (info `withOpacity` lama boleh).
2. `flutter test` hijau (setelah B1 tidak ada lagi test yang gagal).
3. `grep -c "GoogleFonts.poppins" <file screen>` = 0.
4. Tidak ada hex/`Colors.<warna>` baru di screen (kecuali pengecualian §9.9).
5. Checklist visual di task itu dicocokkan dengan mockup memakai skill `run-and-screenshot`. Bila agent tidak punya otomasi browser, koordinator meminta screenshot ke user di akhir plan (bukan per task) dan mencocokkan dengan mockup sebelum merge.
