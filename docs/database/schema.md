# Skema Database Supabase (snapshot)

Diekspor user dari SQL Editor pada 2026-09-24 (schema `public`). Sumber resmi untuk plan dan agent; anon key tidak bisa membaca skema. Minta ekspor ulang bila ragu kolom sudah berubah.

## `budgets`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | TIDAK |  |
| `category_id` | bigint | TIDAK |  |
| `amount` | numeric | TIDAK | `0` |
| `month` | integer | TIDAK |  |
| `year` | integer | TIDAK |  |
| `created_at` | timestamp with time zone | TIDAK | `timezone('utc'::text, now())` |

## `categories`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | ya |  |
| `name` | text | TIDAK |  |
| `is_expense` | boolean | ya | `true` |
| `icon_name` | text | ya | `'question'::text` |
| `created_at` | timestamp with time zone | ya | `now()` |

## `debt_payments`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `debt_id` | bigint | ya |  |
| `user_id` | uuid | TIDAK |  |
| `wallet_id` | bigint | ya |  |
| `amount` | numeric | TIDAK |  |
| `date` | date | TIDAK |  |
| `created_at` | timestamp with time zone | ya | `now()` |

## `debt_payments` (tambahan B2)

`transaction_id bigint null → transactions(id) on delete set null`; FK `wallet_id → wallets` kini ON DELETE SET NULL.

## `debts`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | TIDAK |  |
| `name` | character varying | TIDAK |  |
| `type` | character varying | TIDAK |  |
| `amount` | numeric | TIDAK |  |
| `remaining_amount` | numeric | TIDAK |  |
| `due_date` | date | ya |  |
| `status` | character varying | ya | `'active'::character varying` |
| `created_at` | timestamp with time zone | ya | `now()` |
| `loan_date` | date | TIDAK | `CURRENT_DATE` |
| `notes` | text | ya |  |
| `wallet_id` | bigint | ya |  |
| `transaction_id` | bigint | ya |  |

## `investments`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | ya |  |
| `name` | text | TIDAK |  |
| `type` | text | TIDAK |  |
| `capital_amount` | double precision | TIDAK | `0` |
| `current_value` | double precision | TIDAK | `0` |
| `created_at` | timestamp with time zone | ya | `timezone('utc'::text, now())` |

## `profiles`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | uuid | TIDAK |  |
| `name` | text | ya |  |
| `created_at` | timestamp with time zone | ya | `now()` |
| `updated_at` | timestamp with time zone | ya |  |
| `include_min_balance` | boolean | TIDAK | `true` |
| `use_biometric_lock` | boolean | TIDAK | `false` |

## `recurring_transactions`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | ya |  |
| `category_id` | bigint | ya |  |
| `amount` | numeric | TIDAK |  |
| `note` | text | ya |  |
| `frequency` | text | TIDAK | `'Bulanan'::text` |
| `start_date` | date | TIDAK |  |
| `next_run_date` | date | TIDAK |  |
| `is_active` | boolean | ya | `true` |
| `created_at` | timestamp with time zone | ya | `now()` |
| `wallet_id` | bigint | ya |  |
| `blocked_reason` | text | ya |  |

## `savings`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | TIDAK |  |
| `name` | text | TIDAK |  |
| `amount` | numeric | TIDAK | `0` |
| `location` | text | ya |  |
| `notes` | text | ya |  |
| `created_at` | timestamp with time zone | TIDAK | `timezone('utc'::text, now())` |

## `targets`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | TIDAK |  |
| `name` | text | TIDAK |  |
| `target_amount` | numeric | TIDAK |  |
| `saved_amount` | numeric | TIDAK | `0` |
| `deadline` | date | ya |  |
| `created_at` | timestamp with time zone | TIDAK | `timezone('utc'::text, now())` |
| `storage_location` | text | ya |  |

## `transactions`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | TIDAK |  |
| `category_id` | bigint | ya |  |
| `amount` | numeric | TIDAK |  |
| `date` | date | TIDAK | `CURRENT_DATE` |
| `note` | text | ya |  |
| `created_at` | timestamp with time zone | ya | `now()` |
| `wallet_id` | bigint | ya |  |

## `wallets`

| Kolom | Tipe | Null | Default |
|---|---|---|---|
| `id` | bigint | TIDAK |  |
| `user_id` | uuid | ya |  |
| `name` | text | TIDAK |  |
| `balance` | numeric | ya | `0` |
| `color` | text | ya |  |
| `icon` | text | ya |  |
| `created_at` | timestamp with time zone | ya | `now()` |
| `is_favorite` | boolean | TIDAK | `false` |
| `min_balance` | numeric | TIDAK | `0` (check ≥ 0) |

## Foreign key

| Tabel.kolom | Ke | ON DELETE |
|---|---|---|
| `transactions.category_id` | `categories` | NO ACTION |
| `budgets.category_id` | `categories` | CASCADE |
| `recurring_transactions.category_id` | `categories` | CASCADE |
| `wallets.user_id` | `profiles` | CASCADE |
| `transactions.wallet_id` | `wallets` | SET NULL |
| `recurring_transactions.wallet_id` | `wallets` | SET NULL |
| `debt_payments.debt_id` | `debts` | CASCADE |
| `debt_payments.wallet_id` | `wallets` | NO ACTION |

