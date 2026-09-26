-- supabase/migrations/202609260002_delete_debt_refund.sql
-- Hapus utang dengan pilihan mengembalikan saldo dompet (keputusan user 2026-09-26).
-- Aman dijalankan berulang. Jalankan dari SQL Editor Supabase di LAPTOP.
--
-- delete_debt(p_debt_id, p_refund):
--   p_refund = false -> perilaku lama: utang, cicilan, dan transaksi tertaut dihapus,
--                       saldo dompet TIDAK berubah ("Hapus saja").
--   p_refund = true  -> sebelum menghapus, setiap efek dompet yang tertaut dibalik:
--                       pinjaman dan tiap cicilan dikembalikan ke dompet masing-masing
--                       ("Hapus & kembalikan saldo"). Bila dompet tidak cukup saldo untuk
--                       dibalik, SELURUH penghapusan dibatalkan dengan pesan jelas.
--   Utang/cicilan lama tanpa tautan transaksi, atau yang dompetnya sudah dihapus,
--   tidak mengubah saldo apa pun.

drop function if exists public.delete_debt(bigint);

create or replace function public.delete_debt(p_debt_id bigint, p_refund boolean default false)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_debt debts%rowtype;
  v_pay record;
  v_trx_ids bigint[];
  v_msg text := 'Saldo dompet tidak mencukupi untuk mengembalikan saldo utang ini! Pilih "Hapus saja" bila uangnya sudah terpakai.';
begin
  if v_user is null then
    raise exception 'Sesi login berakhir. Silakan masuk lagi.';
  end if;

  select * into v_debt from debts where id = p_debt_id and user_id = v_user for update;
  if not found then
    raise exception 'Utang tidak ditemukan.';
  end if;

  if p_refund then
    -- Balik pinjaman awal: utang (uang masuk) -> keluarkan lagi; piutang -> masukkan lagi.
    if v_debt.transaction_id is not null and v_debt.wallet_id is not null then
      perform debt_move_wallet(
        v_debt.wallet_id,
        case when v_debt.type = 'payable' then -v_debt.amount else v_debt.amount end,
        v_msg
      );
    end if;

    -- Balik tiap cicilan: bayar utang (uang keluar) -> masukkan lagi; terima piutang -> keluarkan.
    for v_pay in
      select amount, wallet_id from debt_payments
      where debt_id = v_debt.id and user_id = v_user
        and transaction_id is not null and wallet_id is not null
      for update
    loop
      perform debt_move_wallet(
        v_pay.wallet_id,
        case when v_debt.type = 'payable' then v_pay.amount else -v_pay.amount end,
        v_msg
      );
    end loop;
  end if;

  -- Hapus hanya transaksi yang TERTAUT ke utang ini (id pasti).
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

revoke all on function public.delete_debt(bigint, boolean) from public, anon;
grant execute on function public.delete_debt(bigint, boolean) to authenticated;

notify pgrst, 'reload schema';
