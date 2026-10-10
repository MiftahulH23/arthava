@Tags(['e2e'])
library;

// E2E backend B3 + B4 terhadap Supabase sungguhan, lewat provider ASLI app
// (bukan fake): dompet (favorit, saldo minimal, transfer), pengaturan
// "hitung saldo minimal", simpan/edit/hapus transaksi dan saldo dompet, total
// Riwayat & Statistik (transaksi utang dikecualikan).
//
// Pakai akun TEST + dompet sementara "E2E …" yang dihapus lagi di akhir.
// Kredensial lewat environment, tidak disimpan di repo:
//
//   E2E_EMAIL=... E2E_PASSWORD=... flutter test test/e2e/wallet_transaction_e2e_test.dart
//
// Tanpa env, test di-skip (tidak ikut `flutter test` biasa).
import '../../tool/e2e/e2e_env.dart';
import 'dart:io';

import 'package:arthava/models/transaction_model.dart';
import 'package:arthava/providers/home_provider.dart';
import 'package:arthava/providers/input_transaction_provider.dart';
import 'package:arthava/providers/stats_provider.dart';
import 'package:arthava/providers/transaction_history_provider.dart';
import 'package:arthava/providers/user_settings_provider.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// Transitif lewat supabase_flutter; hanya untuk menyiapkan test.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _email = Platform.environment['E2E_EMAIL'];
final _env = readSupabaseEnv();
final _password = Platform.environment['E2E_PASSWORD'];

late SupabaseClient db;
late ProviderContainer container;
final _failures = <String>[];

void check(String label, bool ok, [Object? detail]) {
  if (!ok) _failures.add(label);
  // ignore: avoid_print
  print('${ok ? 'PASS' : 'FAIL'}  $label${ok || detail == null ? '' : '  ->  $detail'}');
}

Future<double> balance(int walletId) async {
  final row = await db.from('wallets').select('balance').eq('id', walletId).single();
  return (row['balance'] as num).toDouble();
}