## RLS policy

| Tabel | Nama | Cmd | USING | WITH CHECK |
|---|---|---|---|---|
| `categories` | User can delete own categories | DELETE | `(auth.uid() = user_id)` | `None` |
| `categories` | User can insert own categories | INSERT | `None` | `(auth.uid() = user_id)` |
| `categories` | User can see global and own categories | SELECT | `((user_id IS NULL) OR (auth.uid() = user_id))` | `None` |
| `categories` | User can update own categories | UPDATE | `(auth.uid() = user_id)` | `None` |
| `transactions` | User can delete own transactions | DELETE | `(auth.uid() = user_id)` | `None` |
| `transactions` | User can insert own transactions | INSERT | `None` | `(auth.uid() = user_id)` |
| `transactions` | User can see own transactions | SELECT | `(auth.uid() = user_id)` | `None` |
| `transactions` | User can update own transactions | UPDATE | `(auth.uid() = user_id)` | `None` |
| `profiles` | User bisa buat profil sendiri | INSERT | `None` | `(auth.uid() = id)` |
| `profiles` | User bisa lihat profil sendiri | SELECT | `(auth.uid() = id)` | `None` |
| `profiles` | User bisa update profil sendiri | UPDATE | `(auth.uid() = id)` | `None` |
| `profiles` | Users can update own profile | UPDATE | `(auth.uid() = id)` | `None` |
| `targets` | User delete targets | DELETE | `(auth.uid() = user_id)` | `None` |
| `targets` | User insert targets | INSERT | `None` | `(auth.uid() = user_id)` |
| `targets` | User select targets | SELECT | `(auth.uid() = user_id)` | `None` |
| `targets` | User update targets | UPDATE | `(auth.uid() = user_id)` | `None` |
| `recurring_transactions` | Users can manage their own recurring transactions | ALL | `(auth.uid() = user_id)` | `None` |
| `savings` | Users can manage their own savings | ALL | `(auth.uid() = user_id)` | `(auth.uid() = user_id)` |
| `budgets` | User delete budgets | DELETE | `(auth.uid() = user_id)` | `None` |
| `budgets` | User insert budgets | INSERT | `None` | `(auth.uid() = user_id)` |
| `budgets` | User select budgets | SELECT | `(auth.uid() = user_id)` | `None` |
| `budgets` | User update budgets | UPDATE | `(auth.uid() = user_id)` | `None` |
| `wallets` | Users can manage their own wallets | ALL | `(auth.uid() = user_id)` | `None` |
| `debt_payments` | Users can manage their own debt payments | ALL | `(auth.uid() = user_id)` | `None` |
| `debts` | Users can manage their own debts | ALL | `(auth.uid() = user_id)` | `None` |
| `investments` | Users can delete their own investments | DELETE | `(auth.uid() = user_id)` | `None` |
| `investments` | Users can insert their own investments | INSERT | `None` | `(auth.uid() = user_id)` |
| `investments` | Users can update their own investments | UPDATE | `(auth.uid() = user_id)` | `None` |
| `investments` | Users can view their own investments | SELECT | `(auth.uid() = user_id)` | `None` |

## Fungsi & trigger

Fungsi: `handle_new_user`. Trigger di schema public: tidak ada (trigger `handle_new_user` terpasang di `auth.users`).

## Catatan penting

