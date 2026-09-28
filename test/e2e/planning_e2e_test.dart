@Tags(['e2e'])
library;

// E2E backend B5 (Anggaran, Target, Tabungan, Tagihan Rutin) terhadap Supabase
// sungguhan, lewat provider ASLI app. Data sementara bernama "E2E …" (dompet,
// kategori, tabungan, target, jadwal) dihapus lagi di akhir. Anggaran memakai
// tahun 2099 supaya "Salin Bulan Lalu" tidak menyentuh anggaran asli akun.
//
//   E2E_EMAIL=... E2E_PASSWORD=... flutter test test/e2e/planning_e2e_test.dart
//
// Tanpa env, test di-skip (tidak ikut `flutter test` biasa).
import 'dart:io';

import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/providers/recurring_provider.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/providers/target_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// Transitif lewat supabase_flutter; hanya untuk menyiapkan test.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _email = Platform.environment['E2E_EMAIL'];
final _password = Platform.environment['E2E_PASSWORD'];
final _skip = _email == null || _password == null;

late SupabaseClient db;
late ProviderContainer container;
late String userId;
final _failures = <String>[];

void check(String label, bool ok, [Object? detail]) {
  if (!ok) _failures.add(label);
  // ignore: avoid_print
  print('${ok ? 'PASS' : 'FAIL'}  $label${ok || detail == null ? '' : '  ->  $detail'}');
}

void report(String name) {
  // ignore: avoid_print
  print(_failures.isEmpty ? '\nSEMUA LULUS ($name)' : '\n${_failures.length} GAGAL ($name): ${_failures.join(' | ')}');
}

Future<double> balance(int walletId) async {
  final row = await db.from('wallets').select('balance').eq('id', walletId).single();
  return (row['balance'] as num).toDouble();
}

Future<double> savingSum(String name) async {
  final rows = await db.from('savings').select('amount').eq('user_id', userId).eq('name', name);
  return rows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
}

/// Menunggu fetch pertama provider (build() menjadwalkan fetch lewat microtask).
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 1500));

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Data sementara satu test; semuanya dihapus di [cleanup].
class _Temp {
  final wallets = <int>[];
  final categories = <int>[];
  final savingNames = <String>{};
  final targets = <int>[];
  final recurring = <int>[];
  late final Set<int> categoriesBefore;

  Future<void> snapshotCategories() async {
    final rows = await db.from('categories').select('id').eq('user_id', userId);
    categoriesBefore = {for (final r in rows) r['id'] as int};
  }

  Future<int> wallet(String name, double balance) async {
    final w = await db
        .from('wallets')
        .insert({'user_id': userId, 'name': name, 'balance': balance, 'color': '#1E3A8A'})
        .select('id')
        .single();
    wallets.add(w['id'] as int);
    return w['id'] as int;
  }

  Future<int> category(String name, {bool isExpense = true}) async {
    final c = await db
        .from('categories')
        .insert({'user_id': userId, 'name': name, 'is_expense': isExpense, 'icon_name': 'tag'})
        .select('id')
        .single();
    categories.add(c['id'] as int);
    return c['id'] as int;
  }

