# Aturan Saldo Dompet, Tukar Arah Transfer, dan "Dompet Baru" di Mana Saja — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Semua uang keluar dari dompet ditolak bila melewati "bisa dipakai" (saldo − saldo minimal), tagihan rutin tertahan saat saldo kurang, transfer bisa ditukar arahnya, dan setiap pemilih dompet bisa membuat dompet baru.

**Architecture:** Satu fungsi database `wallet_spend_guard` dipanggil oleh setiap RPC uang di dalam transaksi yang sama dengan perubahan saldo (pola `wallet_add`/`lock_wallets`). App tidak lagi memeriksa saldo sendiri; ia menampilkan pesan tolakan server (P0001) apa adanya. Form Tambah Dompet dipindah ke satu fungsi bersama `showWalletFormSheet`, lalu dipasang di semua pemilih dompet lewat parameter `onCreate`.

**Tech Stack:** Flutter 3.38, flutter_riverpod 2.6.1, supabase_flutter (Postgres plpgsql RPC, RLS), phosphor_flutter, flutter_test (+ E2E ke Supabase sungguhan).

**Spec:** `docs/superpowers/specs/2026-09-28-wallet-balance-rules-design.md`

## Global Constraints

- Pesan tolakan tunggal (spec §3): `Saldo dompet <nama> tidak cukup! Bisa dipakai: Rp <jumlah>` — rupiah titik ribuan tanpa desimal, jumlah negatif ditampilkan `Rp 0`.
- "Bisa dipakai" = `balance − coalesce(min_balance, 0)`; uang keluar *x* ditolak bila *x* > bisa dipakai; uang masuk tidak pernah ditolak.
- Semua cek di database, di transaksi yang sama dengan perubahan saldo; tidak ada baca-lalu-tulis saldo dari app (AGENTS.md "Commands").
- Migration baru: `supabase/migrations/202609280001_wallet_spend_guard.sql`, `supabase/migrations/202609280002_recurring_blocked.sql`; dijalankan lewat `.superpowers/sdd/tools/supa_sql.sh`, diverifikasi di `pg_proc`/`information_schema`, didokumentasikan di `docs/database/schema.md`.
- Setting "Hitung saldo minimal di total saldo" tidak berubah.
- Modal hanya lewat komponen bersama (AGENTS.md "Modals"); warna hanya dari `AppColors`; teks lewat `AppTextStyles`.
- Commit Conventional Commits, diakhiri:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
  ```
- Setelah `flutter analyze`/`flutter test`: `git checkout -- linux macos windows`.
- E2E: kredensial hanya lewat env `E2E_EMAIL`/`E2E_PASSWORD`; data sementara bernama `E2E …` dengan nama unik per file (file E2E berjalan paralel di satu akun); cleanup di `finally`.

## Review Focus

1. **Dompet yang sudah di bawah batas (data lama) menerima pemasukan** — harus diterima, dan edit yang tidak mengurangi saldo tidak boleh ditolak. → Task 1 E2E `G6`.
2. **Edit transaksi pindah dompet** — dompet lama mendapat uangnya kembali tanpa cek; dompet baru dicek penuh. → Task 1 E2E `G4`.
3. **Dua pengeluaran bersamaan pada dompet yang sama** — hanya yang muat yang lolos, saldo tidak pernah < minimal. → Task 1 E2E `G8`.
4. **Tagihan rutin tertunggak beberapa periode** — jalan sebanyak yang muat, sisanya tertahan dengan `next_run_date` di periode tertahan pertama. → Task 3 E2E `R2`.
5. **"+ Dompet Baru" saat sheet induk masih terbuka** — dompet baru langsung terpilih dan tampil di sheet induk tanpa menutupnya. → Task 5 widget test `AppSelectRow onCreate`.

---

## File Structure

| File | Aksi | Tanggung jawab |
|---|---|---|
| `supabase/migrations/202609280001_wallet_spend_guard.sql` | Create | `rupiah_text`, `wallet_spend_guard`, redefinisi semua RPC uang |
| `supabase/migrations/202609280002_recurring_blocked.sql` | Create | kolom `blocked_reason`, `run_due_recurring` tertahan |
| `lib/core/money_rejection.dart` | Create | `MoneyRejection` (exception berisi pesan server) |
| `lib/core/wallet_rules.dart` | Modify | hapus `minBalanceWarningMessage` |
| `lib/providers/input_transaction_provider.dart` | Modify | pesan P0001 apa adanya |
| `lib/providers/transaction_history_provider.dart` | Modify | `MoneyRejection` saat hapus ditolak |
| `lib/providers/savings_provider.dart` | Modify | `MoneyRejection` saat edit/hapus riwayat ditolak |
| `lib/providers/wallet_provider.dart` | Modify | `validateTransfer` tanpa cek saldo; `insertWallet`/`updateWalletRow` top-level; `addWallet` mengembalikan id |
| `lib/screens/input_transaction/input_transaction_screen.dart` | Modify | hapus dialog saldo minimal; "+ Dompet Baru" |
| `lib/screens/wallet/wallet_screen.dart` | Modify | transfer: tukar arah, tanpa dialog saldo minimal, "+ Dompet Baru"; pakai form bersama |
| `lib/screens/wallet/wallet_form_sheet.dart` | Create | `showWalletFormSheet` (tambah/edit dompet) |
| `lib/widgets/app_create_row.dart` | Create | baris "+ …" untuk sheet pemilih |
| `lib/widgets/app_select_row.dart`, `lib/widgets/app_wallet_select_row.dart`, `lib/screens/debt/debt_wallet_picker.dart` | Modify | parameter `onCreate` |
| `lib/screens/{zakat_sedekah,savings,target,investment,recurring}/*`, `lib/screens/debt/debt_{form,payment}_sheet.dart`, `lib/screens/savings/saving_detail_screen.dart`, `lib/screens/transaction_history/transaction_history_screen.dart` | Modify | `onCreate`, pesan tolakan |
| `lib/models/recurring_transaction_model.dart`, `lib/providers/home_summary.dart`, `lib/providers/home_provider.dart`, `lib/screens/home/home_screen.dart` | Modify | `blockedReason`, pemberitahuan Beranda |
| `test/e2e/balance_rules_e2e_test.dart` | Create | E2E aturan saldo & tagihan tertahan |
| E2E lama (`wallet_transaction`, `planning`, `tools_assets`, `tool/e2e/debt_rpc_e2e.dart`) | Modify | pesan tolakan baru |

---

### Task 0: Branch

- [ ] **Step 1:** pastikan di branch `feat/wallet-balance-rules` (sudah dibuat, berisi commit spec). `git status` bersih.

---

### Task 1: `wallet_spend_guard` + semua RPC uang (database)

**Files:**
- Create: `supabase/migrations/202609280001_wallet_spend_guard.sql`
- Create: `test/e2e/balance_rules_e2e_test.dart`
- Modify: `test/e2e/wallet_transaction_e2e_test.dart:382-383,608-609`, `test/e2e/planning_e2e_test.dart:265,346`, `test/e2e/tools_assets_e2e_test.dart:176-177,336`, `tool/e2e/debt_rpc_e2e.dart:118`
- Modify: `docs/database/schema.md`

**Interfaces:**
- Produces (SQL): `rupiah_text(p numeric) returns text`; `wallet_spend_guard(p_wallet_id bigint, p_amount numeric, p_suffix text default '') returns void` — mengunci dompet, `Dompet tidak ditemukan.` bila bukan milik user, raise pesan tunggal (+ `p_suffix`) bila `p_amount > balance − min_balance`.
- Redefinisi (tanda tangan TIDAK berubah): `save_transaction`, `delete_transaction`, `transfer_between_wallets`, `deposit_to_target`, `saving_transaction`, `edit_saving_item`, `delete_saving_item`, `lock_wallet_with_balance`, `debt_move_wallet`.

- [ ] **Step 1: Tulis E2E (merah dulu)** — `test/e2e/balance_rules_e2e_test.dart`:

```dart
@Tags(['e2e'])
library;

// E2E aturan saldo dompet (spec 2026-09-28): uang keluar ditolak bila melewati
// "bisa dipakai" (saldo − saldo minimal), semua jalur uang. Data "E2E Guard …"
// dihapus lagi di akhir.
//
//   E2E_EMAIL=... E2E_PASSWORD=... flutter test test/e2e/balance_rules_e2e_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _email = Platform.environment['E2E_EMAIL'];
final _password = Platform.environment['E2E_PASSWORD'];
final _skip = _email == null || _password == null;

late SupabaseClient db;
late String userId;
final _failures = <String>[];

void check(String label, bool ok, [Object? detail]) {
  if (!ok) _failures.add(label);
  // ignore: avoid_print
  print('${ok ? 'PASS' : 'FAIL'}  $label${ok || detail == null ? '' : '  ->  $detail'}');
}

Future<double> balance(int id) async =>
    ((await db.from('wallets').select('balance').eq('id', id).single())['balance'] as num).toDouble();

/// Menjalankan RPC; mengembalikan pesan tolakan (P0001) atau null bila sukses.
Future<String?> rpcError(String fn, Map<String, dynamic> params) async {
  try {
    await db.rpc(fn, params: params);
    return null;
  } on PostgrestException catch (e) {
    return e.code == 'P0001' ? e.message : 'LAIN: ${e.message}';
  }
}

const _today = '2099-06-15';

void main() {
  setUpAll(() async {
    if (_skip) return;
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('id_ID', null);
    final src = File('lib/main.dart').readAsStringSync();
    await Supabase.initialize(
      url: RegExp(r"url:\s*'([^']+)'").firstMatch(src)!.group(1)!,
      anonKey: RegExp(r"anonKey:\s*'([^']+)'").firstMatch(src)!.group(1)!,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false, localStorage: EmptyLocalStorage()),
    );
    db = Supabase.instance.client;
    await db.auth.signInWithPassword(email: _email!, password: _password!);
    userId = db.auth.currentUser!.id;
  });

  test('aturan saldo: semua jalur uang keluar', () async {
    _failures.clear();
    final wallets = <int>[];
    final categories = <int>[];
    final targets = <int>[];
    final investments = <int>[];
    const savingName = 'E2E Guard Tab';
    Future<int> wallet(String name, double bal, {double min = 0}) async {
      final w = await db
          .from('wallets')
          .insert({'user_id': userId, 'name': name, 'balance': bal, 'min_balance': min, 'color': '#1E3A8A'})
          .select('id')
          .single();
      wallets.add(w['id'] as int);
      return w['id'] as int;
    }

    Future<int> category(String name, bool expense) async {
      final c = await db
          .from('categories')
          .insert({'user_id': userId, 'name': name, 'is_expense': expense, 'icon_name': 'tag'})
          .select('id')
          .single();
      categories.add(c['id'] as int);
      return c['id'] as int;
    }

    try {
      final a = await wallet('E2E Guard A', 100000, min: 20000); // bisa dipakai 80.000
      final b = await wallet('E2E Guard B', 50000);
      final food = await category('E2E Guard Makan', true);
      final salary = await category('E2E Guard Gaji', false);

      Map<String, dynamic> trx(int? id, int cat, int? w, num amt) =>
          {'p_id': id, 'p_category_id': cat, 'p_wallet_id': w, 'p_amount': amt, 'p_date': _today, 'p_note': 'E2E Guard'};

      // G1 pengeluaran: pas batas diterima, lewat Rp 1 ditolak dengan pesan tunggal.
      final e1 = await rpcError('save_transaction', trx(null, food, a, 80001));
      check('G1 pengeluaran 80.001 dari "bisa dipakai" 80.000 ditolak',
          e1 == 'Saldo dompet E2E Guard A tidak cukup! Bisa dipakai: Rp 80.000', e1);
      check('G1 saldo tidak berubah', await balance(a) == 100000);
      final ok1 = await rpcError('save_transaction', trx(null, food, a, 80000));
      check('G1 pengeluaran tepat 80.000 diterima', ok1 == null && await balance(a) == 20000, ok1);

      // G2 pemasukan selalu diterima (juga saat sudah di batas).
      final ok2 = await rpcError('save_transaction', trx(null, salary, a, 10000));
      check('G2 pemasukan diterima', ok2 == null && await balance(a) == 30000, ok2);

      // G3 edit menaikkan pengeluaran: yang dicek selisihnya.
      final spend = await db.from('transactions').select('id').eq('wallet_id', a).eq('amount', 80000).single();
      final e3 = await rpcError('save_transaction', trx(spend['id'] as int, food, a, 90001));
      check('G3 edit 80.000 → 90.001 (selisih 10.001 > 10.000) ditolak', e3?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e3);
      final ok3 = await rpcError('save_transaction', trx(spend['id'] as int, food, a, 90000));
      check('G3 edit 80.000 → 90.000 diterima', ok3 == null && await balance(a) == 20000, ok3);

      // G4 edit pindah dompet: dompet lama dapat uang kembali, dompet baru dicek penuh.
      final e4 = await rpcError('save_transaction', trx(spend['id'] as int, food, b, 90000));
      check('G4 pindah ke B (bisa dipakai 50.000) ditolak', e4 == 'Saldo dompet E2E Guard B tidak cukup! Bisa dipakai: Rp 50.000', e4);
      final ok4 = await rpcError('save_transaction', trx(spend['id'] as int, food, b, 40000));
      check('G4 pindah ke B 40.000 diterima; A kembali 110.000, B 10.000',
          ok4 == null && await balance(a) == 110000 && await balance(b) == 10000, (ok4, await balance(a), await balance(b)));

      // G5 hapus pemasukan = uang keluar.
      final inc = await db.from('transactions').select('id').eq('wallet_id', a).eq('category_id', salary).single();
      await db.from('wallets').update({'balance': 25000}).eq('id', a); // bisa dipakai 5.000
      final e5 = await rpcError('delete_transaction', {'p_id': inc['id']});
      check('G5 hapus pemasukan 10.000 saat bisa dipakai 5.000 ditolak', e5 == 'Saldo dompet E2E Guard A tidak cukup! Bisa dipakai: Rp 5.000', e5);

      // G6 dompet sudah di bawah batas: pemasukan tetap diterima.
      await db.from('wallets').update({'balance': 5000}).eq('id', a); // di bawah minimal 20.000
      final ok6 = await rpcError('save_transaction', trx(null, salary, a, 1000));
      check('G6 pemasukan ke dompet di bawah batas diterima', ok6 == null && await balance(a) == 6000, ok6);
      final e6 = await rpcError('save_transaction', trx(null, food, a, 1));
      check('G6 pengeluaran Rp 1 ditolak dengan "Bisa dipakai: Rp 0"', e6 == 'Saldo dompet E2E Guard A tidak cukup! Bisa dipakai: Rp 0', e6);

      // G7 jalur lain memakai pesan & batas yang sama.
      await db.from('wallets').update({'balance': 100000}).eq('id', a); // bisa dipakai 80.000
      final e7t = await rpcError('transfer_between_wallets', {'p_from': a, 'p_to': b, 'p_amount': 80001});
      check('G7 transfer ikut saldo minimal', e7t?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e7t);
      final e7z = await rpcError('pay_zakat_sedekah', {'p_is_zakat': false, 'p_wallet_id': a, 'p_amount': 80001, 'p_note': 'E2E Guard', 'p_date': _today});
      check('G7 sedekah ikut saldo minimal', e7z?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e7z);
      final e7i = await rpcError('buy_investment', {'p_name': 'E2E Guard Saham', 'p_type': 'Saham', 'p_amount': 80001, 'p_wallet_id': a, 'p_date': _today});
      check('G7 beli investasi ikut saldo minimal', e7i?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e7i);
      final e7s = await rpcError('saving_transaction', {'p_is_deposit': true, 'p_saving_name': savingName, 'p_amount': 80001, 'p_wallet_id': a, 'p_location': null, 'p_notes': null, 'p_date': _today});
      check('G7 setor tabungan ikut saldo minimal', e7s?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e7s);
      final tg = await db.from('targets').insert({'user_id': userId, 'name': 'E2E Guard Target', 'target_amount': 500000}).select('id').single();
      targets.add(tg['id'] as int);
      final e7g = await rpcError('deposit_to_target', {'p_target_id': tg['id'], 'p_wallet_id': a, 'p_amount': 80001, 'p_date': _today});
      check('G7 nabung target ikut saldo minimal', e7g?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e7g);
      final now = DateTime.now();
      final todayReal = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final e7d = await rpcError('create_debt', {
        // create_debt menolak tanggal di masa depan (> hari ini + 1): pakai tanggal nyata.
        'p_name': 'E2E Guard Utang', 'p_type': 'receivable', 'p_amount': 80001, 'p_date': todayReal,
        'p_due_date': null, 'p_note': null, 'p_wallet_id': a,
      });
      check('G7 pinjamkan (piutang) ikut saldo minimal', e7d?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false, e7d);
      check('G7 saldo A utuh 100.000', await balance(a) == 100000, await balance(a));

      // G7b edit/hapus riwayat tabungan yang mengurangi dompet.
      final dep = await rpcError('saving_transaction', {'p_is_deposit': true, 'p_saving_name': savingName, 'p_amount': 30000, 'p_wallet_id': a, 'p_location': null, 'p_notes': null, 'p_date': _today});
      final depRow = await db.from('savings').select('id').eq('user_id', userId).eq('name', savingName).single();
      final e7e = await rpcError('edit_saving_item', {'p_saving_id': depRow['id'], 'p_amount': 80001, 'p_is_deposit': true, 'p_location': null, 'p_notes': null});
      check('G7b edit setoran 30.000 → 80.001 (selisih 50.001 > 50.000) ditolak', dep == null && (e7e?.startsWith('Saldo dompet E2E Guard A tidak cukup!') ?? false), e7e);

      // G8 dua pengeluaran bersamaan: hanya yang muat.
      await db.from('wallets').update({'balance': 60000}).eq('id', b); // min 0, bisa dipakai 60.000
      final both = await Future.wait([
        rpcError('save_transaction', trx(null, food, b, 40000)),
        rpcError('save_transaction', trx(null, food, b, 40000)),
      ]);
      check('G8 dua pengeluaran 40.000 bersamaan dari 60.000: tepat satu diterima',
          both.where((e) => e == null).length == 1, both);
      check('G8 saldo B 20.000 (tidak pernah minus)', await balance(b) == 20000, await balance(b));
    } finally {
      for (final id in investments) {
        await db.from('investments').delete().eq('id', id);
      }
      await db.from('investments').delete().eq('user_id', userId).like('name', 'E2E Guard%');
      await db.from('debts').delete().eq('user_id', userId).like('name', 'E2E Guard%');
      for (final id in targets) {
        await db.from('transactions').delete().eq('user_id', userId).like('note', '%[SAVING_ID:T-$id]%');
        await db.from('targets').delete().eq('id', id);
      }
      final sv = await db.from('savings').select('id').eq('user_id', userId).eq('name', savingName);
      for (final r in sv) {
        await db.from('transactions').delete().eq('user_id', userId).like('note', '%[SAVING_ID:${r['id']}]%');
      }
      await db.from('savings').delete().eq('user_id', userId).eq('name', savingName);
      for (final id in wallets) {
        await db.from('transactions').delete().eq('wallet_id', id);
        await db.from('wallets').delete().eq('id', id);
      }
      for (final id in categories) {
        await db.from('transactions').delete().eq('category_id', id);
        await db.from('categories').delete().eq('id', id);
      }
      // ignore: avoid_print
      print(_failures.isEmpty ? '\nSEMUA LULUS (aturan saldo)' : '\n${_failures.length} GAGAL: ${_failures.join(' | ')}');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    if (_skip) return;
    await db.auth.signOut();
  });
}
```

Sebelum menjalankan, cocokkan parameter `create_debt` dengan definisi aktualnya (`grep -n "create or replace function public.create_debt" -A12 supabase/migrations/202609240001_debt_rpc.sql`) dan sesuaikan kunci `p_*` di G7 bila berbeda (catat di ledger).

- [ ] **Step 2: Jalankan, catat merah**

Run: `E2E_EMAIL=… E2E_PASSWORD=… flutter test test/e2e/balance_rules_e2e_test.dart`
Expected: FAIL — G1/G3/G4/G5/G6/G8 (tanpa cek), G7 (pesan lama / tanpa saldo minimal). Catat daftar FAIL di ledger.

- [ ] **Step 3: Tulis migration** — `supabase/migrations/202609280001_wallet_spend_guard.sql`:

```sql
-- supabase/migrations/202609280001_wallet_spend_guard.sql
-- Aturan saldo dompet (spec 2026-09-28-wallet-balance-rules-design.md). Aman dijalankan ulang.
-- Uang keluar ditolak bila melewati "bisa dipakai" = saldo − saldo minimal.
-- Satu pesan untuk semua fitur: "Saldo dompet <nama> tidak cukup! Bisa dipakai: Rp <jumlah>".

create or replace function public.rupiah_text(p numeric)
returns text language sql immutable set search_path = public as $$
  select 'Rp ' || replace(to_char(round(greatest(coalesce(p, 0), 0)), 'FM999,999,999,999,990'), ',', '.');
$$;

-- Kunci dompet milik user, lalu tolak uang keluar p_amount yang melewati batas.
-- p_amount <= 0 hanya mengunci & memastikan dompet ada.
create or replace function public.wallet_spend_guard(p_wallet_id bigint, p_amount numeric, p_suffix text default '')
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_w wallets%rowtype;
  v_available numeric;
begin
  perform lock_wallets(array[p_wallet_id]);
  select * into v_w from wallets where id = p_wallet_id and user_id = auth.uid();
  if not found then raise exception 'Dompet tidak ditemukan.'; end if;
  if coalesce(p_amount, 0) <= 0 then return; end if;
  v_available := coalesce(v_w.balance, 0) - coalesce(v_w.min_balance, 0);
  if p_amount > v_available then
    raise exception '%', format('Saldo dompet %s tidak cukup! Bisa dipakai: %s%s',
      v_w.name, rupiah_text(v_available), coalesce(p_suffix, ''));
  end if;
end $$;

-- Dipakai buy_investment, buy_sell_investment, pay_zakat_sedekah (0008/0009).
create or replace function public.lock_wallet_with_balance(p_wallet_id bigint, p_amount numeric, p_message text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform wallet_spend_guard(p_wallet_id, p_amount);
end $$;

-- Dipakai semua RPC utang (0001/0002). Pesan "Hapus saja" dipertahankan sebagai akhiran.
create or replace function public.debt_move_wallet(p_wallet_id bigint, p_delta numeric, p_insufficient_msg text)
returns void language plpgsql security invoker set search_path = public as $$
begin
  perform wallet_spend_guard(p_wallet_id, greatest(-p_delta, 0),
    case when p_insufficient_msg like '%Hapus saja%'
         then ' Pilih "Hapus saja" bila uangnya sudah terpakai.' else '' end);
  update wallets set balance = coalesce(balance, 0) + p_delta where id = p_wallet_id;
end $$;

create or replace function public.save_transaction(
  p_id bigint, p_category_id bigint, p_wallet_id bigint, p_amount numeric, p_date date, p_note text)
returns bigint language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_expense boolean;
  v_old transactions%rowtype;
  v_old_expense boolean;
  v_old_live boolean;
  v_old_delta numeric := 0; -- efek membalik transaksi lama pada dompet lama
  v_new_delta numeric := 0; -- efek transaksi baru pada dompet baru
  v_id bigint;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Jumlah dan Kategori wajib diisi!'; end if;
  select coalesce(is_expense, true) into v_expense
  from categories where id = p_category_id and (user_id is null or user_id = v_user);
  if not found then raise exception 'Kategori tidak ditemukan.'; end if;
  if p_wallet_id is not null and not exists (select 1 from wallets where id = p_wallet_id and user_id = v_user) then
    raise exception 'Dompet tidak ditemukan.';
  end if;
  if p_wallet_id is not null then
    v_new_delta := case when v_expense then -p_amount else p_amount end;
  end if;

  if p_id is null then
    if p_wallet_id is not null then perform wallet_spend_guard(p_wallet_id, -v_new_delta); end if;
    insert into transactions (user_id, category_id, amount, date, note, wallet_id)
    values (v_user, p_category_id, p_amount, p_date, p_note, p_wallet_id)
    returning id into v_id;
    if p_wallet_id is not null then perform wallet_add(p_wallet_id, v_new_delta); end if;
    return v_id;
  end if;

  select * into v_old from transactions where id = p_id and user_id = v_user for update;
  if not found then raise exception 'Transaksi tidak ditemukan.'; end if;
  if v_old.note like '%[DEBT_ID:%' then
    raise exception 'Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.';
  end if;
  select coalesce(is_expense, true) into v_old_expense from categories where id = v_old.category_id;
  perform lock_wallets(array[v_old.wallet_id, p_wallet_id]);
  v_old_live := v_old.wallet_id is not null
    and exists (select 1 from wallets where id = v_old.wallet_id and user_id = v_user);
  if v_old_live then
    v_old_delta := case when coalesce(v_old_expense, true) then v_old.amount else -v_old.amount end;
  end if;

  -- Cek efek bersih per dompet sebelum mengubah apa pun.
  if v_old_live and v_old.wallet_id = p_wallet_id then
    perform wallet_spend_guard(p_wallet_id, -(v_old_delta + v_new_delta));
  else
    if v_old_live then perform wallet_spend_guard(v_old.wallet_id, -v_old_delta); end if;
    if p_wallet_id is not null then perform wallet_spend_guard(p_wallet_id, -v_new_delta); end if;
  end if;

  if v_old_live then perform wallet_add(v_old.wallet_id, v_old_delta); end if;
  update transactions
  set category_id = p_category_id, amount = p_amount, date = p_date, note = p_note, wallet_id = p_wallet_id
  where id = p_id;
  if p_wallet_id is not null then perform wallet_add(p_wallet_id, v_new_delta); end if;
  return p_id;
end $$;

create or replace function public.delete_transaction(p_id bigint)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_old transactions%rowtype;
  v_expense boolean;
  v_delta numeric;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  select * into v_old from transactions where id = p_id and user_id = v_user for update;
  if not found then return; end if;
  if v_old.note like '%[DEBT_ID:%' then
    raise exception 'Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.';
  end if;
  select coalesce(is_expense, true) into v_expense from categories where id = v_old.category_id;
  if v_old.wallet_id is not null and exists (select 1 from wallets where id = v_old.wallet_id and user_id = v_user) then
    v_delta := case when coalesce(v_expense, true) then v_old.amount else -v_old.amount end;
    perform wallet_spend_guard(v_old.wallet_id, -v_delta); -- hapus pemasukan = uang keluar
    perform wallet_add(v_old.wallet_id, v_delta);
  end if;
  delete from transactions where id = p_id;
end $$;

create or replace function public.transfer_between_wallets(p_from bigint, p_to bigint, p_amount numeric)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  if p_from = p_to then raise exception 'Dompet asal dan tujuan tidak boleh sama!'; end if;
  perform lock_wallets(array[p_from, p_to]);
  if not exists (select 1 from wallets where id = p_to and user_id = v_user) then
    raise exception 'Dompet tidak ditemukan.';
  end if;
  perform wallet_spend_guard(p_from, p_amount);
  perform wallet_add(p_from, -p_amount);
  perform wallet_add(p_to, p_amount);
end $$;

create or replace function public.deposit_to_target(
  p_target_id bigint, p_wallet_id bigint, p_amount numeric, p_date date)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_target targets%rowtype;
  v_link text;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal tidak boleh kosong!'; end if;
  select * into v_target from targets where id = p_target_id and user_id = v_user for update;
  if not found then raise exception 'Target tidak ditemukan.'; end if;
  v_link := nullif(trim(coalesce(v_target.storage_location, '')), '');
  if v_link is not null then perform lock_saving(v_link); end if;
  perform wallet_spend_guard(p_wallet_id, p_amount);

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
  v_balance numeric;
  v_loc text := p_location;
  v_notes text := p_notes;
  v_id bigint;
  v_marker text;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  perform lock_saving(p_saving_name);
  perform wallet_spend_guard(p_wallet_id, case when p_is_deposit then p_amount else 0 end);
  if not p_is_deposit then
    v_balance := saving_balance(p_saving_name);
    if p_amount > v_balance then raise exception 'SAVING_INSUFFICIENT:%', v_balance; end if;
  end if;
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
  v_delta numeric;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Isi nominal dengan benar!'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;
  perform lock_saving(v_saving.name);
  select * into v_saving from savings where id = p_saving_id and user_id = v_user for update;
  if not found then raise exception 'Data tabungan tidak ditemukan.'; end if;

  select * into v_trx from transactions
  where user_id = v_user and note like '%' || v_marker || '%' and wallet_id is not null
  order by id limit 1 for update;
  if found and exists (select 1 from wallets where id = v_trx.wallet_id and user_id = v_user) then
    v_delta := (case when v_saving.amount > 0 then v_trx.amount else -v_trx.amount end)
             + (case when p_is_deposit then -p_amount else p_amount end);
    perform wallet_spend_guard(v_trx.wallet_id, -v_delta);
    perform wallet_add(v_trx.wallet_id, v_delta);
  end if;

  update savings
  set amount = case when p_is_deposit then p_amount else -p_amount end, location = p_location, notes = p_notes
  where id = p_saving_id;
  update transactions set amount = p_amount where user_id = v_user and note like '%' || v_marker || '%';
end $$;

create or replace function public.delete_saving_item(p_saving_id bigint)
returns void language plpgsql security invoker set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_saving savings%rowtype;
  v_marker text := '[SAVING_ID:' || p_saving_id || ']';
  v_trx transactions%rowtype;
  v_delta numeric;
begin
  if v_user is null then raise exception 'Sesi login berakhir. Silakan masuk lagi.'; end if;
  select * into v_saving from savings where id = p_saving_id and user_id = v_user;
  if not found then return; end if;
  perform lock_saving(v_saving.name);
  select * into v_saving from savings where id = p_saving_id and user_id = v_user for update;
  if not found then return; end if;

  select * into v_trx from transactions
  where user_id = v_user and note like '%' || v_marker || '%' and wallet_id is not null
  order by id limit 1 for update;
  if found and exists (select 1 from wallets where id = v_trx.wallet_id and user_id = v_user) then
    v_delta := case when v_saving.amount > 0 then v_trx.amount else -v_trx.amount end;
    perform wallet_spend_guard(v_trx.wallet_id, -v_delta); -- hapus tarikan = uang keluar lagi
    perform wallet_add(v_trx.wallet_id, v_delta);
  end if;

  delete from transactions where user_id = v_user and note like '%' || v_marker || '%';
  delete from savings where id = p_saving_id;
end $$;

revoke all on function public.rupiah_text(numeric) from public, anon;
revoke all on function public.wallet_spend_guard(bigint, numeric, text) from public, anon;
grant execute on function public.rupiah_text(numeric) to authenticated;
grant execute on function public.wallet_spend_guard(bigint, numeric, text) to authenticated;

notify pgrst, 'reload schema';
```

- [ ] **Step 4: Jalankan migration & verifikasi**

```bash
.superpowers/sdd/tools/supa_sql.sh supabase/migrations/202609280001_wallet_spend_guard.sql
.superpowers/sdd/tools/supa_sql.sh -q "select proname from pg_proc where proname in ('rupiah_text','wallet_spend_guard') order by 1"
.superpowers/sdd/tools/supa_sql.sh -q "select public.rupiah_text(1234567.4) a, public.rupiah_text(-5) b"
```
Expected: `HTTP 201`; dua fungsi; `a = "Rp 1.234.567"`, `b = "Rp 0"`.

- [ ] **Step 5: E2E baru hijau**

Run: `E2E_EMAIL=… E2E_PASSWORD=… flutter test test/e2e/balance_rules_e2e_test.dart`
Expected: `SEMUA LULUS (aturan saldo)`.

- [ ] **Step 6: Sesuaikan pesan di E2E lama**

Ganti asersi pesan lama dengan awalan pesan tunggal:
- `test/e2e/wallet_transaction_e2e_test.dart:382-383` → `errors.single.toString().contains('Saldo dompet E2E CX tidak cukup!')` dan label `'C2 pesan penolakan "Saldo dompet E2E CX tidak cukup!"'`.
- `test/e2e/wallet_transaction_e2e_test.dart:608-609` → `err11.toString().contains('Saldo dompet E2E CP tidak cukup!')`.
- `test/e2e/planning_e2e_test.dart:265` → `r2?.startsWith('Saldo dompet E2E Target W tidak cukup! Bisa dipakai:') ?? false`.
- `test/e2e/planning_e2e_test.dart:346` → `d2?.startsWith('Saldo dompet E2E Tabungan W tidak cukup!') ?? false` (nama dompet di test itu: `grep -n "t.wallet(" test/e2e/planning_e2e_test.dart`).
- `test/e2e/tools_assets_e2e_test.dart:176-177` → `e2.toString().contains('Saldo dompet E2E Investasi W tidak cukup!')`; `:336` → `e3.toString().contains('Saldo dompet E2E Zakat W tidak cukup!')`.
- `tool/e2e/debt_rpc_e2e.dart:118` → `err6?.contains('tidak cukup! Bisa dipakai:') ?? false`. R4 (`:193`, "Hapus saja") tetap — akhiran dipertahankan `debt_move_wallet`.

Run: `E2E_EMAIL=… E2E_PASSWORD=… flutter test test/e2e/` dan `… dart run tool/e2e/debt_rpc_e2e.dart`
Expected: semua `SEMUA LULUS`.

- [ ] **Step 7: Dokumentasi** — tambahkan ke `docs/database/schema.md` setelah baris migrasi `202609260010`/biometrik:

```markdown
- Aturan saldo dompet (migrasi `202609280001_wallet_spend_guard.sql`, dijalankan 2026-09-28): `wallet_spend_guard(p_wallet_id, p_amount, p_suffix default '')` mengunci dompet dan menolak uang keluar yang melewati `balance − min_balance` dengan pesan tunggal `Saldo dompet <nama> tidak cukup! Bisa dipakai: Rp <jumlah>` (`rupiah_text`). Dipakai `save_transaction` (baru & edit, efek bersih per dompet), `delete_transaction` (hapus pemasukan), `transfer_between_wallets`, `deposit_to_target`, `saving_transaction`, `edit_saving_item`, `delete_saving_item`, `lock_wallet_with_balance` (investasi, zakat) dan `debt_move_wallet` (semua RPC utang; akhiran "Hapus saja" dipertahankan).
```

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/202609280001_wallet_spend_guard.sql test/e2e tool/e2e docs/database/schema.md
git commit -m "$(cat <<'EOF'
feat(db): reject wallet outflows beyond balance minus minimum balance

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: App menampilkan tolakan server (tanpa cek saldo di app)

**Files:**
- Create: `lib/core/money_rejection.dart`
- Modify: `lib/providers/input_transaction_provider.dart:239-240`, `lib/providers/transaction_history_provider.dart:221-237`, `lib/providers/savings_provider.dart` (`editSavingItem`, `deleteSavingItem`), `lib/providers/wallet_provider.dart:23-32`
- Modify: `lib/screens/input_transaction/input_transaction_screen.dart:165-203`, `lib/screens/wallet/wallet_screen.dart:156-171`, `lib/screens/zakat_sedekah/zakat_sedekah_screen.dart:122-128`, `lib/screens/transaction_history/transaction_history_screen.dart:48-59`, `lib/screens/savings/saving_detail_screen.dart` (catch di `_deleteSaving` dan sheet edit)
- Modify: `lib/core/wallet_rules.dart` (hapus `minBalanceWarningMessage`), `test/core/wallet_rules_test.dart`, `test/providers/wallet_provider_test.dart`
- Rewrite: `test/screens/input_transaction/input_transaction_min_balance_test.dart` → tetap nama file, isi baru (lihat Step 1)
- Test: `test/screens/transaction_history/transaction_history_screen_test.dart`, `test/screens/savings/saving_detail_screen_test.dart` (tambahan)

**Interfaces:**
- Produces: `class MoneyRejection implements Exception { const MoneyRejection(this.message); final String message; String toString() => message; }`
- `validateTransfer(...)` tetap ada tanpa cek saldo (nominal ≤ 0, dompet sama).

- [ ] **Step 1: Test gagal**

Isi baru `test/screens/input_transaction/input_transaction_min_balance_test.dart`: salin kelas `FakeInputNotifier`, `_ManyCategoriesNotifier`, helper `pumpInput`/`tapSave`, serta test "dompet pertama otomatis terpilih", "tidak ada kategori…", "Pilih Kategori dengan banyak kategori…", "tap Simpan dua kali…" apa adanya; tambahkan field `String result = 'uji';` di fake (dipakai di `return TransactionSaveResult(false, result);`); ganti enam test dialog saldo minimal dengan:

```dart
  testWidgets('tidak ada lagi dialog "Di bawah saldo minimal": server yang memutuskan', (tester) async {
    final fake = await pumpInput(tester, '60000');
    fake.result = 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 50.000';
    await tapSave(tester);
    expect(find.text('Di bawah saldo minimal'), findsNothing);
    expect(fake.saveCalls, 1);
    expect(find.text('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 50.000'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsOneWidget); // layar tetap terbuka
    await tester.pump(const Duration(seconds: 4));
  });
```

Tambah di `test/screens/transaction_history/transaction_history_screen_test.dart` (fake notifier file itu: override `deleteTransaction` melempar `const MoneyRejection('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000')`; ikuti pola geser-hapus test yang sudah ada di file itu):

```dart
  testWidgets('hapus ditolak server menampilkan pesan tolakan, bukan pesan umum', (tester) async {
    // ... pump layar dengan fake yang melempar MoneyRejection, geser baris, Hapus, konfirmasi ...
    expect(find.text('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000'), findsOneWidget);
    expect(find.text('Gagal menghapus transaksi.'), findsNothing);
  });
```

Tambah di `test/screens/savings/saving_detail_screen_test.dart` (fake `editSavingItem` melempar `MoneyRejection('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 0')` bila field `rejectWith` diisi):

```dart
  testWidgets('edit ditolak server: pesan tolakan tampil, sheet tetap terbuka', (tester) async {
    await pump(tester);
    notifier.rejectWith = 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 0';
    await tester.tap(find.byIcon(PhosphorIconsRegular.pencilSimple).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 0'), findsOneWidget);
    expect(find.text('Edit Setoran'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
```

Di `test/providers/wallet_provider_test.dart`, ganti test `'menolak jika saldo sumber tidak cukup'` dengan:

```dart
    test('saldo tidak lagi dicek di app (server menolak dengan saldo minimal)', () {
      expect(validateTransfer(source: _w(1, 10000), dest: _w(2, 0), amount: 50000), isNull);
    });
```
(`_w` = helper pembuat `WalletModel` yang sudah ada di file itu; sesuaikan nama bila berbeda.)

Di `test/core/wallet_rules_test.dart` hapus grup `minBalanceWarningMessage`.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/input_transaction test/screens/transaction_history test/screens/savings test/providers/wallet_provider_test.dart`
Expected: FAIL (`MoneyRejection` belum ada; dialog masih muncul; `validateTransfer` masih menolak).

- [ ] **Step 3: Implementasi**

`lib/core/money_rejection.dart`:
```dart
/// Tolakan aturan uang dari server (RAISE P0001), mis. "Saldo dompet BCA tidak
/// cukup! Bisa dipakai: Rp 5.000". Layar menampilkan [message] apa adanya.
class MoneyRejection implements Exception {
  const MoneyRejection(this.message);
  final String message;

  @override
  String toString() => message;
}
```

`input_transaction_provider.dart` (catch `save_transaction`):
```dart
    } on PostgrestException catch (e) {
      // P0001 = tolakan aturan (mis. saldo dompet kurang): tampilkan apa adanya.
      return TransactionSaveResult(false, e.code == 'P0001' ? e.message : "Gagal: ${e.message}");
```

`transaction_history_provider.dart` `deleteTransaction`: bungkus `rpc('delete_transaction', …)` dengan
```dart
    } on PostgrestException catch (e) {
      debugPrint("Delete error: $e");
      if (e.code == 'P0001') throw MoneyRejection(e.message);
      throw Exception("Gagal menghapus transaksi.");
    } catch (e) {
```
(pertahankan cabang `catch (e)` lama untuk galat lain).

`transaction_history_screen.dart` `_deleteTransaction`:
```dart
    } on MoneyRejection catch (e) {
      if (mounted) AppNotification.error(context, e.message);
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, "Gagal menghapus transaksi.");
      }
    }
```

`savings_provider.dart` — di `editSavingItem` dan `deleteSavingItem`, ganti pemanggilan rpc langsung dengan:
```dart
    try {
      await _supabase.rpc('edit_saving_item', params: { /* params lama */ });
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw MoneyRejection(e.message);
      rethrow;
    }
