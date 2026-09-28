@Tags(['e2e'])
library;

// E2E backend B6 (Investasi, Zakat & Sedekah, Kategori, Kalender, Export, AI
// Advisor) terhadap Supabase sungguhan, lewat kode ASLI app. Data sementara
// bernama "E2E …" dihapus lagi di akhir; transaksi uji memakai tahun 2099
// supaya tidak bercampur dengan data asli akun.
//
//   E2E_EMAIL=... E2E_PASSWORD=... flutter test test/e2e/tools_assets_e2e_test.dart
//
// Tanpa env, test di-skip (tidak ikut `flutter test` biasa).
import 'dart:io';

import 'package:catat_uang_app/models/investment_model.dart';
import 'package:catat_uang_app/providers/calendar_provider.dart';
import 'package:catat_uang_app/providers/category_provider.dart';
import 'package:catat_uang_app/providers/investment_provider.dart';
import 'package:catat_uang_app/services/ai_context_service.dart';
import 'package:catat_uang_app/services/export_report_service.dart';
import 'package:catat_uang_app/services/zakat_service.dart';
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

/// Menunggu fetch pertama provider (build() menjadwalkan fetch lewat microtask).
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 1500));

/// Data sementara satu test; semuanya dihapus di [cleanup].
class _Temp {
  final wallets = <int>[];
  final categories = <int>[];
  final investments = <int>[];
  final savings = <int>[];
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

  Future<void> trx({required int categoryId, int? walletId, required double amount, required String date, String? note}) async {
    await db.from('transactions').insert({
      'user_id': userId, 'category_id': categoryId, 'wallet_id': walletId,
      'amount': amount, 'date': date, 'note': note,
    });
  }

