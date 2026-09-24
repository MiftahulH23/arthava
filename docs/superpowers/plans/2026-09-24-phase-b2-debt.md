# Phase B2 — Utang & Piutang: Perbaikan Logika + Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memperbaiki semua bug uang di fitur Utang & Piutang (hasil audit), menambah 4 fitur yang disetujui user (edit utang, edit/hapus cicilan, tanda Terlambat + total, tanggal pinjam & catatan), dan mendesain ulang tiga layar Utang sesuai mockup iOS Blue.

**Architecture:** Semua tulis-data uang pindah ke fungsi Postgres (RPC) atomik yang dijalankan user di SQL Editor Supabase; saldo dompet diubah di server. Dart memanggil RPC lewat `DebtApi` (seam yang bisa di-fake untuk test), `DebtNotifier` memegang daftar utang, dompet, dan cicilan. Transaksi hasil utang diberi tag `[DEBT_ID:x]` dan dikecualikan dari semua total pemasukan/pengeluaran lewat helper bersama `lib/core/transaction_tags.dart`. Tiga layar dibangun ulang dari komponen Plan B1.

**Tech Stack:** Flutter, Riverpod 2.6.1 (`NotifierProvider.autoDispose`), `supabase_flutter` 2.12 (`rpc`), Postgres plpgsql, `phosphor_flutter`, komponen `lib/widgets/*` dari Plan B1, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (terutama §3, §4, §5, §6, §7.1, §9, §10). Skema DB asli: `docs/database/schema.md`. Mockup: `docs/design/dompetku-redesign-mockup.html` entri **"Utang & Piutang"**, **"Detail Utang"**, **"Form: Catat Utang / Piutang"**.

## Global Constraints