- `transactions` tidak punya `is_expense`; arah uang berasal dari `categories.is_expense`. Kategori global punya `user_id` null.
- Tidak ada kolom yang menautkan transaksi ke tabungan/utang; penautan memakai tag di `note` (`[SAVING_ID:x]`, dan `[DEBT_ID:x]` mulai Plan B2).
- `debt_payments.wallet_id → wallets` kini ON DELETE SET NULL (migrasi B2, dijalankan user 2026-09-26).
- `transactions.category_id → categories` NO ACTION: kategori yang dipakai transaksi tidak bisa dihapus (disengaja; UI menampilkan "Kategori sedang digunakan").
- Policy publik `profiles` ("Public profiles are viewable by everyone") sudah dihapus (migration 202609260003, 2026-09-26); user hanya bisa membaca profilnya sendiri.
- RPC utang (migrasi `202609240001_debt_rpc.sql`, dijalankan 2026-09-26): `create_debt`, `add_debt_payment`, `update_debt`, `update_debt_payment`, `delete_debt_payment`, `delete_debt(p_debt_id, p_refund)` (versi 202609260002; `p_refund` true = balik efek dompet), helper `debt_category_id`, `debt_move_wallet`.
- RPC uang atomik (migrasi `202609260004_atomic_money.sql`, dijalankan 2026-09-26 lewat Management API): `save_transaction(p_id, p_category_id, p_wallet_id, p_amount, p_date, p_note)` (baru bila p_id null; edit membalik efek lama), `delete_transaction(p_id)`, `transfer_between_wallets(p_from, p_to, p_amount)`, `spend_from_saving(p_saving_name, p_category_id, p_amount, p_date, p_note)` (galat `SAVING_INSUFFICIENT:<sisa>`), `run_due_recurring(p_today date default null)` (versi 202609260005: tanggal perangkat dibatasi maks +1 hari dari server, default WIB; Bulanan/Tahunan berjangkar ke tanggal `start_date` lewat helper `recurring_step_month`; urut `wallet_id`; FOR UPDATE SKIP LOCKED), helper `wallet_add`, `lock_wallets`. Transaksi `[DEBT_ID:` ditolak di edit/hapus.
- RPC Target & Buku Tabungan (migrasi `202609260006_planning_money.sql`, dijalankan 2026-09-26 lewat Management API): `deposit_to_target(p_target_id, p_wallet_id, p_amount, p_date)` (galat `Saldo dompet <nama> tidak cukup!`; masuk `savings` bila `storage_location` tertaut, selain itu `targets.saved_amount`), `saving_transaction(p_is_deposit, p_saving_name, p_amount, p_wallet_id, p_location, p_notes, p_date)` (setor: `Saldo dompet tidak cukup!`; tarik: `SAVING_INSUFFICIENT:<sisa>`), `edit_saving_item(p_saving_id, p_amount, p_is_deposit, p_location, p_notes)`, `delete_saving_item(p_saving_id)` (baris yang sudah terhapus diabaikan), helper `system_category(p_pattern, p_name, p_expense)`, `lock_saving(p_name)` (kunci advisory per user+nama tabungan, sama dengan `spend_from_saving`).
- Normalisasi nama tabungan (migrasi `202609260007_saving_name_normalize.sql`, dijalankan 2026-09-26): saldo (`saving_balance(p_name)`), pewarisan lokasi, kunci `lock_saving`, dan tautan target memakai `lower(trim(name))` seperti pengelompokan di app; `spend_from_saving` memakai `lock_saving`, `saving_balance`, dan `system_category`; `edit_saving_item` menolak baris yang terhapus di tengah proses.
- RPC Investasi & Zakat/Sedekah (migrasi `202609260008_tools_money.sql`, dijalankan 2026-09-26): `buy_investment(p_name, p_type, p_amount, p_wallet_id, p_date)`, `buy_sell_investment(p_investment_id, p_is_buy, p_amount, p_wallet_id, p_date)` (galat `Saldo dompet tidak mencukupi!` / `Nominal penarikan melebihi nilai aset saat ini!`), `pay_zakat_sedekah(p_is_zakat, p_wallet_id, p_amount, p_note, p_date)`, helper `lock_wallet_with_balance(p_wallet_id, p_amount, p_message)`; `system_category` sekarang punya argumen ke-4 opsional `p_icon` (default `'bank'`).
- Migrasi `202609260009_sell_negative_wallet.sql` (dijalankan 2026-09-26): `lock_wallet_with_balance` hanya mengecek saldo bila ada uang keluar (`p_amount > 0`), jadi jual aset ke dompet bersaldo minus tetap bisa. `202609260006` kini juga mendefinisikan `system_category` 4 argumen supaya menjalankan ulang tidak membuat overload ganda (catatan: 0006 menimpa versi 0007 bila dijalankan ulang — jalankan 0007 sesudahnya).
- Aturan saldo dompet (migrasi `202609280001_wallet_spend_guard.sql`, dijalankan 2026-09-28): `wallet_spend_guard(p_wallet_id, p_amount, p_suffix default '')` mengunci dompet dan menolak uang keluar yang melewati `balance − min_balance` dengan pesan tunggal `Saldo dompet <nama> tidak cukup! Bisa dipakai: Rp <jumlah>` (`rupiah_text`). Dipakai `save_transaction` (baru & edit, efek bersih per dompet), `delete_transaction` (hapus pemasukan), `transfer_between_wallets`, `deposit_to_target`, `saving_transaction`, `edit_saving_item`, `delete_saving_item`, `lock_wallet_with_balance` (investasi, zakat) dan `debt_move_wallet` (semua RPC utang; akhiran "Hapus saja" dipertahankan).
- Tagihan rutin tertahan (migrasi `202609280002_recurring_blocked.sql`, dijalankan 2026-09-28): `run_due_recurring` tidak menjalankan periode pengeluaran yang melewati "bisa dipakai" dompet; `next_run_date` tetap di periode itu dan `blocked_reason` berisi pesan saldo (dikosongkan saat berhasil jalan). Beranda menampilkan jadwal aktif yang `blocked_reason`-nya terisi.
- Perbaikan review aturan saldo (migrasi `202609280003_balance_rules_review.sql`, dijalankan 2026-09-28): `rupiah_text` membulatkan ke bawah; `delete_debt(p_refund)` membalik efek uang masuk lebih dulu (yang dicek efek bersih); `run_due_recurring` memproses pemasukan sebelum pengeluaran pada dompet yang sama.
