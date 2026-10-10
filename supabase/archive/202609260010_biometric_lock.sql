-- supabase/migrations/202609260010_biometric_lock.sql
-- Plan B7 Task 5b: kunci biometrik opsional saat aplikasi dibuka (default mati).
-- Aman dijalankan ulang.
alter table public.profiles
  add column if not exists use_biometric_lock boolean not null default false;