```
(sama untuk `delete_saving_item`).

`saving_detail_screen.dart`: di sheet edit, sebelum `catch (e)` yang menampilkan "Gagal update data." tambahkan `on MoneyRejection catch (e) { if (context.mounted) AppNotification.error(context, e.message); }`; di `_deleteSaving` sebelum `catch (e)` tambahkan `on MoneyRejection catch (e) { if (mounted) AppNotification.error(context, e.message); }`.

`wallet_provider.dart` `validateTransfer`: hapus baris `if (source.balance < amount) return 'Saldo di ${source.name} tidak cukup!';` dan perbarui dok-komentarnya ("saldo & saldo minimal dicek server").

`input_transaction_screen.dart`: hapus seluruh blok peringatan saldo minimal (baris `if (... && amount > 0) { Map<String, dynamic>? wallet; ... }` sampai penutupnya sebelum `final notifier = ref.read(inputTransactionProvider.notifier);`) beserta variabel yang hanya dipakai blok itu.

`wallet_screen.dart` transfer: hapus blok `final warning = minBalanceWarningMessage(...)` + dialognya.

`zakat_sedekah_screen.dart` `_processPayment`: hapus cek `amountToPay > currentBalance` beserta `selectedWallet`/`currentBalance` (server menolak dengan pesan tunggal lewat `ZakatRejection`).

`wallet_rules.dart`: hapus `minBalanceWarningMessage` (pastikan `grep -rn minBalanceWarningMessage lib test` kosong).

- [ ] **Step 4: Jalankan test** — `flutter test` → semua PASS; `flutter analyze` → 0 error/warning.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib test
git commit -m "$(cat <<'EOF'
fix(wallet): show server balance rejections instead of app-side checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: Tagihan rutin tertahan + pemberitahuan Beranda

**Files:**
- Create: `supabase/migrations/202609280002_recurring_blocked.sql`
- Modify: `lib/models/recurring_transaction_model.dart`, `lib/providers/home_summary.dart`, `lib/providers/home_provider.dart:233-248`, `lib/screens/home/home_screen.dart` (`_HomeSummaryGrid.build`)
- Modify: `test/e2e/balance_rules_e2e_test.dart` (test baru), `docs/database/schema.md`
- Test: `test/providers/home_summary_test.dart` (tambahan), `test/screens/home/home_screen_test.dart` (tambahan)

**Interfaces:**
- Produces: kolom `recurring_transactions.blocked_reason text null`; `RecurringTransactionModel.blockedReason` (`String?`); `HomeSummary.blockedBills` (`List<RecurringTransactionModel>`, default `const []`); `List<RecurringTransactionModel> pickBlockedBills(List<RecurringTransactionModel>)`.

- [ ] **Step 1: E2E merah** — tambahkan ke `test/e2e/balance_rules_e2e_test.dart` sebelum `tearDownAll`:

```dart
  test('tagihan rutin tertahan saat saldo kurang, jalan saat cukup', () async {
    _failures.clear();
    int? walletId;
    int? catId;
    int? recId;
    try {
      walletId = (await db.from('wallets').insert({'user_id': userId, 'name': 'E2E Guard Rutin', 'balance': 25000, 'min_balance': 0, 'color': '#1E3A8A'}).select('id').single())['id'] as int;
      catId = (await db.from('categories').insert({'user_id': userId, 'name': 'E2E Guard Kos', 'is_expense': true, 'icon_name': 'tag'}).select('id').single())['id'] as int;
      // run_due_recurring membatasi "hari ini" ke tanggal server + 1, jadi pakai
      // tanggal nyata: tiga periode tertunggak tanggal 1 (dua bulan lalu, bulan
      // lalu, bulan ini) @ 10.000.
      String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final today = day(now);
      final first = DateTime(now.year, now.month - 2, 1);
      final thisMonth = day(DateTime(now.year, now.month, 1));
      final nextMonth = day(DateTime(now.year, now.month + 1, 1));
      recId = (await db.from('recurring_transactions').insert({
        'user_id': userId, 'category_id': catId, 'wallet_id': walletId, 'amount': 10000, 'frequency': 'Bulanan',
        'start_date': day(first), 'next_run_date': day(first), 'note': 'E2E Guard kos', 'is_active': true,
      }).select('id').single())['id'] as int;

      await db.rpc('run_due_recurring', params: {'p_today': today});
      var row = await db.from('recurring_transactions').select('next_run_date, blocked_reason').eq('id', recId).single();
      final trx1 = await db.from('transactions').select('id').eq('wallet_id', walletId);
      check('R1 dua periode jalan (saldo 25.000), periode ketiga tertahan', trx1.length == 2, trx1.length);
      check('R1 saldo 5.000 (tidak minus)', await balance(walletId) == 5000, await balance(walletId));
      check('R2 next_run_date tetap di periode tertahan (tanggal 1 bulan ini)', row['next_run_date'] == thisMonth, row);
      check('R2 blocked_reason berisi pesan saldo', (row['blocked_reason'] as String?)?.startsWith('Saldo dompet E2E Guard Rutin tidak cukup!') ?? false, row);

      await db.rpc('run_due_recurring', params: {'p_today': today});
      check('R3 dipanggil ulang saat masih kurang: tidak ada transaksi baru',
          (await db.from('transactions').select('id').eq('wallet_id', walletId)).length == 2);

      await db.from('wallets').update({'balance': 50000}).eq('id', walletId);
      await db.rpc('run_due_recurring', params: {'p_today': today});
      row = await db.from('recurring_transactions').select('next_run_date, blocked_reason').eq('id', recId).single();
      check('R4 saldo cukup: periode tertahan jalan, blocked_reason kosong, jadwal maju ke bulan depan',
          row['blocked_reason'] == null && row['next_run_date'] == nextMonth && await balance(walletId) == 40000,
          (row, await balance(walletId)));
    } finally {
      if (recId != null) await db.from('recurring_transactions').delete().eq('id', recId);
      if (walletId != null) {
        await db.from('transactions').delete().eq('wallet_id', walletId);
        await db.from('wallets').delete().eq('id', walletId);
      }
      if (catId != null) await db.from('categories').delete().eq('id', catId);
      // ignore: avoid_print
      print(_failures.isEmpty ? '\nSEMUA LULUS (tagihan tertahan)' : '\n${_failures.length} GAGAL: ${_failures.join(' | ')}');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 2)));
