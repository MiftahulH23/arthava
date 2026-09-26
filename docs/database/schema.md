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
| `profiles` | Public profiles are viewable by everyone | SELECT | `true` | `None` |
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
- `profiles` punya policy SELECT `true` ("Public profiles are viewable by everyone") sehingga semua user bisa membaca nama user lain — dihapus di Plan B3.
- RPC utang (migrasi `202609240001_debt_rpc.sql`, dijalankan 2026-09-26): `create_debt`, `add_debt_payment`, `update_debt`, `update_debt_payment`, `delete_debt_payment`, `delete_debt`, helper `debt_category_id`, `debt_move_wallet`.
