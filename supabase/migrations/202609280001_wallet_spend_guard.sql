-- supabase/migrations/202609280001_wallet_spend_guard.sql
-- Aturan saldo dompet (spec 2026-09-28-wallet-balance-rules-design.md). Aman dijalankan ulang.
-- Uang keluar ditolak bila melewati "bisa dipakai" = saldo − saldo minimal.
-- Satu pesan untuk semua fitur: "Saldo dompet <nama> tidak cukup! Bisa dipakai: Rp <jumlah>".

create or replace function public.rupiah_text(p numeric)
returns text language sql immutable set search_path = public as $$
  select 'Rp ' || replace(to_char(round(greatest(coalesce(p, 0), 0)), 'FM999,999,999,999,990'), ',', '.');
$$;

-- Kunci dompet milik user, lalu tolak uang keluar p_amount yang melewati batas.
-- p_amount <= 0 hanya mengunci & memastikan dompet ada.
create or replace function public.wallet_spend_guard(p_wallet_id bigint, p_amount numeric, p_suffix text default '')
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_w wallets%rowtype;
  v_available numeric;
begin
  perform lock_wallets(array[p_wallet_id]);
  select * into v_w from wallets where id = p_wallet_id and user_id = auth.uid();
  if not found then raise exception 'Dompet tidak ditemukan.'; end if;
  if coalesce(p_amount, 0) <= 0 then return; end if;
  v_available := coalesce(v_w.balance, 0) - coalesce(v_w.min_balance, 0);
  if p_amount > v_available then
    raise exception '%', format('Saldo dompet %s tidak cukup! Bisa dipakai: %s%s',
      v_w.name, rupiah_text(v_available), coalesce(p_suffix, ''));
  end if;
end $$;