```

Run → FAIL (R1: tiga periode jalan & saldo −5.000; kolom `blocked_reason` belum ada).

- [ ] **Step 2: Migration** — `supabase/migrations/202609280002_recurring_blocked.sql`:

```sql
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
```

Jalankan + verifikasi:
```bash
.superpowers/sdd/tools/supa_sql.sh supabase/migrations/202609280002_recurring_blocked.sql
.superpowers/sdd/tools/supa_sql.sh -q "select column_name from information_schema.columns where table_name='recurring_transactions' and column_name='blocked_reason'"
```
Expected: 1 baris. E2E Step 1 → `SEMUA LULUS (tagihan tertahan)`; E2E lama `planning` R1–R5 tetap hijau.

- [ ] **Step 3: Test app gagal**

`test/providers/home_summary_test.dart` tambahan:
```dart
  test('pickBlockedBills: hanya jadwal aktif yang punya blocked_reason', () {
    RecurringTransactionModel r(int id, {String? blocked, bool active = true}) => RecurringTransactionModel(
          id: id, userId: 'u', categoryId: 1, amount: 10000, frequency: 'Bulanan',
          startDate: DateTime(2026, 9, 1), nextRunDate: DateTime(2026, 9, 1), isActive: active, blockedReason: blocked);
    final picked = pickBlockedBills([r(1), r(2, blocked: 'Saldo dompet BCA tidak cukup!'), r(3, blocked: 'x', active: false)]);
    expect(picked.map((e) => e.id), [2]);
  });