- **Prasyarat:** Plan B1 sudah di-merge ke `main` (komponen `lib/widgets/*`, `lib/core/formatters.dart`, `lib/theme/app_text_styles.dart`, `test/helpers/pump_app.dart` tersedia dengan API persis spec §6). Bila belum, BERHENTI dan laporkan BLOCKED.
- Nama API komponen dipakai persis seperti spec §6 + tambahan B1: `AppSwipeActions(deleteConfirmTitle:, deleteConfirmMessage:)`, `AppTextField(onChanged:, inputFormatters:)`. Jangan membuat widget kembar di screen.
- §9.1 Jangan jalankan `dart format` ke seluruh file. Edit terarah; diff sebanding dengan perubahan.
- §9.2 `Notifier.build()` tidak menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)`.
- §9.3 Refresh provider lewat `ref.invalidate(...)` / pemanggilan fetch, bukan mengganti `ValueKey`.
- §9.4 Setelah `await` (terutama `Navigator.push`), cek `if (!mounted) return;` (atau `context.mounted`) sebelum `setState`/`ref`/`context`.
- §9.6 Tidak ada `Center`/`Align`/`Expanded` tanpa batas di slot bertinggi longgar.
- §9.7 Pertahankan konkurensi fetch asli (fetch dompet lalu utang tetap berurutan seperti sekarang).
- §9.8 Semua `onTap`, navigasi, teks validasi, dan toast lama dipertahankan persis kecuali tabel preservasi task menyebut perubahan (dan alasannya).
- §9.9 Tidak ada hex / `Colors.<warna>` di screen — semua dari `AppColors` (kecuali `Colors.white`, `Colors.transparent`, warna dompet dari data).
- §9.10 Conventional Commits, scope tanpa koma (`fix(debt): ...`, `feat(debt): ...`, `refactor(transactions): ...`). Setiap pesan commit diakhiri baris atribusi yang diberikan sesi eksekusi (mis. `Co-Authored-By: ...` dan `Claude-Session: ...`).
- §9.11 Perubahan DB hanya lewat `supabase/migrations/202609240001_debt_rpc.sql`; user yang mengeksekusi di dashboard. **Task 2 dan seterusnya tidak boleh di-merge sebelum user mengonfirmasi SQL Task 1 sudah dijalankan.**
- §10 Selesai per task: `flutter analyze` tanpa error/warning baru; `flutter test` hijau; `grep -c "GoogleFonts.poppins"` = 0 untuk file screen yang disentuh; tidak ada hex baru.
- Format tanggal tampilan memakai `DateFormat('dd MMM yyyy', 'id_ID')` (bulan Indonesia, "Agu", "Okt"). Ini perubahan kecil yang disengaja dari `DateFormat('dd MMM yyyy')` tanpa locale.
- Status utang di DB: `'active'` / `'paid'`. Jenis: `'payable'` (utang saya) / `'receivable'` (piutang).
- Kategori sistem transaksi utang: `'Sistem: Uang Masuk (Utang/Piutang)'` (`is_expense=false`) dan `'Sistem: Uang Keluar (Utang/Piutang)'` (`is_expense=true`), dicari berdasarkan `user_id` + `name` + `is_expense`.
- Toast (`AppNotification`) masih memakai Poppins sampai Plan B7 Task 6. Widget test yang memunculkan toast wajib memanggil `prewarmToastFont()` di `setUpAll` dan `flushToast(tester)` sebelum test selesai (helper di Task 5).

## Review Focus

1. **Double tap "Simpan"/"Bayar"** → hanya satu RPC terkirim; tombol menampilkan spinner dan disabled selama menyimpan. (Test: Task 3 `isSubmitting guard`, Task 6 `payment sheet submit sekali`.)
2. **Cicilan melebihi sisa atau nominal 0/kosong** → ditolak dengan pesan jelas di klien dan di server; tidak ada baris cicilan 0. (Test: Task 6 `validateDebtPayment`, SQL verifikasi Task 1.)
3. **Hapus cicilan yang pernah memotong dompet** → sisa tagihan bertambah, status LUNAS terbuka lagi, saldo dompet kembali; cicilan lama tanpa tautan transaksi hanya mengubah utang dan dialognya berkata begitu. (Test: Task 6 `pesan konfirmasi hapus cicilan`, SQL verifikasi Task 1.)
4. **Utang lewat jatuh tempo** → badge merah "Terlambat N hari", diurutkan paling atas, masuk total. (Test: Task 2 `overdueDays`, Task 3 `sortDebts`, Task 5 `badge Terlambat`.)
5. **Transaksi utang di Riwayat/Beranda/Statistik** → tidak menambah total pemasukan/pengeluaran dan tidak bisa dihapus/diedit dari Riwayat. (Test: Task 4 `transaction_tags_test`, Task 4 `input read-only utang`.)

---

## Pemetaan temuan audit → task

| # | Temuan audit | Task |
|---|---|---|
| 1 | Kategori dicari hanya berdasarkan nama → piutang tercatat sebagai pemasukan; `maybeSingle` bisa melempar setelah dompet terlanjur diubah | Task 1 (`debt_category_id` cari nama + `is_expense`, `limit 1`), Task 3 |
| 2 | Transaksi utang dihitung sebagai pemasukan/pengeluaran nyata | Task 1 (tag `[DEBT_ID:x]` + tandai data lama), Task 4 |
| 3 | Tulis-data tidak atomik | Task 1 (semua lewat RPC dalam satu transaksi Postgres), Task 3 |
| 4 | Tombol Simpan tanpa guard dobel tap | Task 3 (`isSubmitting`), Task 6, Task 7 (`loading`) |
| 5 | Saldo dompet dibaca dari cache klien | Task 1 (`debt_move_wallet` `for update` + `balance = balance + x` di server) |
| 6 | Beranda tidak refresh setelah kembali dari Utang | Task 8 |
| 7 | Hapus utang: error tertelan `debugPrint`, transaksi hasil utang tertinggal | Task 1 (`delete_debt` menghapus transaksi bertag), Task 6 (notifikasi error) |
| 8 | Hapus transaksi utang dari Riwayat membuat data tidak sinkron | Task 4 (baris tidak bisa digeser/diedit, input read-only, guard provider) |
| 9 | `wallet_id` cicilan tersimpan walau switch mati | Task 1 (`p_wallet_id` null = tidak menyentuh dompet), Task 6 (kirim `null` bila switch mati) |
| 10 | Nominal 0 diterima; nominal cicilan kosong diam saja | Task 1 (validasi server), Task 6 & 7 (validasi klien dengan pesan) |
| 11 | Tidak ada status terlambat | Task 2 (model), Task 3 (urutan), Task 5 (badge) |
| 12 | Transaksi pinjaman selalu bertanggal hari ini | Task 1 (`loan_date`), Task 7 (isian Tanggal Pinjam) |
| 13 | Tanggal cicilan bisa di masa depan / sebelum pinjaman; picker dikunci 2020–2030 | Task 1 (validasi server), Task 6 (picker `firstDate: loanDate`, `lastDate: hari ini`) |
| 14 | Spinner layar penuh setelah tiap cicilan; cicilan tidak disimpan di provider | Task 3 (`payments` di state, fetch diam), Task 6 |
| 15 | `fetchData` menulis `state` setelah notifier dibuang | Task 3 (`_alive` + `ref.onDispose`) |
| 16 | `int.parse` meluap > 19 digit; tipe uang | Task 6 & 7 (`AppAmountField` + `RupiahInputFormatter` maks 15 digit + `parseRupiah`), SQL `numeric` |
| 17 | Poppins & warna hardcoded | Task 5, 6, 7 |
| — | Belum ada: edit utang | Task 1 (`update_debt`), Task 3, Task 7 |
| — | Belum ada: edit/hapus cicilan | Task 1 (`update_debt_payment`, `delete_debt_payment`), Task 3, Task 6 |
| — | Belum ada: buka lagi LUNAS | Task 1 (status dihitung ulang di setiap RPC) |
| — | Belum ada: tautan utang ↔ transaksi | Task 1 (kolom `transaction_id` + tag) |
| — | Belum ada: tanggal pinjam & catatan | Task 1, Task 2, Task 7 |
| — | Belum ada: saldo di pilihan dompet, penanganan dompet kosong | Task 6 & 7 (pemilih dompet menampilkan saldo; switch nonaktif bila belum ada dompet) |
| — | Belum ada: tanda terlambat + total utang/piutang | Task 2, 3, 5 |
| — | Belum ada: pengingat (reminder) | **Di luar scope** — tidak disetujui user di Phase B |

## Peta file

| File | Aksi | Tanggung jawab |
|---|---|---|
| `supabase/migrations/202609240001_debt_rpc.sql` | Create | Kolom baru, FK `set null`, fungsi RPC atomik, penandaan data lama |
| `lib/core/transaction_tags.dart` | Create | Deteksi/penghapus tag `[SAVING_ID:` dan `[DEBT_ID:` (satu sumber) |
| `lib/models/debt_model.dart` | Create | `DebtModel`, `DebtType`, `DebtBadgeKind`, `debtBadgeLabel`, `debtInitials`, `sortDebts` |
| `lib/models/debt_payment_model.dart` | Create | `DebtPaymentModel` |
| `lib/services/debt_service.dart` | Create | `DebtApi` (abstrak), `SupabaseDebtApi`, `DebtActionException`, `runDebtRpc`, `debtApiProvider` |
| `lib/providers/debt_provider.dart` | Rewrite | `DebtState`, `DebtNotifier`, `debtProvider`, `debtClockProvider` |
| `lib/providers/home_provider.dart`, `stats_provider.dart`, `transaction_history_provider.dart`, `budget_provider.dart`, `calendar_provider.dart` | Modify | Pakai `isInternalMutation`/`isDebtMutation` |
| `lib/screens/export/export_screen.dart`, `ai_advisor/ai_advisor_screen.dart`, `budget/budget_detail_screen.dart` | Modify | Idem (satu–dua baris) |
| `lib/screens/transaction_history/transaction_history_screen.dart`, `input_transaction/input_transaction_screen.dart` | Modify | Baris utang tidak bisa dihapus; detail read-only dengan banner Utang |
| `lib/screens/debt/debt_screen.dart` | Rewrite | Daftar utang/piutang + total + segmented |
| `lib/screens/debt/widgets/debt_card.dart` | Create | `DebtCard`, `DebtBadge`, `DebtTotalsRow` |
| `lib/screens/debt/debt_detail_screen.dart` | Rewrite | Detail + riwayat cicilan dengan swipe |
| `lib/screens/debt/debt_payment_sheet.dart` | Create | `showDebtPaymentSheet`, `validateDebtPayment`, pemilih dompet |
| `lib/screens/debt/debt_form_sheet.dart` | Create | `showDebtFormSheet` (catat & edit), `validateDebtForm` |
| `lib/screens/debt/debt_wallet_picker.dart` | Create | `DebtWalletPickerRow`, `walletColorOf` (dipakai kedua sheet) |
| `lib/screens/home/home_screen.dart` | Modify | Refresh Beranda setelah kembali dari `DebtScreen` |
| `test/core/transaction_tags_test.dart`, `test/models/debt_model_test.dart`, `test/services/debt_service_test.dart`, `test/providers/debt_provider_test.dart`, `test/screens/debt/*` | Create | Test |

---

## Task 0: Branch

- [ ] **Step 1: Pastikan B1 sudah di main dan buat branch**

```bash
git checkout main
git pull --ff-only || true
test -f lib/widgets/app_page_scaffold.dart && test -f test/helpers/pump_app.dart && echo "B1 OK"
git checkout -b redesign/phase-b2-debt
```

Expected: `B1 OK`. Bila tidak tercetak, BERHENTI (BLOCKED: Plan B1 belum di-merge).

---

## Task 1: Migrasi SQL — kolom baru, FK, dan RPC atomik

**Files:**
- Create: `supabase/migrations/202609240001_debt_rpc.sql`

**Interfaces:**
- Consumes: skema `docs/database/schema.md` (`debts`, `debt_payments`, `transactions`, `categories`, `wallets`).
- Produces (dipanggil Task 3 lewat `supabase.rpc`), semua `security invoker`, memeriksa `auth.uid()`, pesan error berbahasa Indonesia yang langsung ditampilkan ke user:
  - `create_debt(p_name text, p_type text, p_amount numeric, p_loan_date date, p_due_date date default null, p_notes text default null, p_wallet_id bigint default null) returns bigint` (id utang)
  - `add_debt_payment(p_debt_id bigint, p_amount numeric, p_date date, p_wallet_id bigint default null) returns bigint` (id cicilan)
  - `update_debt(p_debt_id bigint, p_name text, p_amount numeric, p_loan_date date, p_due_date date default null, p_notes text default null) returns void`
  - `update_debt_payment(p_payment_id bigint, p_amount numeric, p_date date) returns void`
  - `delete_debt_payment(p_payment_id bigint) returns void`
  - `delete_debt(p_debt_id bigint) returns void`
  - Kolom baru: `debts.loan_date date not null default current_date`, `debts.notes text`, `debts.wallet_id bigint null → wallets on delete set null`, `debts.transaction_id bigint null → transactions on delete set null`, `debt_payments.transaction_id bigint null → transactions on delete set null`.
  - FK `debt_payments.wallet_id → wallets` diganti `on delete set null`.

Arah uang (dipakai semua fungsi):

| Aksi | `payable` (utang saya) | `receivable` (piutang) |
|---|---|---|
| Catat utang dengan dompet | dompet **+** jumlah, kategori Masuk | dompet **−** jumlah, kategori Keluar |
| Bayar/terima cicilan dengan dompet | dompet **−** nominal, kategori Keluar | dompet **+** nominal, kategori Masuk |

- [ ] **Step 1: Tulis file migrasi**

```sql
-- supabase/migrations/202609240001_debt_rpc.sql
-- Plan B2: Utang & Piutang — kolom baru, FK, dan fungsi RPC atomik.
-- Aman dijalankan berulang (idempotent). Jalankan dari SQL Editor Supabase di LAPTOP
-- (editor versi HP menyisipkan kurung otomatis saat menempel sehingga SQL rusak).

-- =========================================================================
-- 1. Kolom baru
-- =========================================================================
alter table public.debts add column if not exists loan_date date;
update public.debts set loan_date = created_at::date where loan_date is null and created_at is not null;
update public.debts set loan_date = current_date where loan_date is null;
alter table public.debts alter column loan_date set default current_date;
alter table public.debts alter column loan_date set not null;

alter table public.debts add column if not exists notes text;
alter table public.debts add column if not exists wallet_id bigint
  references public.wallets(id) on delete set null;
alter table public.debts add column if not exists transaction_id bigint
  references public.transactions(id) on delete set null;
alter table public.debt_payments add column if not exists transaction_id bigint
  references public.transactions(id) on delete set null;

-- =========================================================================
-- 2. debt_payments.wallet_id: NO ACTION -> SET NULL
--    (dulu dompet yang pernah dipakai cicilan tidak bisa dihapus)
-- =========================================================================
do $$
declare
  v_con text;
begin
  for v_con in
    select c.conname
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.conrelid = 'public.debt_payments'::regclass
      and c.contype = 'f'
      and a.attname = 'wallet_id'
  loop
    execute format('alter table public.debt_payments drop constraint %I', v_con);
  end loop;

  alter table public.debt_payments
    add constraint debt_payments_wallet_id_fkey
    foreign key (wallet_id) references public.wallets(id) on delete set null;
end $$;

-- =========================================================================
-- 3. Helper internal
-- =========================================================================
create or replace function public.debt_category_id(p_is_expense boolean)
returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_name text := case when p_is_expense
    then 'Sistem: Uang Keluar (Utang/Piutang)'
    else 'Sistem: Uang Masuk (Utang/Piutang)' end;
  v_id bigint;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;

  select id into v_id
  from categories
  where user_id = v_user and name = v_name and is_expense = p_is_expense
  order by id
  limit 1;

  if v_id is null then
    insert into categories (user_id, name, is_expense, icon_name)
    values (v_user, v_name, p_is_expense, 'bank')
    returning id into v_id;
  end if;

  return v_id;
end $$;

-- p_delta > 0 menambah saldo, p_delta < 0 mengurangi (ditolak bila saldo jadi negatif).
create or replace function public.debt_move_wallet(
  p_wallet_id bigint,
  p_delta numeric,
  p_insufficient_msg text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_balance numeric;
begin
  select coalesce(balance, 0) into v_balance
  from wallets
  where id = p_wallet_id and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Dompet tidak ditemukan.';
  end if;

  if p_delta < 0 and v_balance + p_delta < 0 then
    raise exception '%', p_insufficient_msg;
  end if;

  update wallets set balance = coalesce(balance, 0) + p_delta where id = p_wallet_id;
end $$;

-- =========================================================================
-- 4. RPC publik
--    Batas "masa depan" = current_date + 1 supaya selisih zona waktu server (UTC)
--    dengan WIB tidak menolak tanggal "hari ini" milik user.
-- =========================================================================
create or replace function public.create_debt(
  p_name text,
  p_type text,
  p_amount numeric,
  p_loan_date date,
  p_due_date date default null,
  p_notes text default null,
  p_wallet_id bigint default null
)
returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_name text := trim(coalesce(p_name, ''));
  v_into_wallet boolean := (p_type = 'payable');
  v_debt_id bigint;
  v_trx_id bigint;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;
  if v_name = '' then
    raise exception 'Nama tidak boleh kosong!';
  end if;
  if p_type is null or p_type not in ('payable', 'receivable') then
    raise exception 'Jenis utang tidak dikenal.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Nominal harus lebih dari 0.';
  end if;
  if p_loan_date is null then
    raise exception 'Tanggal pinjam wajib diisi.';
  end if;
  if p_loan_date > current_date + 1 then
    raise exception 'Tanggal pinjam tidak boleh di masa depan.';
  end if;

  insert into debts (user_id, name, type, amount, remaining_amount, loan_date, due_date, notes, status, wallet_id)
  values (v_user, v_name, p_type, p_amount, p_amount, p_loan_date, p_due_date,
          nullif(trim(coalesce(p_notes, '')), ''), 'active', p_wallet_id)
  returning id into v_debt_id;

  if p_wallet_id is not null then
    perform debt_move_wallet(
      p_wallet_id,
      case when v_into_wallet then p_amount else -p_amount end,
      'Saldo dompet tidak mencukupi untuk dipinjamkan!'
    );

    insert into transactions (user_id, wallet_id, category_id, amount, date, note)
    values (
      v_user, p_wallet_id, debt_category_id(not v_into_wallet), p_amount, p_loan_date,
      case when v_into_wallet then 'Pinjaman diterima dari ' else 'Memberi pinjaman ke ' end
        || v_name || ' [DEBT_ID:' || v_debt_id || ']'
    )
    returning id into v_trx_id;

    update debts set transaction_id = v_trx_id where id = v_debt_id;
  end if;

  return v_debt_id;
end $$;

create or replace function public.add_debt_payment(
  p_debt_id bigint,
  p_amount numeric,
  p_date date,
  p_wallet_id bigint default null
)
returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_debt debts%rowtype;
  v_into_wallet boolean;
  v_trx_id bigint;
  v_payment_id bigint;
  v_new_remaining numeric;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;

  select * into v_debt from debts where id = p_debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;
  if v_debt.remaining_amount <= 0 then
    raise exception 'Utang ini sudah lunas!';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Nominal harus lebih dari 0.';
  end if;
  if p_amount > v_debt.remaining_amount then
    raise exception 'Jumlah bayar tidak boleh melebihi sisa utang!';
  end if;
  if p_date is null then
    raise exception 'Tanggal pembayaran wajib diisi.';
  end if;
  if p_date < v_debt.loan_date then
    raise exception 'Tanggal bayar tidak boleh sebelum tanggal pinjam.';
  end if;
  if p_date > current_date + 1 then
    raise exception 'Tanggal bayar tidak boleh di masa depan.';
  end if;

  v_into_wallet := (v_debt.type = 'receivable');

  if p_wallet_id is not null then
    perform debt_move_wallet(
      p_wallet_id,
      case when v_into_wallet then p_amount else -p_amount end,
      'Saldo dompet tidak mencukupi!'
    );

    insert into transactions (user_id, wallet_id, category_id, amount, date, note)
    values (
      v_user, p_wallet_id, debt_category_id(not v_into_wallet), p_amount, p_date,
      case when v_into_wallet then 'Menerima bayaran dari ' else 'Bayar utang ke ' end
        || v_debt.name || ' [DEBT_ID:' || v_debt.id || ']'
    )
    returning id into v_trx_id;
  end if;

  insert into debt_payments (debt_id, user_id, wallet_id, amount, date, transaction_id)
  values (v_debt.id, v_user, p_wallet_id, p_amount, p_date, v_trx_id)
  returning id into v_payment_id;

  v_new_remaining := v_debt.remaining_amount - p_amount;
  update debts
  set remaining_amount = v_new_remaining,
      status = case when v_new_remaining <= 0 then 'paid' else 'active' end
  where id = v_debt.id;

  return v_payment_id;
end $$;

create or replace function public.update_debt(
  p_debt_id bigint,
  p_name text,
  p_amount numeric,
  p_loan_date date,
  p_due_date date default null,
  p_notes text default null
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_name text := trim(coalesce(p_name, ''));
  v_debt debts%rowtype;
  v_paid numeric;
  v_delta numeric;
  v_into_wallet boolean;
  v_new_remaining numeric;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;
  if v_name = '' then
    raise exception 'Nama tidak boleh kosong!';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Nominal harus lebih dari 0.';
  end if;
  if p_loan_date is null then
    raise exception 'Tanggal pinjam wajib diisi.';
  end if;
  if p_loan_date > current_date + 1 then
    raise exception 'Tanggal pinjam tidak boleh di masa depan.';
  end if;

  select * into v_debt from debts where id = p_debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;

  v_paid := v_debt.amount - v_debt.remaining_amount;
  if p_amount < v_paid then
    raise exception 'Jumlah total tidak boleh kurang dari yang sudah dibayar.';
  end if;
  if exists (select 1 from debt_payments where debt_id = v_debt.id and date < p_loan_date) then
    raise exception 'Tanggal pinjam tidak boleh setelah tanggal cicilan pertama.';
  end if;

  v_delta := p_amount - v_debt.amount;
  v_into_wallet := (v_debt.type = 'payable');
  v_new_remaining := p_amount - v_paid;

  if v_debt.transaction_id is not null and v_debt.wallet_id is not null and v_delta <> 0 then
    perform debt_move_wallet(
      v_debt.wallet_id,
      case when v_into_wallet then v_delta else -v_delta end,
      'Saldo dompet tidak mencukupi untuk mengubah jumlah pinjaman!'
    );
  end if;

  if v_debt.transaction_id is not null then
    update transactions
    set amount = p_amount,
        date = p_loan_date,
        note = case when v_into_wallet then 'Pinjaman diterima dari ' else 'Memberi pinjaman ke ' end
               || v_name || ' [DEBT_ID:' || v_debt.id || ']'
    where id = v_debt.transaction_id and user_id = v_user;
  end if;

  update debts
  set name = v_name,
      amount = p_amount,
      remaining_amount = v_new_remaining,
      loan_date = p_loan_date,
      due_date = p_due_date,
      notes = nullif(trim(coalesce(p_notes, '')), ''),
      status = case when v_new_remaining <= 0 then 'paid' else 'active' end
  where id = v_debt.id;
end $$;

create or replace function public.update_debt_payment(
  p_payment_id bigint,
  p_amount numeric,
  p_date date
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_pay debt_payments%rowtype;
  v_debt debts%rowtype;
  v_available numeric;
  v_delta numeric;
  v_into_wallet boolean;
  v_new_remaining numeric;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;

  select * into v_pay from debt_payments where id = p_payment_id and user_id = v_user for update;
  if not found then
    raise exception 'Cicilan tidak ditemukan.';
  end if;
  select * into v_debt from debts where id = v_pay.debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Nominal harus lebih dari 0.';
  end if;
  v_available := v_debt.remaining_amount + v_pay.amount;
  if p_amount > v_available then
    raise exception 'Jumlah bayar tidak boleh melebihi sisa utang!';
  end if;
  if p_date is null then
    raise exception 'Tanggal pembayaran wajib diisi.';
  end if;
  if p_date < v_debt.loan_date then
    raise exception 'Tanggal bayar tidak boleh sebelum tanggal pinjam.';
  end if;
  if p_date > current_date + 1 then
    raise exception 'Tanggal bayar tidak boleh di masa depan.';
  end if;

  v_delta := p_amount - v_pay.amount;
  v_into_wallet := (v_debt.type = 'receivable');

  if v_pay.transaction_id is not null and v_pay.wallet_id is not null and v_delta <> 0 then
    perform debt_move_wallet(
      v_pay.wallet_id,
      case when v_into_wallet then v_delta else -v_delta end,
      'Saldo dompet tidak mencukupi!'
    );
  end if;

  if v_pay.transaction_id is not null then
    update transactions set amount = p_amount, date = p_date
    where id = v_pay.transaction_id and user_id = v_user;
  end if;

  update debt_payments set amount = p_amount, date = p_date where id = v_pay.id;

  v_new_remaining := v_available - p_amount;
  update debts
  set remaining_amount = v_new_remaining,
      status = case when v_new_remaining <= 0 then 'paid' else 'active' end
  where id = v_debt.id;
end $$;

create or replace function public.delete_debt_payment(p_payment_id bigint)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_pay debt_payments%rowtype;
  v_debt debts%rowtype;
  v_into_wallet boolean;
  v_new_remaining numeric;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;

  select * into v_pay from debt_payments where id = p_payment_id and user_id = v_user for update;
  if not found then
    raise exception 'Cicilan tidak ditemukan.';
  end if;
  select * into v_debt from debts where id = v_pay.debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;

  v_into_wallet := (v_debt.type = 'receivable');

  -- Membalik efek cicilan: uang yang dulu masuk dikeluarkan lagi, dan sebaliknya.
  if v_pay.transaction_id is not null and v_pay.wallet_id is not null then
    perform debt_move_wallet(
      v_pay.wallet_id,
      case when v_into_wallet then -v_pay.amount else v_pay.amount end,
      'Saldo dompet tidak mencukupi untuk membatalkan pembayaran ini!'
    );
  end if;

  delete from debt_payments where id = v_pay.id;

  if v_pay.transaction_id is not null then
    delete from transactions where id = v_pay.transaction_id and user_id = v_user;
  end if;

  v_new_remaining := v_debt.remaining_amount + v_pay.amount;
  update debts
  set remaining_amount = v_new_remaining,
      status = case when v_new_remaining <= 0 then 'paid' else 'active' end
  where id = v_debt.id;
end $$;

-- Sesuai teks dialog yang sudah ada: saldo dompet TIDAK dikembalikan.
create or replace function public.delete_debt(p_debt_id bigint)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;
  if not exists (select 1 from debts where id = p_debt_id and user_id = v_user) then
    raise exception 'Utang tidak ditemukan.';
  end if;

  -- debt_payments ikut terhapus lewat FK on delete cascade.
  delete from debts where id = p_debt_id and user_id = v_user;
  delete from transactions
  where user_id = v_user and note like '%[DEBT_ID:' || p_debt_id || ']%';
end $$;

-- =========================================================================
-- 5. Hak akses: hanya user login yang boleh memanggil
-- =========================================================================
revoke all on function public.debt_category_id(boolean) from public, anon;
revoke all on function public.debt_move_wallet(bigint, numeric, text) from public, anon;
revoke all on function public.create_debt(text, text, numeric, date, date, text, bigint) from public, anon;
revoke all on function public.add_debt_payment(bigint, numeric, date, bigint) from public, anon;
revoke all on function public.update_debt(bigint, text, numeric, date, date, text) from public, anon;
revoke all on function public.update_debt_payment(bigint, numeric, date) from public, anon;
revoke all on function public.delete_debt_payment(bigint) from public, anon;
revoke all on function public.delete_debt(bigint) from public, anon;

grant execute on function public.debt_category_id(boolean) to authenticated;
grant execute on function public.debt_move_wallet(bigint, numeric, text) to authenticated;
grant execute on function public.create_debt(text, text, numeric, date, date, text, bigint) to authenticated;
grant execute on function public.add_debt_payment(bigint, numeric, date, bigint) to authenticated;
grant execute on function public.update_debt(bigint, text, numeric, date, date, text) to authenticated;
grant execute on function public.update_debt_payment(bigint, numeric, date) to authenticated;
grant execute on function public.delete_debt_payment(bigint) to authenticated;
grant execute on function public.delete_debt(bigint) to authenticated;

-- =========================================================================
-- 6. Tandai transaksi utang LAMA (dibuat sebelum migrasi ini) supaya tidak lagi
--    dihitung sebagai pemasukan/pengeluaran. Tautan ke id utang tidak bisa
--    dipulihkan, jadi dipakai penanda 'legacy'.
-- =========================================================================
update public.transactions t
set note = trim(coalesce(t.note, '') || ' [DEBT_ID:legacy]')
from public.categories c
where c.id = t.category_id
  and c.name in ('Utang/Piutang', 'Sistem: Uang Keluar (Utang/Piutang)', 'Sistem: Uang Masuk (Utang/Piutang)')
  and coalesce(t.note, '') not like '%[DEBT_ID:%';

notify pgrst, 'reload schema';
```

- [ ] **Step 2: Serahkan SQL ke user dan tunggu konfirmasi**

Koordinator (bukan subagent) mengirim pesan ke user, berbahasa Indonesia:

> SQL untuk Utang & Piutang sudah siap di `supabase/migrations/202609240001_debt_rpc.sql`. Tolong jalankan **dari laptop** (editor Supabase di HP menambah tanda kurung otomatis saat menempel sehingga SQL-nya rusak): Supabase Dashboard → SQL Editor → New query → tempel seluruh isi file → Run. Hasil yang diharapkan: "Success. No rows returned". Setelah itu jalankan query verifikasi di bawah dan kirim hasilnya ke sini.

Query verifikasi (satu per satu, masing-masing satu statement):

```sql
select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name in ('debts', 'debt_payments')
order by table_name, ordinal_position;
```

```sql
select routine_name
from information_schema.routines
where routine_schema = 'public' and routine_name like '%debt%'
order by routine_name;
```

```sql
select conname, confdeltype
from pg_constraint
where conname = 'debt_payments_wallet_id_fkey';
```

```sql
select count(*) as transaksi_utang_lama_ditandai
from public.transactions
where note like '%[DEBT_ID:legacy]%';
```

Expected:
- `debts` punya `loan_date` (NOT NULL), `notes`, `wallet_id`, `transaction_id`; `debt_payments` punya `transaction_id`.
- 8 fungsi: `add_debt_payment`, `create_debt`, `debt_category_id`, `debt_move_wallet`, `delete_debt`, `delete_debt_payment`, `update_debt`, `update_debt_payment`.
- `confdeltype = 'n'` (set null).
- Angka transaksi lama ≥ 0 (dicatat di laporan).

**Jangan lanjut ke Task 2 sebelum user mengonfirmasi keempat hasil ini.** Bila ada error, salin pesan error ke laporan dan perbaiki SQL di commit baru.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/202609240001_debt_rpc.sql
git commit -m "feat(debt): add atomic debt RPC migration with loan date and notes"
```

---

## Task 2: Model `DebtModel` & `DebtPaymentModel`

**Files:**
- Create: `lib/models/debt_model.dart`
- Create: `lib/models/debt_payment_model.dart`
- Test: `test/models/debt_model_test.dart`

**Interfaces:**
- Produces:
  - `enum DebtType { payable, receivable }` dengan `String get dbValue` (`'payable'`/`'receivable'`).
  - `enum DebtBadgeKind { paid, overdue, due, none }`.
  - `class DebtModel` (field: `int id, String name, DebtType type, double amount, double remainingAmount, DateTime loanDate, DateTime? dueDate, String? notes, String status, int? walletId, int? transactionId, DateTime? createdAt`), `factory DebtModel.fromJson(Map<String, dynamic>)`, getter `isPayable`, `paidAmount`, `isPaidOff`, `progress`; method `bool isOverdue(DateTime today)`, `int overdueDays(DateTime today)`, `DebtBadgeKind badgeKind(DateTime today)`.
  - `String debtBadgeLabel(DebtModel debt, DateTime today)` → `'LUNAS'` / `'Terlambat N hari'` / `'Tempo: dd MMM yyyy'` / `''`.
  - `String debtInitials(String name)` → maks 2 huruf besar.
  - `List<DebtModel> sortDebts(Iterable<DebtModel> debts, DateTime today)` → terlambat → jatuh tempo terdekat → tanpa jatuh tempo → lunas; dalam grup tanpa tanggal: terbaru dulu.
  - `class DebtPaymentModel` (field: `int id, int debtId, int? walletId, String? walletName, int? transactionId, double amount, DateTime date, DateTime? createdAt`), `factory DebtPaymentModel.fromJson`, getter `affectsWallet` (= `transactionId != null`).

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/models/debt_model_test.dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  final today = DateTime(2026, 9, 24);

  DebtModel debt({
    int id = 1,
    DebtType type = DebtType.payable,
    double amount = 2000000,
    double remaining = 1200000,
    DateTime? due,
    String status = 'active',
    DateTime? created,
  }) {
    return DebtModel(
      id: id,
      name: 'Budi Santoso',
      type: type,
      amount: amount,
      remainingAmount: remaining,
      loanDate: DateTime(2026, 8, 1),
      dueDate: due,
      notes: null,
      status: status,
      walletId: null,
      transactionId: null,
      createdAt: created,
    );
  }

  group('DebtModel.fromJson', () {
    test('memetakan kolom baru dan lama', () {
      final m = DebtModel.fromJson({
        'id': 7,
        'user_id': 'u1',
        'name': 'Rina',
        'type': 'receivable',
        'amount': 750000,
        'remaining_amount': 500000.5,
        'loan_date': '2026-09-20',
        'due_date': '2026-11-15',
        'notes': '  Patungan kado  ',
        'status': 'active',
        'wallet_id': 3,
        'transaction_id': 44,
        'created_at': '2026-09-20T10:00:00+00:00',
      });
      expect(m.id, 7);
      expect(m.type, DebtType.receivable);
      expect(m.isPayable, isFalse);
      expect(m.amount, 750000);
      expect(m.remainingAmount, 500000.5);
      expect(m.loanDate, DateTime(2026, 9, 20));
      expect(m.dueDate, DateTime(2026, 11, 15));
      expect(m.notes, 'Patungan kado');
      expect(m.walletId, 3);
      expect(m.transactionId, 44);
    });

    test('catatan kosong jadi null, loan_date hilang jatuh ke created_at', () {
      final m = DebtModel.fromJson({
        'id': 1,
        'name': 'X',
        'type': 'payable',
        'amount': 1,
        'remaining_amount': 1,
        'notes': '   ',
        'status': null,
        'created_at': '2026-01-03T01:00:00+00:00',
      });
      expect(m.notes, isNull);
      expect(m.status, 'active');
      expect(m.loanDate.year, 2026);
      expect(m.loanDate.month, 1);
    });
  });

  group('status & badge', () {
    test('isPaidOff dari status atau sisa <= 0', () {
      expect(debt(status: 'paid').isPaidOff, isTrue);
      expect(debt(remaining: 0).isPaidOff, isTrue);
      expect(debt().isPaidOff, isFalse);
    });

    test('progress dan paidAmount', () {
      expect(debt().paidAmount, 800000);
      expect(debt().progress, closeTo(0.4, 1e-9));
      expect(debt(amount: 0, remaining: 0).progress, 0);
    });

    test('terlambat dihitung per tanggal, bukan jam', () {
      final d = debt(due: DateTime(2026, 9, 22, 23, 59));
      expect(d.isOverdue(DateTime(2026, 9, 24, 0, 1)), isTrue);
      expect(d.overdueDays(today), 2);
      expect(debt(due: today).isOverdue(today), isFalse);
      expect(debt(due: DateTime(2026, 9, 1), status: 'paid').isOverdue(today), isFalse);
    });

    test('badgeKind dan label', () {
      expect(debt(status: 'paid').badgeKind(today), DebtBadgeKind.paid);
      expect(debtBadgeLabel(debt(status: 'paid'), today), 'LUNAS');
      expect(debt(due: DateTime(2026, 9, 22)).badgeKind(today), DebtBadgeKind.overdue);
      expect(debtBadgeLabel(debt(due: DateTime(2026, 9, 22)), today), 'Terlambat 2 hari');
      expect(debt(due: DateTime(2026, 11, 15)).badgeKind(today), DebtBadgeKind.due);
      expect(debtBadgeLabel(debt(due: DateTime(2026, 11, 15)), today), 'Tempo: 15 Nov 2026');
      expect(debt().badgeKind(today), DebtBadgeKind.none);
      expect(debtBadgeLabel(debt(), today), '');
    });
  });

  test('debtInitials', () {
    expect(debtInitials('Budi Santoso'), 'BS');
    expect(debtInitials('rina'), 'R');
    expect(debtInitials('  Bank   Jago Syariah '), 'BJ');
    expect(debtInitials(''), '?');
  });

  test('sortDebts: terlambat -> jatuh tempo terdekat -> tanpa tempo -> lunas', () {
    final lunas = debt(id: 1, status: 'paid');
    final tanpaTempoLama = debt(id: 2, created: DateTime(2026, 1, 1));
    final tanpaTempoBaru = debt(id: 3, created: DateTime(2026, 9, 1));
    final tempoJauh = debt(id: 4, due: DateTime(2026, 12, 1));
    final tempoDekat = debt(id: 5, due: DateTime(2026, 10, 1));
    final telatBaru = debt(id: 6, due: DateTime(2026, 9, 23));
    final telatLama = debt(id: 7, due: DateTime(2026, 9, 1));

    final sorted = sortDebts(
      [lunas, tanpaTempoLama, tempoJauh, telatBaru, tanpaTempoBaru, tempoDekat, telatLama],
      today,
    );
    expect(sorted.map((d) => d.id).toList(), [7, 6, 5, 4, 3, 2, 1]);
  });

  test('DebtPaymentModel.fromJson membaca nama dompet dan tautan transaksi', () {
    final p = DebtPaymentModel.fromJson({
      'id': 11,
      'debt_id': 7,
      'user_id': 'u1',
      'wallet_id': 3,
      'amount': 500000,
      'date': '2026-09-15',
      'transaction_id': 90,
      'created_at': '2026-09-15T02:00:00+00:00',
      'wallets': {'name': 'BCA'},
    });
    expect(p.id, 11);
    expect(p.debtId, 7);
    expect(p.walletName, 'BCA');
    expect(p.affectsWallet, isTrue);
    expect(p.date, DateTime(2026, 9, 15));

    final legacy = DebtPaymentModel.fromJson({
      'id': 12,
      'debt_id': 7,
      'wallet_id': null,
      'amount': 300000,
      'date': '2026-09-01',
      'wallets': null,
    });
    expect(legacy.walletName, isNull);
    expect(legacy.affectsWallet, isFalse);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/models/debt_model_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:catat_uang_app/models/debt_model.dart'`.

- [ ] **Step 3: Implementasi `lib/models/debt_model.dart`**

```dart
import 'package:intl/intl.dart';

enum DebtType {
  payable,
  receivable;

  String get dbValue => this == DebtType.payable ? 'payable' : 'receivable';
}

enum DebtBadgeKind { paid, overdue, due, none }

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.parse(value as String);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

class DebtModel {
  final int id;
  final String name;
  final DebtType type;
  final double amount;
  final double remainingAmount;
  final DateTime loanDate;
  final DateTime? dueDate;
  final String? notes;
  final String status;
  final int? walletId;
  final int? transactionId;
  final DateTime? createdAt;

  const DebtModel({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.remainingAmount,
    required this.loanDate,
    required this.dueDate,
    required this.notes,
    required this.status,
    required this.walletId,
    required this.transactionId,
    required this.createdAt,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String?;
    final created = createdRaw == null ? null : DateTime.parse(createdRaw).toLocal();
    final rawNotes = (json['notes'] as String?)?.trim();
    return DebtModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] == 'receivable' ? DebtType.receivable : DebtType.payable,
      amount: (json['amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      loanDate: _parseDate(json['loan_date']) ??
          (created != null
              ? DateTime(created.year, created.month, created.day)
              : DateTime.now()),
      dueDate: _parseDate(json['due_date']),
      notes: (rawNotes == null || rawNotes.isEmpty) ? null : rawNotes,
      status: (json['status'] as String?) ?? 'active',
      walletId: (json['wallet_id'] as num?)?.toInt(),
      transactionId: (json['transaction_id'] as num?)?.toInt(),
      createdAt: created,
    );
  }

  bool get isPayable => type == DebtType.payable;

  double get paidAmount => (amount - remainingAmount).clamp(0, amount).toDouble();

  bool get isPaidOff => status == 'paid' || remainingAmount <= 0;

  double get progress => amount <= 0 ? 0 : (paidAmount / amount).clamp(0.0, 1.0).toDouble();

  bool isOverdue(DateTime today) =>
      !isPaidOff && dueDate != null && _dateOnly(dueDate!).isBefore(_dateOnly(today));

  int overdueDays(DateTime today) =>
      isOverdue(today) ? _dateOnly(today).difference(_dateOnly(dueDate!)).inDays : 0;

  DebtBadgeKind badgeKind(DateTime today) {
    if (isPaidOff) return DebtBadgeKind.paid;
    if (isOverdue(today)) return DebtBadgeKind.overdue;
    if (dueDate != null) return DebtBadgeKind.due;
    return DebtBadgeKind.none;
  }
}

String debtBadgeLabel(DebtModel debt, DateTime today) {
  switch (debt.badgeKind(today)) {
    case DebtBadgeKind.paid:
      return 'LUNAS';
    case DebtBadgeKind.overdue:
      return 'Terlambat ${debt.overdueDays(today)} hari';
    case DebtBadgeKind.due:
      return 'Tempo: ${DateFormat('dd MMM yyyy', 'id_ID').format(debt.dueDate!)}';
    case DebtBadgeKind.none:
      return '';
  }
}

String debtInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

List<DebtModel> sortDebts(Iterable<DebtModel> debts, DateTime today) {
  int rank(DebtModel d) {
    switch (d.badgeKind(today)) {
      case DebtBadgeKind.overdue:
        return 0;
      case DebtBadgeKind.due:
        return 1;
      case DebtBadgeKind.none:
        return 2;
      case DebtBadgeKind.paid:
        return 3;
    }
  }

  final list = debts.toList();
  list.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    if (rank(a) <= 1) {
      final byDue = a.dueDate!.compareTo(b.dueDate!);
      if (byDue != 0) return byDue;
    }
    final aTime = a.createdAt ?? a.loanDate;
    final bTime = b.createdAt ?? b.loanDate;
    return bTime.compareTo(aTime);
  });
  return list;
}
```

- [ ] **Step 4: Implementasi `lib/models/debt_payment_model.dart`**

```dart
class DebtPaymentModel {
  final int id;
  final int debtId;
  final int? walletId;
  final String? walletName;
  final int? transactionId;
  final double amount;
  final DateTime date;
  final DateTime? createdAt;

  const DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.walletId,
    required this.walletName,
    required this.transactionId,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  factory DebtPaymentModel.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallets'];
    final parsedDate = DateTime.parse(json['date'] as String);
    final createdRaw = json['created_at'] as String?;
    return DebtPaymentModel(
      id: (json['id'] as num).toInt(),
      debtId: (json['debt_id'] as num).toInt(),
      walletId: (json['wallet_id'] as num?)?.toInt(),
      walletName: wallet is Map ? wallet['name'] as String? : null,
      transactionId: (json['transaction_id'] as num?)?.toInt(),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      createdAt: createdRaw == null ? null : DateTime.parse(createdRaw).toLocal(),
    );
  }

  bool get affectsWallet => transactionId != null;
}
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `flutter test test/models/debt_model_test.dart`
Expected: PASS (semua test).

- [ ] **Step 6: Commit**

```bash
git add lib/models/debt_model.dart lib/models/debt_payment_model.dart test/models/debt_model_test.dart
git commit -m "feat(debt): add debt and payment models with overdue and sort helpers"
```

---

## Task 3: `DebtApi` + rewrite `DebtNotifier`

**Files:**
- Create: `lib/services/debt_service.dart`
- Rewrite: `lib/providers/debt_provider.dart`
- Modify (adaptasi sementara supaya tetap compile): `lib/screens/debt/debt_screen.dart`, `lib/screens/debt/debt_detail_screen.dart`
- Test: `test/services/debt_service_test.dart`, `test/providers/debt_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 (nama & parameter RPC), Task 2 (model), `WalletModel.fromJson` (`lib/models/wallet_model.dart`).
- Produces:
  - `class DebtActionException implements Exception { final String message; }` — `toString()` mengembalikan `message`.
  - `Future<T> runDebtRpc<T>(Future<T> Function() run)` — mengubah `PostgrestException` menjadi `DebtActionException(e.message)`.
  - `abstract class DebtApi` dengan: `fetchDebts()`, `fetchWallets()`, `fetchPayments(int debtId)`, `createDebt({required String name, required DebtType type, required double amount, required DateTime loanDate, DateTime? dueDate, String? notes, int? walletId}) → Future<int>`, `updateDebt({required int debtId, required String name, required double amount, required DateTime loanDate, DateTime? dueDate, String? notes})`, `addPayment({required int debtId, required double amount, required DateTime date, int? walletId}) → Future<int>`, `updatePayment({required int paymentId, required double amount, required DateTime date})`, `deletePayment(int paymentId)`, `deleteDebt(int debtId)`.
  - `final debtApiProvider = Provider<DebtApi>(...)`.
  - `final debtClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);`
  - `class DebtState` (field `isLoading, isSubmitting, debts, wallets, payments (Map<int, List<DebtPaymentModel>>), loadingPayments (Set<int>)`; method `myDebts(DateTime today)`, `theirDebts(DateTime today)`, getter `totalPayable`, `totalReceivable`, `debtById(int id)`).
  - `class DebtNotifier extends AutoDisposeNotifier<DebtState>` dengan method publik bernama sama dengan `DebtApi` mutasi (+ `fetchData({bool silent = false})`, `fetchPayments(int debtId)`), dan `updatePayment({required int debtId, required int paymentId, ...})`, `deletePayment({required int debtId, required int paymentId})`.
  - `final debtProvider = NotifierProvider.autoDispose<DebtNotifier, DebtState>(DebtNotifier.new);`

- [ ] **Step 1: Tulis test service yang gagal**

```dart
// test/services/debt_service_test.dart
import 'package:catat_uang_app/services/debt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('runDebtRpc mengubah PostgrestException jadi DebtActionException dengan pesan server', () async {
    await expectLater(
      runDebtRpc<void>(() async {
        throw const PostgrestException(message: 'Jumlah bayar tidak boleh melebihi sisa utang!');
      }),
      throwsA(isA<DebtActionException>().having(
        (e) => e.message,
        'message',
        'Jumlah bayar tidak boleh melebihi sisa utang!',
      )),
    );
  });

  test('runDebtRpc meneruskan hasil bila sukses', () async {
    expect(await runDebtRpc(() async => 42), 42);
  });

  test('DebtActionException.toString hanya pesan', () {
    expect(const DebtActionException('Saldo dompet tidak mencukupi!').toString(),
        'Saldo dompet tidak mencukupi!');
  });
}
```

- [ ] **Step 2: Tulis test provider yang gagal**

```dart
// test/providers/debt_provider_test.dart
import 'dart:async';

import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/services/debt_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DebtModel _debt(int id, {DebtType type = DebtType.payable, double remaining = 100, String status = 'active', DateTime? due}) {
  return DebtModel(
    id: id,
    name: 'D$id',
    type: type,
    amount: 100,
    remainingAmount: remaining,
    loanDate: DateTime(2026, 9, 1),
    dueDate: due,
    notes: null,
    status: status,
    walletId: null,
    transactionId: null,
    createdAt: DateTime(2026, 9, id),
  );
}

class FakeDebtApi implements DebtApi {
  List<DebtModel> debts = [];
  List<WalletModel> wallets = [];
  Map<int, List<DebtPaymentModel>> payments = {};
  final calls = <String>[];
  Completer<void>? gate;
  Object? throwOnMutation;

  Future<void> _mutate(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (throwOnMutation != null) throw throwOnMutation!;
  }

  @override
  Future<List<DebtModel>> fetchDebts() async {
    calls.add('fetchDebts');
    return debts;
  }

  @override
  Future<List<WalletModel>> fetchWallets() async {
    calls.add('fetchWallets');
    return wallets;
  }

  @override
  Future<List<DebtPaymentModel>> fetchPayments(int debtId) async {
    calls.add('fetchPayments:$debtId');
    if (gate != null) await gate!.future;
    return payments[debtId] ?? const [];
  }

  @override
  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) async {
    await _mutate('createDebt:$name:${type.dbValue}:$amount:$walletId');
    return 99;
  }

  @override
  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) =>
      _mutate('updateDebt:$debtId:$name:$amount');

  @override
  Future<int> addPayment({required int debtId, required double amount, required DateTime date, int? walletId}) async {
    await _mutate('addPayment:$debtId:$amount:$walletId');
    return 5;
  }

  @override
  Future<void> updatePayment({required int paymentId, required double amount, required DateTime date}) =>
      _mutate('updatePayment:$paymentId:$amount');

  @override
  Future<void> deletePayment(int paymentId) => _mutate('deletePayment:$paymentId');

  @override
  Future<void> deleteDebt(int debtId) => _mutate('deleteDebt:$debtId');
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeDebtApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeDebtApi()
      ..debts = [
        _debt(1),
        _debt(2, remaining: 0, status: 'paid'),
        _debt(3, type: DebtType.receivable, remaining: 40),
        _debt(4, type: DebtType.receivable, remaining: 0, status: 'paid'),
        _debt(5, due: DateTime(2026, 9, 20)),
      ];
    container = ProviderContainer(overrides: [
      debtApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    container.listen(debtProvider, (_, __) {}, fireImmediately: true);
  });

  test('build() tidak menyentuh state sinkron dan memuat dompet lalu utang berurutan', () async {
    expect(container.read(debtProvider).isLoading, isTrue);
    await _settle();
    final s = container.read(debtProvider);
    expect(s.isLoading, isFalse);
    expect(s.debts, hasLength(5));
    expect(api.calls.take(2).toList(), ['fetchWallets', 'fetchDebts']);
  });

  test('total hanya menjumlahkan sisa utang/piutang yang belum lunas', () async {
    await _settle();
    final s = container.read(debtProvider);
    expect(s.totalPayable, 200);
    expect(s.totalReceivable, 40);
  });

  test('myDebts/theirDebts dipisah per jenis dan diurutkan (terlambat dulu, lunas terakhir)', () async {
    await _settle();
    final s = container.read(debtProvider);
    final today = DateTime(2026, 9, 24);
    expect(s.myDebts(today).map((d) => d.id).toList(), [5, 1, 2]);
    expect(s.theirDebts(today).map((d) => d.id).toList(), [3, 4]);
    expect(s.debtById(3)?.name, 'D3');
    expect(s.debtById(404), isNull);
  });

  test('isSubmitting guard: aksi kedua saat menyimpan ditolak dan hanya satu RPC terkirim', () async {
    await _settle();
    api.gate = Completer<void>();
    final notifier = container.read(debtProvider.notifier);

    final first = notifier.addPayment(debtId: 1, amount: 10, date: DateTime(2026, 9, 24));
    expect(container.read(debtProvider).isSubmitting, isTrue);
    await expectLater(
      notifier.addPayment(debtId: 1, amount: 10, date: DateTime(2026, 9, 24)),
      throwsA(isA<DebtActionException>()),
    );
    api.gate!.complete();
    await first;

    expect(api.calls.where((c) => c.startsWith('addPayment')).length, 1);
    expect(container.read(debtProvider).isSubmitting, isFalse);
  });

  test('mutasi sukses memuat ulang data tanpa spinner layar penuh dan memuat cicilan utang tsb', () async {
    await _settle();
    api.calls.clear();
    await container.read(debtProvider.notifier).addPayment(debtId: 1, amount: 10, date: DateTime(2026, 9, 24), walletId: null);
    expect(api.calls, ['addPayment:1:10.0:null', 'fetchWallets', 'fetchDebts', 'fetchPayments:1']);
    expect(container.read(debtProvider).isLoading, isFalse);
  });

  test('error server diteruskan apa adanya dan isSubmitting kembali false', () async {
    await _settle();
    api.throwOnMutation = const DebtActionException('Jumlah bayar tidak boleh melebihi sisa utang!');
    await expectLater(
      container.read(debtProvider.notifier).addPayment(debtId: 1, amount: 999, date: DateTime(2026, 9, 24)),
      throwsA(isA<DebtActionException>().having((e) => e.message, 'message', 'Jumlah bayar tidak boleh melebihi sisa utang!')),
    );
    expect(container.read(debtProvider).isSubmitting, isFalse);
  });

  test('error tak dikenal dibungkus pesan ramah', () async {
    await _settle();
    api.throwOnMutation = StateError('boom');
    await expectLater(
      container.read(debtProvider.notifier).deleteDebt(1),
      throwsA(isA<DebtActionException>().having((e) => e.message, 'message', 'Gagal menyimpan. Coba lagi.')),
    );
  });

  test('deleteDebt membuang cache cicilan utang tersebut', () async {
    await _settle();
    api.payments[1] = [
      DebtPaymentModel(id: 9, debtId: 1, walletId: null, walletName: null, transactionId: null, amount: 10, date: DateTime(2026, 9, 2), createdAt: null),
    ];
    final notifier = container.read(debtProvider.notifier);
    await notifier.fetchPayments(1);
    expect(container.read(debtProvider).payments[1], hasLength(1));
    await notifier.deleteDebt(1);
    expect(container.read(debtProvider).payments.containsKey(1), isFalse);
  });

  test('menulis state setelah provider dibuang tidak melempar', () async {
    final ownApi = FakeDebtApi();
    final own = ProviderContainer(overrides: [debtApiProvider.overrideWithValue(ownApi)]);
    final sub = own.listen(debtProvider, (_, __) {}, fireImmediately: true);
    await _settle();
    ownApi.gate = Completer<void>();
    final pending = own.read(debtProvider.notifier).fetchPayments(1);
    sub.close();
    own.dispose();
    ownApi.gate!.complete();
    await pending; // tidak boleh melempar StateError
  });
}
```

- [ ] **Step 3: Jalankan test, pastikan gagal**

Run: `flutter test test/services/debt_service_test.dart test/providers/debt_provider_test.dart`
Expected: FAIL — `debt_service.dart` tidak ada; `debtApiProvider` tidak terdefinisi.

- [ ] **Step 4: Implementasi `lib/services/debt_service.dart`**

```dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error dari aksi Utang & Piutang yang pesannya siap ditampilkan ke user.
/// Pesan dari fungsi RPC (Task 1 migrasi) sudah berbahasa Indonesia.
class DebtActionException implements Exception {
  final String message;
  const DebtActionException(this.message);

  @override
  String toString() => message;
}

Future<T> runDebtRpc<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on PostgrestException catch (e) {
    throw DebtActionException(e.message);
  }
}

abstract class DebtApi {
  Future<List<DebtModel>> fetchDebts();
  Future<List<WalletModel>> fetchWallets();
  Future<List<DebtPaymentModel>> fetchPayments(int debtId);

  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  });

  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  });

  Future<int> addPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    int? walletId,
  });

  Future<void> updatePayment({
    required int paymentId,
    required double amount,
    required DateTime date,
  });

  Future<void> deletePayment(int paymentId);
  Future<void> deleteDebt(int debtId);
}

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class SupabaseDebtApi implements DebtApi {
  SupabaseDebtApi(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DebtActionException('Sesi login berakhir. Silakan masuk lagi.');
    }
    return user.id;
  }

  @override
  Future<List<DebtModel>> fetchDebts() async {
    final res = await _client.from('debts').select().eq('user_id', _userId);
    return (res as List)
        .map((e) => DebtModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<WalletModel>> fetchWallets() async {
    final res = await _client.from('wallets').select().eq('user_id', _userId);
    return (res as List)
        .map((e) => WalletModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<DebtPaymentModel>> fetchPayments(int debtId) async {
    final res = await _client
        .from('debt_payments')
        .select('*, wallets(name)')
        .eq('debt_id', debtId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => DebtPaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) {
    return runDebtRpc(() async {
      final res = await _client.rpc('create_debt', params: {
        'p_name': name,
        'p_type': type.dbValue,
        'p_amount': amount,
        'p_loan_date': _day(loanDate),
        'p_due_date': dueDate == null ? null : _day(dueDate),
        'p_notes': notes,
        'p_wallet_id': walletId,
      });
      return (res as num).toInt();
    });
  }

  @override
  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) {
    return runDebtRpc(() async {
      await _client.rpc('update_debt', params: {
        'p_debt_id': debtId,
        'p_name': name,
        'p_amount': amount,
        'p_loan_date': _day(loanDate),
        'p_due_date': dueDate == null ? null : _day(dueDate),
        'p_notes': notes,
      });
    });
  }

  @override
  Future<int> addPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    int? walletId,
  }) {
    return runDebtRpc(() async {
      final res = await _client.rpc('add_debt_payment', params: {
        'p_debt_id': debtId,
        'p_amount': amount,
        'p_date': _day(date),
        'p_wallet_id': walletId,
      });
      return (res as num).toInt();
    });
  }

  @override
  Future<void> updatePayment({
    required int paymentId,
    required double amount,
    required DateTime date,
  }) {
    return runDebtRpc(() async {
      await _client.rpc('update_debt_payment', params: {
        'p_payment_id': paymentId,
        'p_amount': amount,
        'p_date': _day(date),
      });
    });
  }

  @override
  Future<void> deletePayment(int paymentId) {
    return runDebtRpc(() async {
      await _client.rpc('delete_debt_payment', params: {'p_payment_id': paymentId});
    });
  }

  @override
  Future<void> deleteDebt(int debtId) {
    return runDebtRpc(() async {
      await _client.rpc('delete_debt', params: {'p_debt_id': debtId});
    });
  }
}

final debtApiProvider = Provider<DebtApi>((ref) => SupabaseDebtApi(Supabase.instance.client));
```

- [ ] **Step 5: Rewrite `lib/providers/debt_provider.dart`**

```dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/services/debt_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jam yang dipakai layar Utang untuk menghitung "Terlambat N hari".
/// Di-override di test supaya hasilnya pasti.
final debtClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// State bersama DebtScreen dan DebtDetailScreen. Satu provider untuk kedua
/// layar supaya perubahan dari detail (bayar/edit/hapus) langsung terlihat di
/// daftar tanpa refetch manual setelah Navigator.pop.
class DebtState {
  final bool isLoading;
  final bool isSubmitting;
  final List<DebtModel> debts;
  final List<WalletModel> wallets;
  final Map<int, List<DebtPaymentModel>> payments;
  final Set<int> loadingPayments;

  const DebtState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.debts = const [],
    this.wallets = const [],
    this.payments = const {},
    this.loadingPayments = const {},
  });

  List<DebtModel> myDebts(DateTime today) => sortDebts(debts.where((d) => d.isPayable), today);

  List<DebtModel> theirDebts(DateTime today) => sortDebts(debts.where((d) => !d.isPayable), today);

  double get totalPayable => debts
      .where((d) => d.isPayable && !d.isPaidOff)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  double get totalReceivable => debts
      .where((d) => !d.isPayable && !d.isPaidOff)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  DebtModel? debtById(int id) {
    for (final d in debts) {
      if (d.id == id) return d;
    }
    return null;
  }

  DebtState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<DebtModel>? debts,
    List<WalletModel>? wallets,
    Map<int, List<DebtPaymentModel>>? payments,
    Set<int>? loadingPayments,
  }) {
    return DebtState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      debts: debts ?? this.debts,
      wallets: wallets ?? this.wallets,
      payments: payments ?? this.payments,
      loadingPayments: loadingPayments ?? this.loadingPayments,
    );
  }
}

class DebtNotifier extends AutoDisposeNotifier<DebtState> {
  DebtApi get _api => ref.read(debtApiProvider);

  bool _alive = true;

  @override
  DebtState build() {
    _alive = true;
    ref.onDispose(() => _alive = false);
    // Jangan sentuh `state` di sini: Riverpod baru menginisialisasi state
    // SETELAH build() return. Future.microtask menunda fetch pertama.
    Future.microtask(fetchData);
    return const DebtState();
  }

  void _update(DebtState Function(DebtState s) change) {
    if (!_alive) return;
    state = change(state);
  }

  /// `silent: true` dipakai setelah mutasi supaya layar tidak berganti
  /// jadi spinner penuh.
  Future<void> fetchData({bool silent = false}) async {
    if (!silent) _update((s) => s.copyWith(isLoading: true));
    try {
      // Berurutan (dompet dulu, lalu utang), sama seperti sebelum redesign.
      final wallets = await _api.fetchWallets();
      final debts = await _api.fetchDebts();
      _update((s) => s.copyWith(wallets: wallets, debts: debts, isLoading: false));
    } catch (e) {
      debugPrint('Error fetching debts: $e');
      _update((s) => s.copyWith(isLoading: false));
    }
  }

  Future<void> fetchPayments(int debtId) async {
    _update((s) => s.copyWith(loadingPayments: {...s.loadingPayments, debtId}));
    try {
      final list = await _api.fetchPayments(debtId);
      _update((s) => s.copyWith(
            payments: {...s.payments, debtId: list},
            loadingPayments: {...s.loadingPayments}..remove(debtId),
          ));
    } catch (e) {
      debugPrint('Error fetching debt payments: $e');
      _update((s) => s.copyWith(loadingPayments: {...s.loadingPayments}..remove(debtId)));
    }
  }

  Future<T> _submit<T>(Future<T> Function() action, {int? refreshPaymentsFor}) async {
    if (state.isSubmitting) {
      throw const DebtActionException('Sedang menyimpan, tunggu sebentar.');
    }
    _update((s) => s.copyWith(isSubmitting: true));
    try {
      final result = await action();
      await fetchData(silent: true);
      if (refreshPaymentsFor != null) await fetchPayments(refreshPaymentsFor);
      return result;
    } on DebtActionException {
      rethrow;
    } catch (e) {
      debugPrint('Debt action error: $e');
      throw const DebtActionException('Gagal menyimpan. Coba lagi.');
    } finally {
      _update((s) => s.copyWith(isSubmitting: false));
    }
  }

  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) {
    return _submit(() => _api.createDebt(
          name: name,
          type: type,
          amount: amount,
          loanDate: loanDate,
          dueDate: dueDate,
          notes: notes,
          walletId: walletId,
        ));
  }

  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) {
    return _submit(() => _api.updateDebt(
          debtId: debtId,
          name: name,
          amount: amount,
          loanDate: loanDate,
          dueDate: dueDate,
          notes: notes,
        ));
  }

  Future<int> addPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    int? walletId,
  }) {
    return _submit(
      () => _api.addPayment(debtId: debtId, amount: amount, date: date, walletId: walletId),
      refreshPaymentsFor: debtId,
    );
  }

  Future<void> updatePayment({
    required int debtId,
    required int paymentId,
    required double amount,
    required DateTime date,
  }) {
    return _submit(
      () => _api.updatePayment(paymentId: paymentId, amount: amount, date: date),
      refreshPaymentsFor: debtId,
    );
  }

  Future<void> deletePayment({required int debtId, required int paymentId}) {
    return _submit(() => _api.deletePayment(paymentId), refreshPaymentsFor: debtId);
  }

  Future<void> deleteDebt(int debtId) async {
    await _submit(() => _api.deleteDebt(debtId));
    _update((s) => s.copyWith(payments: {...s.payments}..remove(debtId)));
  }
}

final debtProvider = NotifierProvider.autoDispose<DebtNotifier, DebtState>(DebtNotifier.new);
```

- [ ] **Step 6: Adaptasi sementara dua layar lama supaya tetap compile**

Layar lama akan diganti total di Task 5–7; di sini hanya ubah pemakaian API. Ubahan di `lib/screens/debt/debt_screen.dart`:

1. Baris 48 dan 315–323 (dropdown dompet di sheet): `wallets` sekarang `List<WalletModel>`. Ganti blok `items:`:

```dart
                              items: wallets.map((w) {
                                return DropdownMenuItem<int>(
                                  value: w.id,
                                  child: Text(
                                    w.name,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                );
                              }).toList(),
```

2. Baris 386–393 (`addDebt`) ganti dengan:

```dart
                            await ref.read(debtProvider.notifier).createDebt(
                                  name: nameController.text.trim(),
                                  type: debtType == 'payable' ? DebtType.payable : DebtType.receivable,
                                  amount: rawAmount,
                                  loanDate: DateTime.now(),
                                  dueDate: selectedDate,
                                  walletId: affectWallet ? selectedWalletId : null,
                                );
```

3. Baris 431 `_buildDebtList(List<Map<String, dynamic>> debts, ...)` → `_buildDebtList(List<DebtModel> debts, ...)`; di badan `itemBuilder` (baris 456–465) ganti pembacaan map:

```dart
        final debt = debts[index];
        final amount = debt.amount;
        final remaining = debt.remainingAmount;
        final paid = amount - remaining;
        final percentage = amount > 0 ? (paid / amount) : 0.0;
        final isPaid = debt.isPaidOff;

        final isPayable = debt.isPayable;
```

   Baris 472 `DebtDetailScreen(debt: debt)` → `DebtDetailScreen(debtId: debt.id)`; baris 519–521 `debt['due_date'] != null` → `debt.dueDate != null` dan `DateTime.parse(debt['due_date'])` → `debt.dueDate!`; baris 532 `debt['name']` → `debt.name`.

4. Baris 646 `_isMyDebt ? debtState.myDebts : debtState.theirDebts` → `_isMyDebt ? debtState.myDebts(DateTime.now()) : debtState.theirDebts(DateTime.now())`.

5. Tambah import `package:catat_uang_app/models/debt_model.dart`.

Ubahan di `lib/screens/debt/debt_detail_screen.dart`:

1. Ganti field widget: `final Map<String, dynamic> debt;` → `final int debtId;`, konstruktor `const DebtDetailScreen({super.key, required this.debtId});`.
2. Hapus `_supabase`, `_isLoading`, `_payments`, dan `_fetchPayments` (baris 22–24 dan 44–66). `initState` menjadi:

```dart
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(debtProvider.notifier).fetchPayments(widget.debtId));
  }
```

3. `_showAddPaymentSheet(BuildContext context, Map<String, dynamic> debt)` → `(BuildContext context, DebtModel debt)`; baris 69 `(debt['remaining_amount'] as num).toDouble()` → `debt.remainingAmount`; baris 79 `debt['type'] == 'payable'` → `debt.isPayable`; dropdown baris 290–298 pakai `w.id`/`w.name` (seperti di atas); baris 349–355 ganti:

```dart
                            await ref.read(debtProvider.notifier).addPayment(
                                  debtId: debt.id,
                                  amount: rawAmount,
                                  date: selectedDate,
                                  walletId: affectWallet ? selectedWalletId : null,
                                );
```

   dan hapus pemanggilan `_fetchPayments();` di baris 359 (provider memuat ulang cicilan sendiri).
4. `_deleteDebt` baris 419: `widget.debt['id'] as int` → `widget.debtId`.
5. `build()` baris 437–456 ganti dengan:

```dart
    final debtState = ref.watch(debtProvider);
    final debt = debtState.debtById(widget.debtId);
    if (debt == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final payments = debtState.payments[debt.id] ?? const <DebtPaymentModel>[];

    final isPayable = debt.isPayable;
    final amount = debt.amount;
    final remaining = debt.remainingAmount;
    final paid = amount - remaining;
    final isPaid = debt.isPaidOff;
    final percentage = amount > 0 ? (paid / amount) : 0.0;
    final mainColor = isPayable ? Colors.red : Colors.green;
```

   lalu ganti `debt['name']` → `debt.name`, `debt['due_date']` → `debt.dueDate` (dan `DateTime.parse(...)` → `debt.dueDate!`), `_payments` → `payments`, dan di `itemBuilder` riwayat: `final pay = payments[index]; final payAmount = pay.amount; final walletName = pay.walletName ?? 'Tanpa Dompet';`, `DateTime.parse(pay['date'])` → `pay.date`.
6. Tambah import `debt_model.dart` dan `debt_payment_model.dart`; hapus import `supabase_flutter`.

- [ ] **Step 7: Jalankan test & analyze**

Run: `flutter test test/services/debt_service_test.dart test/providers/debt_provider_test.dart && flutter analyze lib/providers/debt_provider.dart lib/services/debt_service.dart lib/screens/debt`
Expected: test PASS; analyze tanpa error (info `withOpacity`/`deprecated_member_use` lama boleh).

- [ ] **Step 8: Commit**

```bash
git add lib/services/debt_service.dart lib/providers/debt_provider.dart lib/screens/debt/debt_screen.dart lib/screens/debt/debt_detail_screen.dart test/services/debt_service_test.dart test/providers/debt_provider_test.dart
git commit -m "fix(debt): route debt writes through atomic RPCs with submit guard"
```

---

## Task 4: Kecualikan `[DEBT_ID:` dari semua total + kunci baris utang di Riwayat

**Files:**
- Create: `lib/core/transaction_tags.dart`
- Modify: `lib/providers/home_provider.dart:217-219`, `lib/providers/stats_provider.dart:196-198`, `lib/providers/transaction_history_provider.dart:195-197` dan `:222-224`, `lib/providers/budget_provider.dart:142`, `lib/providers/calendar_provider.dart:118-122`, `lib/screens/budget/budget_detail_screen.dart:91`, `lib/screens/export/export_screen.dart:282-284`, `lib/screens/ai_advisor/ai_advisor_screen.dart:132-134`, `lib/screens/transaction_history/transaction_history_screen.dart:686-691,822-830,850-857`, `lib/screens/input_transaction/input_transaction_screen.dart:63-71,373`
- Test: `test/core/transaction_tags_test.dart`, `test/screens/input_transaction/input_transaction_debt_readonly_test.dart`

**Interfaces:**
- Produces (dipakai juga oleh Plan B4 saat merombak Riwayat/Statistik/Input — B4 WAJIB memakai helper ini, bukan deteksi sendiri):
  - `bool isSavingMutation(String? note, String? categoryName)`
  - `bool isDebtMutation(String? note)`
  - `bool isInternalMutation(String? note, String? categoryName)`
  - `String stripDebtTag(String? note)`
  - `String stripTransactionTags(String? note)`
  - `String debtTag(int debtId)` → `'[DEBT_ID:12]'`

- [ ] **Step 1: Tulis test helper yang gagal**

```dart
// test/core/transaction_tags_test.dart
import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mutasi tabungan butuh tag DAN kategori tabung/cair (perilaku lama)', () {
    expect(isSavingMutation('Setor [SAVING_ID:3]', 'Tabungan'), isTrue);
    expect(isSavingMutation('Cair [SAVING_ID:3]', 'Pencairan'), isTrue);
    expect(isSavingMutation('Beli [SAVING_ID:3]', 'Makan'), isFalse);
    expect(isSavingMutation('Setor', 'Tabungan'), isFalse);
    expect(isSavingMutation(null, null), isFalse);
  });

  test('mutasi utang cukup tag, termasuk penanda legacy', () {
    expect(isDebtMutation('Bayar utang ke Budi [DEBT_ID:12]'), isTrue);
    expect(isDebtMutation('Pinjaman lama [DEBT_ID:legacy]'), isTrue);
    expect(isDebtMutation('Makan siang'), isFalse);
    expect(isDebtMutation(null), isFalse);
  });

  test('isInternalMutation menggabungkan keduanya', () {
    expect(isInternalMutation('x [DEBT_ID:1]', 'Sistem: Uang Keluar (Utang/Piutang)'), isTrue);
    expect(isInternalMutation('x [SAVING_ID:1]', 'Tabungan'), isTrue);
    expect(isInternalMutation('x', 'Makan'), isFalse);
  });

  test('strip tag membersihkan teks catatan', () {
    expect(stripDebtTag('Bayar utang ke Budi [DEBT_ID:12]'), 'Bayar utang ke Budi');
    expect(stripTransactionTags('Setor [SAVING_ID:3] [DEBT_ID:legacy]'), 'Setor');
    expect(stripTransactionTags(null), '');
    expect(debtTag(12), '[DEBT_ID:12]');
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/core/transaction_tags_test.dart`
Expected: FAIL — file `transaction_tags.dart` tidak ada.

- [ ] **Step 3: Implementasi `lib/core/transaction_tags.dart`**

```dart
/// Penanda di `transactions.note` untuk transaksi yang memindahkan uang
/// tanpa menjadi pemasukan/pengeluaran sungguhan. Satu-satunya tempat logika
/// ini — screen/provider lain wajib memanggil helper di sini.
library;

final RegExp _savingTag = RegExp(r'\s*\[SAVING_ID:[^\]]*\]');
final RegExp _debtTag = RegExp(r'\s*\[DEBT_ID:[^\]]*\]');

/// Mutasi tabungan: bertag `[SAVING_ID:` dan kategori sistem tabungan
/// (nama mengandung "tabung"/"cair"). Sama persis dengan cek lama di tiap provider.
bool isSavingMutation(String? note, String? categoryName) {
  final n = note ?? '';
  final c = (categoryName ?? '').toLowerCase();
  return n.contains('[SAVING_ID:') && (c.contains('tabung') || c.contains('cair'));
}

/// Transaksi dari fitur Utang & Piutang (termasuk data lama bertanda `legacy`).
bool isDebtMutation(String? note) => (note ?? '').contains('[DEBT_ID:');

bool isInternalMutation(String? note, String? categoryName) =>
    isSavingMutation(note, categoryName) || isDebtMutation(note);

String stripDebtTag(String? note) => (note ?? '').replaceAll(_debtTag, '').trim();

String stripTransactionTags(String? note) =>
    (note ?? '').replaceAll(_savingTag, '').replaceAll(_debtTag, '').trim();

String debtTag(int debtId) => '[DEBT_ID:$debtId]';
```

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/core/transaction_tags_test.dart`
Expected: PASS.

- [ ] **Step 5: Ganti setiap situs pengecualian**

Tambahkan `import 'package:catat_uang_app/core/transaction_tags.dart';` di setiap file berikut, lalu edit terarah:

`lib/providers/home_provider.dart` baris 217–219:

```dart
        final isPureMutation = isInternalMutation(note, catName);
```

`lib/providers/stats_provider.dart` baris 196–198:

```dart
        final isPureMutation = isInternalMutation(note, catName);
```

`lib/providers/transaction_history_provider.dart` baris 195–197:

```dart
        final isPureMutation = isInternalMutation(note, catName);
```

dan di awal `deleteTransaction` (sebelum `try`, baris 223):

```dart
    if (isDebtMutation(trx.note)) {
      throw Exception('Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.');
    }
```

`lib/providers/budget_provider.dart` baris 142:

```dart
        if (noteStr.contains('[SAVING_ID:') || isDebtMutation(noteStr)) continue;
```

`lib/screens/budget/budget_detail_screen.dart` baris 91:

```dart
        if (noteStr.contains('[SAVING_ID:') || isDebtMutation(noteStr)) continue;
```

`lib/providers/calendar_provider.dart` baris 118–122 (ganti tiga statement `catName`/`isSystemCat`/`isPureMutation`; `note` tetap):

```dart
        final isPureMutation = isInternalMutation(note, trx.category?.name);
```

`lib/screens/export/export_screen.dart` baris 282–284:

```dart
        final catStr = itemData['categories']?['name']?.toString().toLowerCase() ?? '';
        final isPureMutation = isInternalMutation(noteStr, catStr);
```

`lib/screens/ai_advisor/ai_advisor_screen.dart` baris 132–134:

```dart
        final isPureMutation = isInternalMutation(note, catName);
```

(Periksa setelah edit: variabel `hasSavingMarker`/`isSystemCat` yang tidak terpakai lagi ikut dihapus; `flutter analyze` tidak boleh memunculkan `unused_local_variable` baru.)

- [ ] **Step 6: Kunci baris utang di Riwayat (UI lama, sebelum Plan B4)**

`lib/screens/transaction_history/transaction_history_screen.dart` baris 686–691 ganti dengan:

```dart
                      final noteStr = trx.note?.toString() ?? '';
                      final isDebtRow = isDebtMutation(noteStr);
                      final isPureMutation =
                          isInternalMutation(noteStr, trx.category?.name);
```

Baris ±822–830 (teks catatan) ganti isi `Text(...)`:

```dart
                                        child: Text(
                                          stripTransactionTags(trx.note),
```

Baris ±850–857 (teks badge "Mutasi Internal"):

```dart
                                        child: Text(
                                          isDebtRow ? "Utang/Piutang" : "Mutasi Internal",
```

Baris `if (isPureMutation) return transactionCard;` (±898) sudah membuat baris utang tidak bisa digeser — biarkan. Ketuk baris tetap membuka `InputTransactionScreen`, yang kini read-only untuk utang (Step 7).

- [ ] **Step 7: Input read-only untuk transaksi utang**

`lib/screens/input_transaction/input_transaction_screen.dart`:

Tambah field di bawah `bool _isReadOnly = false;` (baris 46):

```dart
  bool _readOnlyFromDebt = false;
```

Baris 63–71 (deteksi marker) ganti dengan:

```dart
      String rawNote = trx.note ?? '';
      final match = RegExp(r'\s*\[SAVING_ID:\d+\]').firstMatch(rawNote);
      final debtMatch = RegExp(r'\s*\[DEBT_ID:[^\]]*\]').firstMatch(rawNote);
      if (match != null) {
        _hiddenSavingMarker = match.group(0);
        _noteController.text = rawNote.replaceAll(match.group(0)!, '');
        _isReadOnly = true;
      } else if (debtMatch != null) {
        _hiddenSavingMarker = debtMatch.group(0);
        _noteController.text = rawNote.replaceAll(debtMatch.group(0)!, '').trim();
        _isReadOnly = true;
        _readOnlyFromDebt = true;
      } else {
        _noteController.text = rawNote;
      }
```

Baris 373 (teks banner) ganti literal string dengan:

```dart
                        _readOnlyFromDebt
                            ? "Ini adalah catatan otomatis dari fitur Utang & Piutang. Silakan gunakan menu Utang & Piutang di Beranda untuk mengedit/menghapus data ini."
                            : "Ini adalah catatan otomatis dari fitur Tabungan. Silakan gunakan Menu Tabungan di Beranda untuk mengedit/menghapus data ini.",
```

- [ ] **Step 8: Test read-only utang**

```dart
// test/screens/input_transaction/input_transaction_debt_readonly_test.dart
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('transaksi bertag DEBT_ID tampil read-only dengan banner Utang dan tag tersembunyi', (tester) async {
    final trx = TransactionModel(
      id: 1,
      userId: 'u1',
      categoryId: 10,
      amount: 500000,
      date: DateTime(2026, 9, 15),
      note: 'Bayar utang ke Budi [DEBT_ID:12]',
      category: CategoryModel.fromJson({
        'id': 10,
        'user_id': 'u1',
        'name': 'Sistem: Uang Keluar (Utang/Piutang)',
        'is_expense': true,
        'icon_name': 'bank',
      }),
      walletId: 3,
    );

    await pumpApp(tester, InputTransactionScreen(initialIsExpense: true, transactionToEdit: trx));
    await tester.pump();

    expect(find.textContaining('fitur Utang & Piutang'), findsOneWidget);
    expect(find.textContaining('[DEBT_ID:'), findsNothing);
    expect(find.text('Bayar utang ke Budi'), findsOneWidget);
  });
}
```

Catatan untuk eksekutor: bila `InputTransactionScreen` memanggil Supabase saat `initState` sehingga test gagal karena Supabase belum diinisialisasi, override provider-nya dengan fake notifier sesuai pola spec §6 (lihat `lib/providers/input_transaction_provider.dart`; `build()` fake mengembalikan state kosong tanpa fetch). Bila `CategoryModel.fromJson` membutuhkan kunci lain, sesuaikan map dengan konstruktornya di `lib/models/category_model.dart`.

Run: `flutter test test/screens/input_transaction/input_transaction_debt_readonly_test.dart`
Expected: PASS.

- [ ] **Step 9: Analyze + test penuh**

Run: `flutter analyze && flutter test`
Expected: tidak ada error/warning baru; semua test PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/core/transaction_tags.dart lib/providers/home_provider.dart lib/providers/stats_provider.dart lib/providers/transaction_history_provider.dart lib/providers/budget_provider.dart lib/providers/calendar_provider.dart lib/screens/budget/budget_detail_screen.dart lib/screens/export/export_screen.dart lib/screens/ai_advisor/ai_advisor_screen.dart lib/screens/transaction_history/transaction_history_screen.dart lib/screens/input_transaction/input_transaction_screen.dart test/core/transaction_tags_test.dart test/screens/input_transaction/input_transaction_debt_readonly_test.dart
git commit -m "fix(transactions): exclude debt transfers from income and expense totals"
```

---

## Task 5: Redesign daftar Utang & Piutang

**Files:**
- Rewrite: `lib/screens/debt/debt_screen.dart`
- Create: `lib/screens/debt/widgets/debt_card.dart`
- Create: `test/screens/debt/debt_test_utils.dart`
- Test: `test/screens/debt/debt_screen_test.dart`

**Interfaces:**
- Consumes: `debtProvider`, `debtClockProvider`, `DebtModel`, `debtBadgeLabel`; B1: `AppPageScaffold`, `AppNavAction.add`, `AppSegmentedControl`, `AppSurfaceCard`, `AppProgressBar`, `AppChip`, `AppEmptyState`, `AppTextStyles`, `formatRupiah`.
- Produces:
  - `class DebtCard extends StatelessWidget { const DebtCard({required DebtModel debt, required DateTime today, VoidCallback? onTap}); }`
  - `class DebtBadge extends StatelessWidget { const DebtBadge({required DebtModel debt, required DateTime today}); }` → `SizedBox.shrink()` bila `DebtBadgeKind.none`.
  - `class DebtTotalsRow extends StatelessWidget { const DebtTotalsRow({required double totalPayable, required double totalReceivable}); }`
  - Test utils: `FakeDebtNotifier`, `sampleDebt(...)`, `samplePayment(...)`, `debtOverrides(...)`, `prewarmToastFont()`, `flushToast(WidgetTester)`.

Tabel preservasi (kode sekarang = `lib/screens/debt/debt_screen.dart` versi `main` sebelum Task 3):

| # | Perilaku lama (file:baris) | Di layout baru |
|---|---|---|
| 1 | AppBar judul "Utang & Piutang" (613–619) | Judul besar `AppPageScaffold(title: 'Utang & Piutang', backLabel: 'Beranda')` |
| 2 | Toggle "Utang Saya"/"Piutang", `_isMyDebt` default true, tap hanya bila berubah (636–637, 663–672) | `AppSegmentedControl(['Utang Saya','Piutang'])`; komponen B1 sudah tidak memanggil `onChanged` untuk segmen terpilih |
| 3 | Spinner saat `isLoading` (643–644) | Spinner primary di tengah area list |
| 4 | Empty state ikon `handCoins` 64 + teks "Belum ada utang yang dicatat.\nAlhamdulillah!" / "Belum ada orang yang ngutang ke kamu." (432–449, 647–649) | `AppEmptyState(icon: PhosphorIconsRegular.handCoins, title: <teks sama>)` |
| 5 | Kartu per utang: label "Saya berutang ke:"/"Piutang dari:" (465), badge "LUNAS" hijau (503–518), atau "Tempo: dd MMM yyyy" oranye (519–527), nama (531–538), "Total Uang" + nominal (546–560), "Sudah lunas"/"Sisa Tagihan" + nominal merah(utang)/hijau(piutang)/hijau(lunas) (566–580), progress bar tinggi 8 warna sama (586–596) | `DebtCard` — sama, ditambah badge merah "Terlambat N hari" (spec §7.1) dan baris "Dipinjam dd MMM yyyy · catatan" |
| 6 | Tap kartu → push `DebtDetailScreen` (467–475) | Sama, `DebtDetailScreen(debtId: debt.id)` |
| 7 | FAB "+" → `_showAddDebtSheet` (654–659) | `AppNavAction.add` di nav bar → `_showAddDebtSheet` (sheet lama hasil adaptasi Task 3, diganti di Task 7) |
| 8 | Urutan: `status` asc lalu `created_at` desc (provider lama) | Urutan baru spec §7.1 via `sortDebts` (perubahan disengaja) |
| 9 | — | Baru: `DebtTotalsRow` (Total Utang merah, Total Piutang hijau) di atas segmented |
| 10 | — | Baru: pull-to-refresh (`onRefresh: fetchData`) |

- [ ] **Step 1: Tulis test utils**

```dart
// test/screens/debt/debt_test_utils.dart
import 'dart:async';

import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final DateTime kToday = DateTime(2026, 9, 24);

DebtModel sampleDebt({
  int id = 1,
  String name = 'Budi Santoso',
  DebtType type = DebtType.payable,
  double amount = 2000000,
  double remaining = 1200000,
  DateTime? loanDate,
  DateTime? dueDate,
  String? notes,
  String status = 'active',
  int? walletId,
  int? transactionId,
}) {
  return DebtModel(
    id: id,
    name: name,
    type: type,
    amount: amount,
    remainingAmount: remaining,
    loanDate: loanDate ?? DateTime(2026, 8, 1),
    dueDate: dueDate,
    notes: notes,
    status: status,
    walletId: walletId,
    transactionId: transactionId,
    createdAt: DateTime(2026, 8, id),
  );
}

DebtPaymentModel samplePayment({
  int id = 10,
  int debtId = 1,
  double amount = 500000,
  DateTime? date,
  int? walletId = 3,
  String? walletName = 'BCA',
  int? transactionId = 90,
}) {
  return DebtPaymentModel(
    id: id,
    debtId: debtId,
    walletId: walletId,
    walletName: walletName,
    transactionId: transactionId,
    amount: amount,
    date: date ?? DateTime(2026, 9, 15),
    createdAt: null,
  );
}

WalletModel sampleWallet({int id = 3, String name = 'BCA', double balance = 9300000, String color = '#4A6CF7'}) {
  return WalletModel(id: id, userId: 'u1', name: name, balance: balance, color: color);
}

class FakeDebtNotifier extends DebtNotifier {
  FakeDebtNotifier(this.initial);

  final DebtState initial;
  final List<String> calls = [];
  Completer<void>? gate;
  Object? error;

  @override
  DebtState build() => initial;

  Future<void> _record(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
  }

  @override
  Future<void> fetchData({bool silent = false}) async => calls.add('fetchData');

  @override
  Future<void> fetchPayments(int debtId) async => calls.add('fetchPayments:$debtId');

  @override
  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) async {
    await _record('createDebt:$name:${type.dbValue}:${amount.toInt()}:${loanDate.day}:${dueDate?.day}:$notes:$walletId');
    return 99;
  }

  @override
  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) =>
      _record('updateDebt:$debtId:$name:${amount.toInt()}:$notes');

  @override
  Future<int> addPayment({required int debtId, required double amount, required DateTime date, int? walletId}) async {
    await _record('addPayment:$debtId:${amount.toInt()}:$walletId');
    return 5;
  }

  @override
  Future<void> updatePayment({required int debtId, required int paymentId, required double amount, required DateTime date}) =>
      _record('updatePayment:$debtId:$paymentId:${amount.toInt()}');

  @override
  Future<void> deletePayment({required int debtId, required int paymentId}) =>
      _record('deletePayment:$debtId:$paymentId');

  @override
  Future<void> deleteDebt(int debtId) => _record('deleteDebt:$debtId');
}

List<Override> debtOverrides(FakeDebtNotifier fake) => [
      debtProvider.overrideWith(() => fake),
      debtClockProvider.overrideWithValue(() => kToday),
    ];

/// Toast `AppNotification` masih memakai Poppins (dibereskan Plan B7). Unduhan
/// font yang gagal di test di-"telan" di zona terpisah, pola sama dengan
/// test/flutter_test_config.dart.
Future<void> prewarmToastFont() async {
  await runZonedGuarded(() async {
    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500).fontFamily;
  }, (_, __) {});
}

/// Toast memakai Timer 3 detik + animasi 600 ms; habiskan supaya test tidak
/// gagal karena "A Timer is still pending".
Future<void> flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}
```

Catatan: bila konstruktor `WalletModel` di `lib/models/wallet_model.dart` berbeda, sesuaikan `sampleWallet` dengan konstruktornya (saat plan ditulis: `id, userId, name, balance, color, icon`).

- [ ] **Step 2: Tulis test layar yang gagal**

```dart
// test/screens/debt/debt_screen_test.dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  DebtState state() => DebtState(
        isLoading: false,
        debts: [
          sampleDebt(id: 1, dueDate: DateTime(2026, 9, 22), notes: 'Modal usaha'),
          sampleDebt(id: 2, name: 'Rina', amount: 750000, remaining: 750000, dueDate: DateTime(2026, 11, 15)),
          sampleDebt(id: 3, name: 'Bank Jago', amount: 5000000, remaining: 0, status: 'paid'),
          sampleDebt(id: 4, name: 'Andi', type: DebtType.receivable, amount: 1500000, remaining: 1500000),
        ],
      );

  testWidgets('judul, total, segmented, dan kartu utang saya', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake));
    await tester.pump();

    expect(find.text('Utang & Piutang'), findsOneWidget);
    expect(find.text('Total Utang'), findsOneWidget);
    expect(find.text('Rp 1.950.000'), findsOneWidget); // 1.200.000 + 750.000
    expect(find.text('Total Piutang'), findsOneWidget);
    expect(find.text('Rp 1.500.000'), findsWidgets);
    expect(find.byType(AppSegmentedControl), findsOneWidget);

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Terlambat 2 hari'), findsOneWidget);
    expect(find.text('Tempo: 15 Nov 2026'), findsOneWidget);
    expect(find.text('LUNAS'), findsOneWidget);
    expect(find.text('Dipinjam 01 Agu 2026 · Modal usaha'), findsOneWidget);
    expect(find.text('Andi'), findsNothing);
  });

  testWidgets('urutan kartu: terlambat, tempo, lunas', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())));
    await tester.pump();
    final budi = tester.getTopLeft(find.text('Budi Santoso')).dy;
    final rina = tester.getTopLeft(find.text('Rina')).dy;
    final jago = tester.getTopLeft(find.text('Bank Jago')).dy;
    expect(budi, lessThan(rina));
    expect(rina, lessThan(jago));
  });

  testWidgets('pindah ke Piutang menampilkan label "Piutang dari:"', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())));
    await tester.pump();
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();
    expect(find.text('Andi'), findsOneWidget);
    expect(find.text('Piutang dari:'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsNothing);
  });

  testWidgets('empty state per tab memakai teks lama', (tester) async {
    await pumpApp(tester, const DebtScreen(),
        overrides: debtOverrides(FakeDebtNotifier(const DebtState(isLoading: false))));
    await tester.pump();
    expect(find.text('Belum ada utang yang dicatat.\nAlhamdulillah!'), findsOneWidget);
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada orang yang ngutang ke kamu.'), findsOneWidget);
  });

  testWidgets('loading menampilkan spinner', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(const DebtState())));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `flutter test test/screens/debt/debt_screen_test.dart`
Expected: FAIL (mis. `Total Utang` tidak ditemukan; `debt_card.dart` belum ada).

- [ ] **Step 4: Implementasi `lib/screens/debt/widgets/debt_card.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

/// Warna utama per jenis (sama dengan layar lama: utang merah, piutang hijau).
Color debtMainColor(DebtModel debt) => debt.isPayable ? AppColors.expense : AppColors.income;

class DebtBadge extends StatelessWidget {
  const DebtBadge({required this.debt, required this.today, super.key});

  final DebtModel debt;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final kind = debt.badgeKind(today);
    if (kind == DebtBadgeKind.none) return const SizedBox.shrink();
    final color = switch (kind) {
      DebtBadgeKind.paid => AppColors.income,
      DebtBadgeKind.overdue => AppColors.expense,
      _ => AppColors.tintOrange,
    };
    return AppChip(label: debtBadgeLabel(debt, today), color: color);
  }
}

class DebtCard extends StatelessWidget {
  const DebtCard({required this.debt, required this.today, this.onTap, super.key});

  final DebtModel debt;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPaid = debt.isPaidOff;
    final accent = isPaid ? AppColors.income : debtMainColor(debt);
    final meta = debt.notes == null
        ? 'Dipinjam ${_dayFormat.format(debt.loanDate)}'
        : 'Dipinjam ${_dayFormat.format(debt.loanDate)} · ${debt.notes}';

    return AppSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  debt.isPayable ? 'Saya berutang ke:' : 'Piutang dari:',
                  style: AppTextStyles.caption,
                ),
              ),
              DebtBadge(debt: debt, today: today),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            debt.name,
            style: AppTextStyles.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(meta, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Uang', style: AppTextStyles.caption),
                    Text(formatRupiah(debt.amount), style: AppTextStyles.amountRow),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isPaid ? 'Sudah lunas' : 'Sisa Tagihan', style: AppTextStyles.caption),
                  Text(
                    formatRupiah(debt.remainingAmount),
                    style: AppTextStyles.amountRow.copyWith(color: accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(value: debt.progress, color: accent),
        ],
      ),
    );
  }
}

class DebtTotalsRow extends StatelessWidget {
  const DebtTotalsRow({required this.totalPayable, required this.totalReceivable, super.key});

  final double totalPayable;
  final double totalReceivable;

  Widget _tile(String label, double value, Color color) {
    return Expanded(
      child: AppSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatRupiah(value), style: AppTextStyles.amountRow.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile('Total Utang', totalPayable, AppColors.expense),
        const SizedBox(width: 12),
        _tile('Total Piutang', totalReceivable, AppColors.income),
      ],
    );
  }
}
```

- [ ] **Step 5: Rewrite `build()` dan bagian list `lib/screens/debt/debt_screen.dart`**

Pertahankan `_showAddDebtSheet` hasil adaptasi Task 3 untuk sementara (dihapus di Task 7). Hapus `_buildDebtList` dan `_buildToggleBtn`. Ganti import dan `build()`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
// ...import yang masih dipakai _showAddDebtSheet sementara (app_notification,
// app_bottom_sheet, google_fonts, intl, phosphor) tetap sampai Task 7.

  @override
  Widget build(BuildContext context) {
    final debtState = ref.watch(debtProvider);
    final today = ref.watch(debtClockProvider)();
    final debts = _isMyDebt ? debtState.myDebts(today) : debtState.theirDebts(today);

    return AppPageScaffold(
      title: 'Utang & Piutang',
      backLabel: 'Beranda',
      actions: [
        AppNavAction.add(onPressed: () => _showAddDebtSheet(context)),
      ],
      onRefresh: () => ref.read(debtProvider.notifier).fetchData(),
      children: [
        DebtTotalsRow(
          totalPayable: debtState.totalPayable,
          totalReceivable: debtState.totalReceivable,
        ),
        AppSegmentedControl(
          labels: const ['Utang Saya', 'Piutang'],
          selectedIndex: _isMyDebt ? 0 : 1,
          onChanged: (index) => setState(() => _isMyDebt = index == 0),
        ),
        if (debtState.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (debts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: AppEmptyState(
              icon: PhosphorIconsRegular.handCoins,
              title: _isMyDebt
                  ? 'Belum ada utang yang dicatat.\nAlhamdulillah!'
                  : 'Belum ada orang yang ngutang ke kamu.',
            ),
          )
        else
          for (final debt in debts)
            DebtCard(
              key: ValueKey('debt-${debt.id}'),
              debt: debt,
              today: today,
              onTap: () => _openDetail(debt),
            ),
      ],
    );
  }

  Future<void> _openDetail(DebtModel debt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DebtDetailScreen(debtId: debt.id)),
    );
  }
```

`AppNavAction` diimpor dari `app_page_scaffold.dart` (didefinisikan di file yang sama oleh B1; bila B1 menaruhnya di file lain, sesuaikan import).

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/debt/debt_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Checklist visual vs mockup "Utang & Piutang"**

Jalankan skill `run-and-screenshot`, buka Beranda → Utang. Cocokkan:
- [ ] Nav bar tipis: `‹ Beranda` kiri (primary), `+` kanan. Tidak ada AppBar putih di tengah dan tidak ada FAB.
- [ ] Judul besar "Utang & Piutang" rata kiri.
- [ ] Dua kartu putih berdampingan: "Total Utang" (angka merah) dan "Total Piutang" (angka hijau).
- [ ] Segmented control abu dengan pill putih "Utang Saya" / "Piutang".
- [ ] Kartu putih radius 24 tanpa border: label kecil kiri + badge kanan (merah "Terlambat N hari" / oranye "Tempo: …" / hijau "LUNAS"), nama tebal, baris "Dipinjam … · catatan", "Total Uang" kiri, "Sisa Tagihan" kanan berwarna, progress bar tipis.
- [ ] Urutan: terlambat di atas, lunas paling bawah.
- [ ] Empty state: ikon abu besar + teks, di tengah.

- [ ] **Step 8: Cek Poppins/hex & analyze**

Run: `grep -c "GoogleFonts.poppins" lib/screens/debt/widgets/debt_card.dart; flutter analyze lib/screens/debt`
Expected: `0` untuk `debt_card.dart`. (`debt_screen.dart` masih memuat Poppins di `_showAddDebtSheet` sementara — dibersihkan Task 7.) Analyze tanpa error.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/debt/debt_screen.dart lib/screens/debt/widgets/debt_card.dart test/screens/debt/debt_test_utils.dart test/screens/debt/debt_screen_test.dart
git commit -m "feat(debt): redesign debt list with totals and overdue badges"
```

---

## Task 6: Redesign Detail Utang + sheet cicilan (tambah/edit) + swipe edit/hapus

**Files:**
- Rewrite: `lib/screens/debt/debt_detail_screen.dart`
- Create: `lib/screens/debt/debt_wallet_picker.dart`
- Create: `lib/screens/debt/debt_payment_sheet.dart`
- Test: `test/screens/debt/debt_payment_sheet_test.dart`, `test/screens/debt/debt_detail_screen_test.dart`

**Interfaces:**
- Consumes: `debtProvider` (`fetchPayments`, `addPayment`, `updatePayment`, `deletePayment`, `deleteDebt`), `DebtModel`, `DebtPaymentModel`, `debtInitials`, `DebtBadge`, `debtMainColor`; B1: `AppPageScaffold(largeTitle: false, titleWidget:)`, `AppNavAction.icon`, `AppNavAction.text`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppSwipeActions(deleteConfirmTitle:, deleteConfirmMessage:)`, `AppPrimaryButton`, `AppSurfaceCard`, `AppProgressBar`, `AppAmountField`, `AppAmountDisplay`, `AppSwitch`, `AppCallout`, `showAppFormSheet`, `showAppConfirmDialog`, `parseRupiah`, `formatRupiah`.
- Produces:
  - `Future<void> showDebtPaymentSheet(BuildContext context, {required DebtModel debt, DebtPaymentModel? payment})`
  - `String? validateDebtPayment({required String amountText, required double maxAmount, required bool affectWallet, required int? walletId})`
  - `class DebtWalletPickerRow extends StatelessWidget { const DebtWalletPickerRow({required List<WalletModel> wallets, required int? selectedWalletId, required ValueChanged<int> onSelected}); }`
  - `Color walletColorOf(WalletModel wallet)`
  - `String deletePaymentConfirmMessage(DebtPaymentModel payment)` (teks dialog hapus cicilan)
  - `DebtDetailScreen({required int debtId})` (sudah sejak Task 3). Aksi "Edit" di nav bar ditambahkan di Task 7.

Tabel preservasi (kode `main` sebelum Task 3 = `lib/screens/debt/debt_detail_screen.dart`):

| # | Perilaku lama (baris) | Di layout baru |
|---|---|---|
| 1 | Judul "Detail Utang"/"Detail Piutang", AppBar berwarna merah/hijau (460–470) | `AppPageScaffold(title: ..., largeTitle: false)` nav bar polos; header avatar |
| 2 | Aksi hapus ikon trash (471–476) → dialog "Hapus Catatan?" + teks lama (395–414) → `deleteDebt` → pop + "Data berhasil dihapus!" (418–423); error hanya `debugPrint` (424–426) | `AppNavAction.icon(trash, color: expense)` → `showAppConfirmDialog` teks sama → pop + toast sama; **error kini tampil** `AppNotification.error` (audit #7) |
| 3 | Header: ikon `handCoins`/`handHeart` dalam lingkaran (493–504), nama (506–513), badge "LUNAS" atau "Jatuh Tempo: dd MMM yyyy" (515–539) | Header: avatar inisial (warna utama tipis), nama, `DebtBadge` (LUNAS / Terlambat / Tempo) — ikon diganti inisial sesuai mockup |
| 4 | Kartu statistik: "Total Awal", "Sisa Tagihan" berwarna, progress tinggi 10, "x.x% Terbayar" (544–624) | `AppSurfaceCard` isi sama, `AppProgressBar(height: 10)`, format persen `toStringAsFixed(1)` tetap |
| 5 | Judul "Riwayat Cicilan" (639–645) | Header grup `AppGroupedSection(header: 'Riwayat Cicilan')` |
| 6 | Kosong: "Belum ada riwayat pembayaran." italic (650–660) | Baris italic yang sama di dalam grup |
| 7 | Baris cicilan: ikon `trendUp` hijau (utang) / `trendDown` merah (piutang) (682–693), tanggal tebal (699–705), nama dompet atau "Tanpa Dompet" (670, 706–712), nominal (716–723) | `AppListRow` isi sama; **baru**: geser kiri → Edit / Hapus |
| 8 | FAB "Bayar Cicilan"/"Terima Pembayaran" ikon `money`, hanya bila belum lunas (734–746) | `bottomBar: AppPrimaryButton` label/ikon sama, warna utama, hanya bila belum lunas |
| 9 | Sheet cicilan: judul "Bayar Cicilan Utang"/"Terima Pembayaran" (102), kotak "Sisa Tagihan Saat Ini" (125–138), "Jumlah Uang" (145), "Tanggal Pembayaran" (196) default hari ini, switch "Catat ke Dompet?" (254) + dropdown "Pilih Dompet" + info "Info: Saldo dompet akan BERKURANG karena Anda membayar utang." / "…BERTAMBAH karena Anda menerima pembayaran." (305–307), tombol "Simpan"; validasi "Silakan pilih dompet!" (333–338), sukses "Pembayaran berhasil dicatat!" (360–363), error dari exception (365–372), "Utang ini sudah lunas!" bila sisa ≤ 0 (70–73) | `showDebtPaymentSheet` — semua teks sama; **baru**: nominal kosong/0 → "Nominal harus lebih dari 0." (audit #10), picker tanggal `firstDate = tanggal pinjam`, `lastDate = hari ini` (audit #13), pemilih dompet menampilkan saldo, switch nonaktif + teks "Belum ada dompet" bila tidak ada dompet, `walletId` null bila switch mati (audit #9), tombol loading (audit #4) |
| 10 | Spinner layar penuh setiap memuat cicilan (443–448) | Spinner kecil hanya di grup Riwayat saat pertama kali memuat (audit #14) |

- [ ] **Step 1: Tulis test sheet yang gagal**

```dart
// test/screens/debt/debt_payment_sheet_test.dart
import 'dart:async';

import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  setUpAll(prewarmToastFont);

  group('validateDebtPayment', () {
    test('kosong atau 0 ditolak', () {
      expect(validateDebtPayment(amountText: '', maxAmount: 100, affectWallet: false, walletId: null),
          'Nominal harus lebih dari 0.');
      expect(validateDebtPayment(amountText: '0', maxAmount: 100, affectWallet: false, walletId: null),
          'Nominal harus lebih dari 0.');
    });
    test('melebihi sisa ditolak dengan pesan lama', () {
      expect(validateDebtPayment(amountText: '1.000.001', maxAmount: 1000000, affectWallet: false, walletId: null),
          'Jumlah bayar tidak boleh melebihi sisa utang!');
    });
    test('dompet wajib bila switch aktif', () {
      expect(validateDebtPayment(amountText: '500.000', maxAmount: 1000000, affectWallet: true, walletId: null),
          'Silakan pilih dompet!');
    });
    test('valid mengembalikan null', () {
      expect(validateDebtPayment(amountText: '500.000', maxAmount: 1000000, affectWallet: true, walletId: 3), isNull);
    });
  });

  test('pesan konfirmasi hapus cicilan sesuai tautan dompet', () {
    expect(deletePaymentConfirmMessage(samplePayment()),
        'Sisa tagihan bertambah Rp 500.000 dan saldo BCA dikembalikan.');
    expect(deletePaymentConfirmMessage(samplePayment(transactionId: null)),
        'Sisa tagihan bertambah Rp 500.000. Cicilan lama ini tidak terhubung ke transaksi dompet, jadi saldo dompet tidak berubah.');
    expect(deletePaymentConfirmMessage(samplePayment(transactionId: null, walletId: null, walletName: null)),
        'Sisa tagihan bertambah Rp 500.000.');
  });

  Widget opener(DebtModel debt) => Consumer(builder: (context, ref, _) {
        return TextButton(
          onPressed: () => showDebtPaymentSheet(context, debt: debt),
          child: const Text('buka'),
        );
      });

  testWidgets('bayar cicilan tanpa dompet mengirim walletId null dan menampilkan toast lama', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt], wallets: [sampleWallet()]));
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Bayar Cicilan Utang'), findsOneWidget);
    expect(find.text('Sisa Tagihan Saat Ini'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('addPayment:1:500000:null'));
    expect(find.text('Pembayaran berhasil dicatat!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('switch dompet aktif mengirim walletId terpilih dan menampilkan info lama', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt], wallets: [sampleWallet()]));
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.tap(find.byKey(const ValueKey('debt-affect-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('Info: Saldo dompet akan BERKURANG karena Anda membayar utang.'), findsOneWidget);

    await tester.tap(find.text('Pilih Dompet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCA').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('addPayment:1:500000:3'));
    await flushToast(tester);
  });

  testWidgets('payment sheet submit sekali: tombol disabled saat menyimpan', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt]))..gate = Completer<void>();
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls.where((c) => c.startsWith('addPayment')).length, 1);

    fake.gate!.complete();
    await tester.pumpAndSettle();
    await flushToast(tester);
  });

  testWidgets('edit cicilan memanggil updatePayment dengan nominal baru', (tester) async {
    final debt = sampleDebt();
    final payment = samplePayment();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt]));
    await pumpApp(
      tester,
      Consumer(builder: (context, ref, _) => TextButton(
            onPressed: () => showDebtPaymentSheet(context, debt: debt, payment: payment),
            child: const Text('buka'),
          )),
      overrides: debtOverrides(fake),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Cicilan'), findsOneWidget);
    expect(find.text('Perubahan nominal ikut menyesuaikan saldo BCA.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '600000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('updatePayment:1:10:600000'));
    await flushToast(tester);
  });
}
```

`Consumer` diimpor dari `package:flutter_riverpod/flutter_riverpod.dart` (tambahkan import di file test).

- [ ] **Step 2: Tulis test detail yang gagal**

```dart
// test/screens/debt/debt_detail_screen_test.dart
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_detail_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  setUpAll(prewarmToastFont);

  DebtState state({bool paid = false}) => DebtState(
        isLoading: false,
        debts: [
          sampleDebt(
            dueDate: DateTime(2026, 9, 22),
            notes: 'Modal usaha',
            remaining: paid ? 0 : 1200000,
            status: paid ? 'paid' : 'active',
          ),
        ],
        payments: {
          1: [
            samplePayment(),
            samplePayment(id: 11, amount: 300000, date: DateTime(2026, 9, 1), walletId: null, walletName: null, transactionId: null),
          ],
        },
      );

  testWidgets('header, statistik, info, dan riwayat cicilan', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    expect(find.text('BS'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Terlambat 2 hari'), findsOneWidget);
    expect(find.text('Total Awal'), findsOneWidget);
    expect(find.text('Rp 2.000.000'), findsOneWidget);
    expect(find.text('Sisa Tagihan'), findsOneWidget);
    expect(find.text('40.0% Terbayar'), findsOneWidget);
    expect(find.text('Tanggal Pinjam'), findsOneWidget);
    expect(find.text('01 Agu 2026'), findsOneWidget);
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Modal usaha'), findsOneWidget);
    expect(find.text('RIWAYAT CICILAN'), findsOneWidget);
    expect(find.text('15 Sep 2026'), findsOneWidget);
    expect(find.text('Tanpa Dompet'), findsOneWidget);
    expect(find.text('Bayar Cicilan'), findsOneWidget);
    expect(fake.calls, contains('fetchPayments:1'));
  });

  testWidgets('utang lunas menyembunyikan tombol bayar', (tester) async {
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(FakeDebtNotifier(state(paid: true))));
    await tester.pump();
    expect(find.text('LUNAS'), findsOneWidget);
    expect(find.text('Bayar Cicilan'), findsNothing);
  });

  testWidgets('geser cicilan lalu Hapus + konfirmasi memanggil deletePayment', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.drag(find.text('15 Sep 2026'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Cicilan?'), findsOneWidget);
    expect(find.text('Sisa tagihan bertambah Rp 500.000 dan saldo BCA dikembalikan.'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('deletePayment:1:10'));
    await flushToast(tester);
  });

  testWidgets('hapus utang memakai teks dialog lama dan menampilkan error bila gagal', (tester) async {
    final fake = FakeDebtNotifier(state())..error = Exception('Utang tidak ditemukan.');
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.tap(find.byTooltip('Hapus utang'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Catatan?'), findsOneWidget);
    expect(
      find.text('Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen. Saldo dompet tidak akan dikembalikan otomatis.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('deleteDebt:1'));
    expect(find.text('Utang tidak ditemukan.'), findsOneWidget);
    await flushToast(tester);
  });
}
```

Catatan: `find.byTooltip('Hapus utang')` mengandalkan `AppNavAction.icon(..., tooltip:)`. Bila B1 belum punya parameter `tooltip` di `AppNavAction.icon` (Plan B6 yang menambahkannya), tambahkan parameter opsional `String? tooltip` ke `AppNavAction.icon` di task ini beserta test kecil di `test/widgets/app_page_scaffold_test.dart` (`expect(find.byTooltip('x'), findsOneWidget)`), dan catat di laporan. Jangan membuat tombol ikon sendiri di screen.

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `flutter test test/screens/debt/debt_payment_sheet_test.dart test/screens/debt/debt_detail_screen_test.dart`
Expected: FAIL — `debt_payment_sheet.dart` tidak ada.

- [ ] **Step 4: Implementasi `lib/screens/debt/debt_wallet_picker.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Warna dompet disimpan sebagai teks "#RRGGBB" (pola sama dengan
/// stats_provider/wallet_screen). Nilai rusak jatuh ke primary.
Color walletColorOf(WalletModel wallet) {
  final hex = wallet.color;
  if (hex == null || hex.isEmpty) return AppColors.primary;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.primary;
  }
}

class DebtWalletPickerRow extends StatelessWidget {
  const DebtWalletPickerRow({
    required this.wallets,
    required this.selectedWalletId,
    required this.onSelected,
    super.key,
  });

  final List<WalletModel> wallets;
  final int? selectedWalletId;
  final ValueChanged<int> onSelected;

  WalletModel? get _selected {
    for (final w in wallets) {
      if (w.id == selectedWalletId) return w;
    }
    return null;
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppFormSheet<int>(
      context: context,
      title: 'Pilih Dompet',
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final w in wallets)
            AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: walletColorOf(w), filled: true),
              title: w.name,
              value: formatRupiah(w.balance),
              trailing: w.id == selectedWalletId
                  ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(sheetContext, w.id),
            ),
        ],
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AppListRow(
      leading: AppIconTile(
        icon: PhosphorIconsFill.wallet,
        color: selected == null ? AppColors.tintGray : walletColorOf(selected),
        filled: selected != null,
      ),
      title: selected == null ? 'Pilih Dompet' : selected.name,
      value: selected == null ? null : formatRupiah(selected.balance),
      showChevron: true,
      onTap: () => _pick(context),
    );
  }
}
```

(`AppIconTile` diekspor dari `app_list_row.dart` oleh B1; bila di file lain, tambahkan import yang sesuai.)

- [ ] **Step 5: Implementasi `lib/screens/debt/debt_payment_sheet.dart`**

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_wallet_picker.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

String _amountText(double value) => formatRupiah(value).replaceFirst('Rp ', '');

String? validateDebtPayment({
  required String amountText,
  required double maxAmount,
  required bool affectWallet,
  required int? walletId,
}) {
  final amount = parseRupiah(amountText);
  if (amount <= 0) return 'Nominal harus lebih dari 0.';
  if (amount > maxAmount) return 'Jumlah bayar tidak boleh melebihi sisa utang!';
  if (affectWallet && walletId == null) return 'Silakan pilih dompet!';
  return null;
}

String deletePaymentConfirmMessage(DebtPaymentModel payment) {
  final base = 'Sisa tagihan bertambah ${formatRupiah(payment.amount)}';
  if (payment.affectsWallet) {
    return '$base dan saldo ${payment.walletName ?? 'dompet'} dikembalikan.';
  }
  if (payment.walletId != null) {
    return '$base. Cicilan lama ini tidak terhubung ke transaksi dompet, jadi saldo dompet tidak berubah.';
  }
  return '$base.';
}

Future<void> showDebtPaymentSheet(
  BuildContext context, {
  required DebtModel debt,
  DebtPaymentModel? payment,
}) async {
  if (payment == null && debt.remainingAmount <= 0) {
    AppNotification.success(context, 'Utang ini sudah lunas!');
    return;
  }
  final title = payment != null
      ? 'Edit Cicilan'
      : (debt.isPayable ? 'Bayar Cicilan Utang' : 'Terima Pembayaran');
  await showAppFormSheet<void>(
    context: context,
    title: title,
    builder: (sheetContext) => _DebtPaymentForm(debt: debt, payment: payment),
  );
}

class _DebtPaymentForm extends ConsumerStatefulWidget {
  const _DebtPaymentForm({required this.debt, this.payment});

  final DebtModel debt;
  final DebtPaymentModel? payment;

  @override
  ConsumerState<_DebtPaymentForm> createState() => _DebtPaymentFormState();
}

class _DebtPaymentFormState extends ConsumerState<_DebtPaymentForm> {
  late final TextEditingController _amountController;
  late DateTime _date;
  bool _affectWallet = false;
  int? _walletId;
  bool _submitting = false;

  bool get _isEdit => widget.payment != null;

  double get _maxAmount => widget.debt.remainingAmount + (widget.payment?.amount ?? 0);

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _amountController = TextEditingController(text: p == null ? '' : _amountText(p.amount));
    _date = p?.date ?? DateUtils.dateOnly(ref.read(debtClockProvider)());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(ref.read(debtClockProvider)());
    final first = widget.debt.loanDate.isAfter(today) ? today : widget.debt.loanDate;
    DateTime initial = _date;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(today)) initial = today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final error = validateDebtPayment(
      amountText: _amountController.text,
      maxAmount: _maxAmount,
      affectWallet: !_isEdit && _affectWallet,
      walletId: _walletId,
    );
    if (error != null) {
      AppNotification.error(context, error);
      return;
    }
    setState(() => _submitting = true);
    final notifier = ref.read(debtProvider.notifier);
    final amount = parseRupiah(_amountController.text).toDouble();
    try {
      if (_isEdit) {
        await notifier.updatePayment(
          debtId: widget.debt.id,
          paymentId: widget.payment!.id,
          amount: amount,
          date: _date,
        );
      } else {
        await notifier.addPayment(
          debtId: widget.debt.id,
          amount: amount,
          date: _date,
          walletId: _affectWallet ? _walletId : null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, _isEdit ? 'Cicilan diperbarui!' : 'Pembayaran berhasil dicatat!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final wallets = ref.watch(debtProvider.select((s) => s.wallets));
    final mainColor = debtMainColor(debt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurfaceCard(
          child: AppAmountDisplay(
            label: 'Sisa Tagihan Saat Ini',
            amountText: formatRupiah(_maxAmount),
            color: mainColor,
          ),
        ),
        const SizedBox(height: 14),
        AppAmountField(controller: _amountController, label: 'Jumlah Uang', autofocus: !_isEdit),
        const SizedBox(height: 14),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.tintBlue),
              title: 'Tanggal Pembayaran',
              value: _dayFormat.format(_date),
              showChevron: true,
              onTap: _pickDate,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isEdit) ...[
          if (widget.payment!.affectsWallet)
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text('Perubahan nominal ikut menyesuaikan saldo ${widget.payment!.walletName ?? 'dompet'}.'),
            ),
        ] else ...[
          AppGroupedSection(
            children: [
              AppListRow(
                title: 'Catat ke Dompet?',
                subtitle: wallets.isEmpty ? 'Belum ada dompet' : null,
                trailing: AppSwitch(
                  key: const ValueKey('debt-affect-wallet'),
                  value: _affectWallet,
                  onChanged: wallets.isEmpty ? null : (v) => setState(() => _affectWallet = v),
                ),
              ),
              if (_affectWallet)
                DebtWalletPickerRow(
                  wallets: wallets,
                  selectedWalletId: _walletId,
                  onSelected: (id) => setState(() => _walletId = id),
                ),
            ],
          ),
          if (_affectWallet) ...[
            const SizedBox(height: 10),
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                debt.isPayable
                    ? 'Info: Saldo dompet akan BERKURANG karena Anda membayar utang.'
                    : 'Info: Saldo dompet akan BERTAMBAH karena Anda menerima pembayaran.',
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: 'Simpan',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
        const SizedBox(height: 4),
        Text(
          'Maksimal ${formatRupiah(_maxAmount)}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Rewrite `lib/screens/debt/debt_detail_screen.dart`**

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_payment_sheet.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(debtProvider.notifier).fetchPayments(widget.debtId));
  }

  Future<void> _deleteDebt(DebtModel debt) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Hapus Catatan?',
      message:
          'Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen. Saldo dompet tidak akan dikembalikan otomatis.',
    );
    if (!confirm || !mounted) return;
    try {
      await ref.read(debtProvider.notifier).deleteDebt(debt.id);
      if (!mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, 'Data berhasil dihapus!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePayment(DebtModel debt, DebtPaymentModel payment) async {
    try {
      await ref.read(debtProvider.notifier).deletePayment(debtId: debt.id, paymentId: payment.id);
      if (!mounted) return;
      AppNotification.success(context, 'Cicilan dihapus!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtState = ref.watch(debtProvider);
    final today = ref.watch(debtClockProvider)();
    final debt = debtState.debtById(widget.debtId);

    if (debt == null) {
      return AppPageScaffold(
        title: 'Detail Utang',
        largeTitle: false,
        backLabel: 'Utang',
        children: [
          if (debtState.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: AppEmptyState(icon: PhosphorIconsRegular.handCoins, title: 'Data utang tidak ditemukan.'),
            ),
        ],
      );
    }

    final mainColor = debtMainColor(debt);
    final accent = debt.isPaidOff ? AppColors.income : mainColor;
    final payments = debtState.payments[debt.id];
    final loadingPayments = payments == null && debtState.loadingPayments.contains(debt.id);
    final overdue = debt.isOverdue(today);

    return AppPageScaffold(
      title: debt.isPayable ? 'Detail Utang' : 'Detail Piutang',
      largeTitle: false,
      backLabel: 'Utang',
      titleWidget: _DebtHeader(debt: debt, today: today, color: mainColor),
      actions: [
        AppNavAction.icon(
          PhosphorIconsRegular.trash,
          color: AppColors.expense,
          tooltip: 'Hapus utang',
          onPressed: () => _deleteDebt(debt),
        ),
      ],
      bottomBar: debt.isPaidOff
          ? null
          : AppPrimaryButton(
              label: debt.isPayable ? 'Bayar Cicilan' : 'Terima Pembayaran',
              icon: PhosphorIconsBold.money,
              color: mainColor,
              onPressed: () => showDebtPaymentSheet(context, debt: debt),
            ),
      children: [
        AppSurfaceCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Awal', style: AppTextStyles.caption),
                        Text(formatRupiah(debt.amount), style: AppTextStyles.headline),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Sisa Tagihan', style: AppTextStyles.caption),
                      Text(
                        formatRupiah(debt.remainingAmount),
                        style: AppTextStyles.headline.copyWith(color: accent),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppProgressBar(value: debt.progress, color: accent, height: 10),
              const SizedBox(height: 8),
              Text(
                '${(debt.progress * 100).toStringAsFixed(1)}% Terbayar',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        AppGroupedSection(
          insetSeparators: false,
          children: [
            AppListRow(title: 'Tanggal Pinjam', value: _dayFormat.format(debt.loanDate)),
            AppListRow(
              title: 'Jatuh Tempo',
              trailing: Text(
                debt.dueDate == null ? '-' : _dayFormat.format(debt.dueDate!),
                style: AppTextStyles.subhead.copyWith(color: overdue ? AppColors.expense : AppColors.textSecondary),
              ),
            ),
            if (debt.notes != null) AppListRow(title: 'Catatan', value: debt.notes),
          ],
        ),
        AppGroupedSection(
          header: 'Riwayat Cicilan',
          children: [
            if (loadingPayments)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (payments == null || payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text(
                  'Belum ada riwayat pembayaran.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subhead.copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              for (final p in payments)
                AppSwipeActions(
                  key: ValueKey('payment-${p.id}'),
                  deleteConfirmTitle: 'Hapus Cicilan?',
                  deleteConfirmMessage: deletePaymentConfirmMessage(p),
                  onEdit: () => showDebtPaymentSheet(context, debt: debt, payment: p),
                  onDelete: () => _deletePayment(debt, p),
                  child: AppListRow(
                    leading: AppIconTile(
                      icon: debt.isPayable ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown,
                      color: debt.isPayable ? AppColors.income : AppColors.expense,
                      round: true,
                    ),
                    title: _dayFormat.format(p.date),
                    subtitle: p.walletName ?? 'Tanpa Dompet',
                    trailing: Text(formatRupiah(p.amount), style: AppTextStyles.amountRow),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _DebtHeader extends StatelessWidget {
  const _DebtHeader({required this.debt, required this.today, required this.color});

  final DebtModel debt;
  final DateTime today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
            child: Text(debtInitials(debt.name), style: AppTextStyles.title.copyWith(color: color)),
          ),
          const SizedBox(height: 10),
          Text(debt.name, style: AppTextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          DebtBadge(debt: debt, today: today),
        ],
      ),
    );
  }
}
```

Catatan untuk eksekutor: `withOpacity` sengaja dipakai supaya konsisten dengan konvensi codebase (lihat AGENTS.md); bila B1 memperkenalkan helper warna tipis (mis. `AppColors.tint(color, 0.14)`), pakai itu.

- [ ] **Step 7: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/debt/`
Expected: PASS semua file (termasuk `debt_screen_test.dart`).

- [ ] **Step 8: Checklist visual vs mockup "Detail Utang"**

- [ ] Nav bar: `‹ Utang` kiri, ikon sampah merah kanan (tombol "Edit" menyusul di Task 7).
- [ ] Header: lingkaran inisial "BS" berwarna tipis, nama tebal di tengah, badge merah "Terlambat N hari" / oranye "Tempo" / hijau "LUNAS".
- [ ] Kartu putih: "Total Awal" kiri, "Sisa Tagihan" kanan berwarna, progress bar tebal 10, "x.x% Terbayar" di tengah.
- [ ] Grup putih datar: Tanggal Pinjam, Jatuh Tempo (merah bila lewat), Catatan.
- [ ] Label grup "RIWAYAT CICILAN", baris dengan ikon bulat, tanggal, dompet, nominal. Geser kiri memperlihatkan tombol biru Edit + merah Hapus.
- [ ] Tombol penuh "Bayar Cicilan" menempel di bawah (tidak ada FAB), hilang bila lunas.
- [ ] Sheet cicilan: grabber, `Batal` kiri, judul tengah, kartu "Sisa Tagihan Saat Ini", nominal besar di tengah, baris Tanggal Pembayaran, grup switch "Catat ke Dompet?" + baris pilih dompet dengan saldo, callout info biru, tombol Simpan.

- [ ] **Step 9: Poppins/hex & analyze**

Run: `grep -c "GoogleFonts.poppins" lib/screens/debt/debt_detail_screen.dart lib/screens/debt/debt_payment_sheet.dart lib/screens/debt/debt_wallet_picker.dart; grep -nE "Color\(0x|Colors\.(red|green|blue|orange|grey)" lib/screens/debt/debt_detail_screen.dart lib/screens/debt/debt_payment_sheet.dart lib/screens/debt/debt_wallet_picker.dart; flutter analyze lib/screens/debt`
Expected: tiga `0`; grep warna hanya menemukan `Color(int.parse(...` di `walletColorOf` (warna dompet dari data — pengecualian §9.9); analyze tanpa error.

- [ ] **Step 10: Commit**

```bash
git add lib/screens/debt/debt_detail_screen.dart lib/screens/debt/debt_payment_sheet.dart lib/screens/debt/debt_wallet_picker.dart test/screens/debt/debt_payment_sheet_test.dart test/screens/debt/debt_detail_screen_test.dart
git commit -m "feat(debt): redesign debt detail with editable and deletable installments"
```

---

## Task 7: Sheet "Catat Utang / Piutang" (catat & edit)

**Files:**
- Create: `lib/screens/debt/debt_form_sheet.dart`
- Modify: `lib/screens/debt/debt_screen.dart` (hapus `_showAddDebtSheet`, import lama), `lib/screens/debt/debt_detail_screen.dart` (tambah aksi "Edit")
- Test: `test/screens/debt/debt_form_sheet_test.dart`

**Interfaces:**
- Consumes: `debtProvider.createDebt/updateDebt`, `DebtWalletPickerRow`, `debtMainColor`; B1: `showAppFormSheet`, `AppSegmentedControl(selectedLabelColors:)`, `AppAmountField`, `AppTextField`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppSwitch`, `AppCallout`, `AppPrimaryButton`, `parseRupiah`.
- Produces:
  - `Future<void> showDebtFormSheet(BuildContext context, {DebtType initialType = DebtType.payable, DebtModel? debt})`
  - `String? validateDebtForm({required String name, required String amountText, required bool affectWallet, required int? walletId, double minAmount = 0})`

Tabel preservasi (`debt_screen.dart` `main`, `_showAddDebtSheet` baris 35–429):

| # | Perilaku lama | Di layout baru |
|---|---|---|
| 1 | Judul "Catat Utang / Piutang" + tombol X (63–74) | Header sheet `Batal` · "Catat Utang / Piutang" (mode edit: "Edit Utang"/"Edit Piutang") |
| 2 | Toggle "Utang" (merah) / "Piutang" (hijau), default mengikuti tab aktif (39, 78–135) | `AppSegmentedControl(['Utang','Piutang'], selectedLabelColors: [expense, income])`, default `initialType`; disembunyikan di mode edit (jenis tidak bisa diubah) |
| 3 | "Nama Peminjam / Pemberi Pinjaman" + hint "Contoh: Budi, Bank, dll" / "Contoh: Andi, Teman, dll" (138–161) | Label caption + `AppTextField` hint sama |
| 4 | "Jumlah Uang" + prefix "Rp" + format ribuan (164–212) | `AppAmountField(label: 'Jumlah Uang')` (maks 15 digit — audit #16) |
| 5 | "Jatuh Tempo (Opsional)", "Pilih Tanggal Jatuh Tempo", picker 2020–2030 (215–262) | Baris "Jatuh Tempo (Opsional)" nilai "Pilih Tanggal" / tanggal; tombol ×; picker 2000..(tahun ini + 10) |
| 6 | Switch "Catat transaksi ini ke Dompet?" + dropdown "Pilih Dompet" + info BERTAMBAH/BERKURANG (265–342) | Grup switch + `DebtWalletPickerRow` (saldo terlihat) + `AppCallout` teks info sama; hanya mode catat |
| 7 | Validasi "Nama tidak boleh kosong!", "Jumlah tidak boleh kosong!", "Silakan pilih dompet!" (356–376) | `validateDebtForm` pesan sama + baru "Nominal harus lebih dari 0." dan (edit) "Jumlah total tidak boleh kurang dari yang sudah dibayar." |
| 8 | Sukses: pop + "Utang/Piutang berhasil dicatat!" (395–401); error: pesan exception (402–409) | Sama; edit: "Perubahan disimpan!" |
| 9 | — | Baru: "Tanggal Pinjam" (default hari ini, maks hari ini) dan "Catatan (Opsional)" |

- [ ] **Step 1: Tulis test yang gagal**

```dart
// test/screens/debt/debt_form_sheet_test.dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_detail_screen.dart';
import 'package:catat_uang_app/screens/debt/debt_form_sheet.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  setUpAll(prewarmToastFont);

  group('validateDebtForm', () {
    test('pesan lama dipertahankan', () {
      expect(validateDebtForm(name: '  ', amountText: '100', affectWallet: false, walletId: null),
          'Nama tidak boleh kosong!');
      expect(validateDebtForm(name: 'Budi', amountText: '', affectWallet: false, walletId: null),
          'Jumlah tidak boleh kosong!');
      expect(validateDebtForm(name: 'Budi', amountText: '100', affectWallet: true, walletId: null),
          'Silakan pilih dompet!');
    });
    test('nol ditolak dan batas minimal saat edit', () {
      expect(validateDebtForm(name: 'Budi', amountText: '0', affectWallet: false, walletId: null),
          'Nominal harus lebih dari 0.');
      expect(validateDebtForm(name: 'Budi', amountText: '700.000', affectWallet: false, walletId: null, minAmount: 800000),
          'Jumlah total tidak boleh kurang dari yang sudah dibayar.');
      expect(validateDebtForm(name: 'Budi', amountText: '800.000', affectWallet: false, walletId: null, minAmount: 800000),
          isNull);
    });
  });

  testWidgets('tombol + di daftar membuka sheet catat dan mengirim createDebt', (tester) async {
    final fake = FakeDebtNotifier(DebtState(isLoading: false, wallets: [sampleWallet()]));
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Catat Utang / Piutang'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Tanggal Pinjam'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '2000000');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Budi, Bank, dll'), 'Budi Santoso');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Modal usaha'), 'Modal usaha');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('createDebt:Budi Santoso:payable:2000000:24:null:Modal usaha:null'));
    expect(find.text('Utang/Piutang berhasil dicatat!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('tab Piutang membuat default jenis piutang dan hint lama', (tester) async {
    final fake = FakeDebtNotifier(const DebtState(isLoading: false));
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake));
    await tester.pump();
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Contoh: Andi, Teman, dll'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '150000');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Andi, Teman, dll'), 'Andi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(fake.calls.single, startsWith('createDebt:Andi:receivable:150000'));
    await flushToast(tester);
  });

  testWidgets('Edit di detail membuka sheet terisi dan mengirim updateDebt', (tester) async {
    final debt = sampleDebt(notes: 'Modal usaha');
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt], payments: const {1: []}));
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Utang'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsWidgets);
    expect(find.text('Catat transaksi ini ke Dompet?'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '2500000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('updateDebt:1:Budi Santoso:2500000:Modal usaha'));
    expect(find.text('Perubahan disimpan!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('validasi nama kosong memakai toast lama dan tidak memanggil provider', (tester) async {
    final fake = FakeDebtNotifier(const DebtState(isLoading: false));
    await pumpApp(
      tester,
      Consumer(builder: (context, ref, _) => TextButton(
            onPressed: () => showDebtFormSheet(context),
            child: const Text('buka'),
          )),
      overrides: debtOverrides(fake),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '100000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama tidak boleh kosong!'), findsOneWidget);
    expect(fake.calls, isEmpty);
    await flushToast(tester);
  });
}
```

Catatan: urutan `TextField` di sheet = nominal (`AppAmountField`) dulu, lalu nama, lalu catatan — `find.byType(TextField).at(0)` bergantung pada urutan ini. `find.byTooltip('Tambah')` bergantung pada tooltip B1 di `AppNavAction.add`.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/debt/debt_form_sheet_test.dart`
Expected: FAIL — `debt_form_sheet.dart` tidak ada.

- [ ] **Step 3: Implementasi `lib/screens/debt/debt_form_sheet.dart`**

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_wallet_picker.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

String _amountText(double value) => formatRupiah(value).replaceFirst('Rp ', '');

String? validateDebtForm({
  required String name,
  required String amountText,
  required bool affectWallet,
  required int? walletId,
  double minAmount = 0,
}) {
  if (name.trim().isEmpty) return 'Nama tidak boleh kosong!';
  if (amountText.trim().isEmpty) return 'Jumlah tidak boleh kosong!';
  final amount = parseRupiah(amountText);
  if (amount <= 0) return 'Nominal harus lebih dari 0.';
  if (amount < minAmount) return 'Jumlah total tidak boleh kurang dari yang sudah dibayar.';
  if (affectWallet && walletId == null) return 'Silakan pilih dompet!';
  return null;
}

Future<void> showDebtFormSheet(
  BuildContext context, {
  DebtType initialType = DebtType.payable,
  DebtModel? debt,
}) {
  final title = debt == null
      ? 'Catat Utang / Piutang'
      : (debt.isPayable ? 'Edit Utang' : 'Edit Piutang');
  return showAppFormSheet<void>(
    context: context,
    title: title,
    builder: (sheetContext) => _DebtForm(initialType: initialType, debt: debt),
  );
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({required this.initialType, this.debt});

  final DebtType initialType;
  final DebtModel? debt;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late DebtType _type;
  late DateTime _loanDate;
  DateTime? _dueDate;
  bool _affectWallet = false;
  int? _walletId;
  bool _submitting = false;

  bool get _isEdit => widget.debt != null;

  DateTime get _today => DateUtils.dateOnly(ref.read(debtClockProvider)());

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _type = d?.type ?? widget.initialType;
    _amountController = TextEditingController(text: d == null ? '' : _amountText(d.amount));
    _nameController = TextEditingController(text: d?.name ?? '');
    _notesController = TextEditingController(text: d?.notes ?? '');
    _loanDate = d?.loanDate ?? _today;
    _dueDate = d?.dueDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickLoanDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _loanDate.isAfter(today) ? today : _loanDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _loanDate = picked);
  }

  Future<void> _pickDueDate() async {
    final today = _today;
    final last = DateTime(today.year + 10, 12, 31);
    final initial = _dueDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(2000)) ? today : initial,
      firstDate: DateTime(2000),
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    final error = validateDebtForm(
      name: _nameController.text,
      amountText: _amountController.text,
      affectWallet: !_isEdit && _affectWallet,
      walletId: _walletId,
      minAmount: widget.debt?.paidAmount ?? 0,
    );
    if (error != null) {
      AppNotification.error(context, error);
      return;
    }
    setState(() => _submitting = true);
    final notifier = ref.read(debtProvider.notifier);
    final amount = parseRupiah(_amountController.text).toDouble();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    try {
      if (_isEdit) {
        await notifier.updateDebt(
          debtId: widget.debt!.id,
          name: _nameController.text.trim(),
          amount: amount,
          loanDate: _loanDate,
          dueDate: _dueDate,
          notes: notes,
        );
      } else {
        await notifier.createDebt(
          name: _nameController.text.trim(),
          type: _type,
          amount: amount,
          loanDate: _loanDate,
          dueDate: _dueDate,
          notes: notes,
          walletId: _affectWallet ? _walletId : null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, _isEdit ? 'Perubahan disimpan!' : 'Utang/Piutang berhasil dicatat!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(debtProvider.select((s) => s.wallets));
    final isPayable = _type == DebtType.payable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isEdit) ...[
          AppSegmentedControl(
            labels: const ['Utang', 'Piutang'],
            selectedIndex: isPayable ? 0 : 1,
            selectedLabelColors: const [AppColors.expense, AppColors.income],
            onChanged: (i) => setState(() => _type = i == 0 ? DebtType.payable : DebtType.receivable),
          ),
          const SizedBox(height: 14),
        ],
        AppAmountField(controller: _amountController, label: 'Jumlah Uang', autofocus: !_isEdit),
        const SizedBox(height: 14),
        Text('Nama Peminjam / Pemberi Pinjaman', style: AppTextStyles.caption),
        const SizedBox(height: 6),
        AppTextField(
          controller: _nameController,
          icon: PhosphorIconsRegular.user,
          hint: isPayable ? 'Contoh: Budi, Bank, dll' : 'Contoh: Andi, Teman, dll',
        ),
        const SizedBox(height: 14),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.tintBlue),
              title: 'Tanggal Pinjam',
              value: _dayFormat.format(_loanDate),
              showChevron: true,
              onTap: _pickLoanDate,
            ),
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsRegular.clock, color: AppColors.tintOrange),
              title: 'Jatuh Tempo (Opsional)',
              value: _dueDate == null ? 'Pilih Tanggal' : _dayFormat.format(_dueDate!),
              showChevron: _dueDate == null,
              trailing: _dueDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Hapus jatuh tempo',
                      icon: const Icon(PhosphorIconsRegular.xCircle, color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: _pickDueDate,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Catatan (Opsional)', style: AppTextStyles.caption),
        const SizedBox(height: 6),
        AppTextField(controller: _notesController, hint: 'Contoh: Modal usaha', maxLines: 2),
        const SizedBox(height: 14),
        if (_isEdit) ...[
          if (widget.debt!.transactionId != null)
            const AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text('Perubahan jumlah ikut menyesuaikan saldo dompet yang dipakai saat pinjaman dicatat.'),
            ),
        ] else ...[
          AppGroupedSection(
            children: [
              AppListRow(
                title: 'Catat transaksi ini ke Dompet?',
                subtitle: wallets.isEmpty ? 'Belum ada dompet' : null,
                trailing: AppSwitch(
                  key: const ValueKey('debt-form-affect-wallet'),
                  value: _affectWallet,
                  onChanged: wallets.isEmpty ? null : (v) => setState(() => _affectWallet = v),
                ),
              ),
              if (_affectWallet)
                DebtWalletPickerRow(
                  wallets: wallets,
                  selectedWalletId: _walletId,
                  onSelected: (id) => setState(() => _walletId = id),
                ),
            ],
          ),
          if (_affectWallet) ...[
            const SizedBox(height: 10),
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                isPayable
                    ? 'Info: Saldo dompet akan BERTAMBAH karena Anda menerima uang pinjaman.'
                    : 'Info: Saldo dompet akan BERKURANG karena Anda meminjamkan uang.',
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: 'Simpan',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}
```

Catatan: `AppListRow` dengan `trailing` dan `showChevron` sekaligus — bila B1 merender keduanya, `showChevron: _dueDate == null` memastikan hanya satu yang tampil.

- [ ] **Step 4: Sambungkan ke layar**

`lib/screens/debt/debt_screen.dart`: hapus seluruh `_showAddDebtSheet`, field `currencyFormat`/`inputFormat`, dan import yang tidak terpakai lagi (`app_notification`, `app_bottom_sheet`, `google_fonts`, `intl`). Tambah import `debt_form_sheet.dart`, ganti aksi nav:

```dart
      actions: [
        AppNavAction.add(
          onPressed: () => showDebtFormSheet(
            context,
            initialType: _isMyDebt ? DebtType.payable : DebtType.receivable,
          ),
        ),
      ],
```

`lib/screens/debt/debt_detail_screen.dart`: tambah import `debt_form_sheet.dart`, dan di `actions` sebelum ikon sampah:

```dart
        AppNavAction.text('Edit', onPressed: () => showDebtFormSheet(context, debt: debt)),
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/debt/`
Expected: PASS semua.

- [ ] **Step 6: Checklist visual vs mockup "Form: Catat Utang / Piutang"**

- [ ] Sheet dari bawah, grabber, `Batal` kiri (primary), judul tebal tengah.
- [ ] Segmented "Utang" (teks merah saat terpilih) / "Piutang" (teks hijau).
- [ ] Nominal besar di tengah dengan "Rp".
- [ ] Field nama putih radius 16, hint lama.
- [ ] Grup: Tanggal Pinjam (ikon biru), Jatuh Tempo (ikon oranye) dengan chevron.
- [ ] Field catatan.
- [ ] Grup switch "Catat transaksi ini ke Dompet?" (switch hijau iOS) → baris pilih dompet berisi saldo → callout info biru.
- [ ] Tombol Simpan penuh; spinner saat menyimpan.
- [ ] Mode edit: judul "Edit Utang"/"Edit Piutang", tanpa segmented dan tanpa grup dompet.

- [ ] **Step 7: Poppins/hex & analyze**

Run: `grep -c "GoogleFonts.poppins" lib/screens/debt/*.dart lib/screens/debt/widgets/*.dart; grep -nE "Colors\.(red|green|blue|orange|grey)" lib/screens/debt -r; flutter analyze lib/screens/debt`
Expected: semua `0`; grep warna kosong; analyze tanpa error.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/debt/debt_form_sheet.dart lib/screens/debt/debt_screen.dart lib/screens/debt/debt_detail_screen.dart test/screens/debt/debt_form_sheet_test.dart
git commit -m "feat(debt): add create and edit debt sheet with loan date and notes"
```

---

## Task 8: Beranda refresh setelah kembali dari Utang

**Files:**
- Modify: `lib/screens/home/home_screen.dart:616-625` (mobile, tombol "Utang") dan `:1012-1015` (web)

**Interfaces:**
- Consumes: pola yang sudah dipakai tombol lain di file ini: `await Navigator.push(...); ref.read(homeProvider.notifier).refreshData(); _bumpRefreshCounter();` (mis. baris 497–505).

Catatan: Plan B3 mengganti grid ini dengan halaman Semua Fitur; B3 wajib mempertahankan refresh ini.

- [ ] **Step 1: Ubah tombol mobile (baris 616–625)**

```dart
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.handCoins,
                          label: "Utang",
                          color: Colors.teal,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DebtScreen(),
                              ),
                            );
                            if (!mounted) return;
                            ref.read(homeProvider.notifier).refreshData();
                            _bumpRefreshCounter();
                          },
                        ),
```

- [ ] **Step 2: Ubah tombol web (baris 1012–1015)**

```dart
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.handCoins, label: "Utang", color: Colors.teal,
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const DebtScreen())); if (!mounted) return; ref.read(homeProvider.notifier).refreshData(); _bumpRefreshCounter(); },
                    ),
```

(`Colors.teal` di baris ini sudah ada sebelumnya dan akan hilang bersama grid di Plan B3 — tidak disentuh di sini.)

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/screens/home/home_screen.dart`
Expected: tidak ada error/warning baru.

- [ ] **Step 4: Verifikasi manual singkat**

Run app (`run-and-screenshot`): catat utang Rp 100.000 dengan switch dompet aktif → kembali ke Beranda → Total Saldo berubah Rp 100.000 tanpa pull-to-refresh, dan "Masuk" bulan ini **tidak** bertambah (Task 4).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "fix(home): refresh home after returning from debt screen"
```

---

## Task 9: Verifikasi akhir + checkpoint screenshot user

- [ ] **Step 1: Analyze & test penuh**

Run: `flutter analyze && flutter test`
Expected: tidak ada error/warning baru dibanding `main`; semua test PASS.

- [ ] **Step 2: Cek konvensi**

Run:

```bash
grep -rn "GoogleFonts.poppins" lib/screens/debt lib/core/transaction_tags.dart lib/services/debt_service.dart lib/models/debt_model.dart lib/models/debt_payment_model.dart
grep -rnE "Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|grey)" lib/screens/debt
grep -rn "SAVING_ID:" lib/providers lib/screens | grep -v transaction_tags
```

Expected: dua grep pertama kosong (kecuali `Color(int.parse(` warna dompet di `debt_wallet_picker.dart`). Grep ketiga hanya menyisakan situs yang **membuat** atau **membaca id** tag tabungan (`savings_provider`, `target_provider`, `input_transaction_*`, `saving_detail_screen`, `calendar_screen`, `export_screen` untuk nama sumber, `stats_screen`/`transaction_history_screen` untuk pembersihan teks) — tidak ada situs *pengecualian total* yang masih memeriksa `[SAVING_ID:` sendiri tanpa `isInternalMutation`.

- [ ] **Step 3: Skenario uang end-to-end (manual, dicatat di laporan)**

Jalankan app (web) dan lakukan, mencatat saldo dompet BCA sebelum/sesudah:
1. Catat **utang** Rp 1.000.000 ke "Tes A", switch dompet BCA aktif → BCA +1.000.000; Beranda "Masuk" bulan ini tidak berubah; Riwayat Pemasukan menampilkan baris abu "Utang/Piutang" yang tidak bisa digeser.
2. Bayar cicilan Rp 400.000 dari BCA → BCA −400.000; sisa 600.000.
3. Edit cicilan jadi Rp 500.000 → BCA −100.000 lagi; sisa 500.000.
4. Hapus cicilan → BCA +500.000; sisa 1.000.000; status aktif.
5. Bayar penuh Rp 1.000.000 → badge LUNAS, tombol bayar hilang. Hapus cicilan itu → LUNAS terbuka lagi.
6. Catat **piutang** Rp 50.000.000 dari BCA (lebih dari saldo) → ditolak "Saldo dompet tidak mencukupi untuk dipinjamkan!", saldo tidak berubah, tidak ada baris baru.
7. Tap "Simpan" dua kali cepat → hanya satu cicilan tercatat.
8. Hapus utang "Tes A" → utang & cicilan hilang, transaksi bertag hilang dari Riwayat, saldo BCA tidak dikembalikan (sesuai dialog).

- [ ] **Step 4: Checkpoint screenshot user**

Pakai skill `run-and-screenshot`. Bila tidak ada otomasi browser, koordinator meminta user mengirim screenshot:
1. Daftar Utang (tab Utang Saya dengan satu utang terlambat, satu jatuh tempo, satu lunas).
2. Daftar tab Piutang.
3. Detail Utang dengan dua cicilan, satu digeser memperlihatkan Edit/Hapus.
4. Sheet "Catat Utang / Piutang" dengan switch dompet aktif.
5. Sheet "Bayar Cicilan Utang".

Cocokkan tiap screenshot dengan checklist visual Task 5–7 dan mockup; perbaiki perbedaan di commit `fix(debt): ...` lalu ulangi Step 1.

- [ ] **Step 5: Review & laporan**

Jalankan subagent `flutter-code-reviewer` pada `git diff main...HEAD`. Laporan akhir ke koordinator: daftar commit, hasil Step 1–3 (angka saldo per langkah), konfirmasi SQL dari user (Task 1 Step 2, termasuk jumlah transaksi lama yang ditandai), perubahan komponen bersama (mis. `AppNavAction.icon(tooltip:)` bila ditambahkan di Task 6), dan catatan untuk plan berikut:
- **B3** (Beranda): widget "Utang" membaca `debtProvider` (`myDebts(today)`, `debtBadgeLabel`), dan navigasi ke `DebtScreen` dari Semua Fitur wajib mempertahankan refresh Task 8.
- **B4** (Riwayat/Statistik/Input): wajib memakai `lib/core/transaction_tags.dart` (`isInternalMutation`, `isDebtMutation`, `stripTransactionTags`) dan mempertahankan banner read-only Utang di Input.
- **B5/B6**: `budget_detail_screen.dart`, `calendar_provider.dart`, `export_screen.dart`, `ai_advisor_screen.dart` sudah memakai helper tag — jangan dikembalikan ke cek `[SAVING_ID:` manual saat redesign.

Merge ke `main` hanya setelah user menyetujui hasil visual dan mengonfirmasi SQL sudah dijalankan (`superpowers:finishing-a-development-branch`).

---

## Self-Review (dijalankan saat menulis plan)

- **Cakupan spec §7.1:** bug 1–9 → Task 1/3/4/6/7/8 (lihat tabel pemetaan); fitur baru edit utang (Task 1 `update_debt`, Task 7), edit/hapus cicilan (Task 1, Task 6), Terlambat + total + urutan (Task 2, 3, 5), tanggal pinjam & catatan (Task 1, 2, 7). Aturan G1–G4, G6, G11–G13, G16 di Task 5–7.
- **Placeholder:** tidak ada TBD/"tambahkan validasi". Satu dependensi bersyarat terdokumentasi: `AppNavAction.icon(tooltip:)` (Task 6 Step 2 catatan) dengan instruksi konkret bila belum ada.
- **Konsistensi tipe:** `DebtType.dbValue`, `DebtBadgeKind`, `debtBadgeLabel`, `debtInitials`, `sortDebts`, `DebtState.myDebts(DateTime)`, `debtClockProvider`, `DebtNotifier.updatePayment({debtId, paymentId, amount, date})`, `deletePayment({debtId, paymentId})`, `showDebtPaymentSheet(context, {debt, payment})`, `showDebtFormSheet(context, {initialType, debt})`, `DebtWalletPickerRow`, `walletColorOf` — dipakai dengan nama & parameter sama di Task 2–9 dan di `FakeDebtNotifier`.
- **Review Focus:** #1 Task 3 `isSubmitting guard` + Task 6 `payment sheet submit sekali`; #2 Task 6 `validateDebtPayment`; #3 Task 6 `pesan konfirmasi hapus cicilan` + Task 9 skenario 4–5; #4 Task 2/3/5; #5 Task 4 `transaction_tags_test` + `input read-only utang`.