/// Menunggu fetch pertama provider (build() menjadwalkan fetchAll lewat microtask).
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 1500));

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() async {
    if (_email == null || _password == null || _env == null) return;
    HttpOverrides.global = null; // flutter test memblokir HTTP; E2E butuh jaringan sungguhan.
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('id_ID', null);
    await Supabase.initialize(
      url: _env!.url,
      anonKey: _env!.anonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false, localStorage: EmptyLocalStorage()),
    );
    db = Supabase.instance.client;
    await db.auth.signInWithPassword(email: _email!, password: _password!);
    container = ProviderContainer();
  });

  test('backend dompet, pengaturan, dan transaksi (B3 + B4)', () async {
    final userId = db.auth.currentUser!.id;
    final today = DateTime.now();
    final createdWallets = <int>[];
    final createdDebts = <int>[];
    bool? originalIncludeMin;

    // Provider autoDispose: tetap hidup selama test.
    container.listen(walletProvider, (_, _) {});
    container.listen(userSettingsProvider, (_, _) {});
    container.listen(homeProvider, (_, _) {});
    container.listen(inputTransactionProvider, (_, _) {});
    container.listen(transactionHistoryProvider(true), (_, _) {});
    container.listen(transactionHistoryProvider(false), (_, _) {});
    container.listen(statsProvider, (_, _) {});
    await settle();

    final wallets = container.read(walletProvider.notifier);
    try {
      // ---------- Dompet ----------
      await wallets.addWallet(name: 'E2E A', balance: 1000000, color: '#1E3A8A', minBalance: 200000);
      await wallets.addWallet(name: 'E2E B', balance: 500000, color: '#E65100');
      final rows = await db.from('wallets').select().eq('user_id', userId).like('name', 'E2E %');
      final a = rows.firstWhere((r) => r['name'] == 'E2E A');
      final b = rows.firstWhere((r) => r['name'] == 'E2E B');
      final aId = a['id'] as int, bId = b['id'] as int;
      createdWallets.addAll([aId, bId]);
      check('W1 tambah dompet: saldo minimal 200.000 tersimpan, bukan favorit',
          (a['min_balance'] as num) == 200000 && a['is_favorite'] == false, a);

      await wallets.setFavorite(aId, true);
      final fav = await db.from('wallets').select('is_favorite').eq('id', aId).single();
      check('W2 jadikan favorit tersimpan', fav['is_favorite'] == true, fav);
      check('W2 state provider ikut favorit',
          container.read(walletProvider).wallets.firstWhere((w) => w.id == aId).isFavorite);

      await wallets.updateWallet(id: aId, name: 'E2E A', balance: 1000000, color: '#1E3A8A', minBalance: 300000);
      final upd = await db.from('wallets').select('min_balance').eq('id', aId).single();
      check('W3 ubah saldo minimal jadi 300.000', (upd['min_balance'] as num) == 300000, upd);

      await wallets.transfer(sourceId: aId, destId: bId, amount: 100000);
      check('W4 transfer 100.000 A->B: A 900.000', await balance(aId) == 900000, await balance(aId));
      check('W4 transfer 100.000 A->B: B 600.000', await balance(bId) == 600000, await balance(bId));

      Object? err5;
      try {
        await wallets.transfer(sourceId: aId, destId: bId, amount: 99000000);
      } catch (e) {
        err5 = e;
      }
      check('W5 transfer melebihi saldo ditolak', err5 != null);
      check('W5 saldo tidak berubah', await balance(aId) == 900000 && await balance(bId) == 600000);

      // ---------- Pengaturan saldo minimal ----------
      final settings = container.read(userSettingsProvider.notifier);
      await settings.fetch();
      originalIncludeMin = container.read(userSettingsProvider).includeMinBalance;
      await settings.setIncludeMinBalance(!originalIncludeMin);
      final prof = await db.from('profiles').select('include_min_balance').eq('id', userId).maybeSingle();
      check('S1 pengaturan "hitung saldo minimal" tersimpan di profiles',
          prof != null && prof['include_min_balance'] == !originalIncludeMin,
          prof ?? 'baris profiles untuk user ini TIDAK ADA');
      await container.read(homeProvider.notifier).getUserProfile();
      check('S2 Beranda membaca nilai pengaturan yang sama',
          container.read(homeProvider).includeMinBalance == !originalIncludeMin,
          container.read(homeProvider).includeMinBalance);

      // ---------- Transaksi ----------
      final expenseCat = (await db
              .from('categories')
              .select('id, name')
              .eq('is_expense', true)
              .or('user_id.is.null,user_id.eq.$userId')
              .not('name', 'ilike', '%tabung%')
              .not('name', 'ilike', '%sistem%')
              .not('name', 'like', 'E2E %') // kategori sementara file E2E lain
              .limit(1))
          .single;
      final incomeCat = (await db
              .from('categories')
              .select('id, name')
              .eq('is_expense', false)
              .or('user_id.is.null,user_id.eq.$userId')
              .not('name', 'ilike', '%tabung%')
              .not('name', 'ilike', '%sistem%')
              .not('name', 'like', 'E2E %') // kategori sementara file E2E lain
              .limit(1))
          .single;

      final input = container.read(inputTransactionProvider.notifier);
      await input.fetchWallets();

      Future<TransactionSaveResult> save({
        required String amount,
        required int categoryId,
        required int walletId,
        required bool isExpense,
        TransactionModel? edit,
        String note = 'E2E',
      }) =>
          input.saveTransaction(
            amountText: amount,
            noteText: note,
            selectedCategoryId: categoryId,
            selectedWalletId: walletId,
            isExpense: isExpense,
            isFromSaving: false,
            selectedSavingName: null,
            selectedDate: today,
            hiddenSavingMarker: null,
            isReadOnly: false,
            transactionToEdit: edit,
            initialIsExpense: isExpense,
          );

      Future<TransactionModel> lastTrx(int walletId) async {
        final r = await db
            .from('transactions')
            .select('*, categories(*)')
            .eq('wallet_id', walletId)
            .order('id', ascending: false)
            .limit(1)
            .single();
        return TransactionModel.fromJson(r);
      }

      final r1 = await save(amount: '50.000', categoryId: expenseCat['id'] as int, walletId: aId, isExpense: true);
      check('T1 simpan pengeluaran 50.000: sukses', r1.success, r1.message);
      check('T1 saldo A 900.000 -> 850.000', await balance(aId) == 850000, await balance(aId));
      final t1 = await lastTrx(aId);
      check('T1 baris transaksi tersimpan (50.000, dompet A, tanggal hari ini)',
          t1.amount == 50000 && _day(t1.date) == _day(today), '${t1.amount} ${t1.date}');

      final r2 = await save(amount: '80.000', categoryId: expenseCat['id'] as int, walletId: aId, isExpense: true, edit: t1);
      check('T2 edit jadi 80.000: sukses', r2.success, r2.message);
      check('T2 saldo A 820.000', await balance(aId) == 820000, await balance(aId));

      final t2 = (await db.from('transactions').select('*, categories(*)').eq('id', t1.id).single());
      final r3 = await save(
          amount: '80.000', categoryId: expenseCat['id'] as int, walletId: bId, isExpense: true, edit: TransactionModel.fromJson(t2));
      check('T3 pindah ke dompet B: sukses', r3.success, r3.message);
      check('T3 saldo A kembali 900.000', await balance(aId) == 900000, await balance(aId));
      check('T3 saldo B 600.000 -> 520.000', await balance(bId) == 520000, await balance(bId));

      final r4 = await save(amount: '20.000', categoryId: incomeCat['id'] as int, walletId: bId, isExpense: false);
      check('T4 simpan pemasukan 20.000 ke B: sukses', r4.success, r4.message);
      check('T4 saldo B 540.000', await balance(bId) == 540000, await balance(bId));

      final r5 = await save(amount: '', categoryId: expenseCat['id'] as int, walletId: aId, isExpense: true);
      check('T5 nominal kosong ditolak dengan pesan', !r5.success && r5.message.contains('wajib'), r5.message);

      // Utang ke dompet A: transaksi bertag [DEBT_ID:] tidak dihitung di total.
      final debtId = await db.rpc('create_debt', params: {
        'p_name': 'E2E Utang', 'p_type': 'payable', 'p_amount': 300000,
        'p_loan_date': _day(today), 'p_due_date': null, 'p_notes': null, 'p_wallet_id': aId,
      }) as int;
      createdDebts.add(debtId);

      final expHistory = container.read(transactionHistoryProvider(true).notifier);
      expHistory.toggleWalletFilter(bId, true);
      await expHistory.fetchTransactions();
      final hB = container.read(transactionHistoryProvider(true));
      check('H1 Riwayat pengeluaran dompet B: total 80.000',
          hB.totalAmount == 80000, '${hB.totalAmount} (${hB.transactions.length} trx)');

      final incHistory = container.read(transactionHistoryProvider(false).notifier);
      incHistory.toggleWalletFilter(aId, true);
      await incHistory.fetchTransactions();
      final hA = container.read(transactionHistoryProvider(false));
      final hasDebtRow = hA.transactions.any((t) => (t.note ?? '').contains('[DEBT_ID:'));
      check('H2 Riwayat pemasukan dompet A: baris utang tampil tapi total 0',
          hasDebtRow && hA.totalAmount == 0, '${hA.totalAmount}, debtRow=$hasDebtRow');

      final stats = container.read(statsProvider.notifier);
      stats.setIsExpense(false);
      stats.toggleWalletFilter(aId, true);
      await stats.fetchStats();
      check('H3 Statistik pemasukan dompet A: utang dikecualikan (total 0)',
          container.read(statsProvider).totalAmount == 0, container.read(statsProvider).totalAmount);

      Object? err6;
      try {
        await incHistory.deleteTransaction(hA.transactions.firstWhere((t) => (t.note ?? '').contains('[DEBT_ID:')));
      } catch (e) {
        err6 = e;
      }
      check('H4 hapus transaksi utang dari Riwayat ditolak', err6 != null);

      final expTrx = container.read(transactionHistoryProvider(true)).transactions.firstWhere((t) => t.id == t1.id);
      await expHistory.deleteTransaction(expTrx);
      check('T6 hapus pengeluaran 80.000: saldo B kembali 620.000', await balance(bId) == 620000, await balance(bId));
      final gone = await db.from('transactions').select('id').eq('id', t1.id);
      check('T6 baris transaksi terhapus', gone.isEmpty);

      // ---------- Beranda ----------
      await container.read(homeProvider.notifier).refreshData();
      final home = container.read(homeProvider);
      check('B1 Beranda memuat dompet E2E (favorit A ikut)',
          home.wallets.any((w) => w.id == aId && w.isFavorite) && home.wallets.any((w) => w.id == bId));
      check('B2 kartu ringkasan Utang di Beranda terisi (utang E2E aktif)',
          home.summary.debt != null, home.summary.debt?.name);
    } finally {
      for (final id in createdDebts) {
        try {
          await db.rpc('delete_debt', params: {'p_debt_id': id, 'p_refund': false});
        } catch (_) {}
      }
      for (final id in createdWallets) {
        await db.from('transactions').delete().eq('wallet_id', id);
        await db.from('wallets').delete().eq('id', id);
      }
      if (originalIncludeMin != null) {
        await db.from('profiles').update({'include_min_balance': originalIncludeMin}).eq('id', userId);
      }
      // ignore: avoid_print
      print(_failures.isEmpty ? '\nSEMUA LULUS' : '\n${_failures.length} GAGAL: ${_failures.join(' | ')}');
    }
    expect(_failures, isEmpty);
  }, skip: _email == null || _password == null || _env == null, timeout: const Timeout(Duration(minutes: 3)));

  test('operasi uang bersamaan (B4b)', () async {
    _failures.clear();
    final userId = db.auth.currentUser!.id;
    final today = DateTime.now();
    final walletIds = <int>[];
    int? recurringId;

    container.listen(walletProvider, (_, _) {});
    container.listen(homeProvider, (_, _) {});
    container.listen(inputTransactionProvider, (_, _) {});
    container.listen(transactionHistoryProvider(true), (_, _) {});
    await settle();

    Future<int> newWallet(String name, double balance) async {
      final w = await db
          .from('wallets')
          .insert({'user_id': userId, 'name': name, 'balance': balance, 'color': '#1E3A8A'})
          .select('id')
          .single();
      walletIds.add(w['id'] as int);
      return w['id'] as int;
    }

    final expenseCat = (await db
            .from('categories')
            .select('id')
            .eq('is_expense', true)
            .or('user_id.is.null,user_id.eq.$userId')
            .not('name', 'ilike', '%tabung%')
            .not('name', 'ilike', '%sistem%')
            .not('name', 'like', 'E2E %') // kategori sementara file E2E lain
            .limit(1))
        .single['id'] as int;
    final hadWithdrawCategory = (await db
            .from('categories')
            .select('id')
            .eq('user_id', userId)
            .eq('is_expense', false)
            .ilike('name', '%Cair%'))
        .isNotEmpty;

    final input = container.read(inputTransactionProvider.notifier);
    final wallets = container.read(walletProvider.notifier);

    Future<TransactionSaveResult> save(int? walletId, String amount,
            {TransactionModel? edit, bool fromSaving = false, String? savingName}) =>
        input.saveTransaction(
          amountText: amount,
          noteText: 'E2E konkuren',
          selectedCategoryId: expenseCat,
          selectedWalletId: walletId,
          isExpense: true,
          isFromSaving: fromSaving,
          selectedSavingName: savingName,
          selectedDate: today,
          hiddenSavingMarker: null,
          isReadOnly: false,
          transactionToEdit: edit,
          initialIsExpense: true,
        );

    try {
      // C1: dua simpan bersamaan, 5 ronde.
      final c1 = await newWallet('E2E C1', 1000000);
      await input.fetchWallets();
      var wrongRounds = 0;
      for (var round = 0; round < 5; round++) {
        final before = await balance(c1);
        await Future.wait([save(c1, '10.000'), save(c1, '10.000')]);
        if (await balance(c1) != before - 20000) wrongRounds++;
      }
      final c1Rows = await db.from('transactions').select('id').eq('wallet_id', c1);
      check('C1 dua simpan bersamaan x5: saldo selalu turun 20.000', wrongRounds == 0, '$wrongRounds ronde salah');
      check('C1 10 baris transaksi tercatat', c1Rows.length == 10, c1Rows.length);

      // C2: dua transfer bersamaan yang hanya cukup untuk satu.
      final cx = await newWallet('E2E CX', 150000);
      final cy = await newWallet('E2E CY', 0);
      await wallets.fetchWallets();
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          wallets
              .transfer(sourceId: cx, destId: cy, amount: 100000)
              .then<Object?>((_) => null, onError: (Object e) => e),
      ]);
      final errors = results.whereType<Object>().toList();
      check('C2 dua transfer bersamaan: tepat satu berhasil', errors.length == 1, results);
      check('C2 pesan penolakan "Saldo dompet E2E CX tidak cukup!"',
          errors.length == 1 && errors.single.toString().contains('Saldo dompet E2E CX tidak cukup!'), errors);
      check('C2 saldo X 50.000 & Y 100.000', await balance(cx) == 50000 && await balance(cy) == 100000,
          '${await balance(cx)} / ${await balance(cy)}');

      // C3: hapus baris yang sama dua kali bersamaan.
      final c3 = await newWallet('E2E C3', 500000);
      await input.fetchWallets();
      await save(c3, '30.000');
      final c3Trx = TransactionModel.fromJson(
          await db.from('transactions').select('*, categories(*)').eq('wallet_id', c3).single());
      final history = container.read(transactionHistoryProvider(true).notifier);
      await Future.wait([
        for (var i = 0; i < 2; i++)
          history.deleteTransaction(c3Trx).then<Object?>((_) => null, onError: (Object e) => e),
      ]);
      check('C3 hapus ganda bersamaan: saldo kembali tepat 500.000', await balance(c3) == 500000, await balance(c3));

      // C4: tagihan rutin jatuh tempo, dijalankan dua kali bersamaan.
      final cz = await newWallet('E2E CZ', 1000000);
      final start = today.subtract(const Duration(days: 2));
      final rec = await db
          .from('recurring_transactions')
          .insert({
            'user_id': userId,
            'category_id': expenseCat,
            'wallet_id': cz,
            'amount': 25000,
            'note': 'E2E Rutin',
            'frequency': 'Harian',
            'start_date': _day(start),
            'next_run_date': _day(start),
            'is_active': true,
          })
          .select('id')
          .single();
      recurringId = rec['id'] as int;
      final home = container.read(homeProvider.notifier);
      await Future.wait([home.checkRecurringTransactions(), home.checkRecurringTransactions()]);
      final recTrx =
          await db.from('transactions').select('id').eq('wallet_id', cz).like('note', 'E2E Rutin (Otomatis: Harian)%');
      check('C4 tagihan rutin 3 hari, dijalankan dua kali bersamaan: tepat 3 transaksi', recTrx.length == 3,
          recTrx.length);
      check('C4 saldo turun tepat 75.000', await balance(cz) == 925000, await balance(cz));
      final recRow = await db.from('recurring_transactions').select('next_run_date').eq('id', recurringId).single();
      check('C4 jadwal maju ke besok', recRow['next_run_date'] == _day(today.add(const Duration(days: 1))), recRow);

      // C5: dua pemakaian tabungan bersamaan melebihi sisa.
      await db.from('savings').insert({'user_id': userId, 'name': 'E2E Tab', 'amount': 100000});
      await input.fetchSavingsBalances();
      final c5 = await Future.wait([
        save(null, '70.000', fromSaving: true, savingName: 'E2E Tab'),
        save(null, '70.000', fromSaving: true, savingName: 'E2E Tab'),
      ]);
      final ok = c5.where((r) => r.success).length;
      final rejected = c5.where((r) => !r.success && r.message.startsWith('Saldo tabungan tidak cukup!')).length;
      check('C5 dua pakai tabungan bersamaan: tepat satu berhasil, satu ditolak', ok == 1 && rejected == 1,
          c5.map((r) => r.message).toList());
      final savingRows = await db.from('savings').select('amount').eq('user_id', userId).eq('name', 'E2E Tab');
      final savingSum = savingRows.fold<num>(0, (sum, r) => sum + (r['amount'] as num));
      check('C5 sisa tabungan 30.000', savingSum == 30000, savingSum);

      // C6: edit transaksi yang dompetnya sudah dihapus.
      final cd = await newWallet('E2E CD', 100000);
      final ce = await newWallet('E2E CE', 100000);
      await input.fetchWallets();
      await save(cd, '10.000');
      final c6Trx = TransactionModel.fromJson(
          await db.from('transactions').select('*, categories(*)').eq('wallet_id', cd).single());
      await db.from('wallets').delete().eq('id', cd);
      walletIds.remove(cd);
      await input.fetchWallets();
      final r6 = await save(ce, '15.000', edit: c6Trx);
      check('C6 edit transaksi yang dompet lamanya dihapus: sukses', r6.success, r6.message);
      check('C6 dompet baru terpotong 15.000', await balance(ce) == 85000, await balance(ce));

      // C7: RPC menolak dompet yang bukan milik user.
      Object? err7;
      try {
        await db.rpc('save_transaction', params: {
          'p_id': null,
          'p_category_id': expenseCat,
          'p_wallet_id': -1,
          'p_amount': 1000,
          'p_date': _day(today),
          'p_note': 'E2E C7',
        });
      } catch (e) {
        err7 = e;
      }
      final c7Rows = await db.from('transactions').select('id').eq('note', 'E2E C7');
      check('C7 dompet asing ditolak "Dompet tidak ditemukan."',
          err7 is PostgrestException && err7.message.contains('Dompet tidak ditemukan.'), err7);
      check('C7 tidak ada transaksi tercatat', c7Rows.isEmpty, c7Rows.length);
    } finally {
      final savingIds = (await db.from('savings').select('id').eq('user_id', userId).eq('name', 'E2E Tab'))
          .map((r) => r['id'])
          .toList();
      for (final id in savingIds) {
        await db.from('transactions').delete().like('note', '%[SAVING_ID:$id]%');
      }
      await db.from('savings').delete().eq('user_id', userId).eq('name', 'E2E Tab');
      if (recurringId != null) await db.from('recurring_transactions').delete().eq('id', recurringId);
      for (final id in walletIds) {
        await db.from('transactions').delete().eq('wallet_id', id);
        await db.from('wallets').delete().eq('id', id);
      }
      await db.from('transactions').delete().eq('user_id', userId).eq('note', 'E2E konkuren');
      if (!hadWithdrawCategory) {
        try {
          await db.from('categories').delete().eq('user_id', userId).eq('name', 'Pencairan Tabungan');
        } catch (_) {}
      }
      // ignore: avoid_print
      print(_failures.isEmpty ? '\nSEMUA LULUS (konkuren)' : '\n${_failures.length} GAGAL (konkuren): ${_failures.join(' | ')}');
    }
    expect(_failures, isEmpty);
  }, skip: _email == null || _password == null || _env == null, timeout: const Timeout(Duration(minutes: 4)));

  test('jadwal rutin & transfer (perbaikan review B4b)', () async {
    _failures.clear();
    final userId = db.auth.currentUser!.id;
    final today = DateTime.now();
    final walletIds = <int>[];
    final recurringIds = <int>[];

    container.listen(walletProvider, (_, _) {});
    await settle();

    Future<int> newWallet(String name, double balance) async {
      final w = await db
          .from('wallets')
          .insert({'user_id': userId, 'name': name, 'balance': balance, 'color': '#1E3A8A'})
          .select('id')
          .single();
      walletIds.add(w['id'] as int);
      return w['id'] as int;
    }

    final expenseCat = (await db
            .from('categories')
            .select('id')
            .eq('is_expense', true)
            .or('user_id.is.null,user_id.eq.$userId')
            .not('name', 'ilike', '%tabung%')
            .not('name', 'ilike', '%sistem%')
            .not('name', 'like', 'E2E %') // kategori sementara file E2E lain
            .limit(1))
        .single['id'] as int;

    Future<int> newSchedule(int walletId, String freq, DateTime start, String note) async {
      final r = await db
          .from('recurring_transactions')
          .insert({
            'user_id': userId,
            'category_id': expenseCat,
            'wallet_id': walletId,
            'amount': 1000,
            'note': note,
            'frequency': freq,
            'start_date': _day(start),
            'next_run_date': _day(start),
            'is_active': true,
          })
          .select('id')
          .single();
      recurringIds.add(r['id'] as int);
      return r['id'] as int;
    }

    Future<List<String>> runDates(int walletId, String note) async =>
        (await db.from('transactions').select('date').eq('wallet_id', walletId).like('note', '$note%'))
            .map((r) => r['date'].toString())
            .toList();

    try {
      // C8: tanggal dari perangkat (WIB) dipakai, bukan tanggal UTC server.
      final w8 = await newWallet('E2E C8', 100000);
      final tomorrow = today.add(const Duration(days: 1));
      await newSchedule(w8, 'Harian', tomorrow, 'E2E C8');
      Object? err8;
      try {
        await db.rpc('run_due_recurring', params: {'p_today': _day(tomorrow)});
      } catch (e) {
        err8 = e;
      }
      final c8 = await runDates(w8, 'E2E C8');
      check('C8 jadwal "besok" jalan bila perangkat mengirim tanggal besok', err8 == null && c8.length == 1,
          err8 ?? c8);

      // C9: tanggal perangkat dibatasi maksimal satu hari di depan server.
      final w9 = await newWallet('E2E C9', 100000);
      await newSchedule(w9, 'Harian', today, 'E2E C9');
      try {
        await db.rpc('run_due_recurring', params: {'p_today': _day(today.add(const Duration(days: 10)))});
      } catch (_) {}
      final c9 = await runDates(w9, 'E2E C9');
      check('C9 tanggal perangkat +10 hari dibatasi (maks 2 eksekusi, bukan 11)', c9.isNotEmpty && c9.length <= 2,
          c9.length);

      // C10: tagihan bulanan tanggal 31 tetap di akhir bulan, tidak bergeser ke 28.
      final year = today.month >= 4 ? today.year : today.year - 1;
      final w10 = await newWallet('E2E C10', 10000000);
      await newSchedule(w10, 'Bulanan', DateTime(year, 1, 31), 'E2E C10');
      try {
        await db.rpc('run_due_recurring', params: {'p_today': _day(today)});
      } catch (_) {
        await container.read(homeProvider.notifier).checkRecurringTransactions();
      }
      final c10 = await runDates(w10, 'E2E C10');
      check('C10 Februari jatuh di akhir bulan', c10.any((d) => d.startsWith('$year-02-2')), c10);
      check('C10 Maret kembali ke tanggal 31 (bukan 28)', c10.contains('$year-03-31') && !c10.contains('$year-03-28'),
          c10);

      // C11: penolakan transfer dari server menyegarkan saldo di layar.
      final p = await newWallet('E2E CP', 100000);
      final q = await newWallet('E2E CQ', 0);
      final wallets = container.read(walletProvider.notifier);
      await wallets.fetchWallets();
      await db.from('wallets').update({'balance': 30000}).eq('id', p); // berubah dari perangkat lain
      Object? err11;
      try {
        await wallets.transfer(sourceId: p, destId: q, amount: 50000);
      } catch (e) {
        err11 = e;
      }
      check('C11 transfer ditolak server "Saldo dompet E2E CP tidak cukup!"',
          err11.toString().contains('Saldo dompet E2E CP tidak cukup!'), err11);
      final shown = container.read(walletProvider).wallets.firstWhere((w) => w.id == p).balance;
      check('C11 saldo di layar ikut diperbarui ke 30.000', shown == 30000, shown);

      // C7 (lanjutan): id transaksi dan kategori yang tidak dimiliki ditolak.
      Future<Object?> rpcError(Map<String, dynamic> params) async {
        try {
          await db.rpc('save_transaction', params: params);
          return null;
        } catch (e) {
          return e;
        }
      }

      final e7a = await rpcError({
        'p_id': -1, 'p_category_id': expenseCat, 'p_wallet_id': q,
        'p_amount': 1000, 'p_date': _day(today), 'p_note': 'E2E C7a',
      });
      check('C7a id transaksi asing ditolak "Transaksi tidak ditemukan."',
          e7a is PostgrestException && e7a.message.contains('Transaksi tidak ditemukan.'), e7a);
      final e7b = await rpcError({
        'p_id': null, 'p_category_id': -1, 'p_wallet_id': q,
        'p_amount': 1000, 'p_date': _day(today), 'p_note': 'E2E C7b',
      });
      check('C7b kategori asing ditolak "Kategori tidak ditemukan."',
          e7b is PostgrestException && e7b.message.contains('Kategori tidak ditemukan.'), e7b);
    } finally {
      for (final id in recurringIds) {
        await db.from('recurring_transactions').delete().eq('id', id);
      }
      for (final id in walletIds) {
        await db.from('transactions').delete().eq('wallet_id', id);
        await db.from('wallets').delete().eq('id', id);
      }
      // ignore: avoid_print
      print(_failures.isEmpty ? '\nSEMUA LULUS (review)' : '\n${_failures.length} GAGAL (review): ${_failures.join(' | ')}');
    }
    expect(_failures, isEmpty);
  }, skip: _email == null || _password == null || _env == null, timeout: const Timeout(Duration(minutes: 3)));

  tearDownAll(() async {
    if (_email == null || _env == null) return;
    container.dispose();
    await db.auth.signOut();
  });
}
