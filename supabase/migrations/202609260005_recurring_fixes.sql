-- supabase/migrations/202609260005_recurring_fixes.sql
-- Perbaikan review B4b untuk run_due_recurring. Aman dijalankan ulang.
--
-- 1. Tanggal "hari ini" = tanggal perangkat (p_today, perilaku lama: DateTime.now()
--    di HP), dibatasi paling jauh satu hari di depan tanggal server; tanpa p_today
--    dipakai tanggal WIB. Sebelumnya current_date (UTC): tagihan hari ini baru
--    jalan setelah 07:00 WIB.
-- 2. Bulanan/Tahunan berjangkar ke tanggal start_date: 31 Jan -> 28/29 Feb -> 31 Mar
--    (sebelumnya berhenti permanen di tanggal 28 setelah melewati Februari).
-- 3. Jadwal diproses urut wallet_id supaya urutan kunci dompet sama dengan
--    lock_wallets (tidak deadlock dengan transfer yang bersamaan).

-- Tanggal ke-p_anchor pada bulan (p_date + p_months), dijepit ke hari terakhir bulan itu.
create or replace function public.recurring_step_month(p_date date, p_anchor integer, p_months integer)
returns date language plpgsql immutable set search_path = public as $$
declare
  v_first date := (date_trunc('month', p_date) + make_interval(months => p_months))::date;
  v_last integer := extract(day from (v_first + interval '1 month' - interval '1 day'))::integer;
begin
  return v_first + (least(p_anchor, v_last) - 1);
end $$;

drop function if exists public.run_due_recurring();

create or replace function public.run_due_recurring(p_today date default null)
returns integer language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_today date := least(coalesce(p_today, (now() at time zone 'Asia/Jakarta')::date), current_date + 1);
  r record;
  v_next date;
  v_count integer;
  v_total integer := 0;
  v_anchor integer;
  v_expense boolean;
begin
  if v_user is null then return 0; end if;
  for r in
    select * from recurring_transactions
    where user_id = v_user and is_active = true and next_run_date <= v_today
    order by wallet_id nulls last, id
    for update skip locked
  loop
    continue when r.frequency not in ('Harian', 'Mingguan', 'Bulanan', 'Tahunan'); -- dulu berputar tanpa henti

    v_anchor := extract(day from r.start_date)::integer;
    v_next := r.next_run_date;
    v_count := 0;
    while v_next <= v_today and v_count < 400 loop
      insert into transactions (user_id, category_id, wallet_id, amount, date, note)
      values (v_user, r.category_id, r.wallet_id, r.amount, v_next,
              trim(coalesce(r.note, '') || ' (Otomatis: ' || r.frequency || ')'));
      v_count := v_count + 1;
      v_next := case r.frequency
        when 'Harian' then v_next + 1
        when 'Mingguan' then v_next + 7
        when 'Bulanan' then recurring_step_month(v_next, v_anchor, 1)
        else recurring_step_month(v_next, v_anchor, 12)
      end;
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

revoke all on function public.recurring_step_month(date, integer, integer) from public, anon;
revoke all on function public.run_due_recurring(date) from public, anon;
grant execute on function public.recurring_step_month(date, integer, integer) to authenticated;
grant execute on function public.run_due_recurring(date) to authenticated;

notify pgrst, 'reload schema';