  Future<void> cleanup() async {
    for (final id in recurring) {
      await db.from('recurring_transactions').delete().eq('id', id);
    }
    for (final id in targets) {
      await db.from('transactions').delete().eq('user_id', userId).like('note', '%[SAVING_ID:T-$id]%');
      await db.from('targets').delete().eq('id', id);
    }
    for (final name in savingNames) {
      final rows = await db.from('savings').select('id').eq('user_id', userId).eq('name', name);
      for (final r in rows) {
        await db.from('transactions').delete().eq('user_id', userId).like('note', '%[SAVING_ID:${r['id']}]%');
      }
      await db.from('savings').delete().eq('user_id', userId).eq('name', name);
    }
    for (final id in wallets) {
      await db.from('transactions').delete().eq('wallet_id', id);
      await db.from('wallets').delete().eq('id', id);
    }
    for (final id in categories) {
      await db.from('budgets').delete().eq('category_id', id);
      await db.from('transactions').delete().eq('category_id', id);
      await db.from('categories').delete().eq('id', id);
    }
    // Kategori sistem ("Tabungan", "Pencairan Tabungan", "Tabungan Target") yang
    // baru dibuat oleh test ini: hapus bila sudah tidak dipakai transaksi mana pun.
    final now = await db
        .from('categories')
        .select('id')
        .eq('user_id', userId)
        .inFilter('name', ['Tabungan', 'Pencairan Tabungan', 'Tabungan Target']); // file E2E lain berjalan bersamaan
    for (final r in now) {
      final id = r['id'] as int;
      if (categoriesBefore.contains(id)) continue;
      final used = await db.from('transactions').select('id').eq('category_id', id).limit(1);
      if (used.isEmpty) await db.from('categories').delete().eq('id', id);
    }
  }
}

