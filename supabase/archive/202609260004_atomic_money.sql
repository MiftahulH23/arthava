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