  Future<void> cleanup() async {
    for (final id in investments) {
      await db.from('investments').delete().eq('id', id);
    }
    for (final id in savings) {
      await db.from('savings').delete().eq('id', id);
    }
    for (final id in wallets) {
      await db.from('transactions').delete().eq('wallet_id', id);
      await db.from('wallets').delete().eq('id', id);
    }
    for (final id in categories) {
      await db.from('transactions').delete().eq('category_id', id);
      await db.from('categories').delete().eq('id', id);
    }
    // Kategori sistem ("Investasi", "Zakat", …) yang baru dibuat test ini:
    // hapus bila tidak dipakai transaksi mana pun. Hanya nama sistem milik file
    // ini — file E2E lain berjalan bersamaan di akun yang sama.
    final now = await db
        .from('categories')
        .select('id')
        .eq('user_id', userId)
        .inFilter('name', ['Investasi', 'Hasil Jual Investasi', 'Zakat', 'Sedekah']);
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

  test('investasi: beli, top up, jual, bersamaan, update nilai, hapus', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(investmentProvider, (_, _) {});
    await settle();
    final inv = container.read(investmentProvider.notifier);
    try {
      final walletId = await t.wallet('E2E Investasi W', 500000);
      await inv.fetchData();

      await inv.buyInvestment(name: 'E2E Saham', type: 'Saham', amount: 100000, walletId: walletId);
      final row = await db.from('investments').select().eq('user_id', userId).eq('name', 'E2E Saham').single();
      final invId = row['id'] as int;
      t.investments.add(invId);
      check('I1 beli 100.000: modal & nilai 100.000', (row['capital_amount'] as num) == 100000 && (row['current_value'] as num) == 100000, row);
      check('I1 dompet 500.000 → 400.000', await balance(walletId) == 400000, await balance(walletId));
      final buyTrx = await db.from('transactions').select('amount, note').eq('wallet_id', walletId);
      check('I1 transaksi "Beli Aset: E2E Saham" dari dompet',
          buyTrx.length == 1 && buyTrx.single['note'] == 'Beli Aset: E2E Saham', buyTrx);

      Object? e2;
      try {
        await inv.buyInvestment(name: 'E2E Mahal', type: 'Saham', amount: 999999, walletId: walletId);
      } catch (e) {
        e2 = e;
      }
      check('I2 beli melebihi saldo ditolak dengan pesan saldo',
          e2.toString().contains('Saldo dompet E2E Investasi W tidak cukup!'), e2);
      check('I2 saldo tidak berubah', await balance(walletId) == 400000, await balance(walletId));
      final mahal = await db.from('investments').select('id').eq('user_id', userId).eq('name', 'E2E Mahal');
      t.investments.addAll(mahal.map((r) => r['id'] as int));

      await inv.fetchData();
      await Future.wait([
        inv.buyInvestment(name: 'E2E Kripto', type: 'Kripto', amount: 50000, walletId: walletId),
        inv.buyInvestment(name: 'E2E Emas', type: 'Emas', amount: 50000, walletId: walletId),
      ]);
      final more = await db.from('investments').select('id').eq('user_id', userId).inFilter('name', ['E2E Kripto', 'E2E Emas']);
      t.investments.addAll(more.map((r) => r['id'] as int));
      check('I3 dua beli bersamaan: dompet 300.000 (tidak ada potongan hilang)', await balance(walletId) == 300000, await balance(walletId));

      await inv.fetchData();
      InvestmentModel current() => container.read(investmentProvider).investments.firstWhere((x) => x.id == invId);
      final snap = current();
      await Future.wait([
        inv.buySellInvestment(inv: snap, isBuy: true, amount: 20000, walletId: walletId),
        inv.buySellInvestment(inv: snap, isBuy: true, amount: 20000, walletId: walletId),
      ]);
      final topped = await db.from('investments').select().eq('id', invId).single();
      check('I4 dua top up bersamaan: modal 140.000', (topped['capital_amount'] as num) == 140000, topped);
      check('I4 dua top up bersamaan: dompet 260.000', await balance(walletId) == 260000, await balance(walletId));

      await inv.fetchData();
      await inv.buySellInvestment(inv: current(), isBuy: false, amount: 40000, walletId: walletId);
      final sold = await db.from('investments').select().eq('id', invId).single();
      check('I5 jual 40.000: nilai 100.000, modal 100.000',
          (sold['current_value'] as num) == 100000 && (sold['capital_amount'] as num) == 100000, sold);
      check('I5 dompet +40.000 = 300.000', await balance(walletId) == 300000, await balance(walletId));

      Object? e6;
      try {
        await inv.fetchData();
        await inv.buySellInvestment(inv: current(), isBuy: false, amount: 500000, walletId: walletId);
      } catch (e) {
        e6 = e;
      }
      check('I6 jual melebihi nilai aset ditolak', e6.toString().contains('Nominal penarikan melebihi nilai aset saat ini!'), e6);
      check('I6 tolakan tidak memunculkan spinner daftar di belakang sheet', container.read(investmentProvider).isLoading == false);

      await inv.updateInvestmentValue(invId, 150000);
      final upd = await db.from('investments').select('current_value, capital_amount').eq('id', invId).single();
      check('I7 update nilai 150.000 (untung 50.000), dompet tidak berubah',
          (upd['current_value'] as num) == 150000 && await balance(walletId) == 300000, upd);
      check('I7 state provider: total nilai ikut', container.read(investmentProvider).investments.firstWhere((x) => x.id == invId).currentValue == 150000);

      // Jual ke dompet bersaldo minus: boleh (transaksi biasa memang boleh membuat saldo minus).
      final minusWallet = await t.wallet('E2E Minus W', -50000);
      await inv.fetchData();
      Object? e9;
      try {
        await inv.buySellInvestment(inv: current(), isBuy: false, amount: 100000, walletId: minusWallet);
      } catch (e) {
        e9 = e;
      }
      check('I9 jual ke dompet bersaldo minus diterima: dompet -50.000 → 50.000',
          e9 == null && await balance(minusWallet) == 50000, (e9, await balance(minusWallet)));

      await inv.deleteInvestment(invId);
      final gone = await db.from('investments').select('id').eq('id', invId);
      check('I8 hapus aset', gone.isEmpty, gone);
    } finally {
      await t.cleanup();
      report('investasi');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('kategori & kalender', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    container.listen(categoryProvider, (_, _) {});
    container.listen(calendarProvider, (_, _) {});
    await settle();
    final cats = container.read(categoryProvider.notifier);
    try {
      await cats.fetchCategories(isExpense: true);
      await cats.addCategory('E2E Bensin');
      final row = await db.from('categories').select().eq('user_id', userId).eq('name', 'E2E Bensin').single();
      final catId = row['id'] as int;
      t.categories.add(catId);
      check('K1 tambah kategori pengeluaran', row['is_expense'] == true, row);
      check('K1 state provider memuat kategori', container.read(categoryProvider).categories.any((c) => c.id == catId));

      await cats.editCategory(catId, 'E2E BBM');
      final ed = await db.from('categories').select('name').eq('id', catId).single();
      check('K2 ganti nama', ed['name'] == 'E2E BBM', ed);

      final walletId = await t.wallet('E2E Kalender W', 1000000);
      await t.trx(categoryId: catId, walletId: walletId, amount: 45000, date: '2099-03-10', note: 'E2E isi bensin');
      Object? used;
      try {
        await cats.deleteCategory(catId);
      } catch (e) {
        used = e;
      }
      final still = await db.from('categories').select('id').eq('id', catId);
      check('K3 hapus kategori yang dipakai transaksi ditolak', used != null && still.length == 1, used);

      // Kalender: transaksi biasa tampil di tanggalnya; mutasi tabungan & utang tidak.
      final incomeCat = await t.category('E2E Gaji', isExpense: false);
      await t.trx(categoryId: incomeCat, walletId: walletId, amount: 500000, date: '2099-03-10', note: 'E2E gaji');
      final tabungCat = await t.category('E2E Tabung Masuk', isExpense: false); // bukan pola kategori sistem ("%Tabungan%" dst.) supaya tidak terpakai RPC tes lain yang berjalan bersamaan
      await t.trx(categoryId: tabungCat, walletId: walletId, amount: 20000, date: '2099-03-10', note: 'E2E nabung [SAVING_ID:0]');
      await t.trx(categoryId: catId, walletId: walletId, amount: 10000, date: '2099-03-10', note: 'E2E utang [DEBT_ID:0]');
      await container.read(calendarProvider.notifier).fetchTransactions();
      final day = container.read(calendarProvider).eventsForDay(DateTime(2099, 3, 10));
      final notes = day.map((x) => x.note).toSet();
      check('C1 kalender 10 Mar 2099: 2 transaksi (bensin & gaji)',
          day.length == 2 && notes.containsAll({'E2E isi bensin', 'E2E gaji'}), notes);

      await db.from('transactions').delete().eq('category_id', catId);
      await cats.deleteCategory(catId);
      final gone = await db.from('categories').select('id').eq('id', catId);
      check('K4 hapus kategori yang tidak dipakai', gone.isEmpty, gone);
    } finally {
      await t.cleanup();
      report('kategori & kalender');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('zakat & sedekah: bayar dari dompet, saldo kurang, bersamaan', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    final zakat = ZakatService(db);
    try {
      final walletId = await t.wallet('E2E Zakat W', 100000);

      await zakat.pay(isZakat: true, walletId: walletId, amount: 25000, note: 'Pembayaran Zakat Maal (2.5% dari harta)');
      final z = await db.from('transactions').select('amount, note, categories(name, is_expense)').eq('wallet_id', walletId).single();
      check('Z1 bayar zakat 25.000: dompet 75.000', await balance(walletId) == 75000, await balance(walletId));
      check('Z1 transaksi kategori Zakat (pengeluaran), catatan lama',
          z['categories']['name'] == 'Zakat' && z['categories']['is_expense'] == true &&
              z['note'] == 'Pembayaran Zakat Maal (2.5% dari harta)', z);

      await zakat.pay(isZakat: false, walletId: walletId, amount: 10000, note: 'E2E Sedekah Jumat');
      final sd = await db.from('transactions').select('categories(name)').eq('wallet_id', walletId).eq('note', 'E2E Sedekah Jumat').single();
      check('Z2 sedekah 10.000: kategori Sedekah, dompet 65.000',
          sd['categories']['name'].toString().contains('Sedekah') && await balance(walletId) == 65000, sd);

      Object? e0;
      try {
        await zakat.pay(isZakat: true, walletId: walletId, amount: 0, note: 'E2E nol');
      } catch (e) {
        e0 = e;
      }
      check('Z0 zakat 0 ditolak "Masukkan total harta yang valid!"', e0 is ZakatRejection && e0.message == 'Masukkan total harta yang valid!', e0);

      Object? e3;
      try {
        await zakat.pay(isZakat: false, walletId: walletId, amount: 999999, note: 'E2E kebanyakan');
      } catch (e) {
        e3 = e;
      }
      check('Z3 saldo kurang ditolak dengan pesan saldo', e3.toString().contains('Saldo dompet E2E Zakat W tidak cukup!'), e3);
      check('Z3 saldo tidak berubah', await balance(walletId) == 65000, await balance(walletId));

      await Future.wait([
        zakat.pay(isZakat: false, walletId: walletId, amount: 5000, note: 'E2E bersamaan 1'),
        zakat.pay(isZakat: false, walletId: walletId, amount: 5000, note: 'E2E bersamaan 2'),
      ]);
      check('Z4 dua sedekah bersamaan: dompet 55.000', await balance(walletId) == 55000, await balance(walletId));
    } finally {
      await t.cleanup();
      report('zakat & sedekah');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  test('export laporan & konteks AI Advisor dari data yang benar', () async {
    _failures.clear();
    final t = _Temp();
    await t.snapshotCategories();
    try {
      final walletId = await t.wallet('E2E Export W', 750000);
      final gaji = await t.category('E2E Gaji', isExpense: false);
      final makan = await t.category('E2E Makan');
      final tabung = await t.category('E2E Tabung Masuk', isExpense: false); // bukan pola kategori sistem ("%Tabungan%" dst.) supaya tidak terpakai RPC tes lain yang berjalan bersamaan
      await t.trx(categoryId: gaji, walletId: walletId, amount: 1000000, date: '2099-04-01', note: 'E2E gaji');
      await t.trx(categoryId: makan, walletId: walletId, amount: 200000, date: '2099-04-05', note: 'E2E belanja');
      await t.trx(categoryId: makan, walletId: walletId, amount: 50000, date: '2099-04-30', note: 'E2E kopi');
      await t.trx(categoryId: tabung, walletId: walletId, amount: 300000, date: '2099-04-10', note: 'E2E nabung [SAVING_ID:0]');
      await t.trx(categoryId: makan, walletId: walletId, amount: 70000, date: '2099-04-11', note: 'E2E utang [DEBT_ID:0]');
      await t.trx(categoryId: makan, walletId: walletId, amount: 99000, date: '2099-05-01', note: 'E2E bulan lain');

      final data = await loadExportReport(db, startDate: DateTime(2099, 4, 1), endDate: DateTime(2099, 4, 30, 23, 59, 59));
      check('E1 export April 2099: 3 transaksi (mutasi tabungan/utang & bulan lain tidak ikut)',
          data.transactions.length == 3, data.transactions.map((x) => x.note).toList());
      check('E2 total pemasukan 1.000.000 & pengeluaran 250.000',
          data.totalIncome == 1000000 && data.totalExpense == 250000, (data.totalIncome, data.totalExpense));
      check('E3 per kategori & terbesar',
          data.expensesByCategory['E2E Makan'] == 250000 && data.largestExpense?.amount == 200000 && data.largestIncome?.amount == 1000000,
          data.expensesByCategory);
      check('E4 dompet ikut di laporan & catatan diberi nama dompet',
          data.walletsInfo.any((w) => w['name'] == 'E2E Export W' && w['balance'] == 750000) &&
              data.transactions.every((x) => (x.note ?? '').contains('[Dompet: E2E Export W]')),
          data.transactions.map((x) => x.note).toList());

      final ctx = await buildFinancialContext(db);
      check('A1 konteks AI memuat dompet user dan saldonya', ctx.contains('* E2E Export W: Rp750.000'), ctx.split('\n').take(8).join(' / '));
      check('A2 konteks AI: rekap April 2099 tanpa mutasi tabungan/utang',
          ctx.contains('[Bulan: April 2099]') &&
              ctx.contains('- Total Pemasukan: Rp1.000.000') &&
              ctx.contains('- Total Pengeluaran: Rp250.000') &&
              ctx.contains('    - E2E Makan: Rp250.000'),
          ctx.substring(0, ctx.length.clamp(0, 900)));
    } finally {
      await t.cleanup();
      report('export & AI');
    }
    expect(_failures, isEmpty);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    if (_skip) return;
    container.dispose();
    await db.auth.signOut();
  });
}
