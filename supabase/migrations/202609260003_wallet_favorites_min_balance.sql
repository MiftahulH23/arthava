-- supabase/migrations/202609260003_wallet_favorites_min_balance.sql (dijalankan lewat Management API)
-- Plan B3: dompet favorit, saldo minimal per dompet, pengaturan "Hitung saldo minimal
-- di total saldo", dan perbaikan keamanan policy profiles.
-- Idempotent: aman dijalankan ulang.

alter table public.wallets
  add column if not exists is_favorite boolean not null default false;

alter table public.wallets
  add column if not exists min_balance numeric not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'wallets_min_balance_nonnegative'
  ) then
    alter table public.wallets
      add constraint wallets_min_balance_nonnegative check (min_balance >= 0);
  end if;
end $$;

alter table public.profiles
  add column if not exists include_min_balance boolean not null default true;

-- Keamanan: policy ini membuat SEMUA user login bisa membaca profil (nama) user lain.
-- Policy "User bisa lihat profil sendiri" (auth.uid() = id) tetap ada dan cukup.
drop policy if exists "Public profiles are viewable by everyone" on public.profiles;
