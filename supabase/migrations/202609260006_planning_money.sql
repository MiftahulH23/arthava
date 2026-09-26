-- supabase/migrations/202609260006_planning_money.sql
-- Operasi uang Target & Buku Tabungan (Plan B5 Task 7b). Aman dijalankan ulang.
-- Dulu app membaca saldo lalu menulis saldo baru (baca-lalu-tulis): dua setoran
-- bersamaan kehilangan satu potongan, dan tarik tabungan tidak dicek saldonya.
-- Sekarang satu transaksi database per operasi, saldo dompet lewat wallet_add
-- (202609260004_atomic_money.sql), tabungan dikunci per (user, nama).

-- Kategori sistem milik user (mis. "Tabungan"); dibuat bila belum ada. Kunci
-- advisory supaya dua operasi bersamaan tidak membuat kategori kembar.
-- Bentuk 4 argumen (ikon opsional) sama dengan 202609260008, supaya file ini
-- tetap aman dijalankan ulang tanpa membuat overload 3 argumen yang ambigu.
drop function if exists public.system_category(text, text, boolean);
create or replace function public.system_category(p_pattern text, p_name text, p_expense boolean, p_icon text default 'bank')
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

-- Kunci satu kelompok tabungan (nama sama dengan spend_from_saving).
create or replace function public.lock_saving(p_name text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(auth.uid()::text || ':' || p_name));
end $$;

-- Nabung ke target: potong dompet, catat transaksi [SAVING_ID:T-id], lalu tambah
-- Buku Tabungan yang tertaut (storage_location) atau saved_amount target.
create or replace function public.deposit_to_target(
  p_target_id bigint, p_wallet_id bigint, p_amount numeric, p_date date)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_target targets%rowtype;
  v_wallet wallets%rowtype;
  v_link text;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  select * into v_target from targets where id = p_target_id and user_id = v_user for update;
  if not found then raise exception 'Target tidak ditemukan.'; end if;
  -- Urutan kunci sama dengan saving_transaction (tabungan dulu, lalu dompet): tidak deadlock.
  v_link := nullif(trim(coalesce(v_target.storage_location, '')), '');
  if v_link is not null then perform lock_saving(v_link); end if;
  perform lock_wallets(array[p_wallet_id]);
  select * into v_wallet from wallets where id = p_wallet_id and user_id = v_user;
  if not found then raise exception 'Dompet tidak ditemukan.'; end if;
  if coalesce(v_wallet.balance, 0) < p_amount then
    raise exception 'Saldo dompet % tidak cukup!', v_wallet.name;
  end if;

  perform wallet_add(p_wallet_id, -p_amount);
  insert into transactions (user_id, category_id, wallet_id, amount, date, note)
  values (v_user, system_category('%Tabung%', 'Tabungan Target', true), p_wallet_id, p_amount, p_date,
          'Nabung Target: ' || v_target.name || ' [SAVING_ID:T-' || v_target.id || ']');

  if v_link is not null and exists (select 1 from savings where user_id = v_user and trim(name) = v_link) then
    insert into savings (user_id, name, amount, location, notes)
    values (v_user, v_link, p_amount, null, 'Dari Target: ' || v_target.name);
  else
    update targets set saved_amount = coalesce(saved_amount, 0) + p_amount where id = v_target.id;
  end if;
end $$;

-- Setor ke / tarik dari satu kelompok tabungan lewat dompet. Mengembalikan id
-- baris tabungan baru. Tarik melebihi saldo tabungan: SAVING_INSUFFICIENT:<saldo>.
create or replace function public.saving_transaction(
  p_is_deposit boolean, p_saving_name text, p_amount numeric, p_wallet_id bigint,
  p_location text, p_notes text, p_date date)
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_wallet wallets%rowtype;
  v_balance numeric;
  v_loc text := p_location;
  v_notes text := p_notes;
  v_id bigint;
  v_marker text;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  perform lock_saving(p_saving_name);
  perform lock_wallets(array[p_wallet_id]);
  select * into v_wallet from wallets where id = p_wallet_id and user_id = v_user;
  if not found then raise exception 'Dompet tidak ditemukan.'; end if;

  if p_is_deposit then
    if coalesce(v_wallet.balance, 0) < p_amount then raise exception 'Saldo dompet tidak cukup!'; end if;
  else
    select coalesce(sum(amount), 0) into v_balance from savings where user_id = v_user and name = p_saving_name;
    if p_amount > v_balance then raise exception 'SAVING_INSUFFICIENT:%', v_balance; end if;
  end if;

  -- Tanpa lokasi & catatan: warisi dari baris tertua kelompok ini (perilaku lama).
  if v_loc is null and v_notes is null then
    select location, notes into v_loc, v_notes from savings
    where user_id = v_user and name = p_saving_name
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