```

`test/screens/home/home_screen_test.dart` tambahan (pakai fake Home notifier yang sudah ada di file itu, isi `summary: HomeSummary(blockedBills: [ … note: 'Bayar Kos', blockedReason: 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000' ])`):
```dart
  testWidgets('tagihan tertahan tampil sebagai pemberitahuan di Beranda', (tester) async {
    // ... pump Home dengan state di atas ...
    expect(find.text('Tagihan Bayar Kos belum terbayar'), findsOneWidget);
    expect(find.text('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000'), findsOneWidget);
  });
```

Run → FAIL (`blockedReason`/`blockedBills`/`pickBlockedBills` belum ada).

- [ ] **Step 4: Implementasi app**

`recurring_transaction_model.dart`: field `final String? blockedReason;`, parameter konstruktor `this.blockedReason,`, `fromJson`: `blockedReason: json['blocked_reason'],`.

`home_summary.dart`:
```dart
  final List<RecurringTransactionModel> blockedBills;

  const HomeSummary({this.budget, this.target, this.nextBill, this.debt, this.blockedBills = const []});
```
dan
```dart
/// Jadwal aktif yang tertahan karena saldo dompet kurang (run_due_recurring).
List<RecurringTransactionModel> pickBlockedBills(List<RecurringTransactionModel> items) =>
    items.where((r) => r.isActive && (r.blockedReason ?? '').isNotEmpty).toList();
```

`home_provider.dart` `fetchSummary`: ubah hasil recurring jadi variabel lokal dan tambahkan `blockedBills: pickBlockedBills(recurring),` di `HomeSummary(...)`:
```dart
      final recurring = (results[3] as List).map((e) => RecurringTransactionModel.fromJson(e)).toList();
      ...
          nextBill: pickNextBill(recurring),
          debt: ...,
          blockedBills: pickBlockedBills(recurring),
```

`home_screen.dart` `_HomeSummaryGrid.build`: sebelum grid ringkasan, tambahkan untuk tiap jadwal tertahan:
```dart
        for (final bill in summary.blockedBills) ...[
          GestureDetector(
            onTap: () => onOpen(AppFeature.recurring),
            child: AppCallout(
              icon: PhosphorIconsFill.warningCircle,
              tone: AppCalloutTone.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tagihan ${(bill.note ?? '').isNotEmpty ? bill.note : (bill.category?['name'] ?? '')} belum terbayar',
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(bill.blockedReason!, style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
```
(Tambahkan import `app_callout.dart` bila belum ada.)

- [ ] **Step 5: Test hijau + dokumentasi** — `flutter test` PASS; `docs/database/schema.md`: baris kolom `blocked_reason` di tabel `recurring_transactions` + catatan migrasi `202609280002_recurring_blocked.sql` (tagihan tertahan).

- [ ] **Step 6: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add supabase/migrations/202609280002_recurring_blocked.sql lib test docs/database/schema.md
git commit -m "$(cat <<'EOF'
feat(recurring): hold due bills when the wallet balance is too low

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: Transfer — tombol tukar & tukar otomatis

**Files:**
- Modify: `lib/screens/wallet/wallet_screen.dart:64-196` (`_showTransferSheet`)
- Test: `test/screens/wallet/wallet_transfer_test.dart` (baru)

**Interfaces:**
- Produces: tombol dengan tooltip `'Tukar arah'` di sheet Transfer.

- [ ] **Step 1: Test gagal** — `test/screens/wallet/wallet_transfer_test.dart`:

```dart
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeWallets extends WalletNotifier {
  final transfers = <(int, int, double)>[];
  @override
  WalletState build() => WalletState(isLoading: false, wallets: [
        WalletModel.fromJson({'id': 1, 'user_id': 'u', 'name': 'A', 'balance': 100000, 'color': '#1E3A8A', 'min_balance': 0, 'is_favorite': false}),
        WalletModel.fromJson({'id': 2, 'user_id': 'u', 'name': 'B', 'balance': 50000, 'color': '#E65100', 'min_balance': 0, 'is_favorite': false}),
      ]);
  @override
  Future<void> fetchWallets() async {}
  @override
  Future<void> transfer({required int sourceId, required int destId, required double amount}) async =>
      transfers.add((sourceId, destId, amount));
}

Future<_FakeWallets> _openTransfer(WidgetTester tester) async {
  final fake = _FakeWallets();
  await pumpApp(tester, const WalletScreen(), overrides: [walletProvider.overrideWith(() => fake)], size: const Size(390, 1400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transfer'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('tombol tukar membalik sumber dan tujuan', (tester) async {
    final fake = await _openTransfer(tester);
    await tester.tap(find.byTooltip('Tukar arah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10000');
    await tester.tap(find.text('Transfer Sekarang'));
    await tester.pumpAndSettle();
    expect(fake.transfers, [(2, 1, 10000.0)]);
  });

  testWidgets('memilih sumber = tujuan menukar kedua sisi, tanpa pesan error', (tester) async {
    final fake = await _openTransfer(tester);
    await tester.tap(find.text('Dari Dompet (Sumber)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    expect(find.text('Dompet asal dan tujuan tidak boleh sama!'), findsNothing);
    await tester.enterText(find.byType(TextField).last, '10000');
    await tester.tap(find.text('Transfer Sekarang'));
    await tester.pumpAndSettle();
    expect(fake.transfers, [(2, 1, 10000.0)]);
  });
}
```
(Periksa kunci JSON `WalletModel.fromJson` dan label pill transfer di `wallet_screen.dart`; sesuaikan bila berbeda dan catat.)

Run → FAIL (tidak ada tooltip "Tukar arah"; memilih B menampilkan error).

- [ ] **Step 2: Implementasi** — di `_showTransferSheet`:
- pada `onTap` baris sumber, ganti blok `if (picked == destId) { AppNotification.error(...); return; } setSheetState(() => sourceId = picked);` dengan:
```dart
                      setSheetState(() {
                        if (picked == destId) destId = sourceId; // tukar otomatis
                        sourceId = picked;
                      });
```
- pada baris tujuan, analog:
```dart
                      setSheetState(() {
                        if (picked == sourceId) sourceId = destId;
                        destId = picked;
                      });
```
- di antara dua `AppListRow` sumber & tujuan (di dalam `AppGroupedSection`), sisipkan:
```dart
                  Center(
                    heightFactor: 1,
                    child: IconButton(
                      tooltip: 'Tukar arah',
                      icon: const Icon(PhosphorIconsBold.arrowsDownUp, color: AppColors.primary),
                      onPressed: () => setSheetState(() {
                        final s = sourceId;
                        sourceId = destId;
                        destId = s;
                      }),
                    ),
                  ),
```
- baris subtitle tujuan tampilkan saldo juga: `subtitle: '${dest.name} (Sisa: ${formatRupiah(dest.balance)})'`.

- [ ] **Step 3: Test hijau** — `flutter test test/screens/wallet` PASS.

- [ ] **Step 4: Commit** — `feat(wallet): swap transfer direction with a button or by picking the other wallet`.

---

### Task 5: "+ Dompet Baru" di semua pemilih dompet

**Files:**
- Create: `lib/screens/wallet/wallet_form_sheet.dart`, `lib/widgets/app_create_row.dart`
- Modify: `lib/providers/wallet_provider.dart` (`insertWallet`, `updateWalletRow`, `addWallet` → `Future<int>`)
- Modify: `lib/screens/wallet/wallet_screen.dart` (pakai `showWalletFormSheet`; transfer "+ Dompet Baru"; <2 dompet → tawarkan buat)
- Modify: `lib/widgets/app_select_row.dart`, `lib/widgets/app_wallet_select_row.dart`, `lib/screens/debt/debt_wallet_picker.dart`
- Modify (sambungkan `onCreate`): `lib/screens/input_transaction/input_transaction_screen.dart`, `lib/screens/savings/savings_screen.dart` (2 sheet), `lib/screens/target/target_screen.dart`, `lib/screens/investment/investment_screen.dart` (2 sheet), `lib/screens/zakat_sedekah/zakat_sedekah_screen.dart`, `lib/screens/debt/debt_form_sheet.dart`, `lib/screens/debt/debt_payment_sheet.dart`, `lib/screens/recurring/recurring_screen.dart`
- Test: `test/widgets/app_select_row_test.dart`, `test/widgets/app_wallet_select_row_test.dart`, `test/widgets/app_create_row_test.dart` (baru), `test/screens/input_transaction/input_transaction_min_balance_test.dart` (tambahan)

**Interfaces:**
- Produces:
  - `Future<int> insertWallet({required String name, required double balance, required String color, double minBalance = 0})` (top-level, `wallet_provider.dart`)
  - `Future<void> updateWalletRow({required int id, required String name, required double balance, required String color, double minBalance = 0})` (top-level)
  - `WalletNotifier.addWallet(...)` → `Future<int>` (memanggil `insertWallet` lalu `fetchWallets`)
  - `Future<int?> showWalletFormSheet(BuildContext context, {WalletModel? wallet, required Future<void> Function() onSaved})` — id dompet baru/diedit, null bila batal
  - `class AppCreateRow extends StatelessWidget { const AppCreateRow({required String label, required VoidCallback onTap}); }` — `AppListRow` dengan tile `PhosphorIconsBold.plus` primary, judul `label` berwarna primary
  - `AppSelectRow<T>`: parameter opsional `String createLabel = 'Dompet Baru'`, `Future<T?> Function()? onCreate`
  - `AppWalletSelectRow`: parameter opsional `Future<int?> Function()? onCreate`
  - `DebtWalletPickerRow`: parameter opsional `Future<int?> Function()? onCreate`

- [ ] **Step 1: Test komponen gagal**

`test/widgets/app_create_row_test.dart`:
```dart
import 'package:catat_uang_app/widgets/app_create_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppCreateRow menampilkan "+ label" dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppCreateRow(label: 'Dompet Baru', onTap: () => taps++)));
    await tester.tap(find.text('Dompet Baru'));
    expect(taps, 1);
  });
}
```

`test/widgets/app_select_row_test.dart` tambahan:
```dart
  testWidgets('onCreate: baris "Dompet Baru" di sheet membuat & memilih opsi baru', (tester) async {
    int? picked;
    var options = const [AppSelectOption(1, 'BCA')];
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: AppSelectRow<int>(
            title: 'Dompet',
            value: picked ?? 1,
            options: options,
            onChanged: (v) => setState(() => picked = v),
            onCreate: () async {
              setState(() => options = const [AppSelectOption(1, 'BCA'), AppSelectOption(9, 'Jago')]);
              return 9;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dompet Baru'));
    await tester.pumpAndSettle();
    expect(picked, 9);
    expect(find.text('Jago'), findsOneWidget);
  });

  testWidgets('onCreate tanpa opsi: baris langsung membuat (placeholder "Buat Dompet")', (tester) async {
    var created = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Dompet',
          value: null,
          options: const [],
          onChanged: (_) {},
          onCreate: () async {
            created++;
            return null;
          },
        ),
      ),
    );
    expect(find.text('Buat Dompet'), findsOneWidget);
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    expect(created, 1);
  });
```

`test/widgets/app_wallet_select_row_test.dart` tambahan:
```dart
  testWidgets('onCreate tanpa dompet: "Buat Dompet" memanggil onCreate dan memilih hasilnya', (tester) async {
    int? picked;
    await pumpApp(
      tester,
      Scaffold(
        body: AppWalletSelectRow(
          wallets: const [],
          selectedId: null,
          onChanged: (v) => picked = v,
          onCreate: () async => 7,
        ),
      ),
    );
    expect(find.text('Buat Dompet'), findsOneWidget);
    await tester.tap(find.text('Buat Dompet'));
    await tester.pumpAndSettle();
    expect(picked, 7);
  });
```

Run → FAIL (file/parameter belum ada).

- [ ] **Step 2: Implementasi komponen**

`lib/widgets/app_create_row.dart`:
```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Baris "+ …" di bawah daftar pemilih (mis. "Dompet Baru").
class AppCreateRow extends StatelessWidget {
  const AppCreateRow({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsBold.plus, color: AppColors.primary),
      title: label,
      titleColor: AppColors.primary,
      onTap: onTap,
    );
  }
}
```

`app_select_row.dart`:
- field & parameter: `this.createLabel = 'Dompet Baru', this.onCreate,` / `final String createLabel; final Future<T?> Function()? onCreate;` (dok: "Bila diisi, sheet pemilih mendapat baris '+ createLabel'; hasil non-null langsung dipilih. Tanpa opsi, baris ini langsung membuat.")
- `_open`: builder sheet menjadi
```dart
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchableGroup<int>( /* seperti sekarang */ ),
          if (onCreate != null) ...[
            const SizedBox(height: 12),
            AppGroupedSection(children: [
              AppCreateRow(label: createLabel, onTap: () => Navigator.pop(sheetContext, -1)),
            ]),
          ],
        ],
      ),
```
  lalu setelah `await`:
```dart
    if (index == -1) {
      await _create();
    } else if (index != null) {
      onChanged(options[index].value);
    }
```
  dengan
```dart
  Future<void> _create() async {
    final created = await onCreate!();
    if (created != null) onChanged(created);
  }
```
- `build`: bila `options.isEmpty && onCreate != null` → `value: 'Buat ${createLabel.replaceFirst(' Baru', '')}'` ("Buat Dompet"), `showChevron: true`, `onTap: _create`; selain itu seperti sekarang.

`app_wallet_select_row.dart`:
- parameter `this.onCreate` / `final Future<int?> Function()? onCreate;`
- di `_openPicker`, builder sheet dibungkus `Column` seperti di atas dengan `AppCreateRow(label: 'Dompet Baru', onTap: () => Navigator.pop(sheetContext, -1))`; setelah `await`: `if (picked == -1) { await _create(); } else if (picked != null) onChanged(picked);` dengan `_create()` memanggil `onCreate!()` dan `onChanged(id)` bila non-null.
- `build`: bila `isEmpty && onCreate != null` → judul `'Buat Dompet'`, `titleColor: AppColors.primary`, `showChevron: true`, `onTap: _create`.

`debt_wallet_picker.dart` (`DebtWalletPickerRow`): parameter `this.onCreate`; `_pick` sheet mendapat `AppCreateRow` yang sama (pop `-1`) → `onCreate` → `onSelected(id)`; bila `wallets.isEmpty && onCreate != null`, judul `'Buat Dompet'` dan tap langsung `onCreate`.

Run test komponen → PASS.

- [ ] **Step 3: Form dompet bersama**

`wallet_provider.dart` — tambahkan top-level dan pakai di notifier:
```dart
/// Menyimpan dompet baru dan mengembalikan id-nya. Top-level supaya bisa
/// dipanggil dari layar mana pun (form "Dompet Baru") tanpa bergantung pada
/// WalletNotifier yang sedang hidup.
Future<int> insertWallet({
  required String name,
  required double balance,
  required String color,
  double minBalance = 0,
}) async {
  final client = Supabase.instance.client;
  final row = await client
      .from('wallets')
      .insert({
        'user_id': client.auth.currentUser!.id,
        'name': name,
        'balance': balance,
        'color': color,
        'icon': 'wallet',
        'min_balance': minBalance,
      })
      .select('id')
      .single();
  return row['id'] as int;
}

Future<void> updateWalletRow({
  required int id,
  required String name,
  required double balance,
  required String color,
  double minBalance = 0,
}) async {
  await Supabase.instance.client.from('wallets').update({
    'name': name,
    'balance': balance,
    'color': color,
    'icon': 'wallet',
    'min_balance': minBalance,
  }).eq('id', id);
}
```
`addWallet` → `Future<int> addWallet(...) async { final id = await insertWallet(...); await fetchWallets(); return id; }`; `updateWallet` memanggil `updateWalletRow(...)` lalu `fetchWallets()`.

`lib/screens/wallet/wallet_form_sheet.dart`: pindahkan isi `_showAddEditWalletSheet` dari `wallet_screen.dart` apa adanya menjadi
```dart
/// Form Tambah/Edit Dompet (dipakai layar Dompet dan semua "+ Dompet Baru").
/// Mengembalikan id dompet yang disimpan, atau null bila dibatalkan.
/// [onSaved] menyegarkan daftar dompet milik layar pemanggil.
Future<int?> showWalletFormSheet(
  BuildContext context, {
  WalletModel? wallet,
  required Future<void> Function() onSaved,
}) {
```
dengan perubahan: `showAppFormSheet<int>`; tombol simpan memanggil `updateWalletRow(...)` (edit) atau `final id = await insertWallet(...)` (tambah), lalu `await onSaved();`, toast sukses yang sama, dan `Navigator.pop(sheetContext, isEdit ? wallet.id : id)`. `_thousands` ikut dipindah (`NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0)`).
Di `wallet_screen.dart` semua pemanggilan `_showAddEditWalletSheet(context, ref, wallet: w)` diganti `showWalletFormSheet(context, wallet: w, onSaved: ref.read(walletProvider.notifier).fetchWallets)`, dan method lama dihapus.

- [ ] **Step 4: Sambungkan ke layar** (pola sama: buka form, segarkan daftar dompet layar itu, kembalikan id)

- `input_transaction_screen.dart`:
  ```dart
  Future<int?> _createWallet() async {
    final id = await showWalletFormSheet(context, onSaved: ref.read(inputTransactionProvider.notifier).fetchWallets);
    if (id != null && mounted) setState(() => _selectedWalletId = id);
    return id;
  }
  ```
  `_showWalletPicker`: builder dibungkus `Column` + `AppCreateRow(label: 'Dompet Baru', onTap: () { Navigator.pop(sheetContext); _createWallet(); })`. Baris "Dompet" saat kosong: `value: 'Buat Dompet'`, `showChevron: true`, `onTap: _createWallet` (menggantikan "Buat dompet di menu utama!"). Pesan provider "Kamu belum membuat dompet. Silakan buat di Beranda > Dompet." diganti "Kamu belum membuat dompet. Ketuk \"Buat Dompet\" dulu.".
- `wallet_screen.dart` transfer: parameter `List<WalletModel> wallets` jadi variabel lokal `var wallets`; `_pickWallet` mendapat parameter `Future<int?> Function()? onCreate` dan `AppCreateRow` (pop `-1` → `onCreate`); `onCreate` transfer = `() async { final id = await showWalletFormSheet(context, onSaved: ref.read(walletProvider.notifier).fetchWallets); wallets = ref.read(walletProvider).wallets; return id; }`. Dompet < 2: ganti toast "Minimal butuh 2 dompet untuk transfer." dengan `showAppConfirmDialog(title: 'Butuh 2 dompet', message: 'Transfer butuh minimal 2 dompet. Buat dompet baru sekarang?', confirmLabel: 'Buat Dompet', destructive: false)` → bila ya, `showWalletFormSheet(...)`.
- `savings_screen.dart` (dua `AppSelectRow<int>` dompet): `onCreate: () => showWalletFormSheet(context, onSaved: ref.read(savingsProvider.notifier).fetchWallets),` (daftar dibaca ulang dari provider di builder, sudah demikian).
- `target_screen.dart` (`_showDepositSheet`): `onCreate: () => showWalletFormSheet(context, onSaved: ref.read(targetProvider.notifier).fetchWallets),` (daftar di-`watch`).
- `recurring_screen.dart`: `onCreate: () => showWalletFormSheet(context, onSaved: ref.read(recurringProvider.notifier).fetchWallets),`.
- `investment_screen.dart` (dua sheet): `final wallets` → `var wallets`; `AppWalletSelectRow(..., onCreate: () async { final id = await showWalletFormSheet(context, onSaved: () => ref.read(investmentProvider.notifier).fetchData(showLoading: false)); wallets = ref.read(investmentProvider).wallets; return id; })`.
- `zakat_sedekah_screen.dart`: `onCreate: () => showWalletFormSheet(context, onSaved: _fetchWallets),`.
- `debt_form_sheet.dart`, `debt_payment_sheet.dart`: `DebtWalletPickerRow(..., onCreate: () => showWalletFormSheet(context, onSaved: () => ref.read(debtProvider.notifier).fetchData(silent: true)))`; switch "pengaruhi dompet" tetap aktif saat belum ada dompet (hapus `wallets.isEmpty ? null :` pada `onChanged`, subtitle 'Belum ada dompet' → 'Belum ada dompet — buat di bawah').

- [ ] **Step 5: Test layar** — tambah di `test/screens/input_transaction/input_transaction_min_balance_test.dart`:
```dart
  testWidgets('tanpa dompet: baris Dompet menawarkan "Buat Dompet"', (tester) async {
    await pumpApp(
      tester,
      const InputTransactionScreen(initialIsExpense: true),
      overrides: [inputTransactionProvider.overrideWith(_NoWalletNotifier.new)],
      size: const Size(600, 1400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buat Dompet'), findsOneWidget);
    expect(find.text('Buat dompet di menu utama!'), findsNothing);
  });
```
dengan
```dart
class _NoWalletNotifier extends InputTransactionNotifier {
  @override
  InputTransactionState build() => const InputTransactionState(categories: [
        {'id': 10, 'name': 'Makan', 'is_expense': true},
      ]);
}
```
Run: `flutter test` → semua PASS (perbaiki test layar lain yang memakai teks lama). `flutter analyze` → 0 error/warning.

- [ ] **Step 6: Commit** — `feat(wallet): create a wallet from every wallet picker`.

---

### Task 6: Verifikasi akhir + screenshot

- [ ] **Step 1:** `flutter analyze` (0 error/warning), `flutter test` penuh dengan env E2E (semua hijau, termasuk `balance_rules_e2e_test.dart`), `dart run tool/e2e/debt_rpc_e2e.dart` (SEMUA LULUS), cek sisa data `E2E%` = 0 (query yang sama dengan plan B7).
- [ ] **Step 2:** tambah `test/screenshots/wallet_rules_screenshots_test.dart` (pola `b5_screenshots_test.dart`): (1) sheet Transfer dengan tombol tukar, (2) sheet "Pilih Dompet" dengan "+ Dompet Baru", (3) Tambah Transaksi tanpa dompet ("Buat Dompet"), (4) Beranda dengan pemberitahuan tagihan tertahan, (5) toast tolakan saldo. Jalankan & periksa gambar.
- [ ] **Step 3:** review akhir (fresh reviewer, model paling kuat), perbaiki temuan dengan test RED→GREEN, laporkan ke user dengan screenshot; merge lokal hanya setelah user setuju.