void main() {
  setUpAll(() async {
    if (_skip) return;
    HttpOverrides.global = null; // flutter test memblokir HTTP; E2E butuh jaringan sungguhan.
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('id_ID', null);
    final src = File('lib/main.dart').readAsStringSync();
    final url = RegExp(r"url:\s*'([^']+)'").firstMatch(src)!.group(1)!;
    final anonKey = RegExp(r"anonKey:\s*'([^']+)'").firstMatch(src)!.group(1)!;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false, localStorage: EmptyLocalStorage()),
    );
    db = Supabase.instance.client;
    await db.auth.signInWithPassword(email: _email!, password: _password!);
    userId = db.auth.currentUser!.id;
    container = ProviderContainer();
  });

  test('anggaran: buat, ubah, hapus, salin bulan lalu, total terpakai, detail', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(budgetProvider, (_, _) {});
    await settle();
    final budget = container.read(budgetProvider.notifier);
    try {
      final walletId = await t.wallet('E2E Anggaran', 1000000);
      final catId = await t.category('E2E Makan');
      await budget.fetchCategories();

      budget.setMonth(DateTime(2099, 1));
      await budget.addBudget(categoryId: catId, month: 1, year: 2099, amount: 500000);
      final rows = await db.from('budgets').select().eq('category_id', catId);
      check('A1 buat anggaran Jan 2099 = 500.000',
          rows.length == 1 && (rows.single['amount'] as num) == 500000 && rows.single['month'] == 1, rows);

      Object? dup;
      try {
        await budget.addBudget(categoryId: catId, month: 1, year: 2099, amount: 1);
      } catch (e) {
        dup = e;
      }
      check('A2 anggaran kembar ditolak "Anggaran kategori ini sudah ada!"', dup == 'Anggaran kategori ini sudah ada!', dup);

      await db.rpc('save_transaction', params: {
        'p_id': null, 'p_category_id': catId, 'p_wallet_id': walletId,
        'p_amount': 120000, 'p_date': '2099-01-15', 'p_note': 'E2E makan',
      });
      await db.rpc('save_transaction', params: {
        'p_id': null, 'p_category_id': catId, 'p_wallet_id': walletId,
        'p_amount': 30000, 'p_date': '2099-02-01', 'p_note': 'E2E bulan lain',
      });
      await budget.fetchBudgets();
      final s = container.read(budgetProvider);
      check('A3 terpakai kategori Jan 2099 = 120.000 (transaksi Feb tidak ikut)', s.spendingMap[catId] == 120000, s.spendingMap[catId]);
      check('A3 total terpakai & total anggaran', s.totalSpent == 120000 && s.totalBudget == 500000, (s.totalSpent, s.totalBudget));

      final budgetId = rows.single['id'] as int;
      await budget.updateBudgetAmount(budgetId, 750000);
      final upd = await db.from('budgets').select('amount').eq('id', budgetId).single();
      check('A4 ubah limit jadi 750.000', (upd['amount'] as num) == 750000, upd);
      check('A4 state ikut berubah', container.read(budgetProvider).budgets.firstWhere((b) => b.id == budgetId).amount == 750000);

      final detailKey = (categoryId: catId, month: 1, year: 2099);
      final detail = await container.read(budgetDetailProvider(detailKey).future);
      check('A5 detail anggaran: 1 transaksi, total 120.000, nama dompet',
          detail.transactions.length == 1 && detail.totalSpent == 120000 && detail.walletNames[walletId] == 'E2E Anggaran',
          (detail.transactions.length, detail.totalSpent));

      budget.setMonth(DateTime(2099, 2));
      await settle();
      final copied = await budget.copyFromLastMonth();
      final feb = await db.from('budgets').select().eq('category_id', catId).eq('month', 2).eq('year', 2099);
      check('A6 salin bulan lalu: Feb 2099 dapat anggaran 750.000',
          copied && feb.length == 1 && (feb.single['amount'] as num) == 750000, (copied, feb));

      budget.setMonth(DateTime(2099, 6));
      await settle();
      final none = await budget.copyFromLastMonth();
      check('A7 salin tanpa data bulan lalu → false', none == false);

      await budget.deleteBudget(budgetId);
      final left = await db.from('budgets').select('id').eq('id', budgetId);
      check('A8 hapus anggaran', left.isEmpty, left);
    } finally {
      await t.cleanup();
      report('anggaran');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('target: buat, edit (deadline lewat), nabung, nabung bersamaan, hapus', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(targetProvider, (_, _) {});
    await settle();
    final target = container.read(targetProvider.notifier);
    try {
      final walletId = await t.wallet('E2E Target W', 500000);
      await target.fetchWallets();

      await target.addTarget(name: 'E2E Target', targetAmount: 1000000, deadline: DateTime(2020, 1, 1));
      final row = await db.from('targets').select().eq('user_id', userId).eq('name', 'E2E Target').single();
      final targetId = row['id'] as int;
      t.targets.add(targetId);
      check('T1 buat target (deadline lama 2020-01-01)', row['deadline'] == '2020-01-01' && (row['target_amount'] as num) == 1000000, row);

      await target.editTarget(
          id: targetId, name: 'E2E Target', targetAmount: 1200000, savedAmount: 0, deadline: DateTime(2020, 2, 1));
      final ed = await db.from('targets').select().eq('id', targetId).single();
      check('T2 edit target dengan deadline lewat tersimpan', ed['deadline'] == '2020-02-01' && (ed['target_amount'] as num) == 1200000, ed);

      TargetModel current() => container.read(targetProvider).targets.firstWhere((x) => x.id == targetId);

      final r1 = await target.depositToTarget(target: current(), rawAmount: 100000, walletId: walletId);
      final saved1 = (await db.from('targets').select('saved_amount').eq('id', targetId).single())['saved_amount'] as num;
      final trx = await db.from('transactions').select('amount, wallet_id').like('note', '%[SAVING_ID:T-$targetId]%');
      check('T3 nabung 100.000: sukses', r1 == null, r1);
      check('T3 dompet 500.000 → 400.000', await balance(walletId) == 400000, await balance(walletId));
      check('T3 saved_amount = 100.000', saved1 == 100000, saved1);
      check('T3 transaksi bertanda [SAVING_ID:T-id] dari dompet', trx.length == 1 && trx.single['wallet_id'] == walletId, trx);

      final r2 = await target.depositToTarget(target: current(), rawAmount: 999999, walletId: walletId);
      check('T4 nabung melebihi saldo ditolak dengan pesan saldo',
          r2?.startsWith('Saldo dompet E2E Target W tidak cukup! Bisa dipakai:') ?? false, r2);
      check('T4 saldo tidak berubah', await balance(walletId) == 400000, await balance(walletId));

      await target.fetchWallets();
      await target.fetchTargets();
      final snap = current();
      await Future.wait([
        target.depositToTarget(target: snap, rawAmount: 50000, walletId: walletId),
        target.depositToTarget(target: snap, rawAmount: 50000, walletId: walletId),
      ]);
      final saved2 = (await db.from('targets').select('saved_amount').eq('id', targetId).single())['saved_amount'] as num;
      check('T5 dua nabung bersamaan: dompet 300.000 (tidak ada potongan hilang)', await balance(walletId) == 300000, await balance(walletId));
      check('T5 dua nabung bersamaan: saved_amount 200.000', saved2 == 200000, saved2);

      // Target yang tertaut ke Buku Tabungan: setoran masuk ke tabungan.
      t.savingNames.add('E2E Tab Target');
      await db.from('savings').insert({'user_id': userId, 'name': 'E2E Tab Target', 'amount': 0});
      await target.addTarget(name: 'E2E Target Link', targetAmount: 500000, storageLocation: 'E2E Tab Target');
      final linkId = (await db.from('targets').select('id').eq('user_id', userId).eq('name', 'E2E Target Link').single())['id'] as int;
      t.targets.add(linkId);
      await target.fetchTargets();
      final link = container.read(targetProvider).targets.firstWhere((x) => x.id == linkId);
      final r3 = await target.depositToTarget(target: link, rawAmount: 70000, walletId: walletId);
      await target.fetchTargets();
      check('T6 nabung target tertaut: sukses', r3 == null, r3);
      check('T6 masuk Buku Tabungan "E2E Tab Target" = 70.000', await savingSum('E2E Tab Target') == 70000, await savingSum('E2E Tab Target'));
      check('T6 progres target ikut saldo tabungan',
          container.read(targetProvider).targets.firstWhere((x) => x.id == linkId).savedAmount == 70000);
      check('T6 dompet 230.000', await balance(walletId) == 230000, await balance(walletId));

      await target.deleteTarget(targetId);
      final gone = await db.from('targets').select('id').eq('id', targetId);
      check('T7 hapus target', gone.isEmpty, gone);
      check('T7 saldo dompet tidak dikembalikan (perilaku lama)', await balance(walletId) == 230000, await balance(walletId));
    } finally {
      await t.cleanup();
      report('target');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('tabungan: buat, setor, tarik, edit, hapus, bersamaan, tarik melebihi saldo', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(savingsProvider, (_, _) {});
    await settle();
    final savings = container.read(savingsProvider.notifier);
    const name = 'E2E Tab Buku'; // unik: file E2E lain memakai "E2E Tab" dan berjalan bersamaan
    t.savingNames.addAll({name, 'E2E Tab Baru'});
    try {
      final walletId = await t.wallet('E2E Tabungan W', 1000000);
      await savings.fetchWallets();

      await savings.addEmptyGroup(name: name, location: 'Bank E2E', notes: 'catatan E2E');
      check('S1 buat tabungan kosong', await savingSum(name) == 0 &&
          (await db.from('savings').select('id').eq('user_id', userId).eq('name', name)).length == 1);

      final d1 = await savings.processSavingTransaction(isDeposit: true, savingName: name, amount: 200000, walletId: walletId);
      check('S2 setor 200.000: sukses', d1 == null, d1);
      check('S2 dompet 800.000', await balance(walletId) == 800000, await balance(walletId));
      check('S2 saldo tabungan 200.000', await savingSum(name) == 200000, await savingSum(name));
      final depRow = await db.from('savings').select().eq('user_id', userId).eq('name', name).eq('amount', 200000).single();
      check('S2 lokasi & catatan diwarisi dari baris lama', depRow['location'] == 'Bank E2E' && depRow['notes'] == 'catatan E2E', depRow);
      final depTrx = await db.from('transactions').select('amount, wallet_id').like('note', '%[SAVING_ID:${depRow['id']}]%');
      check('S2 transaksi bertanda dari dompet', depTrx.length == 1 && depTrx.single['wallet_id'] == walletId, depTrx);

      await savings.fetchWallets();
      final w1 = await savings.processSavingTransaction(isDeposit: false, savingName: name, amount: 50000, walletId: walletId);
      check('S3 tarik 50.000: sukses', w1 == null, w1);
      check('S3 dompet 850.000', await balance(walletId) == 850000, await balance(walletId));
      check('S3 saldo tabungan 150.000', await savingSum(name) == 150000, await savingSum(name));

      await savings.fetchWallets();
      final w2 = await savings.processSavingTransaction(isDeposit: false, savingName: name, amount: 1000000, walletId: walletId);
      check('S4 tarik melebihi saldo tabungan ditolak', w2 == 'Saldo tabungan tidak cukup! Sisa: Rp 150.000', w2);
      check('S4 saldo tidak berubah', await savingSum(name) == 150000 && await balance(walletId) == 850000,
          (await savingSum(name), await balance(walletId)));

      await savings.fetchWallets();
      final d2 = await savings.processSavingTransaction(isDeposit: true, savingName: name, amount: 5000000, walletId: walletId);
      check('S5 setor melebihi saldo dompet ditolak dengan pesan saldo', d2?.startsWith('Saldo dompet E2E Tabungan W tidak cukup!') ?? false, d2);

      await savings.fetchWallets();
      await Future.wait([
        savings.processSavingTransaction(isDeposit: true, savingName: name, amount: 10000, walletId: walletId),
        savings.processSavingTransaction(isDeposit: true, savingName: name, amount: 10000, walletId: walletId),
      ]);
      check('S6 dua setor bersamaan: dompet 830.000', await balance(walletId) == 830000, await balance(walletId));
      check('S6 dua setor bersamaan: tabungan 170.000', await savingSum(name) == 170000, await savingSum(name));

      await savings.fetchWallets();
      final both = await Future.wait([
        savings.processSavingTransaction(isDeposit: false, savingName: name, amount: 100000, walletId: walletId),
        savings.processSavingTransaction(isDeposit: false, savingName: name, amount: 100000, walletId: walletId),
      ]);
      check('S7 dua tarik 100.000 bersamaan dari 170.000: tepat satu berhasil',
          both.where((r) => r == null).length == 1, both);
      check('S7 tabungan 70.000, dompet 930.000', await savingSum(name) == 70000 && await balance(walletId) == 930000,
          (await savingSum(name), await balance(walletId)));

      // Edit setoran 200.000 → 250.000: dompet ikut -50.000.
      await savings.fetchSavings();
      SavingModel item(num amount) =>
          container.read(savingsProvider).groupedSavings[name]!.firstWhere((s) => s.amount == amount);
      await savings.editSavingItem(saving: item(200000), rawAmount: 250000, isDeposit: true, location: 'Bank E2E', notes: 'edit');
      final edTrx = await db.from('transactions').select('amount').like('note', '%[SAVING_ID:${depRow['id']}]%').single();
      check('S8 edit setoran → 250.000: dompet 880.000', await balance(walletId) == 880000, await balance(walletId));
      check('S8 edit setoran: baris tabungan & transaksi = 250.000',
          await savingSum(name) == 120000 && (edTrx['amount'] as num) == 250000, (await savingSum(name), edTrx));

      // Hapus tarikan 50.000: tabungan +50.000, dompet -50.000.
      await savings.fetchSavings();
      await savings.deleteSavingItem(item(-50000));
      check('S9 hapus tarikan: dompet 830.000, tabungan 170.000',
          await balance(walletId) == 830000 && await savingSum(name) == 170000, (await balance(walletId), await savingSum(name)));

      // Baris dari "pakai tabungan" (dua transaksi bertanda sama, tanpa dompet) bisa dihapus.
      final expenseCat = await t.category('E2E Pakai');
      await db.rpc('spend_from_saving', params: {
        'p_saving_name': name, 'p_category_id': expenseCat, 'p_amount': 20000, 'p_date': _day(DateTime.now()), 'p_note': 'E2E pakai',
      });
      await savings.fetchSavings();
      final spent = item(-20000);
      Object? delErr;
      try {
        await savings.deleteSavingItem(spent);
      } catch (e) {
        delErr = e;
      }
      final spentTrx = await db.from('transactions').select('id').like('note', '%[SAVING_ID:${spent.id}]%');
      check('S10 hapus baris "pakai tabungan" (2 transaksi bertanda) berhasil',
          delErr == null && spentTrx.isEmpty && await savingSum(name) == 170000, (delErr, spentTrx.length, await savingSum(name)));
      check('S10 dompet tidak berubah', await balance(walletId) == 830000, await balance(walletId));

      // Detail Tabungan: data provider = isi tabel.
      await savings.fetchSavings();
      final tableRows = await db.from('savings').select('id').eq('user_id', userId).eq('name', name);
      final group = container.read(savingsProvider).groupedSavings[name]!;
      check('S11 riwayat Detail Tabungan = isi tabel',
          group.map((s) => s.id).toSet().containsAll(tableRows.map((r) => r['id'])) && group.length == tableRows.length,
          (group.length, tableRows.length));

      await savings.renameGroup(oldName: name, newName: 'E2E Tab Baru', location: 'Bank Baru', notes: '');
      check('S12 ganti nama tabungan: semua baris pindah', await savingSum('E2E Tab Baru') == 170000 && await savingSum(name) == 0);

      await savings.deleteGroup('E2E Tab Baru');
      final gone = await db.from('savings').select('id').eq('user_id', userId).eq('name', 'E2E Tab Baru');
      check('S13 hapus tabungan', gone.isEmpty, gone);
    } finally {
      await t.cleanup();
      report('tabungan');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('tagihan rutin: tambah, edit, jalan tepat sekali, nonaktif, hapus', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(recurringProvider, (_, _) {});
    await settle();
    final recurring = container.read(recurringProvider.notifier);
    try {
      final walletId = await t.wallet('E2E Rutin W', 100000);
      final catId = await t.category('E2E Kos');
      final today = _day(DateTime.now());

      // Map sama seperti yang dibangun sheet "Buat Jadwal Tagihan".
      await recurring.addRecurring({
        'user_id': userId, 'category_id': catId, 'wallet_id': walletId, 'amount': 10000,
        'frequency': 'Bulanan', 'start_date': today, 'next_run_date': today, 'note': 'E2E kos', 'is_active': true,
      });
      final row = await db.from('recurring_transactions').select().eq('category_id', catId).single();
      final id = row['id'] as int;
      t.recurring.add(id);
      check('R1 tambah jadwal', row['frequency'] == 'Bulanan' && row['is_active'] == true, row);
      check('R1 state provider memuat jadwal', container.read(recurringProvider).recurringList.any((r) => r.id == id));

      await recurring.updateRecurring(id, {'amount': 20000, 'note': 'E2E kos edit'});
      final ed = await db.from('recurring_transactions').select().eq('id', id).single();
      check('R2 edit nominal & catatan', (ed['amount'] as num) == 20000 && ed['note'] == 'E2E kos edit', ed);

      final results = await Future.wait([
        db.rpc('run_due_recurring', params: {'p_today': today}),
        db.rpc('run_due_recurring', params: {'p_today': today}),
      ]);
      final trx = await db.from('transactions').select('amount').eq('wallet_id', walletId);
      check('R3 jatuh tempo dijalankan tepat sekali (dua panggilan bersamaan)', trx.length == 1, (results, trx.length));
      check('R3 dompet 100.000 → 80.000', await balance(walletId) == 80000, await balance(walletId));
      final next = (await db.from('recurring_transactions').select('next_run_date').eq('id', id).single())['next_run_date'];
      check('R3 jadwal maju ke bulan berikutnya', next != today, next);

      final item = container.read(recurringProvider).recurringList.firstWhere((r) => r.id == id);
      await recurring.toggleActive(item, false);
      await db.from('recurring_transactions').update({'next_run_date': today}).eq('id', id);
      await db.rpc('run_due_recurring', params: {'p_today': today});
      final off = await db.from('recurring_transactions').select('is_active').eq('id', id).single();
      check('R4 nonaktifkan: is_active false dan tidak dijalankan',
          off['is_active'] == false && (await db.from('transactions').select('id').eq('wallet_id', walletId)).length == 1, off);

      await recurring.deleteItem(id);
      final gone = await db.from('recurring_transactions').select('id').eq('id', id);
      check('R5 hapus jadwal', gone.isEmpty, gone);
    } finally {
      await t.cleanup();
      report('tagihan rutin');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('perbaikan review B5: nama tabungan beda huruf/spasi, pesan server', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(savingsProvider, (_, _) {});
    container.listen(targetProvider, (_, _) {});
    await settle();
    final savings = container.read(savingsProvider.notifier);
    final target = container.read(targetProvider.notifier);
    t.savingNames.addAll({'E2E Tab Case', 'e2e tab case '});
    try {
      final walletId = await t.wallet('E2E Review W', 100000);
      await db.from('savings').insert([
        {'user_id': userId, 'name': 'E2E Tab Case', 'amount': 100000},
        {'user_id': userId, 'name': 'e2e tab case ', 'amount': 50000},
      ]);
      await savings.fetchSavings();
      await savings.fetchWallets();
      final keys = container.read(savingsProvider).groupedSavings.keys.where((k) => k.toLowerCase() == 'e2e tab case');
      check('V1 app menampilkan satu kelompok untuk dua ejaan', keys.length == 1, keys.toList());

      final r1 = await savings.processSavingTransaction(
          isDeposit: false, savingName: keys.first, amount: 120000, walletId: walletId);
      check('V2 tarik 120.000 dari kelompok 150.000 (dua ejaan) diterima', r1 == null, r1);
      final rows = await db.from('savings').select('amount').eq('user_id', userId).ilike('name', '%e2e tab case%');
      final total = rows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
      check('V2 sisa kelompok 30.000', total == 30000, total);

      final r2 = await savings.processSavingTransaction(
          isDeposit: false, savingName: 'e2e tab case ', amount: 40000, walletId: walletId);
      check('V3 tarik 40.000 dari sisa 30.000 ditolak lewat ejaan lain', r2 == 'Saldo tabungan tidak cukup! Sisa: Rp 30.000', r2);

      final r3 = await savings.processSavingTransaction(isDeposit: true, savingName: keys.first, amount: 0, walletId: walletId);
      check('V4 setor 0 → pesan server "Isi nominal dengan benar!"', r3 == 'Isi nominal dengan benar!', r3);

      await target.addTarget(name: 'E2E Target Review', targetAmount: 100000);
      final tid = (await db.from('targets').select('id').eq('user_id', userId).eq('name', 'E2E Target Review').single())['id'] as int;
      t.targets.add(tid);
      await target.fetchTargets();
      await target.fetchWallets();
      final tm = container.read(targetProvider).targets.firstWhere((x) => x.id == tid);
      final r4 = await target.depositToTarget(target: tm, rawAmount: 0, walletId: walletId);
      check('V5 nabung target 0 → pesan server "Nominal tidak boleh kosong!"', r4 == 'Nominal tidak boleh kosong!', r4);
    } finally {
      await t.cleanup();
      report('review');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    if (_skip) return;
    container.dispose();
    await db.auth.signOut();
  });
}