-- Ubah satu baris riwayat setor/tarik: balik efek lama di dompet, terapkan yang
-- baru, perbarui baris tabungan dan semua transaksi bertanda [SAVING_ID:id].
create or replace function public.edit_saving_item(
  p_saving_id bigint, p_amount numeric, p_is_deposit boolean, p_location text, p_notes text)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_saving savings%rowtype;
  v_marker text := '[SAVING_ID:' || p_saving_id || ']';
  v_trx transactions%rowtype;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;
  perform lock_saving(v_saving.name);
  select * into v_saving from savings where id = p_saving_id for update;

  select * into v_trx from transactions
  where user_id = v_user and note like '%' || v_marker || '%' and wallet_id is not null
  order by id limit 1 for update;
  if found and exists (select 1 from wallets where id = v_trx.wallet_id and user_id = v_user) then
    perform lock_wallets(array[v_trx.wallet_id]);
    perform wallet_add(v_trx.wallet_id,
      (case when v_saving.amount > 0 then v_trx.amount else -v_trx.amount end)
      + (case when p_is_deposit then -p_amount else p_amount end));
  end if;

  update savings
  set amount = case when p_is_deposit then p_amount else -p_amount end, location = p_location, notes = p_notes
  where id = p_saving_id;
  update transactions set amount = p_amount where user_id = v_user and note like '%' || v_marker || '%';
end $$;

-- Hapus satu baris riwayat setor/tarik dan kembalikan saldo dompetnya. Baris yang
-- sudah terhapus (tap ganda) tidak mengubah saldo lagi.
create or replace function public.delete_saving_item(p_saving_id bigint)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_saving savings%rowtype;
  v_marker text := '[SAVING_ID:' || p_saving_id || ']';
  v_trx transactions%rowtype;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then return; end if;
  perform lock_saving(v_saving.name);
  select * into v_saving from savings where id = p_saving_id for update;
  if not found then return; end if;

  select * into v_trx from transactions
  where user_id = v_user and note like '%' || v_marker || '%' and wallet_id is not null
  order by id limit 1 for update;
  if found and exists (select 1 from wallets where id = v_trx.wallet_id and user_id = v_user) then
    perform lock_wallets(array[v_trx.wallet_id]);
    perform wallet_add(v_trx.wallet_id, case when v_saving.amount > 0 then v_trx.amount else -v_trx.amount end);
  end if;

  delete from transactions where user_id = v_user and note like '%' || v_marker || '%';
  delete from savings where id = p_saving_id;
end $$;

revoke all on function public.system_category(text, text, boolean, text) from public, anon;
revoke all on function public.lock_saving(text) from public, anon;
revoke all on function public.deposit_to_target(bigint, bigint, numeric, date) from public, anon;
revoke all on function public.saving_transaction(boolean, text, numeric, bigint, text, text, date) from public, anon;
revoke all on function public.edit_saving_item(bigint, numeric, boolean, text, text) from public, anon;
revoke all on function public.delete_saving_item(bigint) from public, anon;
grant execute on function public.system_category(text, text, boolean, text) to authenticated;
grant execute on function public.lock_saving(text) to authenticated;
grant execute on function public.deposit_to_target(bigint, bigint, numeric, date) to authenticated;
grant execute on function public.saving_transaction(boolean, text, numeric, bigint, text, text, date) to authenticated;
grant execute on function public.edit_saving_item(bigint, numeric, boolean, text, text) to authenticated;
grant execute on function public.delete_saving_item(bigint) to authenticated;

notify pgrst, 'reload schema';
