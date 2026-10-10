-- supabase/migrations/202609260001_debt_fixes.sql
-- Perbaikan kecil dari review akhir Plan B2 (dijalankan setelah 202609240001).
-- Aman dijalankan berulang. Jalankan dari SQL Editor Supabase di LAPTOP.
--
-- M1: delete_debt menghapus transaksi berdasarkan tautan id, bukan LIKE teks catatan.
-- M3: update_debt / update_debt_payment hanya memvalidasi tanggal bila tanggalnya diubah.
-- M4: tanggal pinjam hasil backfill (dihitung UTC) dikoreksi ke tanggal WIB.

-- =========================================================================
-- M1
-- =========================================================================
create or replace function public.delete_debt(p_debt_id bigint)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_trx_ids bigint[];
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;
  if not exists (select 1 from debts where id = p_debt_id and user_id = v_user) then
    raise exception 'Utang tidak ditemukan.';
  end if;

  -- Hapus hanya transaksi yang TERTAUT ke utang ini (id pasti), bukan pencarian
  -- teks catatan: nama utang ketikan user bisa mengandung "[DEBT_ID:x]".
  select array_agg(t.id) into v_trx_ids
  from (
    select transaction_id as id from debts
    where id = p_debt_id and user_id = v_user and transaction_id is not null
    union all
    select transaction_id from debt_payments
    where debt_id = p_debt_id and user_id = v_user and transaction_id is not null
  ) t;

  -- debt_payments ikut terhapus lewat FK on delete cascade. Saldo dompet
  -- tidak dikembalikan (sesuai teks dialog).
  delete from debts where id = p_debt_id and user_id = v_user;
  if v_trx_ids is not null then
    delete from transactions where user_id = v_user and id = any (v_trx_ids);
  end if;
end $$;

-- =========================================================================
-- M3
-- =========================================================================
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
  select * into v_debt from debts where id = p_debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;

  v_paid := v_debt.amount - v_debt.remaining_amount;
  if p_amount < v_paid then
    raise exception 'Jumlah total tidak boleh kurang dari yang sudah dibayar.';
  end if;
  -- Cek tanggal hanya bila tanggal pinjam memang diubah, supaya data lama
  -- (cicilan sebelum loan_date hasil backfill) tetap bisa diganti nama/jumlah.
  if p_loan_date <> v_debt.loan_date then
    if p_loan_date > current_date + 1 then
      raise exception 'Tanggal pinjam tidak boleh di masa depan.';
    end if;
    if exists (select 1 from debt_payments where debt_id = v_debt.id and date < p_loan_date) then
      raise exception 'Tanggal pinjam tidak boleh setelah tanggal cicilan pertama.';
    end if;
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
  -- Cek tanggal hanya bila tanggal cicilan diubah (cicilan lama bisa bertanggal
  -- di masa depan / sebelum loan_date dan tetap harus bisa diubah nominalnya).
  if p_date <> v_pay.date then
    if p_date < v_debt.loan_date then
      raise exception 'Tanggal bayar tidak boleh sebelum tanggal pinjam.';
    end if;
    if p_date > current_date + 1 then
      raise exception 'Tanggal bayar tidak boleh di masa depan.';
    end if;
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

-- =========================================================================
-- M4: hanya utang lama (dibuat sebelum migrasi pertama, tanpa transaksi
-- tertaut) yang loan_date-nya masih sama dengan tanggal UTC created_at.
-- =========================================================================
update public.debts d
set loan_date = (d.created_at at time zone 'Asia/Jakarta')::date
where d.transaction_id is null
  and d.created_at is not null
  and d.created_at < timestamptz '2026-09-26 00:00:00+07'
  and d.loan_date = (d.created_at at time zone 'UTC')::date
  and (d.created_at at time zone 'Asia/Jakarta')::date <> (d.created_at at time zone 'UTC')::date
  and not exists (
    select 1 from public.debt_payments p
    where p.debt_id = d.id and p.date < (d.created_at at time zone 'Asia/Jakarta')::date
  );

notify pgrst, 'reload schema';
