# Phase B4b — Operasi uang atomik (transaksi, transfer, tagihan rutin, pakai tabungan) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Semua perubahan saldo dompet/tabungan dari Tambah/Edit/Hapus Transaksi, Transfer, dan Tagihan Rutin otomatis terjadi **atomik di database**, sehingga tidak ada saldo yang "hilang" saat dua operasi berjalan hampir bersamaan, tagihan rutin tidak pernah tercatat dua kali, dan tombol Simpan tidak bisa mengirim dua kali. Dibuktikan dengan E2E ke Supabase sungguhan (aturan user 2026-09-26: setiap plan membuktikan backend-nya jalan).

**Latar belakang (temuan E2E 2026-09-26, sebelum plan ini):**
- Probe dua `saveTransaction` bersamaan di dompet yang sama: saldo hanya berkurang sekali, **5 dari 5 ronde salah** (pola baca-saldo → hitung → tulis di app).
- Pola yang sama di `deleteTransaction`, `WalletNotifier.transfer` (bahkan memakai saldo dari cache app), dan `HomeNotifier.checkRecurringTransactions`.
- `checkRecurringTransactions` yang berjalan dua kali bersamaan (Beranda refresh dua kali, atau dua HP) bisa mencatat tagihan yang sama dua kali karena `next_run_date` baru diperbarui di akhir.
- "Pakai tabungan" (Tambah Transaksi → Sumber Dana Tabungan) mengecek sisa tabungan hanya di app.
- Tombol "Simpan Transaksi" bisa terpicu dua kali sebelum layar sempat menonaktifkannya → transaksi ganda.

**Architecture:** Satu migration berisi 5 RPC Postgres (`security invoker`, cek `auth.uid()`, RLS tetap berlaku) mengikuti pola RPC Utang B2: `save_transaction`, `delete_transaction`, `transfer_between_wallets`, `spend_from_saving`, `run_due_recurring`, plus helper `wallet_add` (tambah saldo dengan satu `UPDATE … SET balance = balance + delta`, jadi tidak ada lost update). Provider Dart tetap memegang validasi & pesan lama, lalu memanggil RPC. UI tidak berubah kecuali penjaga tap ganda.

