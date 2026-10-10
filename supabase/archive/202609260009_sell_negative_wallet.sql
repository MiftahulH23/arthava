-- supabase/migrations/202609260009_sell_negative_wallet.sql
-- Perbaikan review B6. Aman dijalankan ulang.
-- lock_wallet_with_balance dipanggil dengan p_amount 0 saat JUAL aset (uang
-- masuk ke dompet); cek "saldo < 0" menolak dompet bersaldo minus dengan pesan
-- kosong. Saldo minus sah (wallet_add), jadi cek saldo hanya bila ada uang keluar.
create or replace function public.lock_wallet_with_balance(p_wallet_id bigint, p_amount numeric, p_message text)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_balance numeric;
begin
  perform lock_wallets(array[p_wallet_id]);
  select balance into v_balance from wallets where id = p_wallet_id and user_id = auth.uid();
  if not found then raise exception 'Dompet tidak ditemukan.'; end if;
  if p_amount > 0 and coalesce(v_balance, 0) < p_amount then raise exception '%', p_message; end if;
end $$;

notify pgrst, 'reload schema';
