# Phase B3 — Beranda, Semua Fitur, Dompet (favorit & saldo minimal) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengganti Beranda jadi ringkasan (hero + list dompet + 4 kartu ringkasan + baris "Semua Fitur"), menambah halaman Semua Fitur, mendesain ulang halaman Dompet (kartu bertumpuk), serta menambah dompet favorit dan saldo minimal per dompet beserta pengaturan "Hitung saldo minimal di total saldo".

**Architecture:** Kolom baru di Supabase (`wallets.is_favorite`, `wallets.min_balance`, `profiles.include_min_balance`) lewat satu file migration yang dijalankan user. Aturan tampilan dompet & saldo dipisah ke fungsi murni (`lib/core/wallet_rules.dart`), pemilihan data kartu ringkasan ke fungsi murni (`lib/providers/home_summary.dart`), dan daftar 12 fitur ke enum `AppFeature` (`lib/screens/all_features/app_feature.dart`) yang juga menyimpan jenis refresh Beranda setelah kembali — pengganti 12 callback grid lama. UI memakai komponen Plan B1 (spec §6).

**Tech Stack:** Flutter, flutter_riverpod 2.6.1 (`NotifierProvider.autoDispose`), supabase_flutter, intl, phosphor_flutter, komponen `lib/widgets/*` dari Plan B1.

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (§3 aturan G1–G16, §4 token, §5 teks, §6 kontrak komponen, §7.2 Beranda & Semua Fitur, §7.3 Dompet, §9 aturan engineering, §10 verifikasi). Mockup: `docs/design/dompetku-redesign-mockup.html` entri **"Beranda (usulan baru)"**, **"Semua Fitur"**, **"Dompet"**. Skema DB: `docs/database/schema.md`.

## Global Constraints

Dari spec §9 (wajib di setiap task):

1. **Jangan jalankan `dart format` ke seluruh file.** Edit terarah saja; diff sebanding dengan perubahan.
2. `Notifier.build()` tidak boleh menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)`.
3. Refresh provider lewat `ref.invalidate(...)`, bukan mengganti `ValueKey`.
4. Setelah `await` (terutama `Navigator.push`), cek `if (!mounted) return;` (State) atau `if (!context.mounted) return;` (widget tanpa State) sebelum `setState`/`ref`/`context`.
5. Tab di dalam Home (`extendBody: true`): konten pakai `AppPageScaffold(embedded: true)`.
6. Jangan menaruh `Center`/`Align`/`Expanded` tanpa batas di slot yang memberi tinggi longgar (mis. `bottomNavigationBar`, `bottomBar`) — pakai `heightFactor: 1`.
7. Pertahankan konkurensi fetch asli; fetch baru yang independen dijalankan paralel lewat `Future.wait`.
8. Semua `onTap`/navigasi/efek samping lama dipertahankan persis kecuali spec menyebut perubahan (tabel preservasi di tiap task).
9. Tidak ada hex/`Colors.<warna>` di screen — semua dari `AppColors`. Pengecualian: `Colors.white`, `Colors.transparent`, `Colors.black.withOpacity(..)` untuk bayangan, dan warna dompet dari data.
10. Commit message Conventional Commits (hook `commit-msg`), scope tanpa koma. Setiap commit diakhiri dua baris atribusi:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
    ```
11. Perubahan skema: file `supabase/migrations/…sql`, user yang menjalankan di SQL Editor. **Kode Dart yang membaca/menulis kolom baru tidak di-merge sebelum user konfirmasi SQL sudah dijalankan.**

Dari spec §10 (definisi selesai tiap task screen): `flutter analyze` tanpa error/warning baru; `flutter test` hijau; `grep -c "GoogleFonts.poppins" <file>` = 0 untuk tiap file yang disentuh; tidak ada hex/`Colors.<warna>` baru; checklist visual dicocokkan dengan mockup (skill `run-and-screenshot`; bila tidak ada otomasi browser, koordinator minta screenshot user di Task 10).

Lain-lain:
- Branch: `redesign/phase-b3-home-wallet` dari `main` setelah Plan B1 dan B2 di-merge.
- Label UI baru yang diperkenalkan plan ini (persis): "Semua Fitur", "Cari fitur", "Fitur tidak ditemukan", "Lihat semua (N dompet)", "Ringkasan", "Belum ada anggaran", "Belum ada target", "Tidak ada tagihan", "Bebas utang", "Buat", "Terlambat N hari", "Tempo: d MMM yyyy", "Tanpa jatuh tempo", "Bisa dipakai Rp …", "Sudah dikurangi saldo minimal", "Saldo Minimal (Opsional)", "Jadikan Favorit", "Hapus dari Favorit", "Di bawah saldo minimal", "Lanjutkan", "Hitung saldo minimal di total saldo".
- Format uang: `formatRupiah` (penuh) untuk saldo/nominal; `formatRupiahCompact` hanya di kartu ringkasan.

## Review Focus

1. **User tanpa dompet sama sekali** — Beranda menampilkan baris "Buat Dompet Pertama" (bukan list kosong), total `Rp 0`, tanpa baris "Lihat semua"; halaman Dompet menampilkan empty state + pill "Tambah" saja. (Task 5 test 3, Task 7 test 4)
2. **Saldo minimal lebih besar dari saldo** dengan pengaturan nonaktif — "bisa dipakai" dijepit 0, total tidak pernah minus karena satu dompet. (Task 2 test `spendableTotal clamps…`)
3. **Tepat 3 dompet tanpa favorit** — ketiganya tampil, tidak ada baris "Lihat semua". Lebih dari 5 favorit — hanya 5 tampil dan baris "Lihat semua (N dompet)" muncul. (Task 2 test `homeWallets…`, Task 5 test 1)
4. **Migration belum dijalankan** (kolom baru belum ada di JSON) — `WalletModel.fromJson` dan pembacaan `include_min_balance` tidak crash, memakai default `false`/`0`/`true`. (Task 2 test `fromJson tanpa kolom baru`, Task 3 test)
5. **Data ringkasan kosong / tidak ada anggaran** — tiap kartu menampilkan teks empty state, tidak ada pembagian dengan nol (anggaran total 0). Nominal kosong di form transaksi tidak memunculkan dialog saldo minimal. (Task 3 test `summarizeBudgets…`, Task 5 test 2, Task 2 test `wouldBreachMinBalance…`)

---

## Peta file

| File | Aksi | Tanggung jawab |
|---|---|---|
| `supabase/migrations/202609240002_wallet_favorites_min_balance.sql` | Create | Kolom `is_favorite`, `min_balance`, `include_min_balance`; hapus policy publik `profiles` |
| `lib/core/colors.dart` | Modify | `walletColorChoices`, `fromWalletHex`, 4 warna statistik hero |
| `lib/core/formatters.dart` | Modify | `initialsOf` |
| `lib/core/wallet_rules.dart` | Create | `homeWallets`, `spendableOf`, `spendableTotal`, `wouldBreachMinBalance`, `minBalanceWarningMessage` |
| `lib/models/wallet_model.dart` | Modify | `isFavorite`, `minBalance`, `displayColor` |
| `lib/providers/wallet_provider.dart` | Modify | `minBalance` di add/update, `setFavorite` |
| `lib/providers/user_settings_provider.dart` | Create | `userSettingsProvider` (`include_min_balance`) |
| `lib/providers/home_summary.dart` | Create | `BudgetSummary`, `HomeSummary`, `summarizeBudgets`, `pickTarget`, `pickNextBill`, `pickDebt`, `overdueDays` |
| `lib/providers/home_provider.dart` | Modify | `wallets` jadi `List<WalletModel>`, `includeMinBalance`, `summary`, `fetchSummary()` |
| `lib/screens/all_features/app_feature.dart` | Create | enum `AppFeatureGroup`, `HomeRefreshAfter`, `AppFeature`, `filterFeatures` |
| `lib/screens/all_features/all_features_screen.dart` | Create | `AllFeaturesScreen`, `AllFeaturesSections` |
| `lib/screens/home/home_screen.dart` | Modify | Konten Beranda mobile & web baru |
| `lib/screens/wallet/wallet_screen.dart` | Rewrite | Kartu bertumpuk, sheet aksi, sheet tambah/edit, sheet transfer |
| `lib/screens/input_transaction/input_transaction_screen.dart` | Modify (minimal) | Dialog peringatan saldo minimal sebelum simpan pengeluaran |
| `lib/screens/settings/include_min_balance_row.dart` | Create | Baris switch pengaturan |
| `lib/screens/settings/settings_screen.dart` | Modify (minimal) | Sisipkan baris switch di grup "Umum" |
| `test/...` | Create | lihat tiap task |

## Interfaces dari Plan B2 (diasumsikan)

> **Catatan koordinator — interface B2 yang SEBENARNYA (menggantikan asumsi di bawah):**
> Plan B2 (`2026-09-24-phase-b2-debt.md`, Task 2) mendefinisikan:
> ```dart
> enum DebtType { payable, receivable }          // String get dbValue => 'payable' / 'receivable'
> class DebtModel {                               // lib/models/debt_model.dart
>   final int id; final String name; final DebtType type; final double amount;
>   final double remainingAmount; final DateTime loanDate; final DateTime? dueDate;
>   final String? notes; final String status;     // 'active' | 'paid'
>   final int? walletId; final int? transactionId; final DateTime? createdAt;
>   factory DebtModel.fromJson(Map<String, dynamic> json);
>   bool get isPayable; double get paidAmount; bool get isPaidOff; double get progress;
>   bool isOverdue(DateTime today); int overdueDays(DateTime today); DebtBadgeKind badgeKind(DateTime today);
> }
> ```
> Maka di Task 3 plan ini:
> 1. `type` adalah enum: pakai `d.type == DebtType.payable` (bukan `== 'payable'`), dan `!d.isPaidOff` untuk "aktif".
> 2. **Jangan** membuat `overdueDays` sendiri di `home_summary.dart` — pakai `d.isOverdue(today)` / `d.overdueDays(today)` milik B2 supaya aturan "terlambat" identik dengan halaman Utang.
> 3. Helper `debt(...)` di test dibangun lewat `DebtModel.fromJson({...})` (kolom DB snake_case: `id`, `name`, `type`, `amount`, `remaining_amount`, `loan_date`, `due_date`, `status`) — tidak bergantung pada urutan konstruktor.
> 4. Sumber data widget Utang = provider/API B2, bukan query `debts` baru, bila B2 menyediakan fetch daftar utang yang bisa dipanggil tanpa layar Utang terbuka; bila tidak, query `debts` langsung lalu map lewat `DebtModel.fromJson`.

Plan B3 memakai `lib/models/debt_model.dart` dari Plan B2. Yang dipakai **hanya** field berikut (nama kolom DB di `docs/database/schema.md`, tabel `debts`):

```dart
class DebtModel {
  final int id;
  final String name;
  final String type;             // 'payable' (Utang Saya) | 'receivable' (Piutang)
  final double amount;
  final double remainingAmount;
  final DateTime? dueDate;
  final String status;           // 'active' | 'paid'
  // ... field lain dari B2 (loanDate, notes, dst.) tidak dipakai di sini
  DebtModel({required this.id, required this.name, required this.type, required this.amount,
      required this.remainingAmount, this.dueDate, required this.status /*, ...*/});
  factory DebtModel.fromJson(Map<String, dynamic> json);
}
```

Bila nama field/konstruktor B2 berbeda, **sesuaikan hanya pemanggilan di `home_summary.dart` dan test Task 3** — jangan mengubah model B2. Jumlah hari terlambat dihitung di plan ini (`overdueDays`) supaya tidak bergantung pada semantik tanggal di B2. Plan B2 juga sudah menambahkan pengecualian `[DEBT_ID:` di `fetchHomeData` dan mengubah tombol grid "Utang" agar me-refresh Beranda — **jangan membatalkan** perubahan B2 itu saat mengedit `home_provider.dart`.

---

### Task 0: Branch

- [ ] **Step 1: Buat branch**

```bash
git checkout main && git pull
git checkout -b redesign/phase-b3-home-wallet
flutter analyze 2>&1 | tail -1
flutter test 2>&1 | tail -1
```

Expected: analyze tanpa error; test hijau (Plan B1 menghapus test counter lama). Catat jumlah issue analyze sebagai baseline.

---

### Task 1: SQL migration (favorit, saldo minimal, pengaturan, perbaikan policy)

**Files:**
- Create: `supabase/migrations/202609240002_wallet_favorites_min_balance.sql`

**Interfaces:**
- Produces: kolom `wallets.is_favorite boolean not null default false`, `wallets.min_balance numeric not null default 0` (check ≥ 0), `profiles.include_min_balance boolean not null default true`. Policy `"Public profiles are viewable by everyone"` dihapus.

- [ ] **Step 1: Tulis file migration**

```sql
-- 202609240002_wallet_favorites_min_balance.sql
-- Plan B3: dompet favorit, saldo minimal per dompet, pengaturan "Hitung saldo minimal
-- di total saldo", dan perbaikan keamanan policy profiles.
-- Idempotent: aman dijalankan ulang.

alter table public.wallets
  add column if not exists is_favorite boolean not null default false;

alter table public.wallets
  add column if not exists min_balance numeric not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'wallets_min_balance_nonnegative'
  ) then
    alter table public.wallets
      add constraint wallets_min_balance_nonnegative check (min_balance >= 0);
  end if;
end $$;

alter table public.profiles
  add column if not exists include_min_balance boolean not null default true;

-- Keamanan: policy ini membuat SEMUA user login bisa membaca profil (nama) user lain.
-- Policy "User bisa lihat profil sendiri" (auth.uid() = id) tetap ada dan cukup.
drop policy if exists "Public profiles are viewable by everyone" on public.profiles;
```

- [ ] **Step 2: Serahkan ke user untuk dijalankan (skill `supabase-schema-change`)**

Kirim ke user pesan berikut (bahasa Indonesia), lalu **tunggu konfirmasi** sebelum Task 2 dijalankan di perangkat:

> Tolong jalankan SQL di file `supabase/migrations/202609240002_wallet_favorites_min_balance.sql` lewat **Supabase Dashboard → SQL Editor → New query → Run**. Sebaiknya dari laptop: editor di HP menambahkan tanda kurung otomatis sehingga query rusak. Setelah itu jalankan query cek di bawah dan kirim hasilnya.

Query verifikasi (satu per satu):

```sql
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and ((table_name = 'wallets' and column_name in ('is_favorite','min_balance'))
    or (table_name = 'profiles' and column_name = 'include_min_balance'));
```

Expected: 3 baris; `is_nullable = NO`; default `false`, `0`, `true`.

```sql
select policyname, cmd from pg_policies where schemaname = 'public' and tablename = 'profiles';
```

Expected: **tidak ada** baris "Public profiles are viewable by everyone"; "User bisa lihat profil sendiri" (SELECT) masih ada.

- [ ] **Step 3: Perbarui snapshot skema**

Edit `docs/database/schema.md`: tambahkan baris kolom baru di tabel `wallets` dan `profiles`, hapus baris policy publik di tabel RLS, dan ubah butir "Catatan penting" tentang policy publik menjadi "sudah dihapus (migration 202609240002)".

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/202609240002_wallet_favorites_min_balance.sql docs/database/schema.md
git commit -m "$(cat <<'EOF'
feat(db): add wallet favorites, min balance, and profile setting

