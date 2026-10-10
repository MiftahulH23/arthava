-- supabase/migrations/202609260007_saving_name_normalize.sql
-- Perbaikan review B5. Aman dijalankan ulang.
-- App mengelompokkan tabungan tanpa peka huruf besar/spasi ("Liburan" dan
-- "liburan " satu kelompok), jadi saldo, pewarisan lokasi, dan kunci tabungan
-- di database memakai lower(trim(name)) juga. spend_from_saving ikut memakai
-- kunci & kategori sistem yang sama (tidak ada kategori "Pencairan" kembar).

create or replace function public.lock_saving(p_name text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext(auth.uid()::text || ':' || lower(trim(p_name))));
end $$;

create or replace function public.saving_balance(p_name text)
returns numeric language sql stable security invoker set search_path = public as $$
  select coalesce(sum(amount), 0) from savings
  where user_id = auth.uid() and lower(trim(name)) = lower(trim(p_name));
$$;

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
    v_balance := saving_balance(p_saving_name);
    if p_amount > v_balance then raise exception 'SAVING_INSUFFICIENT:%', v_balance; end if;
  end if;

  -- Tanpa lokasi & catatan: warisi dari baris tertua kelompok ini (perilaku lama).
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
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;
  perform lock_saving(v_saving.name);
  -- Baca ulang di bawah kunci: baris bisa terhapus di antara dua perintah.
  select * into v_saving from savings where id = p_saving_id and user_id = v_user for update;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;

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

-- Sama dengan versi 202609260004, kecuali kunci/saldo per nama ternormalisasi
-- dan kategori "Pencairan Tabungan" lewat system_category.
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
  perform lock_saving(p_saving_name);
  v_balance := saving_balance(p_saving_name);
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
  v_income_cat := system_category('%Cair%', 'Pencairan Tabungan', false);
  insert into transactions (user_id, category_id, amount, date, note)
  values (v_user, v_income_cat, p_amount, p_date, 'Pencairan otomatis ' || v_marker);
  insert into transactions (user_id, category_id, amount, date, note)
  values (v_user, p_category_id, p_amount, p_date, case when v_note is null then v_marker else v_note || ' ' || v_marker end);
end $$;

revoke all on function public.saving_balance(text) from public, anon;
grant execute on function public.saving_balance(text) to authenticated;

notify pgrst, 'reload schema';
