-- supabase/migrations/202609280002_recurring_blocked.sql
-- Tagihan rutin tertahan saat saldo dompet kurang (spec 2026-09-28 §4). Aman dijalankan ulang.
alter table public.recurring_transactions add column if not exists blocked_reason text;

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
  v_live boolean;
  v_w wallets%rowtype;
  v_blocked text;
begin
  if v_user is null then return 0; end if;
  for r in
    select * from recurring_transactions
    where user_id = v_user and is_active = true and next_run_date <= v_today
    order by wallet_id nulls last, id
    for update skip locked
  loop
    continue when r.frequency not in ('Harian', 'Mingguan', 'Bulanan', 'Tahunan');
    select coalesce(is_expense, true) into v_expense from categories where id = r.category_id;
    v_expense := coalesce(v_expense, true);
    v_live := r.wallet_id is not null and exists (select 1 from wallets where id = r.wallet_id and user_id = v_user);
    if v_live then perform lock_wallets(array[r.wallet_id]); end if;

    v_anchor := extract(day from r.start_date)::integer;
    v_next := r.next_run_date;
    v_count := 0;
    v_blocked := null;
    while v_next <= v_today and v_count < 400 loop
      if v_live and v_expense then
        select * into v_w from wallets where id = r.wallet_id;
        if r.amount > coalesce(v_w.balance, 0) - coalesce(v_w.min_balance, 0) then
          v_blocked := format('Saldo dompet %s tidak cukup! Bisa dipakai: %s',
            v_w.name, rupiah_text(coalesce(v_w.balance, 0) - coalesce(v_w.min_balance, 0)));
          exit; -- periode ini dan sesudahnya tertahan
        end if;
      end if;
      insert into transactions (user_id, category_id, wallet_id, amount, date, note)
      values (v_user, r.category_id, r.wallet_id, r.amount, v_next,
              trim(coalesce(r.note, '') || ' (Otomatis: ' || r.frequency || ')'));
      if v_live then perform wallet_add(r.wallet_id, case when v_expense then -r.amount else r.amount end); end if;
      v_count := v_count + 1;
      v_next := case r.frequency
        when 'Harian' then v_next + 1
        when 'Mingguan' then v_next + 7
        when 'Bulanan' then recurring_step_month(v_next, v_anchor, 1)
        else recurring_step_month(v_next, v_anchor, 12)
      end;
    end loop;

    update recurring_transactions set next_run_date = v_next, blocked_reason = v_blocked where id = r.id;
    v_total := v_total + v_count;
  end loop;
  return v_total;
end $$;

notify pgrst, 'reload schema';