Also drops the public-read policy on profiles so users can only read
their own profile.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: Model dompet, aturan dompet, provider dompet & pengaturan

**Files:**
- Modify: `lib/core/colors.dart`
- Modify: `lib/core/formatters.dart`
- Create: `lib/core/wallet_rules.dart`
- Modify: `lib/models/wallet_model.dart`
- Modify: `lib/providers/wallet_provider.dart:69-103`
- Create: `lib/providers/user_settings_provider.dart`
- Test: `test/core/wallet_rules_test.dart`, `test/models/wallet_model_test.dart`, `test/core/initials_test.dart`

**Interfaces:**
- Consumes: `formatRupiah` (B1, `lib/core/formatters.dart`).
- Produces:
  - `AppColors.walletColorChoices` (`List<String>`, 8 hex string yang disimpan ke DB), `AppColors.fromWalletHex(String? hex) -> Color` (fallback `#1E3A8A`), `AppColors.heroStatIncome/heroStatExpense/heroStatSavings/heroStatInvest`.
  - `String initialsOf(String name)`.
  - `WalletModel.isFavorite` (bool, default false), `WalletModel.minBalance` (double, default 0), `WalletModel.displayColor` (Color).
  - `({List<WalletModel> shown, int hiddenCount}) homeWallets(List<WalletModel> wallets)`; `double spendableOf(WalletModel w)`; `double spendableTotal(List<WalletModel> wallets, {required bool includeMinBalance})`; `bool wouldBreachMinBalance({required double balance, required double minBalance, required double amount})`; `String? minBalanceWarningMessage({required String walletName, required double balance, required double minBalance, required double amount})`.
  - `WalletNotifier.addWallet({..., double minBalance = 0})`, `updateWallet({..., double minBalance = 0})`, `Future<void> setFavorite(int id, bool isFavorite)`.
  - `userSettingsProvider` (`NotifierProvider.autoDispose<UserSettingsNotifier, UserSettingsState>`), `UserSettingsState({bool includeMinBalance = true, bool isLoading = true})`, `UserSettingsNotifier.setIncludeMinBalance(bool value)`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/core/wallet_rules_test.dart
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

WalletModel w(int id, double balance, {bool fav = false, double min = 0}) => WalletModel(
      id: id,
      userId: 'u',
      name: 'W$id',
      balance: balance,
      isFavorite: fav,
      minBalance: min,
    );

