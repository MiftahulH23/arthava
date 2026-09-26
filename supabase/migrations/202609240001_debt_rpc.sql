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
