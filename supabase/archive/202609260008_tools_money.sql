-- supabase/migrations/202609260008_tools_money.sql
-- Operasi uang Investasi & Zakat/Sedekah (Plan B6 Task 6b). Aman dijalankan ulang.
-- Dulu app membaca saldo lalu menulis saldo baru (baca-lalu-tulis): dua beli /
-- top up / bayar bersamaan kehilangan satu potongan. Sekarang satu transaksi
-- database per operasi, saldo lewat wallet_add (202609260004_atomic_money.sql).

-- system_category mendapat ikon opsional (dulu selalu 'bank'); pemanggil lama
-- (3 argumen) tetap jalan lewat nilai default.
drop function if exists public.system_category(text, text, boolean);
create or replace function public.system_category(
  p_pattern text, p_name text, p_expense boolean, p_icon text default 'bank')
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_id bigint;
begin
  perform pg_advisory_xact_lock(hashtext(v_user::text || ':category:' || p_name));
  select id into v_id from categories
  where user_id = v_user and is_expense = p_expense and name ilike p_pattern
  order by id limit 1;
  if v_id is null then
    insert into categories (user_id, name, is_expense, icon_name)
    values (v_user, p_name, p_expense, p_icon) returning id into v_id;
  end if;
  return v_id;
end $$;

-- Kunci dompet milik user dan pastikan saldonya cukup.
create or replace function public.lock_wallet_with_balance(p_wallet_id bigint, p_amount numeric, p_message text)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_balance numeric;
begin
  perform lock_wallets(array[p_wallet_id]);
  select balance into v_balance from wallets where id = p_wallet_id and user_id = auth.uid();
  if not found then raise exception 'Dompet tidak ditemukan.'; end if;
  if coalesce(v_balance, 0) < p_amount then raise exception '%', p_message; end if;
end $$;

-- Beli aset baru: potong dompet, catat aset & transaksi "Beli Aset: <nama>".
create or replace function public.buy_investment(
  p_name text, p_type text, p_amount numeric, p_wallet_id bigint, p_date date)
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_id bigint;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Semua kolom wajib diisi!'; end if;
  perform lock_wallet_with_balance(p_wallet_id, p_amount, 'Saldo dompet tidak mencukupi!');
  insert into investments (user_id, name, type, capital_amount, current_value)
  values (v_user, p_name, p_type, p_amount, p_amount) returning id into v_id;
  insert into transactions (user_id, wallet_id, category_id, amount, date, note)
  values (v_user, p_wallet_id, system_category('%Investasi%', 'Investasi', true, 'chart-line-up'),
          p_amount, p_date, 'Beli Aset: ' || p_name);
  perform wallet_add(p_wallet_id, -p_amount);
  return v_id;
end $$;

-- Top up (p_is_buy) atau jual sebagian aset.
create or replace function public.buy_sell_investment(
  p_investment_id bigint, p_is_buy boolean, p_amount numeric, p_wallet_id bigint, p_date date)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_inv investments%rowtype;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  select * into v_inv from investments where id = p_investment_id and user_id = v_user for update;
  if not found then raise exception 'Aset investasi tidak ditemukan.'; end if;
  if p_is_buy then
    perform lock_wallet_with_balance(p_wallet_id, p_amount, 'Saldo dompet tidak mencukupi!');
  else
    if p_amount > coalesce(v_inv.current_value, 0) then
      raise exception 'Nominal penarikan melebihi nilai aset saat ini!';
    end if;
    perform lock_wallet_with_balance(p_wallet_id, 0, '');
  end if;

  update investments set
    capital_amount = case when p_is_buy then capital_amount + p_amount else greatest(capital_amount - p_amount, 0) end,
    current_value = case when p_is_buy then current_value + p_amount else greatest(current_value - p_amount, 0) end
  where id = v_inv.id;
  insert into transactions (user_id, wallet_id, category_id, amount, date, note)
  values (v_user, p_wallet_id,
          case when p_is_buy then system_category('%Investasi%', 'Investasi', true, 'chart-line-up')
               else system_category('%Hasil Jual Investasi%', 'Hasil Jual Investasi', false, 'chart-line-up') end,
          p_amount, p_date,
          case when p_is_buy then 'Top Up Aset: ' else 'Jual Aset: ' end || v_inv.name);
  perform wallet_add(p_wallet_id, case when p_is_buy then -p_amount else p_amount end);
end $$;

-- Bayar zakat maal / sedekah dari dompet.
create or replace function public.pay_zakat_sedekah(
  p_is_zakat boolean, p_wallet_id bigint, p_amount numeric, p_note text, p_date date)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then
    raise exception '%', case when p_is_zakat then 'Masukkan total harta yang valid!' else 'Masukkan nominal sedekah yang valid!' end;
  end if;
  perform lock_wallet_with_balance(p_wallet_id, p_amount, 'Saldo dompet tidak mencukupi!');
  insert into transactions (user_id, category_id, amount, date, note, wallet_id)
  values (v_user,
          case when p_is_zakat then system_category('%Zakat%', 'Zakat', true, 'hand-heart')
               else system_category('%Sedekah%', 'Sedekah', true, 'hand-coins') end,
          p_amount, p_date, p_note, p_wallet_id);
  perform wallet_add(p_wallet_id, -p_amount);
end $$;

revoke all on function public.system_category(text, text, boolean, text) from public, anon;
revoke all on function public.lock_wallet_with_balance(bigint, numeric, text) from public, anon;
revoke all on function public.buy_investment(text, text, numeric, bigint, date) from public, anon;
revoke all on function public.buy_sell_investment(bigint, boolean, numeric, bigint, date) from public, anon;
revoke all on function public.pay_zakat_sedekah(boolean, bigint, numeric, text, date) from public, anon;
grant execute on function public.system_category(text, text, boolean, text) to authenticated;
grant execute on function public.lock_wallet_with_balance(bigint, numeric, text) to authenticated;
grant execute on function public.buy_investment(text, text, numeric, bigint, date) to authenticated;
grant execute on function public.buy_sell_investment(bigint, boolean, numeric, bigint, date) to authenticated;
grant execute on function public.pay_zakat_sedekah(boolean, bigint, numeric, text, date) to authenticated;

notify pgrst, 'reload schema';