void main() {
  group('homeWallets', () {
    test('tanpa favorit: 3 saldo terbesar, sisanya dihitung tersembunyi', () {
      final r = homeWallets([w(1, 100), w(2, 500), w(3, 300), w(4, 900), w(5, 50)]);
      expect(r.shown.map((e) => e.id), [4, 2, 3]);
      expect(r.hiddenCount, 2);
    });

    test('tepat 3 dompet tanpa favorit: semua tampil, tidak ada yang tersembunyi', () {
      final r = homeWallets([w(1, 100), w(2, 200), w(3, 300)]);
      expect(r.shown.length, 3);
      expect(r.hiddenCount, 0);
    });

    test('saldo sama diurutkan berdasarkan id supaya stabil', () {
      final r = homeWallets([w(3, 100), w(1, 100), w(2, 100)]);
      expect(r.shown.map((e) => e.id), [1, 2, 3]);
    });

    test('ada favorit: hanya favorit yang tampil walau saldonya kecil', () {
      final r = homeWallets([w(1, 900), w(2, 10, fav: true), w(3, 20, fav: true)]);
      expect(r.shown.map((e) => e.id), [2, 3]);
      expect(r.hiddenCount, 1);
    });

    test('lebih dari 5 favorit: maksimal 5 tampil', () {
      final wallets = [for (var i = 1; i <= 7; i++) w(i, i * 10.0, fav: true)];
      final r = homeWallets(wallets);
      expect(r.shown.length, 5);
      expect(r.shown.map((e) => e.id), [1, 2, 3, 4, 5]);
      expect(r.hiddenCount, 2);
    });

    test('list kosong', () {
      final r = homeWallets([]);
      expect(r.shown, isEmpty);
      expect(r.hiddenCount, 0);
    });
  });

  group('spendableTotal', () {
    test('pengaturan aktif: jumlah saldo apa adanya', () {
      expect(spendableTotal([w(1, 1000, min: 200), w(2, 500)], includeMinBalance: true), 1500);
    });

    test('pengaturan nonaktif: saldo dikurangi saldo minimal', () {
      expect(spendableTotal([w(1, 1000, min: 200), w(2, 500)], includeMinBalance: false), 1300);
    });

    test('spendableTotal clamps per dompet di 0 bila saldo minimal > saldo', () {
      expect(spendableTotal([w(1, 100, min: 300), w(2, 500)], includeMinBalance: false), 500);
      expect(spendableOf(w(1, 100, min: 300)), 0);
    });
  });

  group('wouldBreachMinBalance', () {
    test('tanpa saldo minimal tidak pernah melanggar', () {
      expect(wouldBreachMinBalance(balance: 100, minBalance: 0, amount: 500), isFalse);
    });

    test('melanggar bila sisa < saldo minimal', () {
      expect(wouldBreachMinBalance(balance: 100000, minBalance: 50000, amount: 60000), isTrue);
    });

    test('tepat sama dengan saldo minimal tidak melanggar', () {
      expect(wouldBreachMinBalance(balance: 100000, minBalance: 50000, amount: 50000), isFalse);
    });

    test('nominal 0 / kosong tidak pernah memicu peringatan', () {
      expect(wouldBreachMinBalance(balance: 10000, minBalance: 50000, amount: 0), isFalse);
    });

    test('pesan peringatan memakai nama dompet dan saldo minimal', () {
      expect(
        minBalanceWarningMessage(walletName: 'BCA', balance: 100000, minBalance: 50000, amount: 60000),
        'Saldo BCA akan di bawah saldo minimal (Rp 50.000). Lanjutkan?',
      );
      expect(
        minBalanceWarningMessage(walletName: 'BCA', balance: 100000, minBalance: 50000, amount: 10000),
        isNull,
      );
    });
  });
}
```

```dart
// test/models/wallet_model_test.dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson tanpa kolom baru (migration belum jalan) memakai default', () {
    final m = WalletModel.fromJson({'id': 1, 'user_id': 'u', 'name': 'BCA', 'balance': 1000, 'color': '#00796B'});
    expect(m.isFavorite, isFalse);
    expect(m.minBalance, 0);
    expect(m.displayColor, const Color(0xFF00796B));
  });

  test('fromJson membaca is_favorite dan min_balance', () {
    final m = WalletModel.fromJson({
      'id': 1, 'user_id': 'u', 'name': 'BCA', 'balance': 1000,
      'is_favorite': true, 'min_balance': 50000,
    });
    expect(m.isFavorite, isTrue);
    expect(m.minBalance, 50000);
  });

  test('warna dompet null / rusak jatuh ke warna default', () {
    expect(AppColors.fromWalletHex(null), const Color(0xFF1E3A8A));
    expect(AppColors.fromWalletHex('bukan-warna'), const Color(0xFF1E3A8A));
    expect(AppColors.walletColorChoices.first, '#1E3A8A');
    expect(AppColors.walletColorChoices.length, 8);
  });
}
```

```dart
// test/core/initials_test.dart
import 'package:catat_uang_app/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initialsOf', () {
    expect(initialsOf('Akun Tes'), 'AT');
    expect(initialsOf('miftahul huda ramadhan'), 'MH');
    expect(initialsOf('Budi'), 'B');
    expect(initialsOf('   '), '?');
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/core/wallet_rules_test.dart test/models/wallet_model_test.dart test/core/initials_test.dart`
Expected: FAIL (compile error: `wallet_rules.dart` tidak ada, `isFavorite`/`minBalance`/`initialsOf` tidak terdefinisi).

- [ ] **Step 3: Tambahkan ke `lib/core/colors.dart`**

Tambahkan di dalam `class AppColors` (setelah token B1 yang sudah ada; jangan ubah yang lain):

```dart
  // Statistik kecil di kartu hero Beranda (pastel supaya terbaca di atas gradasi biru).
  static const Color heroStatIncome = Color(0xFF9BF0C4);
  static const Color heroStatExpense = Color(0xFFFFB4AE);
  static const Color heroStatSavings = Color(0xFFBFE6FF);
  static const Color heroStatInvest = Color(0xFFFFD28A);

  // Pilihan warna dompet. Disimpan sebagai string hex di kolom wallets.color,
  // jadi urutan & nilainya jangan diubah (data lama merujuk ke nilai ini).
  static const List<String> walletColorChoices = [
    '#1E3A8A', '#00796B', '#5E35B1', '#E65100',
    '#C62828', '#2E7D32', '#37474F', '#E91E63',
  ];

  /// Warna dompet dari string hex di data (mis. "#1E3A8A"); nilai null/rusak
  /// jatuh ke pilihan pertama, sama seperti fallback layar lama.
  static Color fromWalletHex(String? hex) {
    final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
    if (value == null || (hex ?? '').replaceFirst('#', '').length != 6) {
      return const Color(0xFF1E3A8A);
    }
    return Color(0xFF000000 | value);
  }
```

Bila file belum meng-import `package:flutter/material.dart`, biarkan import yang ada (sudah ada).

- [ ] **Step 4: Tambahkan `initialsOf` ke `lib/core/formatters.dart`** (di akhir file)

```dart
/// Inisial untuk avatar: dua huruf dari dua kata pertama, satu huruf bila
/// hanya satu kata, "?" bila kosong.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
```

- [ ] **Step 5: Tulis ulang `lib/models/wallet_model.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/painting.dart';

class WalletModel {
  final int id;
  final String userId;
  final String name;
  final double balance;
  final String? color;
  final String? icon;
  final bool isFavorite;
  final double minBalance;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.color,
    this.icon,
    this.isFavorite = false,
    this.minBalance = 0,
  });

  Color get displayColor => AppColors.fromWalletHex(color);

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      balance: (json['balance'] as num).toDouble(),
      color: json['color'],
      icon: json['icon'],
      // Kolom baru (migration 202609240002). Default dipakai bila kolom belum ada.
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      minBalance: (json['min_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
```

- [ ] **Step 6: Buat `lib/core/wallet_rules.dart`**

```dart
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/wallet_model.dart';

const int kHomeFavoriteLimit = 5;
const int kHomeTopWalletCount = 3;

/// Dompet yang tampil di Beranda (spec §7.2): semua favorit (maks 5) bila ada;
/// bila tidak ada favorit, 3 dompet dengan saldo terbesar.
({List<WalletModel> shown, int hiddenCount}) homeWallets(List<WalletModel> wallets) {
  final favorites = wallets.where((w) => w.isFavorite).toList();
  final List<WalletModel> shown;
  if (favorites.isNotEmpty) {
    shown = favorites.take(kHomeFavoriteLimit).toList();
  } else {
    final sorted = [...wallets]
      ..sort((a, b) {
        final byBalance = b.balance.compareTo(a.balance);
        return byBalance != 0 ? byBalance : a.id.compareTo(b.id);
      });
    shown = sorted.take(kHomeTopWalletCount).toList();
  }
  return (shown: shown, hiddenCount: wallets.length - shown.length);
}

/// Uang yang benar-benar bisa dipakai dari satu dompet: saldo − saldo minimal, minimal 0.
double spendableOf(WalletModel w) {
  final value = w.balance - w.minBalance;
  return value < 0 ? 0 : value;
}

/// Total saldo di Beranda. `includeMinBalance == true` = perilaku lama (jumlah saldo apa adanya).
double spendableTotal(List<WalletModel> wallets, {required bool includeMinBalance}) {
  var total = 0.0;
  for (final w in wallets) {
    total += includeMinBalance ? w.balance : spendableOf(w);
  }
  return total;
}

bool wouldBreachMinBalance({
  required double balance,
  required double minBalance,
  required double amount,
}) {
  return amount > 0 && minBalance > 0 && balance - amount < minBalance;
}

/// Pesan dialog peringatan (spec §7.3), atau null bila tidak perlu peringatan.
String? minBalanceWarningMessage({
  required String walletName,
  required double balance,
  required double minBalance,
  required double amount,
}) {
  if (!wouldBreachMinBalance(balance: balance, minBalance: minBalance, amount: amount)) {
    return null;
  }
  return 'Saldo $walletName akan di bawah saldo minimal (${formatRupiah(minBalance)}). Lanjutkan?';
}
```

- [ ] **Step 7: Ubah `lib/providers/wallet_provider.dart`**

Ganti `addWallet` dan `updateWallet` (baris 69–98) dan tambahkan `setFavorite` tepat setelah `deleteWallet` (baris 100–103). `fetchWallets`, `deleteWallet`, `transfer`, `validateTransfer` tidak diubah.

```dart
  Future<void> addWallet({
    required String name,
    required double balance,
    required String color,
    double minBalance = 0,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('wallets').insert({
      'user_id': userId,
      'name': name,
      'balance': balance,
      'color': color,
      'icon': 'wallet',
      'min_balance': minBalance,
    });
    await fetchWallets();
  }

  Future<void> updateWallet({
    required int id,
    required String name,
    required double balance,
    required String color,
    double minBalance = 0,
  }) async {
    await _supabase.from('wallets').update({
      'name': name,
      'balance': balance,
      'color': color,
      'icon': 'wallet',
      'min_balance': minBalance,
    }).eq('id', id);
    await fetchWallets();
  }
```

```dart
  Future<void> setFavorite(int id, bool isFavorite) async {
    await _supabase.from('wallets').update({'is_favorite': isFavorite}).eq('id', id);
    await fetchWallets();
  }
```

- [ ] **Step 8: Buat `lib/providers/user_settings_provider.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSettingsState {
  /// true = saldo minimal ikut dihitung di total saldo (perilaku lama).
  final bool includeMinBalance;
  final bool isLoading;

  const UserSettingsState({this.includeMinBalance = true, this.isLoading = true});

  UserSettingsState copyWith({bool? includeMinBalance, bool? isLoading}) {
    return UserSettingsState(
      includeMinBalance: includeMinBalance ?? this.includeMinBalance,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserSettingsNotifier extends AutoDisposeNotifier<UserSettingsState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  UserSettingsState build() {
    // Jangan sentuh `state` secara sinkron di build() (lihat WalletNotifier).
    Future.microtask(fetch);
    return const UserSettingsState();
  }

  Future<void> fetch() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final data = await _supabase
          .from('profiles')
          .select('include_min_balance')
          .eq('id', user.id)
          .maybeSingle();
      state = state.copyWith(
        includeMinBalance: (data?['include_min_balance'] as bool?) ?? true,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error fetch user settings: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  /// Optimistis: state langsung berubah, dikembalikan bila penyimpanan gagal (lalu rethrow).
  Future<void> setIncludeMinBalance(bool value) async {
    final previous = state.includeMinBalance;
    state = state.copyWith(includeMinBalance: value);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('profiles').update({'include_min_balance': value}).eq('id', userId);
    } catch (e) {
      state = state.copyWith(includeMinBalance: previous);
      rethrow;
    }
  }
}

final userSettingsProvider =
    NotifierProvider.autoDispose<UserSettingsNotifier, UserSettingsState>(UserSettingsNotifier.new);
```

- [ ] **Step 9: Jalankan test, pastikan lulus**

Run: `flutter test test/core/wallet_rules_test.dart test/models/wallet_model_test.dart test/core/initials_test.dart test/providers/wallet_provider_test.dart`
Expected: PASS semua (test provider lama tetap lulus karena parameter baru opsional).

- [ ] **Step 10: Analyze & commit**

```bash
flutter analyze lib/core lib/models/wallet_model.dart lib/providers/wallet_provider.dart lib/providers/user_settings_provider.dart
git add lib/core/colors.dart lib/core/formatters.dart lib/core/wallet_rules.dart lib/models/wallet_model.dart lib/providers/wallet_provider.dart lib/providers/user_settings_provider.dart test/core/wallet_rules_test.dart test/models/wallet_model_test.dart test/core/initials_test.dart
git commit -m "$(cat <<'EOF'
feat(wallet): add favorite and min balance fields with home rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: Data ringkasan Beranda

**Files:**
- Create: `lib/providers/home_summary.dart`
- Modify: `lib/providers/home_provider.dart` (HomeState 11–53, `refreshData` 71–74, `getUserProfile` 150–167, `fetchHomeData` 186–238, tambah `fetchSummary`)
- Test: `test/providers/home_summary_test.dart`, `test/providers/home_provider_test.dart`

**Interfaces:**
- Consumes: `TargetModel` (`lib/models/target_model.dart`), `RecurringTransactionModel` (`lib/models/recurring_transaction_model.dart`), `DebtModel` (Plan B2), `WalletModel` (Task 2).
- Produces:
  - `class BudgetSummary { final double totalSpent; final double totalBudget; double get ratio; }`
  - `class HomeSummary { final BudgetSummary? budget; final TargetModel? target; final RecurringTransactionModel? nextBill; final DebtModel? debt; const HomeSummary({...}); }`
  - `bool isInternalMutationNote(String? note)` — true untuk `[SAVING_ID:` atau `[DEBT_ID:`.
  - `BudgetSummary? summarizeBudgets({required List<Map<String, dynamic>> budgets, required List<Map<String, dynamic>> monthTransactions})`
  - `TargetModel? pickTarget(List<TargetModel> targets)`
  - `RecurringTransactionModel? pickNextBill(List<RecurringTransactionModel> items)`
  - `DebtModel? pickDebt(List<DebtModel> debts)`
  - `int overdueDays(DateTime? dueDate, DateTime today)`
  - `HomeState.wallets` bertipe `List<WalletModel>` (sebelumnya `List<Map<String, dynamic>>`), `HomeState.includeMinBalance` (bool, default true), `HomeState.summary` (`HomeSummary`, default `const HomeSummary()`), `HomeNotifier.fetchSummary()`.

Aturan pemilihan (spec §7.2):
- **Anggaran:** total anggaran bulan berjalan dan total pengeluaran bulan berjalan pada kategori yang dianggarkan, tanpa mutasi internal — sama dengan `BudgetNotifier.fetchBudgets` (budget_provider.dart:101–159). `null` bila tidak ada anggaran bulan ini.
- **Target:** target belum tercapai (`saved < target`) dengan deadline terdekat; bila tidak ada yang punya deadline, progres tertinggi. `null` bila semua tercapai/kosong.
- **Tagihan:** jadwal rutin aktif yang kategorinya pengeluaran (`categories.is_expense`, default `true` seperti `home_provider.dart:95`) dengan `next_run_date` paling awal.
- **Utang:** utang saya (`type == 'payable'`), status bukan `paid`, sisa > 0; yang punya jatuh tempo diurutkan jatuh tempo paling awal (yang terlambat otomatis di depan); bila tidak ada yang punya jatuh tempo, sisa terbesar.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/providers/home_summary_test.dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:flutter_test/flutter_test.dart';

TargetModel target(int id, double saved, double goal, {DateTime? deadline}) =>
    TargetModel(id: id, name: 'T$id', targetAmount: goal, savedAmount: saved, deadline: deadline);

RecurringTransactionModel bill(int id, DateTime next, {bool active = true, bool? isExpense = true}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u',
      categoryId: 1,
      amount: 100000,
      frequency: 'Bulanan',
      startDate: DateTime(2026, 1, 1),
      nextRunDate: next,
      isActive: active,
      category: isExpense == null ? null : {'name': 'Kos', 'is_expense': isExpense},
    );

DebtModel debt(int id, double remaining, {String type = 'payable', String status = 'active', DateTime? due}) =>
    DebtModel(
      id: id,
      name: 'D$id',
      type: type,
      amount: 1000000,
      remainingAmount: remaining,
      dueDate: due,
      status: status,
    );

void main() {
  group('summarizeBudgets', () {
    test('null bila tidak ada anggaran bulan ini', () {
      expect(summarizeBudgets(budgets: [], monthTransactions: []), isNull);
    });

    test('hanya pengeluaran pada kategori beranggaran, tanpa mutasi internal', () {
      final s = summarizeBudgets(
        budgets: [
          {'category_id': 1, 'amount': 1500000},
          {'category_id': 2, 'amount': 500000},
        ],
        monthTransactions: [
          {'amount': 100000, 'category_id': 1, 'note': 'makan', 'categories': {'is_expense': true}},
          {'amount': 50000, 'category_id': 2, 'note': null, 'categories': {'is_expense': true}},
          {'amount': 999, 'category_id': 3, 'note': '', 'categories': {'is_expense': true}}, // tidak dianggarkan
          {'amount': 700000, 'category_id': 1, 'note': 'gaji', 'categories': {'is_expense': false}}, // pemasukan
          {'amount': 250000, 'category_id': 1, 'note': 'x [SAVING_ID:3]', 'categories': {'is_expense': true}},
          {'amount': 300000, 'category_id': 1, 'note': 'y [DEBT_ID:9]', 'categories': {'is_expense': true}},
        ],
      )!;
      expect(s.totalBudget, 2000000);
      expect(s.totalSpent, 150000);
      expect(s.ratio, closeTo(0.075, 1e-9));
    });

    test('ratio 0 bila total anggaran 0 (tidak membagi dengan nol)', () {
      final s = summarizeBudgets(budgets: [{'category_id': 1, 'amount': 0}], monthTransactions: [])!;
      expect(s.ratio, 0);
    });
  });

  group('pickTarget', () {
    test('deadline terdekat di antara yang belum tercapai', () {
      final t = pickTarget([
        target(1, 10, 100, deadline: DateTime(2026, 12, 31)),
        target(2, 10, 100, deadline: DateTime(2026, 10, 1)),
        target(3, 100, 100, deadline: DateTime(2026, 9, 1)), // tercapai
      ]);
      expect(t!.id, 2);
    });

    test('tanpa deadline: progres tertinggi', () {
      final t = pickTarget([target(1, 10, 100), target(2, 80, 100), target(3, 30, 100)]);
      expect(t!.id, 2);
    });

    test('null bila semua tercapai', () {
      expect(pickTarget([target(1, 100, 100)]), isNull);
      expect(pickTarget([]), isNull);
    });
  });

  group('pickNextBill', () {
    test('jadwal aktif pengeluaran paling awal', () {
      final b = pickNextBill([
        bill(1, DateTime(2026, 10, 5)),
        bill(2, DateTime(2026, 10, 1)),
        bill(3, DateTime(2026, 9, 25), isExpense: false), // pemasukan
        bill(4, DateTime(2026, 9, 20), active: false), // nonaktif
      ]);
      expect(b!.id, 2);
    });

    test('kategori tidak terbaca dianggap pengeluaran', () {
      expect(pickNextBill([bill(1, DateTime(2026, 10, 1), isExpense: null)])!.id, 1);
    });

    test('null bila tidak ada tagihan', () {
      expect(pickNextBill([bill(1, DateTime(2026, 10, 1), isExpense: false)]), isNull);
    });
  });

  group('pickDebt', () {
    test('utang saya dengan jatuh tempo paling awal (yang terlambat duluan)', () {
      final d = pickDebt([
        debt(1, 500000, due: DateTime(2026, 11, 1)),
        debt(2, 200000, due: DateTime(2026, 9, 1)),
        debt(3, 900000, type: 'receivable', due: DateTime(2026, 8, 1)),
        debt(4, 0, due: DateTime(2026, 7, 1)),
        debt(5, 300000, status: 'paid', due: DateTime(2026, 7, 1)),
      ]);
      expect(d!.id, 2);
    });

    test('tanpa jatuh tempo: sisa terbesar', () {
      expect(pickDebt([debt(1, 100), debt(2, 900), debt(3, 500)])!.id, 2);
    });

    test('null bila bebas utang', () {
      expect(pickDebt([debt(1, 500, type: 'receivable')]), isNull);
    });
  });

  test('overdueDays', () {
    final today = DateTime(2026, 9, 24, 15, 30);
    expect(overdueDays(DateTime(2026, 9, 22), today), 2);
    expect(overdueDays(DateTime(2026, 9, 24), today), 0);
    expect(overdueDays(DateTime(2026, 9, 30), today), 0);
    expect(overdueDays(null, today), 0);
  });
}
```

```dart
// test/providers/home_provider_test.dart
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeState default: pengaturan saldo minimal aktif, ringkasan kosong', () {
    const s = HomeState();
    expect(s.includeMinBalance, isTrue);
    expect(s.wallets, isEmpty);
    expect(s.summary.budget, isNull);
    expect(s.summary.debt, isNull);
  });

  test('copyWith mempertahankan summary dan includeMinBalance', () {
    const summary = HomeSummary(budget: BudgetSummary(totalSpent: 1, totalBudget: 2));
    final s = const HomeState().copyWith(summary: summary, includeMinBalance: false);
    final s2 = s.copyWith(userName: 'X');
    expect(s2.summary.budget!.totalBudget, 2);
    expect(s2.includeMinBalance, isFalse);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/providers/home_summary_test.dart test/providers/home_provider_test.dart`
Expected: FAIL (compile error: `home_summary.dart` tidak ada; `HomeState.summary`/`includeMinBalance` tidak ada).

- [ ] **Step 3: Buat `lib/providers/home_summary.dart`**

```dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/models/target_model.dart';

class BudgetSummary {
  final double totalSpent;
  final double totalBudget;

  const BudgetSummary({required this.totalSpent, required this.totalBudget});

  double get ratio => totalBudget <= 0 ? 0 : totalSpent / totalBudget;
}

/// Data empat kartu ringkasan Beranda (spec §7.2). null = tampilkan empty state.
class HomeSummary {
  final BudgetSummary? budget;
  final TargetModel? target;
  final RecurringTransactionModel? nextBill;
  final DebtModel? debt;

  const HomeSummary({this.budget, this.target, this.nextBill, this.debt});
}

/// Transaksi yang hanya memindahkan uang (tabungan / utang-piutang), bukan
/// pemasukan/pengeluaran sungguhan.
bool isInternalMutationNote(String? note) {
  final n = note ?? '';
  return n.contains('[SAVING_ID:') || n.contains('[DEBT_ID:');
}

BudgetSummary? summarizeBudgets({
  required List<Map<String, dynamic>> budgets,
  required List<Map<String, dynamic>> monthTransactions,
}) {
  if (budgets.isEmpty) return null;
  final budgetCategoryIds = <int>{};
  var totalBudget = 0.0;
  for (final b in budgets) {
    budgetCategoryIds.add(b['category_id'] as int);
    totalBudget += (b['amount'] as num).toDouble();
  }
  var totalSpent = 0.0;
  for (final t in monthTransactions) {
    if (isInternalMutationNote(t['note']?.toString())) continue;
    final catId = t['category_id'] as int?;
    final isExpense = (t['categories']?['is_expense'] as bool?) ?? false;
    if (catId == null || !isExpense || !budgetCategoryIds.contains(catId)) continue;
    totalSpent += (t['amount'] as num).toDouble();
  }
  return BudgetSummary(totalSpent: totalSpent, totalBudget: totalBudget);
}

double _progress(TargetModel t) => t.targetAmount <= 0 ? 0 : t.savedAmount / t.targetAmount;

TargetModel? pickTarget(List<TargetModel> targets) {
  final open = targets.where((t) => t.savedAmount < t.targetAmount).toList();
  if (open.isEmpty) return null;
  final withDeadline = open.where((t) => t.deadline != null).toList()
    ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  if (withDeadline.isNotEmpty) return withDeadline.first;
  open.sort((a, b) => _progress(b).compareTo(_progress(a)));
  return open.first;
}

RecurringTransactionModel? pickNextBill(List<RecurringTransactionModel> items) {
  final bills = items
      .where((r) => r.isActive && ((r.category?['is_expense'] as bool?) ?? true))
      .toList()
    ..sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));
  return bills.isEmpty ? null : bills.first;
}

DebtModel? pickDebt(List<DebtModel> debts) {
  final open = debts
      .where((d) => d.type == 'payable' && d.status != 'paid' && d.remainingAmount > 0)
      .toList();
  if (open.isEmpty) return null;
  final dated = open.where((d) => d.dueDate != null).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  if (dated.isNotEmpty) return dated.first;
  open.sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount));
  return open.first;
}

/// Jumlah hari lewat jatuh tempo (0 bila belum lewat / tanpa jatuh tempo).
int overdueDays(DateTime? dueDate, DateTime today) {
  if (dueDate == null) return 0;
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final day = DateTime(today.year, today.month, today.day);
  final diff = day.difference(due).inDays;
  return diff > 0 ? diff : 0;
}
```

- [ ] **Step 4: Ubah `HomeState` di `lib/providers/home_provider.dart` (baris 11–53)**

Tambahkan import di atas file:

```dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
```

Ganti seluruh class `HomeState` dengan:

```dart
class HomeState {
  final String userName;
  final double monthlyIncome;
  final double monthlyExpense;
  final double totalSavings;
  final double totalInvestments;
  final List<WalletModel> wallets;
  final double totalWalletBalance;
  final bool isLoading;
  /// profiles.include_min_balance — true = saldo minimal ikut dihitung (perilaku lama).
  final bool includeMinBalance;
  final HomeSummary summary;

  const HomeState({
    this.userName = "Memuat...",
    this.monthlyIncome = 0,
    this.monthlyExpense = 0,
    this.totalSavings = 0,
    this.totalInvestments = 0,
    this.wallets = const [],
    this.totalWalletBalance = 0,
    this.isLoading = true,
    this.includeMinBalance = true,
    this.summary = const HomeSummary(),
  });

  HomeState copyWith({
    String? userName,
    double? monthlyIncome,
    double? monthlyExpense,
    double? totalSavings,
    double? totalInvestments,
    List<WalletModel>? wallets,
    double? totalWalletBalance,
    bool? isLoading,
    bool? includeMinBalance,
    HomeSummary? summary,
  }) {
    return HomeState(
      userName: userName ?? this.userName,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      totalSavings: totalSavings ?? this.totalSavings,
      totalInvestments: totalInvestments ?? this.totalInvestments,
      wallets: wallets ?? this.wallets,
      totalWalletBalance: totalWalletBalance ?? this.totalWalletBalance,
      isLoading: isLoading ?? this.isLoading,
      includeMinBalance: includeMinBalance ?? this.includeMinBalance,
      summary: summary ?? this.summary,
    );
  }
}
```

- [ ] **Step 5: Ubah `refreshData`, `getUserProfile`, `fetchHomeData`; tambah `fetchSummary`**

`refreshData` (baris 71–74) — `fetchSummary` ikut paralel:

```dart
  Future<void> refreshData() async {
    await checkRecurringTransactions();
    await Future.wait([getUserProfile(), fetchHomeData(), fetchSummary()]);
  }
```

`getUserProfile` — ganti hanya blok `state = state.copyWith(...)` (baris 159–163):

```dart
      state = state.copyWith(
        userName: data != null
            ? data['name']
            : (user.userMetadata?['name'] ?? "User"),
        // Kolom migration 202609240002; default true bila belum ada.
        includeMinBalance: (data?['include_min_balance'] as bool?) ?? true,
      );
```

`fetchHomeData` — ganti hanya satu baris di `state = state.copyWith(...)` (baris 235). **Jangan ubah logika mutasi internal di atasnya** (Plan B2 menambahkan pengecualian `[DEBT_ID:` di sana):

```dart
        wallets: (walletsResponse as List).map((e) => WalletModel.fromJson(e)).toList(),
```

Tambahkan method baru di `HomeNotifier`, setelah `fetchHomeData`:

```dart
  /// Data empat kartu ringkasan Beranda. Lima query independen dijalankan paralel.
  Future<void> fetchSummary() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final startMonth = DateFormat('yyyy-MM-01').format(now);
      final nextMonth = DateFormat('yyyy-MM-01').format(DateTime(now.year, now.month + 1, 1));

      final results = await Future.wait<dynamic>([
        _supabase
            .from('budgets')
            .select('category_id, amount')
            .eq('user_id', userId)
            .eq('month', now.month)
            .eq('year', now.year),
        _supabase
            .from('transactions')
            .select('amount, category_id, note, categories(is_expense)')
            .eq('user_id', userId)
            .gte('date', startMonth)
            .lt('date', nextMonth),
        _supabase.from('targets').select().eq('user_id', userId),
        _supabase
            .from('recurring_transactions')
            .select('*, categories(name, is_expense)')
            .eq('user_id', userId)
            .eq('is_active', true),
        _supabase
            .from('debts')
            .select()
            .eq('user_id', userId)
            .eq('type', 'payable')
            .eq('status', 'active'),
      ]);

      state = state.copyWith(
        summary: HomeSummary(
          budget: summarizeBudgets(
            budgets: List<Map<String, dynamic>>.from(results[0] as List),
            monthTransactions: List<Map<String, dynamic>>.from(results[1] as List),
          ),
          target: pickTarget(
            (results[2] as List).map((e) => TargetModel.fromJson(e)).toList(),
          ),
          nextBill: pickNextBill(
            (results[3] as List).map((e) => RecurringTransactionModel.fromJson(e)).toList(),
          ),
          debt: pickDebt(
            (results[4] as List).map((e) => DebtModel.fromJson(e)).toList(),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error home summary: $e");
    }
  }
```

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: `flutter test test/providers/home_summary_test.dart test/providers/home_provider_test.dart`
Expected: PASS. Bila compile error di `DebtModel(...)` karena konstruktor B2 berbeda, sesuaikan helper `debt()` di test (lihat bagian "Interfaces dari Plan B2").

- [ ] **Step 7: Analyze & commit**

`home_screen.dart` belum dikompilasi ulang dengan `wallets` bertipe baru — Task 5 menulis ulang bagian itu. Agar commit ini tetap hijau, di `home_screen.dart` ganti sementara dua pemakaian `wallet['color']`, `wallet['name']`, `wallet['balance']` (baris 421, 454, 467, 915, 940, 949) menjadi `wallet.color`, `wallet.name`, `wallet.balance`.

```bash
flutter analyze lib/providers lib/screens/home
flutter test
git add lib/providers/home_summary.dart lib/providers/home_provider.dart lib/screens/home/home_screen.dart test/providers/home_summary_test.dart test/providers/home_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(home): fetch summary widgets data and min balance setting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: Halaman Semua Fitur

**Files:**
- Create: `lib/screens/all_features/app_feature.dart`
- Create: `lib/screens/all_features/all_features_screen.dart`
- Test: `test/screens/all_features_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppTextField`, `AppEmptyState` (B1).
- Produces:
  - `enum AppFeatureGroup { harian, perencanaan, asetKewajiban, alat }` dengan `String label`.
  - `enum HomeRefreshAfter { none, homeData, homeDataAndTabs }`.
  - `enum AppFeature { wallet, calendar, category, budget, target, savings, recurring, investment, debt, zakat, aiAdvisor, exportReport }` dengan `label`, `icon`, `color`, `group`, `refreshAfter`, `Widget buildScreen()`.
  - `Map<AppFeatureGroup, List<AppFeature>> filterFeatures(String query)`.
  - `AllFeaturesScreen({required ValueChanged<AppFeature> onOpen})`, `AllFeaturesSections({required String query, required ValueChanged<AppFeature> onOpen})`.

Tabel refresh (dipindahkan persis dari grid lama `home_screen.dart` mobile 493–651 = web 976–1037):

| Fitur | Callback lama | `refreshAfter` |
|---|---|---|
| Tagihan (`RecurringScreen`) | 497–506: `await push` → `refreshData()` → `_bumpRefreshCounter()` | `homeDataAndTabs` |
| Tabungan (`SavingsScreen`) | 512–521: sama | `homeDataAndTabs` |
| Anggaran (`BudgetScreen`) | 527–532: `push` saja | `none` |
| Target (`TargetScreen`) | 538–543: `push` saja | `none` |
| Kategori (`ManageCategoryScreen`) | 555–561: `push` saja | `none` |
| Export (`ExportScreen`) | 567–572: `push` saja | `none` |
| AI Advisor (`AiAdvisorScreen`) | 578–583: `push` saja | `none` |
| Kalender (`CalendarScreen`) | 589–594: `push` saja | `none` |
| Dompet (`WalletScreen`) | 606–614: `await push` → `refreshData()` | `homeData` |
| Utang (`DebtScreen`) | 620–625: `push` saja; **spec §7.1 #7 / Plan B2**: `refreshData()` + `_bumpRefreshCounter()` | `homeDataAndTabs` |
| Investasi (`InvestmentScreen`) | 631–638: `push().then(refreshData)` | `homeData` |
| Zakat (`ZakatSedekahScreen`) | 644–649: `push().then(refreshData)` | `homeData` |

Label di Semua Fitur mengikuti spec §7.2 (lebih lengkap dari label grid: "Target Keuangan", "Buku Tabungan", "Tagihan & Pemasukan Rutin", "Utang & Piutang", "Zakat & Sedekah", "Export Laporan"). Ikon = ikon Fill yang sama dengan grid lama. Warna tile (filled) mengikuti mockup "Semua Fitur".

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/screens/all_features_screen_test.dart
import 'package:catat_uang_app/screens/all_features/all_features_screen.dart';
import 'package:catat_uang_app/screens/all_features/app_feature.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('filterFeatures: kosong = 4 grup berisi 12 fitur', () {
    final g = filterFeatures('');
    expect(g.keys, AppFeatureGroup.values);
    expect(g.values.expand((e) => e).length, 12);
    expect(g[AppFeatureGroup.harian], [AppFeature.wallet, AppFeature.calendar, AppFeature.category]);
  });

  test('filterFeatures: tidak peka huruf besar/kecil, grup kosong disembunyikan', () {
    final g = filterFeatures('  TABUNG ');
    expect(g.keys, [AppFeatureGroup.perencanaan]);
    expect(g[AppFeatureGroup.perencanaan], [AppFeature.savings]);
    expect(filterFeatures('xyz'), isEmpty);
  });

  test('refreshAfter sesuai tabel grid lama', () {
    expect(AppFeature.recurring.refreshAfter, HomeRefreshAfter.homeDataAndTabs);
    expect(AppFeature.savings.refreshAfter, HomeRefreshAfter.homeDataAndTabs);
    expect(AppFeature.debt.refreshAfter, HomeRefreshAfter.homeDataAndTabs);
    expect(AppFeature.wallet.refreshAfter, HomeRefreshAfter.homeData);
    expect(AppFeature.investment.refreshAfter, HomeRefreshAfter.homeData);
    expect(AppFeature.zakat.refreshAfter, HomeRefreshAfter.homeData);
    for (final f in [AppFeature.budget, AppFeature.target, AppFeature.category,
        AppFeature.exportReport, AppFeature.aiAdvisor, AppFeature.calendar]) {
      expect(f.refreshAfter, HomeRefreshAfter.none, reason: f.name);
    }
  });

  testWidgets('menampilkan 4 label grup dan 12 baris', (tester) async {
    await pumpApp(tester, AllFeaturesScreen(onOpen: (_) {}), size: const Size(390, 1600));
    expect(find.text('Semua Fitur'), findsOneWidget);
    for (final label in ['HARIAN', 'PERENCANAAN', 'ASET & KEWAJIBAN', 'ALAT']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(AppListRow), findsNWidgets(12));
  });

  testWidgets('cari memfilter baris; tanpa hasil menampilkan empty state', (tester) async {
    await pumpApp(tester, AllFeaturesScreen(onOpen: (_) {}), size: const Size(390, 1600));
    await tester.enterText(find.byType(TextField), 'tabung');
    await tester.pump();
    expect(find.text('Buku Tabungan'), findsOneWidget);
    expect(find.text('Dompet'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Fitur tidak ditemukan'), findsOneWidget);
  });

  testWidgets('ketuk baris memanggil onOpen dengan fitur yang benar', (tester) async {
    final opened = <AppFeature>[];
    await pumpApp(tester, AllFeaturesScreen(onOpen: opened.add), size: const Size(390, 1600));
    await tester.tap(find.text('Kalender'));
    await tester.pump();
    expect(opened, [AppFeature.calendar]);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/all_features_screen_test.dart`
Expected: FAIL (file screen belum ada).

- [ ] **Step 3: Buat `lib/screens/all_features/app_feature.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:catat_uang_app/screens/budget/budget_screen.dart';
import 'package:catat_uang_app/screens/calendar/calendar_screen.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/screens/export/export_screen.dart';
import 'package:catat_uang_app/screens/investment/investment_screen.dart';
import 'package:catat_uang_app/screens/manage_category/manage_category_screen.dart';
import 'package:catat_uang_app/screens/recurring/recurring_screen.dart';
import 'package:catat_uang_app/screens/savings/savings_screen.dart';
import 'package:catat_uang_app/screens/target/target_screen.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:catat_uang_app/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum AppFeatureGroup {
  harian('Harian'),
  perencanaan('Perencanaan'),
  asetKewajiban('Aset & Kewajiban'),
  alat('Alat');

  const AppFeatureGroup(this.label);
  final String label;
}

/// Refresh Beranda yang dijalankan setelah layar fitur ditutup — dipindahkan
/// persis dari callback grid Beranda lama (lihat tabel di Plan B3 Task 4).
enum HomeRefreshAfter { none, homeData, homeDataAndTabs }

enum AppFeature {
  wallet('Dompet', PhosphorIconsFill.wallet, AppColors.tintBrown, AppFeatureGroup.harian, HomeRefreshAfter.homeData),
  calendar('Kalender', PhosphorIconsFill.calendar, AppColors.tintPink, AppFeatureGroup.harian, HomeRefreshAfter.none),
  category('Kategori', PhosphorIconsFill.squaresFour, AppColors.tintOrange, AppFeatureGroup.harian, HomeRefreshAfter.none),
  budget('Anggaran', PhosphorIconsFill.chartDonut, AppColors.tintIndigo, AppFeatureGroup.perencanaan, HomeRefreshAfter.none),
  target('Target Keuangan', PhosphorIconsFill.target, AppColors.tintGreen, AppFeatureGroup.perencanaan, HomeRefreshAfter.none),
  savings('Buku Tabungan', PhosphorIconsFill.piggyBank, AppColors.tintTeal, AppFeatureGroup.perencanaan, HomeRefreshAfter.homeDataAndTabs),
  recurring('Tagihan & Pemasukan Rutin', PhosphorIconsFill.calendarPlus, AppColors.tintRed, AppFeatureGroup.perencanaan, HomeRefreshAfter.homeDataAndTabs),
  investment('Investasi', PhosphorIconsFill.chartLineUp, AppColors.tintAmber, AppFeatureGroup.asetKewajiban, HomeRefreshAfter.homeData),
  debt('Utang & Piutang', PhosphorIconsFill.handCoins, AppColors.tintSky, AppFeatureGroup.asetKewajiban, HomeRefreshAfter.homeDataAndTabs),
  zakat('Zakat & Sedekah', PhosphorIconsFill.handHeart, AppColors.tintGreen, AppFeatureGroup.asetKewajiban, HomeRefreshAfter.homeData),
  aiAdvisor('AI Advisor', PhosphorIconsFill.robot, AppColors.tintIndigo, AppFeatureGroup.alat, HomeRefreshAfter.none),
  exportReport('Export Laporan', PhosphorIconsFill.filePdf, AppColors.tintBlue, AppFeatureGroup.alat, HomeRefreshAfter.none);

  const AppFeature(this.label, this.icon, this.color, this.group, this.refreshAfter);

  final String label;
  final IconData icon;
  final Color color;
  final AppFeatureGroup group;
  final HomeRefreshAfter refreshAfter;

  Widget buildScreen() => switch (this) {
        AppFeature.wallet => const WalletScreen(),
        AppFeature.calendar => const CalendarScreen(),
        AppFeature.category => const ManageCategoryScreen(),
        AppFeature.budget => const BudgetScreen(),
        AppFeature.target => const TargetScreen(),
        AppFeature.savings => const SavingsScreen(),
        AppFeature.recurring => const RecurringScreen(),
        AppFeature.investment => const InvestmentScreen(),
        AppFeature.debt => const DebtScreen(),
        AppFeature.zakat => const ZakatSedekahScreen(),
        AppFeature.aiAdvisor => const AiAdvisorScreen(),
        AppFeature.exportReport => const ExportScreen(),
      };
}

/// Fitur per grup yang labelnya mengandung [query] (tanpa peka huruf besar/kecil).
/// Grup tanpa hasil tidak disertakan; urutan grup & fitur mengikuti deklarasi enum.
Map<AppFeatureGroup, List<AppFeature>> filterFeatures(String query) {
  final q = query.trim().toLowerCase();
  final result = <AppFeatureGroup, List<AppFeature>>{};
  for (final group in AppFeatureGroup.values) {
    final items = AppFeature.values
        .where((f) => f.group == group && (q.isEmpty || f.label.toLowerCase().contains(q)))
        .toList();
    if (items.isNotEmpty) result[group] = items;
  }
  return result;
}
```

Bila salah satu constructor layar tidak `const` lagi (mis. plan lain menambah parameter wajib), hapus `const` di baris itu saja.

- [ ] **Step 4: Buat `lib/screens/all_features/all_features_screen.dart`**

```dart
import 'package:catat_uang_app/screens/all_features/app_feature.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AllFeaturesScreen extends StatefulWidget {
  const AllFeaturesScreen({required this.onOpen, super.key});

  /// Dipanggil saat baris diketuk. HomeScreen yang melakukan navigasi + refresh
  /// supaya perilaku setelah kembali sama persis dengan grid lama.
  final ValueChanged<AppFeature> onOpen;

  @override
  State<AllFeaturesScreen> createState() => _AllFeaturesScreenState();
}

class _AllFeaturesScreenState extends State<AllFeaturesScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Semua Fitur',
      backLabel: 'Beranda',
      children: [
        AppTextField(
          controller: _search,
          hint: 'Cari fitur',
          icon: PhosphorIconsRegular.magnifyingGlass,
          onChanged: (_) => setState(() {}),
        ),
        AllFeaturesSections(query: _search.text, onOpen: widget.onOpen),
      ],
    );
  }
}

