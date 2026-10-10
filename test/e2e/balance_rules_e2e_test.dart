@Tags(['e2e'])
library;

// E2E aturan saldo dompet (spec 2026-09-28): uang keluar ditolak bila melewati
// "bisa dipakai" (saldo − saldo minimal), semua jalur uang. Data "E2E Guard …"
// dihapus lagi di akhir.
//
//   E2E_EMAIL=... E2E_PASSWORD=... flutter test test/e2e/balance_rules_e2e_test.dart
import '../../tool/e2e/e2e_env.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _email = Platform.environment['E2E_EMAIL'];
final _password = Platform.environment['E2E_PASSWORD'];
final _env = readSupabaseEnv();
final _skip = _email == null || _password == null || _env == null;

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
    await Supabase.initialize(
      url: _env!.url,
      anonKey: _env!.anonKey,
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
        'p_name': 'E2E Guard Utang', 'p_type': 'receivable', 'p_amount': 80001, 'p_loan_date': todayReal,
        'p_due_date': null, 'p_notes': null, 'p_wallet_id': a,
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

  test('perbaikan review: hapus utang dgn pengembalian, pembulatan, pemasukan dulu', () async {
    _failures.clear();
    final wallets = <int>[];
    final cats = <int>[];
    final recs = <int>[];
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final today = day(DateTime.now());
    Future<int> wallet(String name, num bal) async {
      final id = (await db.from('wallets').insert({'user_id': userId, 'name': name, 'balance': bal, 'min_balance': 0, 'color': '#1E3A8A'}).select('id').single())['id'] as int;
      wallets.add(id);
      return id;
    }

    try {
      // F1 hapus utang + kembalikan saldo: efek bersih yang muat harus diterima.
      final a = await wallet('E2E Guard Utang W', 0);
      final debtId = await db.rpc('create_debt', params: {
        'p_name': 'E2E Guard Pinjam', 'p_type': 'payable', 'p_amount': 1000000, 'p_loan_date': today,
        'p_due_date': null, 'p_notes': null, 'p_wallet_id': a,
      }) as int; // A: 1.000.000
      await db.rpc('add_debt_payment', params: {'p_debt_id': debtId, 'p_amount': 900000, 'p_date': today, 'p_wallet_id': a}); // A: 100.000
      await db.from('wallets').update({'balance': 500000}).eq('id', a);
      final e1 = await rpcError('delete_debt', {'p_debt_id': debtId, 'p_refund': true});
      check('F1 hapus & kembalikan (bersih −100.000 dari 500.000) diterima', e1 == null && await balance(a) == 400000, (e1, await balance(a)));

      // F2 "Bisa dipakai" tidak dibulatkan ke atas.
      final b = await wallet('E2E Guard Pecahan', 1000.6);
      final food = (await db.from('categories').insert({'user_id': userId, 'name': 'E2E Guard Jajan', 'is_expense': true, 'icon_name': 'tag'}).select('id').single())['id'] as int;
      cats.add(food);
      final e2 = await rpcError('save_transaction', {'p_id': null, 'p_category_id': food, 'p_wallet_id': b, 'p_amount': 1001, 'p_date': _today, 'p_note': 'E2E Guard'});
      check('F2 pesan menampilkan Rp 1.000 (dibulatkan ke bawah)', e2 == 'Saldo dompet E2E Guard Pecahan tidak cukup! Bisa dipakai: Rp 1.000', e2);

      // F3 pemasukan rutin dijalankan sebelum pengeluaran rutin di dompet yang sama.
      final c = await wallet('E2E Guard Rutin2', 0);
      final salary = (await db.from('categories').insert({'user_id': userId, 'name': 'E2E Guard Gaji2', 'is_expense': false, 'icon_name': 'tag'}).select('id').single())['id'] as int;
      cats.add(salary);
      for (final (cat, note) in [(food, 'E2E Guard keluar'), (salary, 'E2E Guard masuk')]) {
        recs.add((await db.from('recurring_transactions').insert({
          'user_id': userId, 'category_id': cat, 'wallet_id': c, 'amount': 10000, 'frequency': 'Bulanan',
          'start_date': today, 'next_run_date': today, 'note': note, 'is_active': true,
        }).select('id').single())['id'] as int);
      }
      await db.rpc('run_due_recurring', params: {'p_today': today});
      final held = await db.from('recurring_transactions').select('blocked_reason').inFilter('id', recs);
      check('F3 pemasukan dulu: pengeluaran 10.000 tidak tertahan, saldo 0',
          held.every((r) => r['blocked_reason'] == null) && await balance(c) == 0, (held, await balance(c)));
    } finally {
      for (final id in recs) {
        await db.from('recurring_transactions').delete().eq('id', id);
      }
      await db.from('debts').delete().eq('user_id', userId).like('name', 'E2E Guard%');
      for (final id in wallets) {
        await db.from('transactions').delete().eq('wallet_id', id);
        await db.from('wallets').delete().eq('id', id);
      }
      for (final id in cats) {
        await db.from('transactions').delete().eq('category_id', id);
        await db.from('categories').delete().eq('id', id);
      }
      // ignore: avoid_print
      print(_failures.isEmpty ? '\nSEMUA LULUS (perbaikan review)' : '\n${_failures.length} GAGAL: ${_failures.join(' | ')}');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 2)));

  tearDownAll(() async {
    if (_skip) return;
    await db.auth.signOut();
  });
}