**Tech Stack:** Supabase Postgres (plpgsql), supabase_flutter `rpc`, flutter_riverpod, E2E `test/e2e/` (provider asli ke Supabase, akun tes).

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` §7 (logika), §9 (aturan engineering). Skema: `docs/database/schema.md`. Pola RPC: `supabase/migrations/202609240001_debt_rpc.sql`.

## Global Constraints

1. Migration ditulis ke `supabase/migrations/202609260004_atomic_money.sql`, di-commit dulu, lalu dijalankan koordinator lewat Management API (`.superpowers/sdd/tools/supa_sql.sh FILE`, izin user 2026-09-26). Aman dijalankan ulang (`create or replace`).
2. **Perilaku yang dipertahankan persis:** semua pesan yang tampil ke user (toast/validasi), transaksi biasa boleh membuat saldo dompet minus (perilaku lama; saldo minimal hanya peringatan), Transfer menolak bila saldo sumber kurang, transaksi `[DEBT_ID:` tidak bisa diedit/dihapus dari Riwayat.
3. Jangan `dart format` seluruh file; `mounted` dicek setelah `await`; tidak ada hex/Poppins baru.
4. Commit Conventional Commits + dua baris atribusi.
5. Selesai = `flutter analyze` tanpa error/warning baru, `flutter test` hijau, **dan kedua E2E lulus** (`test/e2e/wallet_transaction_e2e_test.dart`, `tool/e2e/debt_rpc_e2e.dart`).
6. Branch `redesign/phase-b4b-atomic-money` dari branch B4 (`redesign/phase-b4-transactions`); B4 dan B4b di-merge ke `main` setelah user menyetujui.

## Keputusan (ruling koordinator, disetujui bersama plan ini)

- **Arah uang saat edit/hapus** diambil dari kategori transaksi lama di database, bukan dari tab layar (`initialIsExpense`). Lebih benar; sama hasilnya pada kasus normal.
- **Dompet transaksi lama sudah dihapus** saat edit/hapus: efek lama dilewati (dulu `.single()` melempar dan edit gagal "Gagal: …").
- **Tagihan rutin "Bulanan"** maju dengan `interval '1 month'` Postgres (31 Jan → 28/29 Feb). Kode lama `DateTime(y, m+1, d)` meluap (31 Jan → 3 Mar, Februari terlewat) — itu bug.
- **Frekuensi tak dikenal** di tagihan rutin: dilewati (kode lama berputar tanpa henti). Batas 400 eksekusi per tagihan per panggilan sebagai pengaman.
- **Dompet tagihan rutin sudah dihapus:** transaksi tetap dicatat tanpa efek saldo (dulu seluruh eksekusi berhenti karena error).

## Review Focus

1. Dua simpan/hapus/transfer bersamaan pada dompet yang sama → saldo akhir benar (E2E C1–C3).
2. `run_due_recurring` dipanggil dua kali bersamaan → setiap jadwal dieksekusi tepat sekali (E2E C4).
3. Dua "pakai tabungan" bersamaan melebihi sisa tabungan → tepat satu berhasil (E2E C5).
4. RLS/kepemilikan: RPC menolak dompet/kategori/transaksi milik user lain (E2E C7 memakai id yang tidak dimiliki).
5. Pesan error server tampil persis seperti pesan lama di app.

---

## Peta file

| File | Aksi | Tanggung jawab |
|---|---|---|
| `supabase/migrations/202609260004_atomic_money.sql` | Create | 5 RPC + helper `wallet_add` + grant |
| `docs/database/schema.md` | Modify | Daftar RPC baru di "Catatan penting" |
| `test/e2e/wallet_transaction_e2e_test.dart` | Modify | Skenario konkuren C1–C7 (merah dulu) |
| `lib/providers/input_transaction_provider.dart` | Modify | `saveTransaction` → `save_transaction` / `spend_from_saving` |
| `lib/providers/transaction_history_provider.dart` | Modify | `deleteTransaction` → `delete_transaction` |
| `lib/providers/wallet_provider.dart` | Modify | `transfer` → `transfer_between_wallets` |
| `lib/providers/home_provider.dart` | Modify | `checkRecurringTransactions` → `run_due_recurring` |
| `lib/screens/input_transaction/input_transaction_screen.dart` | Modify | Penjaga tap ganda `_submitting` |
| `test/screens/input_transaction/input_transaction_min_balance_test.dart` | Modify | Test tap ganda |
| `AGENTS.md`, spec §10, plan B5–B7 | Modify | Aturan "setiap plan membuktikan backend lewat E2E" + task E2E di tiap plan |

---

### Task 1: E2E konkuren (merah dulu)

**Files:** Modify `test/e2e/wallet_transaction_e2e_test.dart` — tambah test kedua `'operasi uang bersamaan (B4b)'` dengan setup/cleanup sendiri (dompet "E2E C…", tabungan "E2E Tab", jadwal rutin "E2E Rutin").

Skenario (masing-masing `check(...)` seperti file ini):

- **C1** Dompet 1.000.000; 5 ronde `Future.wait([save(10.000), save(10.000)])` pengeluaran → setiap ronde saldo turun tepat 20.000; jumlah baris transaksi = 10.
- **C2** Dompet X 150.000, Y 0; `Future.wait` dua `transfer(X→Y, 100.000)` → tepat satu berhasil, satu gagal dengan pesan `Saldo di E2E CX tidak cukup!`; X 50.000, Y 100.000.
- **C3** Satu pengeluaran 30.000 lalu `Future.wait` dua `deleteTransaction` baris yang sama → saldo naik tepat 30.000 sekali.
- **C4** Jadwal rutin Harian 25.000 di dompet Z (`next_run_date` = hari ini − 2, aktif) → `Future.wait` dua `checkRecurringTransactions()` → tepat 3 transaksi bertanda "(Otomatis: Harian)", saldo Z turun 75.000, `next_run_date` = besok.
- **C5** Tabungan "E2E Tab" 100.000 (baris `savings` amount 100000) → `Future.wait` dua "pakai tabungan" 70.000 → tepat satu sukses ("Berhasil! Uang dipotong dari tabungan."), satu gagal dengan pesan diawali "Saldo tabungan tidak cukup!"; sum `savings` = 30.000.
- **C6** Edit transaksi yang dompetnya sudah dihapus → sukses, dompet baru terpotong.
- **C7** `db.rpc('save_transaction', …)` dengan `p_wallet_id` = id dompet yang tidak ada/bukan milik user → ditolak `Dompet tidak ditemukan.`, tidak ada baris transaksi baru.

- [ ] **Step 1:** Tulis skenario di atas. Run: `E2E_EMAIL=… E2E_PASSWORD=… flutter test test/e2e/wallet_transaction_e2e_test.dart`
  Expected: FAIL — C1, C2 (dua-duanya berhasil karena saldo dari cache), C3, C4, C5 gagal; C7 gagal (RPC belum ada). Catat hasil di ledger.
- [ ] **Step 2:** Commit `test(e2e): add concurrent money operation scenarios`.

### Task 2: Migration RPC

**Files:** Create `supabase/migrations/202609260004_atomic_money.sql`; Modify `docs/database/schema.md`.

- [ ] **Step 1: Tulis migration**

```sql
-- supabase/migrations/202609260004_atomic_money.sql
-- Operasi uang atomik (Plan B4b). Aman dijalankan ulang.

-- Tambah saldo dengan satu UPDATE (tanpa baca-lalu-tulis di app). Boleh minus:
-- transaksi biasa memang boleh membuat saldo minus (saldo minimal hanya peringatan).
create or replace function public.wallet_add(p_wallet_id bigint, p_delta numeric)
returns void language plpgsql security invoker set search_path = public as $$
begin
  update wallets set balance = coalesce(balance, 0) + p_delta
  where id = p_wallet_id and user_id = auth.uid();
  if not found then
    raise exception 'Dompet tidak ditemukan.';
  end if;
end $$;

-- Kunci baris dompet dalam urutan id supaya dua operasi bersilangan tidak deadlock.
create or replace function public.lock_wallets(p_ids bigint[])
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform 1 from wallets
  where id = any (p_ids) and user_id = auth.uid()
  order by id
  for update;
end $$;

create or replace function public.save_transaction(
  p_id bigint,          -- null = transaksi baru
  p_category_id bigint,
  p_wallet_id bigint,   -- null = tanpa dompet
  p_amount numeric,
  p_date date,
  p_note text
)
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_expense boolean;
  v_old transactions%rowtype;
  v_old_expense boolean;
  v_id bigint;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Jumlah dan Kategori wajib diisi!'; end if;

  select coalesce(is_expense, true) into v_expense
  from categories where id = p_category_id and (user_id is null or user_id = v_user);
  if not found then raise exception 'Kategori tidak ditemukan.'; end if;

  if p_wallet_id is not null and not exists (select 1 from wallets where id = p_wallet_id and user_id = v_user) then
    raise exception 'Dompet tidak ditemukan.';
  end if;

  if p_id is null then
    perform lock_wallets(array[p_wallet_id]);
    insert into transactions (user_id, category_id, amount, date, note, wallet_id)
    values (v_user, p_category_id, p_amount, p_date, p_note, p_wallet_id)
    returning id into v_id;
    if p_wallet_id is not null then
      perform wallet_add(p_wallet_id, case when v_expense then -p_amount else p_amount end);
    end if;
    return v_id;
  end if;

  select * into v_old from transactions where id = p_id and user_id = v_user for update;
  if not found then raise exception 'Transaksi tidak ditemukan.'; end if;
  if v_old.note like '%[DEBT_ID:%' then
    raise exception 'Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.';
  end if;
  select coalesce(is_expense, true) into v_old_expense from categories where id = v_old.category_id;

  perform lock_wallets(array[v_old.wallet_id, p_wallet_id]);
  -- Balik efek lama; dompet lama yang sudah dihapus dilewati.
  if v_old.wallet_id is not null and exists (select 1 from wallets where id = v_old.wallet_id and user_id = v_user) then
    perform wallet_add(v_old.wallet_id, case when coalesce(v_old_expense, true) then v_old.amount else -v_old.amount end);
  end if;
  update transactions
  set category_id = p_category_id, amount = p_amount, date = p_date, note = p_note, wallet_id = p_wallet_id
  where id = p_id;
  if p_wallet_id is not null then
    perform wallet_add(p_wallet_id, case when v_expense then -p_amount else p_amount end);
  end if;
  return p_id;
end $$;

create or replace function public.delete_transaction(p_id bigint)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_old transactions%rowtype;
  v_expense boolean;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  select * into v_old from transactions where id = p_id and user_id = v_user for update;
  if not found then return; end if; -- sudah dihapus (mis. tap ganda): tidak mengubah saldo lagi
  if v_old.note like '%[DEBT_ID:%' then
    raise exception 'Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.';
  end if;
  select coalesce(is_expense, true) into v_expense from categories where id = v_old.category_id;
  if v_old.wallet_id is not null and exists (select 1 from wallets where id = v_old.wallet_id and user_id = v_user) then
    perform wallet_add(v_old.wallet_id, case when coalesce(v_expense, true) then v_old.amount else -v_old.amount end);
  end if;
  delete from transactions where id = p_id;
end $$;

create or replace function public.transfer_between_wallets(p_from bigint, p_to bigint, p_amount numeric)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_from wallets%rowtype;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  if p_from = p_to then raise exception 'Dompet asal dan tujuan tidak boleh sama!'; end if;
  perform lock_wallets(array[p_from, p_to]);
  select * into v_from from wallets where id = p_from and user_id = v_user;
  if not found or not exists (select 1 from wallets where id = p_to and user_id = v_user) then
    raise exception 'Dompet tidak ditemukan.';
  end if;
  if coalesce(v_from.balance, 0) < p_amount then
    raise exception 'Saldo di % tidak cukup!', v_from.name;
  end if;
  perform wallet_add(p_from, -p_amount);
  perform wallet_add(p_to, p_amount);
end $$;

-- "Pakai tabungan" dari Tambah Transaksi: kurangi tabungan + dua transaksi bertanda
-- [SAVING_ID:x] (pencairan & pengeluaran), semua atau tidak sama sekali.
create or replace function public.spend_from_saving(
  p_saving_name text, p_category_id bigint, p_amount numeric, p_date date, p_note text)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_balance numeric;
  v_saving_id bigint;
  v_income_cat bigint;
  v_marker text;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Jumlah dan Kategori wajib diisi!'; end if;
  -- Satu kunci per (user, nama tabungan): dua pemakaian bersamaan diproses berurutan.
  perform pg_advisory_xact_lock(hashtext(v_user::text || ':' || p_saving_name));
  select coalesce(sum(amount), 0) into v_balance from savings where user_id = v_user and name = p_saving_name;
  if p_amount > v_balance then
    raise exception 'SAVING_INSUFFICIENT:%', v_balance;
  end if;
  if not exists (select 1 from categories where id = p_category_id and (user_id is null or user_id = v_user)) then
    raise exception 'Kategori tidak ditemukan.';
  end if;

  insert into savings (user_id, name, amount, notes)
  values (v_user, p_saving_name, -p_amount, coalesce(v_note, 'Dipakai untuk pengeluaran'))
  returning id into v_saving_id;
  v_marker := '[SAVING_ID:' || v_saving_id || ']';

  select id into v_income_cat from categories
  where user_id = v_user and is_expense = false and name ilike '%Cair%' limit 1;
  if v_income_cat is null then
    insert into categories (user_id, name, is_expense, icon_name)
    values (v_user, 'Pencairan Tabungan', false, 'bank') returning id into v_income_cat;
  end if;

  insert into transactions (user_id, category_id, amount, date, note)
  values (v_user, v_income_cat, p_amount, p_date, 'Pencairan otomatis ' || v_marker);
  insert into transactions (user_id, category_id, amount, date, note)
  values (v_user, p_category_id, p_amount, p_date, case when v_note is null then v_marker else v_note || ' ' || v_marker end);
end $$;

-- Jalankan tagihan/pemasukan rutin yang jatuh tempo, tepat sekali per jadwal.
-- FOR UPDATE SKIP LOCKED: panggilan kedua yang bersamaan melewati jadwal yang sedang diproses.
create or replace function public.run_due_recurring()
returns integer language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  r record;
  v_next date;
  v_count integer;
  v_total integer := 0;
  v_step interval;
  v_expense boolean;
begin
  if v_user is null then return 0; end if;
  for r in
    select * from recurring_transactions
    where user_id = v_user and is_active = true and next_run_date <= current_date
    for update skip locked
  loop
    v_step := case r.frequency
      when 'Harian' then interval '1 day'
      when 'Mingguan' then interval '7 days'
      when 'Bulanan' then interval '1 month'
      when 'Tahunan' then interval '1 year'
    end;
    continue when v_step is null; -- frekuensi tak dikenal: lewati (dulu berputar tanpa henti)

    v_next := r.next_run_date;
    v_count := 0;
    while v_next <= current_date and v_count < 400 loop
      insert into transactions (user_id, category_id, wallet_id, amount, date, note)
      values (v_user, r.category_id, r.wallet_id, r.amount, v_next,
              trim(coalesce(r.note, '') || ' (Otomatis: ' || r.frequency || ')'));
      v_count := v_count + 1;
      v_next := (v_next + v_step)::date;
    end loop;

    if v_count > 0 and r.wallet_id is not null
       and exists (select 1 from wallets where id = r.wallet_id and user_id = v_user) then
      select coalesce(is_expense, true) into v_expense from categories where id = r.category_id;
      perform wallet_add(r.wallet_id,
        case when coalesce(v_expense, true) then -(r.amount * v_count) else r.amount * v_count end);
    end if;

    update recurring_transactions set next_run_date = v_next where id = r.id;
    v_total := v_total + v_count;
  end loop;
  return v_total;
end $$;

revoke all on function public.wallet_add(bigint, numeric) from public, anon;
revoke all on function public.lock_wallets(bigint[]) from public, anon;
revoke all on function public.save_transaction(bigint, bigint, bigint, numeric, date, text) from public, anon;
revoke all on function public.delete_transaction(bigint) from public, anon;
revoke all on function public.transfer_between_wallets(bigint, bigint, numeric) from public, anon;
revoke all on function public.spend_from_saving(text, bigint, numeric, date, text) from public, anon;
revoke all on function public.run_due_recurring() from public, anon;
grant execute on function public.wallet_add(bigint, numeric) to authenticated;
grant execute on function public.lock_wallets(bigint[]) to authenticated;
grant execute on function public.save_transaction(bigint, bigint, bigint, numeric, date, text) to authenticated;
grant execute on function public.delete_transaction(bigint) to authenticated;
grant execute on function public.transfer_between_wallets(bigint, bigint, numeric) to authenticated;
grant execute on function public.spend_from_saving(text, bigint, numeric, date, text) to authenticated;
grant execute on function public.run_due_recurring() to authenticated;

notify pgrst, 'reload schema';
```

- [ ] **Step 2:** Commit file, lalu jalankan: `.superpowers/sdd/tools/supa_sql.sh supabase/migrations/202609260004_atomic_money.sql`. Expected: HTTP 201.
- [ ] **Step 3:** Verifikasi: `supa_sql.sh -q "select proname from pg_proc where proname in ('wallet_add','lock_wallets','save_transaction','delete_transaction','transfer_between_wallets','spend_from_saving','run_due_recurring') order by 1"` → 7 baris.
- [ ] **Step 4:** Tambah daftar RPC ke `docs/database/schema.md` ("Catatan penting"). Commit `feat(db): add atomic money operation RPCs`.

### Task 3: Provider memakai RPC

**Files:** 4 provider di peta file.

- [ ] **Step 1: `InputTransactionNotifier.saveTransaction`** — validasi & pesan lama di awal tidak diubah. Jalur tabungan: ganti insert `savings` + dua insert `transactions` + `_getOrCreateWithdrawCategory` dengan `rpc('spend_from_saving', {p_saving_name, p_category_id, p_amount, p_date, p_note: noteText})`; `PostgrestException` dengan pesan diawali `SAVING_INSUFFICIENT:` → `"Saldo tabungan tidak cukup! Sisa: ${Rp sisa}"` (format lama `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)`), lainnya → "Gagal memproses data.". Hapus `_getOrCreateWithdrawCategory` (pindah ke SQL). Jalur dompet: `finalNote` sama seperti sekarang, lalu `rpc('save_transaction', {p_id: transactionToEdit?.id, p_category_id, p_wallet_id: selectedWalletId, p_amount: amount, p_date: yyyy-MM-dd, p_note: finalNote})`. Pesan sukses lama ("Transaksi berhasil & Saldo dompet terupdate!" / "Transaksi berhasil diperbarui!"); error → `"Gagal: ${pesan server}"`. `isSaving` true/false tetap di `try/finally`.
- [ ] **Step 2: `TransactionHistoryNotifier.deleteTransaction`** — cek `isDebtMutation` di awal tetap; sisanya `rpc('delete_transaction', {p_id: trx.id})`; pesan sukses/gagal lama; `fetchWallets(); fetchTransactions();` tetap.
- [ ] **Step 3: `WalletNotifier.transfer`** — `validateTransfer` di awal tetap (umpan balik instan), lalu `rpc('transfer_between_wallets', {p_from, p_to, p_amount})`; `PostgrestException` → `throw Exception(e.message)` (pesan server sama dengan `validateTransfer`), lainnya → `Exception('Gagal memproses transfer.')`; `fetchWallets()` di akhir.
- [ ] **Step 4: `HomeNotifier.checkRecurringTransactions`** — seluruh isi diganti `await _supabase.rpc('run_due_recurring');` dalam `try/catch` + `debugPrint` yang sama.
- [ ] **Step 5:** `flutter analyze lib/providers` bersih; `flutter test` hijau (UI tidak berubah).
- [ ] **Step 6:** Jalankan kedua E2E. Expected: `wallet_transaction_e2e_test.dart` SEMUA LULUS (termasuk C1–C7), `debt_rpc_e2e.dart` 25/25. Commit `fix(transactions): route money writes through atomic RPCs`.

### Task 4: Penjaga tap ganda di Tambah Transaksi

- [ ] **Step 1 (merah):** di `input_transaction_min_balance_test.dart`, test `'tap Simpan dua kali cepat hanya menyimpan sekali'`: fake `saveTransaction` menunggu `Completer`; dua `tester.tap` tanpa pump di antaranya; lepas completer; `expect(fake.saveCalls, 1)`.
- [ ] **Step 2:** `bool _submitting = false;` di state; `_saveTransaction` diawali `if (_submitting) return; _submitting = true;` dan diakhiri `finally { _submitting = false; }` (mencakup dialog saldo minimal). Pola sama dengan `debt_form_sheet.dart`.
- [ ] **Step 3:** test hijau; commit `fix(transactions): ignore double taps on save`.

### Task 5: Aturan E2E di proses

- [ ] **Step 1:** `AGENTS.md` bagian Commands/Known Context: tambah "E2E backend: `E2E_EMAIL=… E2E_PASSWORD=… flutter test test/e2e/` dan `dart run tool/e2e/debt_rpc_e2e.dart`; setiap plan wajib lulus E2E fitur yang disentuhnya sebelum merge."
- [ ] **Step 2:** Spec §10 (verifikasi per screen): tambah butir yang sama.
- [ ] **Step 3:** Plan B5, B6, B7: tambah task E2E sebelum task verifikasi akhir, berisi daftar operasi backend plan itu yang dibuktikan ke Supabase (B5: anggaran, target + nabung, tabungan setor/tarik/edit/hapus dan efek dompetnya, tagihan rutin tambah/edit/hapus + `run_due_recurring`; B6: investasi beli/jual dan efek dompet, zakat/sedekah, kategori tambah/edit/hapus termasuk "sedang digunakan", export membaca data yang benar; B7: login/daftar/keluar, edit profil, pengaturan kunci biometrik tersimpan). Operasi uang yang masih baca-lalu-tulis di plan itu ditandai untuk dipindah ke RPC atomik dengan pola `wallet_add`.
- [ ] **Step 4:** Commit `docs(plans): require backend E2E in every plan`.

### Task 6: Verifikasi & checkpoint

- [ ] Full `flutter analyze`, `flutter test`, kedua E2E (laporkan jumlah PASS), cek sisa data E2E = 0 (`supa_sql.sh -q "select count(*) from wallets where name like 'E2E%'"`).
- [ ] Review akhir seluruh branch (reviewer terpisah), perbaiki semua temuan termasuk minor.
- [ ] Laporkan ke user; merge B4 + B4b ke `main` hanya setelah user setuju.