/// Grup-grup fitur tanpa scaffold — dipakai AllFeaturesScreen (mobile) dan
/// langsung di kolom Beranda web.
class AllFeaturesSections extends StatelessWidget {
  const AllFeaturesSections({required this.query, required this.onOpen, super.key});

  final String query;
  final ValueChanged<AppFeature> onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = filterFeatures(query);
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AppEmptyState(
          icon: PhosphorIconsRegular.magnifyingGlass,
          title: 'Fitur tidak ditemukan',
          subtitle: 'Coba kata kunci lain.',
        ),
      );
    }
    final entries = groups.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppPageScaffold.blockGap),
          AppGroupedSection(
            header: entries[i].key.label,
            children: [
              for (final f in entries[i].value)
                AppListRow(
                  leading: AppIconTile(icon: f.icon, color: f.color, filled: true),
                  title: f.label,
                  showChevron: true,
                  onTap: () => onOpen(f),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/all_features_screen_test.dart`
Expected: PASS (6 test). Bila `find.text('HARIAN')` gagal karena `AppGroupedSection` B1 tidak mengubah string ke huruf besar, perbaiki komponen B1 (spec §6: label HURUF BESAR) — jangan ubah test.

- [ ] **Step 6: Visual checklist (mockup "Semua Fitur")**

- [ ] Nav bar: `‹ Beranda` biru di kiri, tanpa aksi kanan.
- [ ] Judul besar "Semua Fitur" rata kiri.
- [ ] Field cari putih radius 16 dengan ikon kaca pembesar, hint "Cari fitur".
- [ ] 4 grup berurutan HARIAN, PERENCANAAN, ASET & KEWAJIBAN, ALAT; label kecil huruf besar abu.
- [ ] Tiap baris: tile warna penuh + ikon putih, label, chevron abu; pemisah menjorok setelah tile.
- [ ] Tanpa hasil: empty state kaca pembesar "Fitur tidak ditemukan".

- [ ] **Step 7: Analyze & commit**

```bash
flutter analyze lib/screens/all_features
grep -c "GoogleFonts.poppins" lib/screens/all_features/*.dart
git add lib/screens/all_features test/screens/all_features_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(home): add all features screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

Expected grep: `0` untuk kedua file.

---

### Task 5: Beranda mobile (redesign)

**Files:**
- Modify: `lib/screens/home/home_screen.dart` — ganti blok baris 58–662 (`_showComingSoon` s.d. akhir `_buildMobileHomeContent`) dan import; `_buildMobileLayout` (1049–1130) **tidak diubah**.
- Test: `test/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 (`homeWallets`, `spendableOf`, `spendableTotal`, `WalletModel`, `initialsOf`, `AppColors.heroStat*`), Task 3 (`HomeState`, `HomeSummary`, `overdueDays`), Task 4 (`AppFeature`, `HomeRefreshAfter`, `AllFeaturesScreen`, `AllFeaturesSections`), B1 (`AppPageScaffold`, `AppHeroCard`, `AppHeroLabel`, `AppHeroAmount`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppSummaryWidget`, `AppProgressBar`, `AppTextStyles`, `formatRupiah`, `formatRupiahCompact`).
- Produces: method State `_openFeature(AppFeature)`, `_openWallets()`, `_openSettings()`, `_openAllFeatures()`; widget privat `_HomeHeader`, `_HomeHeroCard`, `_HeroStat`, `_HomeWalletSection`, `_HomeSummaryGrid` (dipakai juga Task 6).

**Tabel preservasi (kode lama `home_screen.dart` → layout baru)**

| # | Perilaku lama | Baris lama | Di layout baru |
|---|---|---|---|
| 1 | Loading → `Center(CircularProgressIndicator())` | 164–166 | Sama, di awal `_buildMobileHomeContent` |
| 2 | Tarik-untuk-refresh → `refreshData()` | 170–171 | `AppPageScaffold.onRefresh` |
| 3 | Header "Halo, Bos!" + `userName` | 185–207 | `_HomeHeader` (judul besar pakai `titleWidget`) |
| 4 | Ketuk ikon pengaturan: `await push(SettingsScreen)` → `getUserProfile()` | 208–217 | Avatar inisial kanan atas → `_openSettings()` (+`mounted`) |
| 5 | Total = `totalWalletBalance` | 274–281 | `spendableTotal(wallets, includeMinBalance)` — sama persis bila pengaturan aktif (default) |
| 6 | 4 statistik Masuk/Keluar/Tabungan/Investasi, format Rupiah penuh | 294–331 | `_HeroStat` ×4, `formatRupiah` penuh |
| 7 | "Dompet Saya" + "Kelola": `await push(WalletScreen)` → `refreshData()` | 340–371 | Header grup "DOMPET" + aksi "Kelola" → `_openWallets()` |
| 8 | Dompet kosong: "Buat Dompet Pertama" → navigasi sama | 373–412 | Satu `AppListRow` "Buat Dompet Pertama" → `_openWallets()` |
| 9 | Kartu dompet geser horizontal (tidak bisa diketuk) | 414–481 | List maks 3/favorit (spec §7.2), tiap baris → `_openWallets()`; "Lihat semua (N dompet)" → `_openWallets()` |
| 10 | Grid 12 menu + callback | 488–654 | Dihapus. Pindah ke Semua Fitur; callback → `_openFeature` + `HomeRefreshAfter` (tabel Task 4). Kartu ringkasan juga memakai `_openFeature` |
| 11 | `_showComingSoon`, `_buildCardStatItem`, `_buildFeatureButton` | 58–154 | Dihapus (tidak ada pemakai lagi) |
| 12 | Bottom nav, tombol "+", `extendBody`, `_bumpRefreshCounter`, tab Transaksi/Statistik | 37–56, 1049–1130 | **Tidak diubah** |

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/screens/home_screen_test.dart
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class FakeHomeNotifier extends HomeNotifier {
  FakeHomeNotifier(this.fixed);
  final HomeState fixed;

  @override
  HomeState build() => fixed;
}

WalletModel wallet(int id, String name, double balance, {bool fav = false, double min = 0}) =>
    WalletModel(id: id, userId: 'u', name: name, balance: balance, color: '#1E3A8A', isFavorite: fav, minBalance: min);

Future<void> pumpHome(WidgetTester tester, HomeState state) {
  return pumpApp(
    tester,
    const HomeScreen(),
    overrides: [homeProvider.overrideWith(() => FakeHomeNotifier(state))],
    size: const Size(390, 1800),
  );
}

void main() {
  testWidgets('menampilkan 3 dompet saldo terbesar + Lihat semua, tanpa grid menu lama', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        userName: 'Akun Tes',
        wallets: [
          wallet(1, 'BCA', 9300000),
          wallet(2, 'GoPay', 1850000),
          wallet(3, 'Tunai', 1300000),
          wallet(4, 'Jago', 750000),
          wallet(5, 'Dana', 10000),
        ],
      ),
    );
    expect(find.text('Halo, Bos!'), findsOneWidget);
    expect(find.text('AT'), findsOneWidget);
    expect(find.text('DOMPET'), findsOneWidget);
    expect(find.text('Kelola'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('Jago'), findsNothing);
    expect(find.text('Lihat semua (5 dompet)'), findsOneWidget);
    expect(find.text('Semua Fitur'), findsOneWidget);
    expect(find.text('AI Advisor'), findsNothing); // grid 12 menu sudah hilang
  });

  testWidgets('ringkasan kosong menampilkan empty state tiap kartu', (tester) async {
    await pumpHome(tester, HomeState(isLoading: false, wallets: [wallet(1, 'BCA', 100)]));
    expect(find.text('RINGKASAN'), findsOneWidget);
    expect(find.text('Belum ada anggaran'), findsOneWidget);
    expect(find.text('Belum ada target'), findsOneWidget);
    expect(find.text('Tidak ada tagihan'), findsOneWidget);
    expect(find.text('Bebas utang'), findsOneWidget);
  });

  testWidgets('tanpa dompet: baris Buat Dompet Pertama dan total Rp 0', (tester) async {
    await pumpHome(tester, const HomeState(isLoading: false));
    expect(find.text('Buat Dompet Pertama'), findsOneWidget);
    expect(find.textContaining('Lihat semua'), findsNothing);
    expect(find.text('Rp 0'), findsWidgets);
  });

  testWidgets('pengaturan saldo minimal nonaktif: total & baris memakai uang yang bisa dipakai', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        includeMinBalance: false,
        wallets: [wallet(1, 'BCA', 1000000, min: 250000), wallet(2, 'GoPay', 400000)],
      ),
    );
    expect(find.text('Rp 1.150.000'), findsOneWidget); // 750.000 + 400.000
    expect(find.text('Sudah dikurangi saldo minimal'), findsOneWidget);
    expect(find.text('Bisa dipakai Rp 750.000'), findsOneWidget);
  });

  testWidgets('kartu ringkasan menampilkan data yang dipilih', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        wallets: [wallet(1, 'BCA', 100)],
        summary: const HomeSummary(budget: BudgetSummary(totalSpent: 3480000, totalBudget: 5000000)),
      ),
    );
    expect(find.text('Rp 3,5 jt'), findsOneWidget);
    expect(find.text('dari Rp 5 jt bulan ini'), findsOneWidget);
  });
}
```

Catatan untuk `formatRupiahCompact` B1: bila hasil untuk 3.480.000 dan 5.000.000 berbeda format (mis. "Rp 3,48 jt"/"Rp 5,0 jt"), sesuaikan dua string ekspektasi di test terakhir dengan keluaran `formatRupiahCompact` yang sudah diuji di B1 — jangan mengubah formatter.

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: FAIL (teks "DOMPET", "Semua Fitur", "RINGKASAN" belum ada; "AI Advisor" masih ditemukan).

- [ ] **Step 3: Ganti import di atas `home_screen.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/providers/transaction_history_provider.dart';
import 'package:catat_uang_app/screens/all_features/all_features_screen.dart';
import 'package:catat_uang_app/screens/all_features/app_feature.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:catat_uang_app/screens/stats/stats_screen.dart';
import 'package:catat_uang_app/screens/transaction_history/transactions_tab_screen.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_bottom_nav.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_summary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
```

Import layar fitur (budget, target, savings, recurring, ai_advisor, calendar, debt, zakat, investment, export, manage_category) dan `app_notification.dart`/`google_fonts` dihapus dari file ini — sekarang di `app_feature.dart`. Setelah Task 6 selesai jalankan analyze; hapus import yang dilaporkan tidak terpakai.

- [ ] **Step 4: Ganti blok baris 58–662 dengan kode berikut**

Hapus mulai `// Tombol Coming Soon` (baris 58) sampai penutup `_buildMobileHomeContent` (baris 662), lalu tempel (baris 37–56 — field state dan `_bumpRefreshCounter` — tetap di atasnya):

```dart
  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (!mounted) return;
    ref.read(homeProvider.notifier).getUserProfile();
  }

  Future<void> _openWallets() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalletScreen()),
    );
    if (!mounted) return;
    ref.read(homeProvider.notifier).refreshData();
  }

  /// Pengganti 12 callback grid lama. Refresh setelah kembali mengikuti
  /// AppFeature.refreshAfter (tabel Plan B3 Task 4).
  Future<void> _openFeature(AppFeature feature) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => feature.buildScreen()),
    );
    if (!mounted) return;
    switch (feature.refreshAfter) {
      case HomeRefreshAfter.none:
        break;
      case HomeRefreshAfter.homeData:
        ref.read(homeProvider.notifier).refreshData();
      case HomeRefreshAfter.homeDataAndTabs:
        ref.read(homeProvider.notifier).refreshData();
        _bumpRefreshCounter();
    }
  }

  Future<void> _openAllFeatures() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AllFeaturesScreen(onOpen: _openFeature)),
    );
  }

  Widget _buildMobileHomeContent() {
    final homeState = ref.watch(homeProvider);

    if (homeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppPageScaffold(
      title: 'Beranda',
      embedded: true,
      titleWidget: _HomeHeader(userName: homeState.userName, onOpenSettings: _openSettings),
      onRefresh: () => ref.read(homeProvider.notifier).refreshData(),
      children: [
        _HomeHeroCard(state: homeState),
        _HomeWalletSection(
          wallets: homeState.wallets,
          includeMinBalance: homeState.includeMinBalance,
          onOpenWallets: _openWallets,
        ),
        _HomeSummaryGrid(summary: homeState.summary, onOpen: _openFeature),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const AppIconTile(
                icon: PhosphorIconsFill.squaresFour,
                color: AppColors.primary,
                filled: true,
              ),
              title: 'Semua Fitur',
              subtitle: 'Anggaran, target, tabungan, dan 9 lainnya',
              showChevron: true,
              onTap: _openAllFeatures,
            ),
          ],
        ),
      ],
    );
  }
```

- [ ] **Step 5: Tambahkan widget privat di akhir file `home_screen.dart`** (setelah penutup `_HomeScreenState`)

```dart
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName, required this.onOpenSettings});

  final String userName;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo, Bos!', style: AppTextStyles.subhead),
              Text(
                userName,
                style: AppTextStyles.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Pengaturan',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onOpenSettings,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text(
                initialsOf(userName),
                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final total = spendableTotal(state.wallets, includeMinBalance: state.includeMinBalance);
    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppHeroLabel('Total Saldo Keseluruhan'),
              Icon(PhosphorIconsFill.wallet, color: AppColors.heroLabel, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          AppHeroAmount(formatRupiah(total)),
          if (!state.includeMinBalance) ...[
            const SizedBox(height: 2),
            const AppHeroLabel('Sudah dikurangi saldo minimal'),
          ],
          const SizedBox(height: 16),
          Container(height: 0.5, color: AppColors.heroLabel.withOpacity(0.3)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.arrowDown,
                  color: AppColors.heroStatIncome,
                  label: 'Masuk',
                  amount: state.monthlyIncome,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.arrowUp,
                  color: AppColors.heroStatExpense,
                  label: 'Keluar',
                  amount: state.monthlyExpense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.piggyBank,
                  color: AppColors.heroStatSavings,
                  label: 'Tabungan',
                  amount: state.totalSavings,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.chartLineUp,
                  color: AppColors.heroStatInvest,
                  label: 'Investasi',
                  amount: state.totalInvestments,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.color, required this.label, required this.amount});

  final IconData icon;
  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeroLabel(label),
              Text(
                formatRupiah(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.amountRow.copyWith(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeWalletSection extends StatelessWidget {
  const _HomeWalletSection({
    required this.wallets,
    required this.includeMinBalance,
    required this.onOpenWallets,
  });

  final List<WalletModel> wallets;
  final bool includeMinBalance;
  final VoidCallback onOpenWallets;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return AppGroupedSection(
        header: 'Dompet',
        headerAction: 'Kelola',
        onHeaderAction: onOpenWallets,
        children: [
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsRegular.plusCircle, color: AppColors.primary),
            title: 'Buat Dompet Pertama',
            titleColor: AppColors.primary,
            showChevron: true,
            onTap: onOpenWallets,
          ),
        ],
      );
    }

    final view = homeWallets(wallets);
    return AppGroupedSection(
      header: 'Dompet',
      headerAction: 'Kelola',
      onHeaderAction: onOpenWallets,
      children: [
        for (final w in view.shown)
          AppListRow(
            leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: w.displayColor, filled: true),
            title: w.name,
            subtitle: includeMinBalance || w.minBalance <= 0
                ? null
                : 'Bisa dipakai ${formatRupiah(spendableOf(w))}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (w.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(PhosphorIconsFill.star, size: 14, color: AppColors.tintAmber),
                  ),
                Text(formatRupiah(w.balance), style: AppTextStyles.amountRow),
              ],
            ),
            onTap: onOpenWallets,
          ),
        if (view.hiddenCount > 0)
          AppListRow(
            title: 'Lihat semua (${wallets.length} dompet)',
            titleColor: AppColors.primary,
            showChevron: true,
            onTap: onOpenWallets,
          ),
      ],
    );
  }
}

class _HomeSummaryGrid extends StatelessWidget {
  const _HomeSummaryGrid({required this.summary, required this.onOpen});

  final HomeSummary summary;
  final ValueChanged<AppFeature> onOpen;

  static Color _budgetColor(double ratio) {
    if (ratio > 1) return AppColors.expense;
    if (ratio > 0.8) return AppColors.tintOrange;
    return AppColors.primary;
  }

  Widget _emptyText(String text, {bool withAction = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: AppTextStyles.bodyStrong, maxLines: 2),
        if (withAction)
          Text(
            'Buat',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }

  Widget _budget() {
    final b = summary.budget;
    return AppSummaryWidget(
      icon: PhosphorIconsFill.chartDonut,
      label: 'Anggaran',
      color: AppColors.primary,
      onTap: () => onOpen(AppFeature.budget),
      children: b == null
          ? [_emptyText('Belum ada anggaran', withAction: true)]
          : [
              Text(formatRupiahCompact(b.totalSpent), style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('dari ${formatRupiahCompact(b.totalBudget)} bulan ini', style: AppTextStyles.caption, maxLines: 2),
              const SizedBox(height: 4),
              AppProgressBar(value: b.ratio, color: _budgetColor(b.ratio), height: 6),
            ],
    );
  }

  Widget _target() {
    final t = summary.target;
    return AppSummaryWidget(
      icon: PhosphorIconsFill.target,
      label: 'Target',
      color: AppColors.tintGreen,
      onTap: () => onOpen(AppFeature.target),
      children: t == null
          ? [_emptyText('Belum ada target', withAction: true)]
          : [
              Text(t.name, style: AppTextStyles.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${formatRupiahCompact(t.savedAmount)} / ${formatRupiahCompact(t.targetAmount)}',
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              AppProgressBar(
                value: t.targetAmount <= 0 ? 0 : t.savedAmount / t.targetAmount,
                color: AppColors.income,
                height: 6,
              ),
            ],
    );
  }

  Widget _bill() {
    final r = summary.nextBill;
    return AppSummaryWidget(
      icon: PhosphorIconsFill.calendarPlus,
      label: 'Tagihan',
      color: AppColors.tintOrange,
      onTap: () => onOpen(AppFeature.recurring),
      children: r == null
          ? [_emptyText('Tidak ada tagihan')]
          : [
              Text(
                r.category?['name']?.toString() ?? 'Tagihan',
                style: AppTextStyles.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(DateFormat('d MMM yyyy', 'id_ID').format(r.nextRunDate), style: AppTextStyles.caption),
              Text('-${formatRupiahCompact(r.amount)}', style: AppTextStyles.amountRow.copyWith(color: AppColors.expense)),
            ],
    );
  }

  Widget _debt() {
    final d = summary.debt;
    final late = d == null ? 0 : overdueDays(d.dueDate, DateTime.now());
    final String dueText;
    if (d == null) {
      dueText = '';
    } else if (late > 0) {
      dueText = 'Terlambat $late hari';
    } else if (d.dueDate != null) {
      dueText = 'Tempo: ${DateFormat('d MMM yyyy', 'id_ID').format(d.dueDate!)}';
    } else {
      dueText = 'Tanpa jatuh tempo';
    }
    return AppSummaryWidget(
      icon: PhosphorIconsFill.handCoins,
      label: 'Utang',
      color: AppColors.expense,
      onTap: () => onOpen(AppFeature.debt),
      children: d == null
          ? [_emptyText('Bebas utang')]
          : [
              Text(d.name, style: AppTextStyles.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                dueText,
                style: late > 0
                    ? AppTextStyles.caption.copyWith(color: AppColors.expense, fontWeight: FontWeight.w700)
                    : AppTextStyles.caption,
              ),
              Text(formatRupiahCompact(d.remainingAmount), style: AppTextStyles.amountRow),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('RINGKASAN', style: AppTextStyles.groupLabel),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _budget()),
              const SizedBox(width: 10),
              Expanded(child: _target()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _bill()),
              const SizedBox(width: 10),
              Expanded(child: _debt()),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: PASS (5 test). Web content (`_buildWebHomeContent`) masih kode lama sampai Task 6 — pastikan tetap terkompilasi (Task 3 Step 7 sudah menyesuaikan akses `wallet.name`/dst.).

- [ ] **Step 7: Visual checklist (mockup "Beranda (usulan baru)")**

- [ ] Header: "Halo, Bos!" abu kecil + nama tebal; avatar lingkaran biru dengan inisial putih di kanan (ketuk → Pengaturan).
- [ ] Kartu hero gradasi biru radius 28: "Total Saldo Keseluruhan", nominal besar putih, garis tipis, 4 statistik 2×2 dengan ikon pastel dalam lingkaran transparan.
- [ ] Label grup "DOMPET" + "Kelola" biru di kanan; baris dompet: tile warna dompet (penuh) + ikon putih, nama, saldo di kanan; bintang kecil bila favorit.
- [ ] Baris "Lihat semua (N dompet)" biru hanya bila ada dompet tersembunyi.
- [ ] Label "RINGKASAN" lalu grid 2×2 kartu putih radius 24: ANGGARAN (biru), TARGET (hijau), TAGIHAN (oranye), UTANG (merah), label kecil huruf besar berwarna di atas.
- [ ] Baris "Semua Fitur" dengan tile grid biru penuh + chevron, di grup sendiri.
- [ ] Tidak ada grid 12 ikon.
- [ ] Scroll: konten lewat di belakang navbar melayang; paling bawah berhenti di atas navbar.
- [ ] Empty: tanpa dompet → "Buat Dompet Pertama"; tanpa data → teks empty di tiap kartu.

- [ ] **Step 8: Commit**

```bash
flutter analyze lib/screens/home
git add lib/screens/home/home_screen.dart test/screens/home_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(home): redesign mobile home with summary widgets

Replaces the 12-icon grid with summary cards and an All Features row;
wallets show as a short list (favorites or top 3 by balance).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 6: Beranda web

**Files:**
- Modify: `lib/screens/home/home_screen.dart` — ganti `_buildWebFeatureButton` + `_buildWebHomeContent` (baris lama 664–1047); di `_buildWebLayout` ganti hanya gaya teks rail & FAB (1160–1167, 1216).
- Test: `test/screens/home_screen_test.dart` (tambah 1 test)

**Interfaces:**
- Consumes: `_HomeHeader`, `_HomeHeroCard`, `_HomeWalletSection`, `_HomeSummaryGrid`, `_openFeature`, `_openWallets`, `_openSettings` (Task 5), `AllFeaturesSections` (Task 4).

**Tabel preservasi (web)**

| # | Perilaku lama | Baris lama | Di layout baru |
|---|---|---|---|
| 1 | Loading spinner | 718–720 | Sama |
| 2 | `SafeArea` + `RefreshIndicator(refreshData)` + scroll, padding 40/30 | 722–728 | Sama |
| 3 | Header + ketuk pengaturan → `getUserProfile()` | 733–767 | `_HomeHeader` → `_openSettings()` |
| 4 | Kartu saldo (flex 5) + dompet (flex 4) berdampingan | 772–963 | `_HomeHeroCard` (flex 5) + `_HomeWalletSection` (flex 4) |
| 5 | "Kelola" & dompet kosong → `await push(WalletScreen)` → `refreshData()` | 863–867, 877–881 | `_openWallets()` |
| 6 | Grid maksimal 4 dompet | 912 | Aturan `homeWallets` (sama dengan mobile) |
| 7 | "Menu & Fitur" + 12 tombol web | 966–1039 | Judul "Semua Fitur" + `AllFeaturesSections(query: '', onOpen: _openFeature)` |
| 8 | NavigationRail 3 destinasi, `_selectedIndex`, FAB "Tambah Transaksi" + refresh | 1150–1219 | **Tidak diubah** kecuali `GoogleFonts.poppins` → `AppTextStyles` dan `Colors.grey` → `AppColors.textSecondary` |

- [ ] **Step 1: Tambah test yang gagal di `test/screens/home_screen_test.dart`**

```dart
  testWidgets('layout web: menampilkan grup Semua Fitur langsung, tanpa grid Menu & Fitur', (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: [
        homeProvider.overrideWith(
          () => FakeHomeNotifier(HomeState(isLoading: false, wallets: [wallet(1, 'BCA', 100)])),
        ),
      ],
      size: const Size(1280, 2400),
    );
    expect(find.text('Menu & Fitur'), findsNothing);
    expect(find.text('Semua Fitur'), findsOneWidget);
    expect(find.text('PERENCANAAN'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget); // label NavigationRail
  });
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/home_screen_test.dart --plain-name "layout web"`
Expected: FAIL ("Menu & Fitur" masih ada).

- [ ] **Step 3: Ganti `_buildWebFeatureButton` + `_buildWebHomeContent` dengan**

```dart
  Widget _buildWebHomeContent() {
    final homeState = ref.watch(homeProvider);

    if (homeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HomeHeader(userName: homeState.userName, onOpenSettings: _openSettings),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _HomeHeroCard(state: homeState)),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 4,
                      child: _HomeWalletSection(
                        wallets: homeState.wallets,
                        includeMinBalance: homeState.includeMinBalance,
                        onOpenWallets: _openWallets,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _HomeSummaryGrid(summary: homeState.summary, onOpen: _openFeature),
                const SizedBox(height: 32),
                Text('Semua Fitur', style: AppTextStyles.title),
                const SizedBox(height: 14),
                AllFeaturesSections(query: '', onOpen: _openFeature),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Gaya teks rail & FAB di `_buildWebLayout`**

Ganti hanya baris berikut (sisanya tidak diubah):

```dart
    final inactiveColor = AppColors.textSecondary;
```

```dart
            selectedLabelTextStyle: AppTextStyles.bodyStrong.copyWith(color: activeColor, fontWeight: FontWeight.w700),
            unselectedIconTheme: IconThemeData(color: inactiveColor),
            unselectedLabelTextStyle: AppTextStyles.body.copyWith(color: inactiveColor),
```

```dart
                Text("DompetKu", style: AppTextStyles.title.copyWith(fontSize: 24, color: activeColor)),
```

```dart
        label: Text("Tambah Transaksi", style: AppTextStyles.button),
```

- [ ] **Step 5: Test & analyze**

Run: `flutter test test/screens/home_screen_test.dart` → PASS (6 test).
Run: `flutter analyze lib/screens/home` → hapus import yang dilaporkan tidak terpakai (mis. `google_fonts`, `app_notification`), ulangi sampai tidak ada warning baru.
Run: `grep -c "GoogleFonts.poppins" lib/screens/home/home_screen.dart` → `0`.
Run: `grep -nE "Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|deepPurple|grey|pinkAccent|redAccent|orangeAccent|tealAccent|brown)" lib/screens/home/home_screen.dart` → tidak ada hasil.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/home_screen.dart test/screens/home_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(home): replace web feature grid with all features list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 7: Halaman Dompet (redesign)

**Files:**
- Rewrite: `lib/screens/wallet/wallet_screen.dart`
- Test: `test/screens/wallet_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 (`WalletModel.isFavorite/minBalance/displayColor`, `WalletNotifier.setFavorite`, `addWallet/updateWallet(minBalance:)`, `spendableOf`, `minBalanceWarningMessage`, `userSettingsProvider`, `AppColors.walletColorChoices`, `AppColors.fromWalletHex`), `validateTransfer` (wallet_provider.dart, tidak berubah), B1 (`AppPageScaffold`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppPrimaryButton`, `AppPillButton`, `AppTextField`, `AppEmptyState`, `showAppFormSheet`, `showAppConfirmDialog`, `AppHeroAmount`, `AppTextStyles`, `formatRupiah`, `parseRupiah`, `RupiahInputFormatter`).
- Produces: `WalletScreen` (constructor tetap `const WalletScreen({super.key})`).

**Tabel preservasi (kode lama `wallet_screen.dart` → layout baru)**

| # | Perilaku lama | Baris lama | Di layout baru |
|---|---|---|---|
| 1 | AppBar "Dompet Saya" + tombol kembali | 257–261 | `AppPageScaffold(title: 'Dompet Saya', backLabel: 'Beranda')` |
| 2 | Loading spinner | 262–263 | Spinner primary di tengah area konten |
| 3 | Empty "Belum ada dompet" + ikon wallet | 264–274 | `AppEmptyState` (judul sama) |
| 4 | Kartu gradasi per dompet: nama HURUF BESAR, "TOTAL SALDO", saldo | 279–437 | `_WalletCard` bertumpuk (mockup "Dompet") |
| 5 | Menu ⋮: Edit / Hapus | 364–413 | Ketuk kartu → sheet aksi: Edit / Jadikan Favorit·Hapus dari Favorit (baru) / Hapus |
| 6 | Dialog hapus "Hapus Dompet?" / "Yakin ingin menghapus X?" + toast sukses/gagal | 373–406 | `showAppConfirmDialog` dengan teks sama; toast "Dompet berhasil dihapus!" / "Gagal menghapus dompet. Pastikan tidak ada transaksi di dompet ini." |
| 7 | FAB "+" saat kosong; pill "Transfer" (≥2 dompet) + "Tambah" | 440–501 | `bottomBar`: pill putih berisi `AppPillButton` "Transfer" (oranye, ≥2 dompet) + "Tambah" (biru penuh) |
| 8 | Transfer: guard "Minimal butuh 2 dompet untuk transfer." | 24–27 | Sama |
| 9 | Transfer default sumber `wallets[0]`, tujuan `wallets[1]` | 29–30 | Sama |
| 10 | Dropdown sumber "Nama (Sisa: RpX)", tujuan "Nama"; error sama-dompet | 47–88 | Baris `AppListRow` → sheet pilih dompet; error "Dompet asal dan tujuan tidak boleh sama!" / "Dompet tujuan dan asal tidak boleh sama!" |
| 11 | Nominal kosong → "Nominal tidak boleh kosong!" | 112–115 | Sama |
| 12 | `transfer()` + toast "Transfer Rp X berhasil!" + tutup sheet; error pesan exception | 116–131 | Sama (`formatRupiah` menghasilkan "Rp X"); **baru**: dialog peringatan saldo minimal sebelum transfer |
| 13 | Tambah/Edit: judul "Tambah Dompet"/"Edit Dompet"; label "Nama Dompet (cth: BCA, GoPay, Tunai)", hint "Masukkan nama dompet", "Saldo Saat Ini", "Pilih Warna" | 157–204 | `showAppFormSheet` judul sama, label sama; **baru**: "Saldo Minimal (Opsional)" |
| 14 | Validasi "Harap isi semua data!"; toast "Dompet diperbarui!" / "Dompet berhasil ditambahkan!" / "Gagal menyimpan dompet." | 211–237 | Sama |
| 15 | 8 pilihan warna, default pilihan pertama / warna dompet | 18–21, 149, 187–203 | `AppColors.walletColorChoices`, lingkaran 45 dengan centang |

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/screens/wallet_screen_test.dart
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/user_settings_provider.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

class FakeWalletNotifier extends WalletNotifier {
  FakeWalletNotifier(this.initial);
  final List<WalletModel> initial;
  int? favoriteId;
  bool? favoriteValue;

  @override
  WalletState build() => WalletState(wallets: initial, isLoading: false);

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {
    favoriteId = id;
    favoriteValue = isFavorite;
  }
}

class FakeUserSettingsNotifier extends UserSettingsNotifier {
  FakeUserSettingsNotifier(this.include);
  final bool include;

  @override
  UserSettingsState build() => UserSettingsState(includeMinBalance: include, isLoading: false);
}

List<WalletModel> sample() => [
      WalletModel(id: 1, userId: 'u', name: 'BCA', balance: 9300000, color: '#1E3A8A', isFavorite: true, minBalance: 50000),
      WalletModel(id: 2, userId: 'u', name: 'GoPay', balance: 1850000, color: '#E65100'),
      WalletModel(id: 3, userId: 'u', name: 'Tunai', balance: 1300000, color: '#00796B'),
    ];

Future<FakeWalletNotifier> pumpWallet(WidgetTester tester, List<WalletModel> wallets, {bool include = true}) async {
  final fake = FakeWalletNotifier(wallets);
  await pumpApp(
    tester,
    const WalletScreen(),
    overrides: [
      walletProvider.overrideWith(() => fake),
      userSettingsProvider.overrideWith(() => FakeUserSettingsNotifier(include)),
    ],
    size: const Size(390, 1200),
  );
  return fake;
}

void main() {
  testWidgets('kartu bertumpuk menampilkan nama huruf besar, saldo, bintang favorit, dan pill', (tester) async {
    await pumpWallet(tester, sample());
    expect(find.text('Dompet Saya'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('GOPAY'), findsOneWidget);
    expect(find.text('Rp 9.300.000'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.star), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(find.textContaining('Bisa dipakai'), findsNothing); // pengaturan aktif
  });

  testWidgets('pengaturan nonaktif: kartu menampilkan Bisa dipakai', (tester) async {
    await pumpWallet(tester, sample(), include: false);
    expect(find.text('Bisa dipakai Rp 9.250.000'), findsOneWidget);
  });

  testWidgets('ketuk kartu membuka sheet aksi; Jadikan Favorit memanggil setFavorite', (tester) async {
    final fake = await pumpWallet(tester, sample());
    await tester.tap(find.text('GOPAY'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Jadikan Favorit'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    await tester.tap(find.text('Jadikan Favorit'));
    await tester.pumpAndSettle();
    expect(fake.favoriteId, 2);
    expect(fake.favoriteValue, isTrue);
  });

  testWidgets('kosong: empty state dan pill hanya Tambah', (tester) async {
    await pumpWallet(tester, []);
    expect(find.text('Belum ada dompet'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing);
  });

  testWidgets('satu dompet: tombol Transfer tidak tampil', (tester) async {
    await pumpWallet(tester, [sample().first]);
    expect(find.text('Transfer'), findsNothing);
  });

  testWidgets('sheet Tambah Dompet punya isian Saldo Minimal (Opsional)', (tester) async {
    await pumpWallet(tester, sample());
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Dompet'), findsOneWidget);
    expect(find.text('Saldo Minimal (Opsional)'), findsOneWidget);
    expect(find.text('Pilih Warna'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/wallet_screen_test.dart`
Expected: FAIL (teks "BCA" tampil huruf besar sudah ada, tetapi "Transfer" dari pill lama `Colors.orange`… sheet aksi, "Saldo Minimal (Opsional)", dan override `userSettingsProvider` belum dipakai).

- [ ] **Step 3: Tulis ulang `lib/screens/wallet/wallet_screen.dart`**

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/user_settings_provider.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const double cardHeight = 176;
  static const double cardStep = 96;

  static final NumberFormat _thousands = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  /// Sheet pilih dompet (pengganti DropdownButton lama). Mengembalikan id atau null.
  Future<int?> _pickWallet(
    BuildContext context,
    List<WalletModel> wallets, {
    required String title,
    required int selectedId,
    bool showBalance = false,
  }) {
    return showAppFormSheet<int>(
      context: context,
      title: title,
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final w in wallets)
            AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: w.displayColor, filled: true),
              title: w.name,
              value: showBalance ? formatRupiah(w.balance) : null,
              trailing: w.id == selectedId
                  ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(sheetContext, w.id),
            ),
        ],
      ),
    );
  }

  void _showTransferSheet(BuildContext context, WidgetRef ref, List<WalletModel> wallets) {
    if (wallets.length < 2) {
      AppNotification.error(context, "Minimal butuh 2 dompet untuk transfer.");
      return;
    }

    int sourceId = wallets[0].id;
    int destId = wallets[1].id;
    final amountController = TextEditingController();
    var isSubmitting = false;

    showAppFormSheet<void>(
      context: context,
      title: 'Transfer Antar Dompet',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final source = wallets.firstWhere((w) => w.id == sourceId);
          final dest = wallets.firstWhere((w) => w.id == destId);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGroupedSection(
                children: [
                  AppListRow(
                    leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: source.displayColor, filled: true),
                    title: 'Dari Dompet (Sumber)',
                    subtitle: '${source.name} (Sisa: ${formatRupiah(source.balance)})',
                    showChevron: true,
                    onTap: () async {
                      final picked = await _pickWallet(
                        sheetContext,
                        wallets,
                        title: 'Dari Dompet (Sumber)',
                        selectedId: sourceId,
                        showBalance: true,
                      );
                      if (picked == null || !sheetContext.mounted) return;
                      if (picked == destId) {
                        AppNotification.error(sheetContext, "Dompet asal dan tujuan tidak boleh sama!");
                        return;
                      }
                      setSheetState(() => sourceId = picked);
                    },
                  ),
                  AppListRow(
                    leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: dest.displayColor, filled: true),
                    title: 'Ke Dompet (Tujuan)',
                    subtitle: dest.name,
                    showChevron: true,
                    onTap: () async {
                      final picked = await _pickWallet(
                        sheetContext,
                        wallets,
                        title: 'Ke Dompet (Tujuan)',
                        selectedId: destId,
                      );
                      if (picked == null || !sheetContext.mounted) return;
                      if (picked == sourceId) {
                        AppNotification.error(sheetContext, "Dompet tujuan dan asal tidak boleh sama!");
                        return;
                      }
                      setSheetState(() => destId = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Nominal Transfer', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppTextField(
                controller: amountController,
                hint: '0',
                icon: PhosphorIconsRegular.money,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Transfer Sekarang',
                loading: isSubmitting,
                onPressed: () async {
                  if (amountController.text.isEmpty) {
                    AppNotification.error(sheetContext, "Nominal tidak boleh kosong!");
                    return;
                  }
                  final cleanAmount = parseRupiah(amountController.text).toDouble();
                  final error = validateTransfer(source: source, dest: dest, amount: cleanAmount);
                  if (error != null) {
                    AppNotification.error(sheetContext, error);
                    return;
                  }
                  final warning = minBalanceWarningMessage(
                    walletName: source.name,
                    balance: source.balance,
                    minBalance: source.minBalance,
                    amount: cleanAmount,
                  );
                  if (warning != null) {
                    final ok = await showAppConfirmDialog(
                      context: sheetContext,
                      title: 'Di bawah saldo minimal',
                      message: warning,
                      confirmLabel: 'Lanjutkan',
                      destructive: false,
                    );
                    if (!ok || !sheetContext.mounted) return;
                  }
                  setSheetState(() => isSubmitting = true);
                  try {
                    await ref.read(walletProvider.notifier).transfer(
                          sourceId: sourceId,
                          destId: destId,
                          amount: cleanAmount,
                        );
                    if (sheetContext.mounted) {
                      AppNotification.success(sheetContext, "Transfer ${formatRupiah(cleanAmount)} berhasil!");
                      Navigator.pop(sheetContext);
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
          );
        },
      ),
    );
  }

  void _showAddEditWalletSheet(BuildContext context, WidgetRef ref, {WalletModel? wallet}) {
    final isEdit = wallet != null;
    final nameController = TextEditingController(text: isEdit ? wallet.name : '');
    final balanceController = TextEditingController(text: isEdit ? _thousands.format(wallet.balance) : '');
    final minBalanceController = TextEditingController(
      text: isEdit && wallet.minBalance > 0 ? _thousands.format(wallet.minBalance) : '',
    );
    String selectedColor =
        isEdit && wallet.color != null ? wallet.color! : AppColors.walletColorChoices[0];
    var isSubmitting = false;

    showAppFormSheet<void>(
      context: context,
      title: isEdit ? "Edit Dompet" : "Tambah Dompet",
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Nama Dompet (cth: BCA, GoPay, Tunai)", style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppTextField(
                controller: nameController,
                hint: "Masukkan nama dompet",
                icon: PhosphorIconsRegular.wallet,
              ),
              const SizedBox(height: 16),
              Text("Saldo Saat Ini", style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppTextField(
                controller: balanceController,
                hint: "0",
                icon: PhosphorIconsRegular.money,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
              ),
              const SizedBox(height: 16),
              Text("Saldo Minimal (Opsional)", style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppTextField(
                controller: minBalanceController,
                hint: "0",
                icon: PhosphorIconsRegular.lockSimple,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
              ),
              const SizedBox(height: 6),
              Text(
                'Saldo yang ditahan bank. Dipakai untuk menghitung uang yang bisa dipakai.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              Text("Pilih Warna", style: AppTextStyles.caption),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppColors.walletColorChoices.map((hexColor) {
                    final color = AppColors.fromWalletHex(hexColor);
                    final isSelected = selectedColor == hexColor;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = hexColor),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: AppColors.textPrimary, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(PhosphorIconsBold.check, color: Colors.white, size: 22) : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: "Simpan Dompet",
                loading: isSubmitting,
                onPressed: () async {
                  if (nameController.text.isEmpty || balanceController.text.isEmpty) {
                    AppNotification.error(sheetContext, "Harap isi semua data!");
                    return;
                  }
                  final cleanBalance = parseRupiah(balanceController.text).toDouble();
                  final minBalance = parseRupiah(minBalanceController.text).toDouble();
                  setSheetState(() => isSubmitting = true);
                  try {
                    if (isEdit) {
                      await ref.read(walletProvider.notifier).updateWallet(
                            id: wallet.id,
                            name: nameController.text.trim(),
                            balance: cleanBalance,
                            color: selectedColor,
                            minBalance: minBalance,
                          );
                    } else {
                      await ref.read(walletProvider.notifier).addWallet(
                            name: nameController.text.trim(),
                            balance: cleanBalance,
                            color: selectedColor,
                            minBalance: minBalance,
                          );
                    }
                    if (sheetContext.mounted) {
                      AppNotification.success(sheetContext, isEdit ? "Dompet diperbarui!" : "Dompet berhasil ditambahkan!");
                      Navigator.pop(sheetContext);
                    }
                  } catch (e) {
                    if (sheetContext.mounted) {
                      setSheetState(() => isSubmitting = false);
                      AppNotification.error(sheetContext, "Gagal menyimpan dompet.");
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWalletActions(BuildContext context, WidgetRef ref, WalletModel wallet) {
    showAppFormSheet<void>(
      context: context,
      title: wallet.name,
      builder: (sheetContext) => AppGroupedSection(
        children: [
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsRegular.pencilSimple, color: AppColors.tintBlue),
            title: 'Edit',
            onTap: () {
              Navigator.pop(sheetContext);
              _showAddEditWalletSheet(context, ref, wallet: wallet);
            },
          ),
          AppListRow(
            leading: AppIconTile(
              icon: wallet.isFavorite ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
              color: AppColors.tintAmber,
            ),
            title: wallet.isFavorite ? 'Hapus dari Favorit' : 'Jadikan Favorit',
            subtitle: 'Dompet favorit tampil di Beranda',
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await ref.read(walletProvider.notifier).setFavorite(wallet.id, !wallet.isFavorite);
              } catch (_) {
                if (context.mounted) AppNotification.error(context, 'Gagal mengubah favorit.');
              }
            },
          ),
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsRegular.trash, color: AppColors.expense),
            title: 'Hapus',
            titleColor: AppColors.expense,
            onTap: () async {
              Navigator.pop(sheetContext);
              final ok = await showAppConfirmDialog(
                context: context,
                title: "Hapus Dompet?",
                message: "Yakin ingin menghapus ${wallet.name}?",
              );
              if (!ok) return;
              try {
                await ref.read(walletProvider.notifier).deleteWallet(wallet.id);
                if (context.mounted) {
                  AppNotification.success(context, "Dompet berhasil dihapus!");
                }
              } catch (_) {
                if (context.mounted) {
                  AppNotification.error(context, "Gagal menghapus dompet. Pastikan tidak ada transaksi di dompet ini.");
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletProvider);
    final includeMinBalance = ref.watch(userSettingsProvider).includeMinBalance;

    final List<Widget> children;
    if (state.isLoading) {
      children = const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    } else if (state.wallets.isEmpty) {
      children = const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: AppEmptyState(
            icon: PhosphorIconsRegular.wallet,
            title: "Belum ada dompet",
            subtitle: "Ketuk Tambah di bawah untuk membuat dompet pertama.",
          ),
        ),
      ];
    } else {
      children = [
        _WalletStack(
          wallets: state.wallets,
          includeMinBalance: includeMinBalance,
          onTap: (w) => _showWalletActions(context, ref, w),
        ),
        Text(
          'Ketuk kartu untuk edit, favorit, atau hapus',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ];
    }

    return AppPageScaffold(
      title: 'Dompet Saya',
      backLabel: 'Beranda',
      bottomBar: Center(
        heightFactor: 1,
        child: _WalletActionPill(
          showTransfer: state.wallets.length >= 2,
          onTransfer: () => _showTransferSheet(context, ref, state.wallets),
          onAdd: () => _showAddEditWalletSheet(context, ref),
        ),
      ),
      children: children,
    );
  }
}

/// Kartu dompet bertumpuk ala Apple Wallet: tiap kartu menutupi bagian bawah
/// kartu sebelumnya, menyisakan strip atas (nama + saldo) yang bisa diketuk.
class _WalletStack extends StatelessWidget {
  const _WalletStack({required this.wallets, required this.includeMinBalance, required this.onTap});

  final List<WalletModel> wallets;
  final bool includeMinBalance;
  final ValueChanged<WalletModel> onTap;

  @override
  Widget build(BuildContext context) {
    final height = WalletScreen.cardHeight + WalletScreen.cardStep * (wallets.length - 1);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < wallets.length; i++)
            Positioned(
              top: WalletScreen.cardStep * i,
              left: 0,
              right: 0,
              height: WalletScreen.cardHeight,
              child: _WalletCard(
                wallet: wallets[i],
                includeMinBalance: includeMinBalance,
                onTap: () => onTap(wallets[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.includeMinBalance, required this.onTap});

  final WalletModel wallet;
  final bool includeMinBalance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = wallet.displayColor;
    return Semantics(
      button: true,
      label: 'Dompet ${wallet.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.25)!],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, -4)),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wallet.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(color: Colors.white, letterSpacing: 1.2),
                    ),
                  ),
                  if (wallet.isFavorite) ...[
                    const Icon(PhosphorIconsFill.star, color: Colors.white, size: 16, semanticLabel: 'Favorit'),
                    const SizedBox(width: 8),
                  ],
                  const Icon(PhosphorIconsBold.dotsThree, color: Colors.white, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              AppHeroAmount(formatRupiah(wallet.balance), fontSize: 24),
              const SizedBox(height: 2),
              const AppHeroLabel('TOTAL SALDO'),
              if (!includeMinBalance && wallet.minBalance > 0) ...[
                const SizedBox(height: 6),
                AppHeroLabel('Bisa dipakai ${formatRupiah(spendableOf(wallet))}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletActionPill extends StatelessWidget {
  const _WalletActionPill({required this.showTransfer, required this.onTransfer, required this.onAdd});

  final bool showTransfer;
  final VoidCallback onTransfer;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTransfer) ...[
            AppPillButton(
              label: 'Transfer',
              icon: PhosphorIconsBold.arrowsLeftRight,
              color: AppColors.tintOrange,
              onPressed: onTransfer,
            ),
            const SizedBox(width: 6),
          ],
          AppPillButton(
            label: 'Tambah',
            icon: PhosphorIconsBold.plus,
            filled: true,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
```

Catatan untuk executor:
- Toast transfer lama `"Transfer Rp ${currencyFormatter.format(x)} berhasil!"` (symbol kosong) menghasilkan string yang sama dengan `"Transfer ${formatRupiah(x)} berhasil!"`. Bila `formatRupiah` B1 memakai spasi berbeda (mis. non-breaking), pertahankan teks lama dengan `NumberFormat` `_thousands`: `"Transfer Rp ${_thousands.format(cleanAmount)} berhasil!"`.
- `validateTransfer` dipanggil di screen sebelum dialog saldo minimal supaya pesan "Saldo di X tidak cukup!" muncul lebih dulu daripada peringatan; `transfer()` tetap memvalidasi ulang.
- Transfer masih memperbarui saldo dari nilai di cache klien (perilaku lama `wallet_provider.dart:117-118`) — di luar scope B3, dicatat sebagai temuan di laporan akhir.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/wallet_screen_test.dart test/providers/wallet_provider_test.dart`
Expected: PASS (6 + test lama). Bila tap `find.text('GOPAY')` tertutup kartu berikutnya, periksa `cardStep` (strip atas tiap kartu harus ≥ 96).

- [ ] **Step 5: Visual checklist (mockup "Dompet")**

- [ ] Nav bar `‹ Beranda`; judul besar "Dompet Saya".
- [ ] Kartu gradasi warna dompet radius 24, bertumpuk; tiap strip menampilkan ikon, NAMA huruf besar, bintang (favorit), ⋯, dan saldo; kartu terakhir utuh dengan "TOTAL SALDO".
- [ ] Teks kecil abu "Ketuk kartu untuk edit, favorit, atau hapus" di bawah tumpukan.
- [ ] Pill putih melayang di bawah: "Transfer" oranye (bila ≥2 dompet) + "Tambah" biru penuh.
- [ ] Sheet aksi (Batal · nama dompet): Edit (pensil biru), Jadikan Favorit / Hapus dari Favorit (bintang kuning), Hapus (merah).
- [ ] Sheet Tambah/Edit: header Batal · judul; field putih tanpa border; "Saldo Minimal (Opsional)" + keterangan; lingkaran warna; tombol "Simpan Dompet" penuh.
- [ ] Sheet Transfer: grup dua baris (Dari/Ke) dengan chevron; field nominal; tombol "Transfer Sekarang"; dialog iOS "Di bawah saldo minimal" bila melewati saldo minimal.
- [ ] Pengaturan saldo minimal nonaktif: "Bisa dipakai Rp …" di kartu yang punya saldo minimal.

- [ ] **Step 6: Analyze, grep, commit**

```bash
flutter analyze lib/screens/wallet
grep -c "GoogleFonts.poppins" lib/screens/wallet/wallet_screen.dart
grep -nE "Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|deepPurple|grey)" lib/screens/wallet/wallet_screen.dart
git add lib/screens/wallet/wallet_screen.dart test/screens/wallet_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(wallet): redesign wallet screen with stacked cards

Adds favorites and the optional minimum balance to the add/edit sheet,
and warns before a transfer drops a wallet below its minimum.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

Expected: grep Poppins `0`; grep warna tanpa hasil.

---

### Task 8: Peringatan saldo minimal di Tambah Transaksi

**Files:**
- Modify: `lib/screens/input_transaction/input_transaction_screen.dart:259-282` (`_saveTransaction`) + import
- Test: tercakup `test/core/wallet_rules_test.dart` (Task 2) + cek manual

**Interfaces:**
- Consumes: `minBalanceWarningMessage` (Task 2), `parseRupiah` (B1), `showAppConfirmDialog` (B1), `InputTransactionState.wallets` (`List<Map<String, dynamic>>`, `select()` sudah memuat kolom `min_balance` setelah migration).

Perubahan minimal: layar ini didesain ulang di Plan B4. **Koordinator:** tambahkan baris "Dialog saldo minimal sebelum simpan pengeluaran baru (B3)" ke tabel preservasi B4 Task 6.

- [ ] **Step 1: Tambah import**

```dart
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
```

(Lewati import yang sudah ada.)

- [ ] **Step 2: Sisipkan pengecekan di awal `_saveTransaction`** (sebelum `final notifier = ...`, baris 260)

```dart
    // Peringatan saldo minimal (spec §7.3): hanya pengeluaran baru dari dompet.
    if (_isExpense && !_isFromSaving && widget.transactionToEdit == null && _selectedWalletId != null) {
      Map<String, dynamic>? wallet;
      for (final w in ref.read(inputTransactionProvider).wallets) {
        if (w['id'] == _selectedWalletId) {
          wallet = w;
          break;
        }
      }
      if (wallet != null) {
        final warning = minBalanceWarningMessage(
          walletName: wallet['name'].toString(),
          balance: (wallet['balance'] as num).toDouble(),
          minBalance: (wallet['min_balance'] as num?)?.toDouble() ?? 0,
          amount: parseRupiah(_amountController.text).toDouble(),
        );
        if (warning != null) {
          final ok = await showAppConfirmDialog(
            context: context,
            title: 'Di bawah saldo minimal',
            message: warning,
            confirmLabel: 'Lanjutkan',
            destructive: false,
          );
          if (!ok || !mounted) return;
        }
      }
    }
```

Nominal kosong → `parseRupiah('') == 0` → tidak ada dialog; validasi lama ("Jumlah dan Kategori wajib diisi!") tetap jalan di provider.

- [ ] **Step 3: Verifikasi**

Run: `flutter analyze lib/screens/input_transaction` → tanpa error/warning baru.
Run: `flutter test` → hijau.
Cek manual (Task 10): dompet BCA saldo Rp 100.000, saldo minimal Rp 50.000 → pengeluaran Rp 60.000 memunculkan dialog; "Batal" tidak menyimpan; "Lanjutkan" menyimpan seperti biasa.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/input_transaction/input_transaction_screen.dart
git commit -m "$(cat <<'EOF'
feat(transactions): warn before an expense drops below wallet minimum

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 9: Pengaturan "Hitung saldo minimal di total saldo"

**Files:**
- Create: `lib/screens/settings/include_min_balance_row.dart`
- Modify: `lib/screens/settings/settings_screen.dart:62-78` (sisipkan setelah item "Profil Akun")
- Test: `test/screens/include_min_balance_row_test.dart`

**Interfaces:**
- Consumes: `userSettingsProvider` (Task 2), `homeProvider`, `walletProvider`, B1 (`AppListRow`, `AppIconTile`, `AppSwitch`, `AppGroupedSection`).
- Produces: `IncludeMinBalanceRow` (`const`, `ConsumerWidget`) — dipakai sekarang di layar Pengaturan lama, dan oleh Plan B7 di `_generalRows`.

Kompatibel sebelum/sesudah B7: baris ini widget mandiri (ConsumerWidget), jadi `SettingsScreen` tetap `StatelessWidget`. **Koordinator:** di Plan B7 Task 4, tambahkan `const IncludeMinBalanceRow()` sebagai elemen terakhir `_generalRows(context)` dan hapus pembungkus `AppGroupedSection` sementara dari Task 9 ini.

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/screens/include_min_balance_row_test.dart
import 'package:catat_uang_app/providers/user_settings_provider.dart';
import 'package:catat_uang_app/screens/settings/include_min_balance_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class FakeUserSettingsNotifier extends UserSettingsNotifier {
  bool? lastSet;

  @override
  UserSettingsState build() => const UserSettingsState(includeMinBalance: true, isLoading: false);

  @override
  Future<void> setIncludeMinBalance(bool value) async {
    lastSet = value;
    state = state.copyWith(includeMinBalance: value);
  }
}

void main() {
  testWidgets('menampilkan judul dan menulis pengaturan saat switch diubah', (tester) async {
    final fake = FakeUserSettingsNotifier();
    await pumpApp(
      tester,
      const Scaffold(body: IncludeMinBalanceRow()),
      overrides: [userSettingsProvider.overrideWith(() => fake)],
    );
    expect(find.text('Hitung saldo minimal di total saldo'), findsOneWidget);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isTrue);

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(fake.lastSet, isFalse);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
    expect(find.text('Total saldo dikurangi saldo minimal'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/include_min_balance_row_test.dart`
Expected: FAIL (file belum ada).

- [ ] **Step 3: Buat `lib/screens/settings/include_min_balance_row.dart`**

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/providers/user_settings_provider.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Baris switch "Hitung saldo minimal di total saldo" (spec §7.3).
/// Aktif (default) = total saldo apa adanya; nonaktif = dikurangi saldo minimal.
class IncludeMinBalanceRow extends ConsumerWidget {
  const IncludeMinBalanceRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final include = ref.watch(userSettingsProvider).includeMinBalance;
    return AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsFill.scales, color: AppColors.tintTeal, filled: true),
      title: 'Hitung saldo minimal di total saldo',
      subtitle: include ? 'Total saldo = semua saldo dompet' : 'Total saldo dikurangi saldo minimal',
      trailing: AppSwitch(
        value: include,
        onChanged: (value) async {
          try {
            await ref.read(userSettingsProvider.notifier).setIncludeMinBalance(value);
            ref.invalidate(homeProvider);
            ref.invalidate(walletProvider);
          } catch (_) {
            if (context.mounted) AppNotification.error(context, 'Gagal menyimpan pengaturan.');
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Sisipkan di `settings_screen.dart`**

Tambah import:

```dart
import 'package:catat_uang_app/screens/settings/include_min_balance_row.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
```

Tepat setelah penutup `_buildSettingItem(...)` "Profil Akun" (baris 76) dan sebelum baris kosong 77–79, sisipkan:

```dart
            // Sementara (layar ini didesain ulang di Plan B7): baris pengaturan
            // saldo minimal di grup "Umum".
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AppGroupedSection(children: [IncludeMinBalanceRow()]),
            ),
```

- [ ] **Step 5: Test & commit**

Run: `flutter test test/screens/include_min_balance_row_test.dart` → PASS.
Run: `flutter analyze lib/screens/settings` → tanpa error/warning baru.

```bash
git add lib/screens/settings/include_min_balance_row.dart lib/screens/settings/settings_screen.dart test/screens/include_min_balance_row_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): add include min balance switch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 10: Verifikasi akhir + checkpoint screenshot user

- [ ] **Step 1: Analyze & test penuh**

```bash
flutter analyze 2>&1 | tail -3
flutter test 2>&1 | tail -3
```

Expected: tidak ada error/warning baru dibanding baseline Task 0; semua test hijau.

- [ ] **Step 2: Grep konvensi untuk file yang disentuh**

```bash
grep -c "GoogleFonts.poppins" lib/screens/home/home_screen.dart lib/screens/wallet/wallet_screen.dart lib/screens/all_features/*.dart lib/screens/settings/include_min_balance_row.dart
grep -nE "Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|deepPurple|grey|pinkAccent|redAccent|orangeAccent|tealAccent|brown)" lib/screens/home lib/screens/wallet lib/screens/all_features lib/screens/settings/include_min_balance_row.dart
```

Expected: semua `0`; grep warna tanpa hasil. (`settings_screen.dart` dan `input_transaction_screen.dart` masih punya Poppins lama — dibersihkan di B7/B4.)

- [ ] **Step 3: Pastikan SQL sudah dijalankan user**

Tanyakan konfirmasi hasil verifikasi Task 1 Step 2 bila belum ada. Tanpa konfirmasi, **jangan merge**.

- [ ] **Step 4: Jalankan app dan kumpulkan screenshot**

Skill `run-and-screenshot`: `flutter run -d chrome --web-port=8765` (background). Bila tidak ada otomasi browser, minta user mengirim screenshot:
1. Beranda (atas dan setelah di-scroll sampai bawah).
2. Beranda dengan 4+ dompet (baris "Lihat semua").
3. Semua Fitur (dan hasil cari "tab").
4. Dompet (tumpukan kartu), sheet aksi, sheet Tambah Dompet.
5. Pengaturan dengan switch saldo minimal dimatikan, lalu Beranda + Dompet menampilkan "Bisa dipakai".
6. Dialog peringatan saldo minimal di Transfer dan di Tambah Transaksi.
7. Layout web (lebar > 800).

- [ ] **Step 5: Cocokkan dengan mockup**

Jalankan checklist visual Task 4, 5, 7 terhadap screenshot dan mockup; perbaiki perbedaan di commit terpisah `fix(home): ...` / `fix(wallet): ...`, lalu ulangi Step 1.

- [ ] **Step 6: Laporan akhir plan**

Laporkan ke koordinator:
- daftar commit;
- hasil analyze/test;
- hal yang perlu diteruskan ke plan lain: (a) B7 Task 4 menambah `const IncludeMinBalanceRow()` di `_generalRows` dan menghapus pembungkus sementara; (b) B4 Task 6 mempertahankan dialog saldo minimal di `_saveTransaction`; (c) B7 memakai `initialsOf` dari `lib/core/formatters.dart` untuk avatar Edit Profil (bukan fungsi baru); (d) `AppColors.walletColorChoices` sudah ada (List<String>) — B7 Task 8 tidak perlu membuat `walletChoices` lagi;
- temuan di luar scope: `WalletNotifier.transfer` masih menulis saldo dari cache klien (risiko sama seperti bug utang #5), layar fitur yang dibuka dari Semua Fitur tetap berlabel kembali "Beranda".

Merge ke `main` hanya setelah user menyetujui hasil visual (skill `finishing-a-development-branch`).