-- Dipakai buy_investment, buy_sell_investment, pay_zakat_sedekah (0008/0009).
create or replace function public.lock_wallet_with_balance(p_wallet_id bigint, p_amount numeric, p_message text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform wallet_spend_guard(p_wallet_id, p_amount);
end $$;

-- Dipakai semua RPC utang (0001/0002). Pesan "Hapus saja" dipertahankan sebagai akhiran.
create or replace function public.debt_move_wallet(p_wallet_id bigint, p_delta numeric, p_insufficient_msg text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform wallet_spend_guard(p_wallet_id, greatest(-p_delta, 0),
    case when p_insufficient_msg like '%Hapus saja%'
         then ' Pilih "Hapus saja" bila uangnya sudah terpakai.' else '' end);
  update wallets set balance = coalesce(balance, 0) + p_delta where id = p_wallet_id;
end $$;

create or replace function public.save_transaction(
  p_id bigint, p_category_id bigint, p_wallet_id bigint, p_amount numeric, p_date date, p_note text)
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_expense boolean;
  v_old transactions%rowtype;
  v_old_expense boolean;
  v_old_live boolean;
  v_old_delta numeric := 0; -- efek membalik transaksi lama pada dompet lama
  v_new_delta numeric := 0; -- efek transaksi baru pada dompet baru
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
  if p_wallet_id is not null then
    v_new_delta := case when v_expense then -p_amount else p_amount end;
  end if;

  if p_id is null then
    if p_wallet_id is not null then perform wallet_spend_guard(p_wallet_id, -v_new_delta); end if;
    insert into transactions (user_id, category_id, amount, date, note, wallet_id)
    values (v_user, p_category_id, p_amount, p_date, p_note, p_wallet_id)
    returning id into v_id;
    if p_wallet_id is not null then perform wallet_add(p_wallet_id, v_new_delta); end if;
    return v_id;
  end if;

  select * into v_old from transactions where id = p_id and user_id = v_user for update;
  if not found then raise exception 'Transaksi tidak ditemukan.'; end if;
  if v_old.note like '%[DEBT_ID:%' then
    raise exception 'Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.';
  end if;
  select coalesce(is_expense, true) into v_old_expense from categories where id = v_old.category_id;
  perform lock_wallets(array[v_old.wallet_id, p_wallet_id]);
  v_old_live := v_old.wallet_id is not null
    and exists (select 1 from wallets where id = v_old.wallet_id and user_id = v_user);
  if v_old_live then
    v_old_delta := case when coalesce(v_old_expense, true) then v_old.amount else -v_old.amount end;
  end if;

  -- Cek efek bersih per dompet sebelum mengubah apa pun.
  if v_old_live and v_old.wallet_id = p_wallet_id then
    perform wallet_spend_guard(p_wallet_id, -(v_old_delta + v_new_delta));
  else
    if v_old_live then perform wallet_spend_guard(v_old.wallet_id, -v_old_delta); end if;
    if p_wallet_id is not null then perform wallet_spend_guard(p_wallet_id, -v_new_delta); end if;
  end if;

  if v_old_live then perform wallet_add(v_old.wallet_id, v_old_delta); end if;
  update transactions
  set category_id = p_category_id, amount = p_amount, date = p_date, note = p_note, wallet_id = p_wallet_id
  where id = p_id;
  if p_wallet_id is not null then perform wallet_add(p_wallet_id, v_new_delta); end if;
  return p_id;
end $$;

create or replace function public.delete_transaction(p_id bigint)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_old transactions%rowtype;
  v_expense boolean;
  v_delta numeric;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  select * into v_old from transactions where id = p_id and user_id = v_user for update;
  if not found then return; end if;
  if v_old.note like '%[DEBT_ID:%' then
    raise exception 'Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.';
  end if;
  select coalesce(is_expense, true) into v_expense from categories where id = v_old.category_id;
  if v_old.wallet_id is not null and exists (select 1 from wallets where id = v_old.wallet_id and user_id = v_user) then
    v_delta := case when coalesce(v_expense, true) then v_old.amount else -v_old.amount end;
    perform wallet_spend_guard(v_old.wallet_id, -v_delta); -- hapus pemasukan = uang keluar
    perform wallet_add(v_old.wallet_id, v_delta);
  end if;
  delete from transactions where id = p_id;
end $$;

create or replace function public.transfer_between_wallets(p_from bigint, p_to bigint, p_amount numeric)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  if p_from = p_to then raise exception 'Dompet asal dan tujuan tidak boleh sama!'; end if;
  perform lock_wallets(array[p_from, p_to]);
  if not exists (select 1 from wallets where id = p_to and user_id = v_user) then
    raise exception 'Dompet tidak ditemukan.';
  end if;
  perform wallet_spend_guard(p_from, p_amount);
  perform wallet_add(p_from, -p_amount);
  perform wallet_add(p_to, p_amount);
end $$;

create or replace function public.deposit_to_target(
  p_target_id bigint, p_wallet_id bigint, p_amount numeric, p_date date)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_target targets%rowtype;
  v_link text;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  select * into v_target from targets where id = p_target_id and user_id = v_user for update;
  if not found then raise exception 'Target tidak ditemukan.'; end if;
  v_link := nullif(trim(coalesce(v_target.storage_location, '')), '');
  if v_link is not null then perform lock_saving(v_link); end if;
  perform wallet_spend_guard(p_wallet_id, p_amount);

  perform wallet_add(p_wallet_id, -p_amount);
  insert into transactions (user_id, category_id, wallet_id, amount, date, note)
  values (v_user, system_category('%Tabung%', 'Tabungan Target', true), p_wallet_id, p_amount, p_date,
          'Nabung Target: ' || v_target.name || ' [SAVING_ID:T-' || v_target.id || ']');
  if v_link is not null and exists (
       select 1 from savings where user_id = v_user and lower(trim(name)) = lower(v_link)) then
    insert into savings (user_id, name, amount, location, notes)
    values (v_user, v_link, p_amount, null, 'Dari Target: ' || v_target.name);
  else
    update targets set saved_amount = coalesce(saved_amount, 0) + p_amount where id = v_target.id;
  end if;
end $$;

create or replace function public.saving_transaction(
  p_is_deposit boolean, p_saving_name text, p_amount numeric, p_wallet_id bigint,
  p_location text, p_notes text, p_date date)
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_balance numeric;
  v_loc text := p_location;
  v_notes text := p_notes;
  v_id bigint;
  v_marker text;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  perform lock_saving(p_saving_name);
  perform wallet_spend_guard(p_wallet_id, case when p_is_deposit then p_amount else 0 end);
  if not p_is_deposit then
    v_balance := saving_balance(p_saving_name);
    if p_amount > v_balance then raise exception 'SAVING_INSUFFICIENT:%', v_balance; end if;
  end if;
  if v_loc is null and v_notes is null then
    select location, notes into v_loc, v_notes from savings
    where user_id = v_user and lower(trim(name)) = lower(trim(p_saving_name))
    order by created_at, id limit 1;
  end if;
  insert into savings (user_id, name, amount, location, notes)
  values (v_user, p_saving_name, case when p_is_deposit then p_amount else -p_amount end, v_loc, v_notes)
  returning id into v_id;
  v_marker := '[SAVING_ID:' || v_id || ']';
  insert into transactions (user_id, category_id, wallet_id, amount, date, note)
  values (v_user,
          case when p_is_deposit then system_category('%Tabungan%', 'Tabungan', true)
               else system_category('%Pencairan Tabungan%', 'Pencairan Tabungan', false) end,
          p_wallet_id, p_amount, p_date,
          case when p_is_deposit then 'Nabung ke ' || p_saving_name || ' ' || v_marker
               else 'Pencairan ' || p_saving_name || ' ' || v_marker end);
  perform wallet_add(p_wallet_id, case when p_is_deposit then -p_amount else p_amount end);
  return v_id;
end $$;

create or replace function public.edit_saving_item(
  p_saving_id bigint, p_amount numeric, p_is_deposit boolean, p_location text, p_notes text)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_saving savings%rowtype;
  v_marker text := '[SAVING_ID:' || p_saving_id || ']';
  v_trx transactions%rowtype;
  v_delta numeric;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;
  perform lock_saving(v_saving.name);
  select * into v_saving from savings where id = p_saving_id and user_id = v_user for update;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;

  select * into v_trx from transactions
  where user_id = v_user and note like '%' || v_marker || '%' and wallet_id is not null
  order by id limit 1 for update;
  if found and exists (select 1 from wallets where id = v_trx.wallet_id and user_id = v_user) then
    v_delta := (case when v_saving.amount > 0 then v_trx.amount else -v_trx.amount end)
             + (case when p_is_deposit then -p_amount else p_amount end);
    perform wallet_spend_guard(v_trx.wallet_id, -v_delta);
    perform wallet_add(v_trx.wallet_id, v_delta);
  end if;

  update savings
  set amount = case when p_is_deposit then p_amount else -p_amount end, location = p_location, notes = p_notes
  where id = p_saving_id;
  update transactions set amount = p_amount where user_id = v_user and note like '%' || v_marker || '%';
end $$;

create or replace function public.delete_saving_item(p_saving_id bigint)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_saving savings%rowtype;
  v_marker text := '[SAVING_ID:' || p_saving_id || ']';
  v_trx transactions%rowtype;
  v_delta numeric;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then return; end if;
  perform lock_saving(v_saving.name);
  select * into v_saving from savings where id = p_saving_id and user_id = v_user for update;
  if not found then return; end if;

  select * into v_trx from transactions
  where user_id = v_user and note like '%' || v_marker || '%' and wallet_id is not null
  order by id limit 1 for update;
  if found and exists (select 1 from wallets where id = v_trx.wallet_id and user_id = v_user) then
    v_delta := case when v_saving.amount > 0 then v_trx.amount else -v_trx.amount end;
    perform wallet_spend_guard(v_trx.wallet_id, -v_delta); -- hapus tarikan = uang keluar lagi
    perform wallet_add(v_trx.wallet_id, v_delta);
  end if;

  delete from transactions where user_id = v_user and note like '%' || v_marker || '%';
  delete from savings where id = p_saving_id;
end $$;

revoke all on function public.rupiah_text(numeric) from public, anon;
revoke all on function public.wallet_spend_guard(bigint, numeric, text) from public, anon;
grant execute on function public.rupiah_text(numeric) to authenticated;
grant execute on function public.wallet_spend_guard(bigint, numeric, text) to authenticated;

notify pgrst, 'reload schema';
