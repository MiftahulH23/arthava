-- supabase/migrations/202609280003_balance_rules_review.sql
-- Perbaikan review aturan saldo (2026-09-28). Aman dijalankan ulang.
-- 1. rupiah_text membulatkan ke BAWAH (1.000,6 → "Rp 1.000"): angka "Bisa dipakai"
--    tidak pernah lebih besar dari yang sungguh bisa dipakai. `stable` (to_char).
-- 2. delete_debt(p_refund): efek uang MASUK dibalik lebih dulu, baru uang keluar,
--    sehingga yang dicek efek bersihnya (bukan pinjaman penuh lebih dulu).
-- 3. run_due_recurring: pemasukan jatuh tempo diproses sebelum pengeluaran di dompet
--    yang sama (tetap urut wallet_id supaya urutan kunci dompet tidak berubah).

create or replace function public.rupiah_text(p numeric)
returns text language sql stable set search_path = public as $$
  select 'Rp ' || replace(to_char(floor(greatest(coalesce(p, 0), 0)), 'FM999,999,999,999,990'), ',', '.');
$$;

create or replace function public.delete_debt(p_debt_id bigint, p_refund boolean default false)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_debt debts%rowtype;
  v_pay record;
  v_trx_ids bigint[];
  v_msg text := 'Saldo dompet tidak mencukupi untuk mengembalikan saldo utang ini! Pilih "Hapus saja" bila uangnya sudah terpakai.';
  v_loan_live boolean;
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;

  select * into v_debt from debts where id = p_debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;

  if p_refund then
    v_loan_live := v_debt.transaction_id is not null and v_debt.wallet_id is not null;

    -- Piutang: pinjaman awal kembali MASUK ke dompet → balik dulu.
    if v_loan_live and v_debt.type <> 'payable' then
      perform debt_move_wallet(v_debt.wallet_id, v_debt.amount, v_msg);
    end if;

    -- Cicilan: bayar utang (keluar) → masuk lagi; terima piutang (masuk) → keluar lagi.
    -- Untuk utang ini semua uang MASUK, jadi dijalankan sebelum pinjaman dikeluarkan.
    for v_pay in
      select amount, wallet_id from debt_payments
      where debt_id = v_debt.id and user_id = v_user
        and transaction_id is not null and wallet_id is not null
      order by id
      for update
    loop
      perform debt_move_wallet(
        v_pay.wallet_id,
        case when v_debt.type = 'payable' then v_pay.amount else -v_pay.amount end,
        v_msg
      );
    end loop;

    -- Utang: pinjaman awal (dulu masuk) dikeluarkan lagi — paling akhir.
    if v_loan_live and v_debt.type = 'payable' then
      perform debt_move_wallet(v_debt.wallet_id, -v_debt.amount, v_msg);
    end if;
  end if;

  select array_agg(t.id) into v_trx_ids
  from (
    select v_debt.transaction_id as id where v_debt.transaction_id is not null
    union all
    select transaction_id from debt_payments
    where debt_id = v_debt.id and user_id = v_user and transaction_id is not null
  ) t;

  delete from debts where id = v_debt.id;  -- debt_payments ikut via on delete cascade
  if v_trx_ids is not null then
    delete from transactions where user_id = v_user and id = any (v_trx_ids);
  end if;
end $$;

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
    select rt.* from recurring_transactions rt
    where rt.user_id = v_user and rt.is_active = true and rt.next_run_date <= v_today
    order by rt.wallet_id nulls last,
             coalesce((select c.is_expense from categories c where c.id = rt.category_id), true), -- pemasukan dulu
             rt.id
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
          exit;
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
