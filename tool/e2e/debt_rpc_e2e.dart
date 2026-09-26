// Skenario uang Utang & Piutang end-to-end terhadap Supabase sungguhan.
// Memakai akun TEST (bukan akun utama) dan dompet sementara "E2E Test" yang
// dihapus lagi di akhir. Kredensial lewat environment, tidak disimpan di repo:
//
//   E2E_EMAIL=... E2E_PASSWORD=... dart run tool/e2e/debt_rpc_e2e.dart
//
// URL & anon key dibaca dari lib/main.dart.
import 'dart:io';

// Paket murni Dart yang ikut lewat supabase_flutter; alat dev, bukan kode app.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

late SupabaseClient db;
late int walletId;
int failures = 0;

void check(String label, bool ok, [Object? detail]) {
  if (!ok) failures++;
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $label${ok || detail == null ? '' : '  ->  $detail'}');
}

Future<double> balance() async {
  final row = await db.from('wallets').select('balance').eq('id', walletId).single();
  return (row['balance'] as num).toDouble();
}

Future<Map<String, dynamic>?> debt(int id) =>
    db.from('debts').select().eq('id', id).maybeSingle();

Future<List<Map<String, dynamic>>> payments(int debtId) =>
    db.from('debt_payments').select().eq('debt_id', debtId);

Future<List<Map<String, dynamic>>> taggedTransactions(int debtId) =>
    db.from('transactions').select('id, note, amount').like('note', '%[DEBT_ID:$debtId]%');

Future<Object?> rpc(String fn, Map<String, dynamic> params) => db.rpc(fn, params: params);

String day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> main() async {
  final email = Platform.environment['E2E_EMAIL'];
  final password = Platform.environment['E2E_PASSWORD'];
  if (email == null || password == null) {
    stderr.writeln('Set E2E_EMAIL dan E2E_PASSWORD.');
    exit(2);
  }
  final main = File('lib/main.dart').readAsStringSync();
  final url = RegExp(r"url:\s*'([^']+)'").firstMatch(main)!.group(1)!;
  final anonKey = RegExp(r"anonKey:\s*'([^']+)'").firstMatch(main)!.group(1)!;

  db = SupabaseClient(url, anonKey);
  final auth = await db.auth.signInWithPassword(email: email, password: password);
  final userId = auth.user!.id;
  stdout.writeln('Login sebagai $email');

  final today = day(DateTime.now());
  final created = <int>[];
  final w = await db
      .from('wallets')
      .insert({'user_id': userId, 'name': 'E2E Test', 'balance': 2000000, 'color': '#4A6CF7'})
      .select('id')
      .single();
  walletId = w['id'] as int;

  try {
    // 1. Catat utang 1.000.000 ke dompet -> saldo +1.000.000, transaksi bertag.
    final a = await rpc('create_debt', {
      'p_name': 'Tes A', 'p_type': 'payable', 'p_amount': 1000000,
      'p_loan_date': today, 'p_due_date': null, 'p_notes': 'E2E', 'p_wallet_id': walletId,
    }) as int;
    created.add(a);
    check('1 utang: saldo 2.000.000 -> 3.000.000', await balance() == 3000000, await balance());
    final aTx = await taggedTransactions(a);
    check('1 utang: 1 transaksi bertag [DEBT_ID:$a]', aTx.length == 1, aTx);

    // 2. Bayar 400.000 -> saldo -400.000, sisa 600.000.
    final p1 = await rpc('add_debt_payment', {
      'p_debt_id': a, 'p_amount': 400000, 'p_date': today, 'p_wallet_id': walletId,
    }) as int;
    check('2 bayar 400rb: saldo 2.600.000', await balance() == 2600000, await balance());
    check('2 bayar 400rb: sisa 600.000', ((await debt(a))!['remaining_amount'] as num) == 600000);

    // 3. Edit cicilan jadi 500.000 -> saldo -100.000, sisa 500.000.
    await rpc('update_debt_payment', {'p_payment_id': p1, 'p_amount': 500000, 'p_date': today});
    check('3 edit jadi 500rb: saldo 2.500.000', await balance() == 2500000, await balance());
    check('3 edit jadi 500rb: sisa 500.000', ((await debt(a))!['remaining_amount'] as num) == 500000);

    // 4. Hapus cicilan -> saldo kembali, sisa 1.000.000, aktif.
    await rpc('delete_debt_payment', {'p_payment_id': p1});
    final a4 = (await debt(a))!;
    check('4 hapus cicilan: saldo 3.000.000', await balance() == 3000000, await balance());
    check('4 hapus cicilan: sisa 1.000.000 & aktif',
        (a4['remaining_amount'] as num) == 1000000 && a4['status'] == 'active', a4);

    // 5. Bayar penuh -> LUNAS; hapus cicilan itu -> aktif lagi.
    final p2 = await rpc('add_debt_payment', {
      'p_debt_id': a, 'p_amount': 1000000, 'p_date': today, 'p_wallet_id': walletId,
    }) as int;
    check('5 bayar penuh: status paid', (await debt(a))!['status'] == 'paid');
    await rpc('delete_debt_payment', {'p_payment_id': p2});
    check('5 hapus cicilan lunas: status active lagi', (await debt(a))!['status'] == 'active');
    check('5 saldo kembali 3.000.000', await balance() == 3000000, await balance());

    // 6. Piutang 50.000.000 dari dompet (saldo kurang) -> ditolak, tidak ada data.
    final before6 = await balance();
    String? err6;
    try {
      await rpc('create_debt', {
        'p_name': 'Tes B', 'p_type': 'receivable', 'p_amount': 50000000,
        'p_loan_date': today, 'p_due_date': null, 'p_notes': null, 'p_wallet_id': walletId,
      });
    } on PostgrestException catch (e) {
      err6 = e.message;
    }
    final b = await db.from('debts').select('id').eq('name', 'Tes B');
    check('6 piutang > saldo ditolak dengan pesan saldo', err6?.contains('Saldo dompet tidak mencukupi') ?? false, err6);
    check('6 tidak ada utang "Tes B" & saldo tetap', b.isEmpty && await balance() == before6, b);

    // 7. Dua pembayaran 600.000 bersamaan (sisa 1.000.000) -> hanya satu berhasil.
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        rpc('add_debt_payment', {'p_debt_id': a, 'p_amount': 600000, 'p_date': today, 'p_wallet_id': walletId})
            .then((_) => true, onError: (_) => false),
    ]);
    check('7 dua pembayaran bersamaan: tepat satu berhasil', results.where((r) => r).length == 1, results);
    check('7 sisa 400.000 & 1 cicilan', ((await debt(a))!['remaining_amount'] as num) == 400000 &&
        (await payments(a)).length == 1);

    // Siapkan M1: utang C yang NAMANYA memuat tag utang A.
    final c = await rpc('create_debt', {
      'p_name': 'Nama [DEBT_ID:$a]', 'p_type': 'payable', 'p_amount': 10000,
      'p_loan_date': today, 'p_due_date': null, 'p_notes': null, 'p_wallet_id': walletId,
    }) as int;
    created.add(c);
    final cTxId = (await debt(c))!['transaction_id'] as int;

    // 8. Hapus utang Tes A -> utang, cicilan, transaksi bertag hilang; saldo tidak dikembalikan.
    final before8 = await balance();
    await rpc('delete_debt', {'p_debt_id': a});
    created.remove(a);
    check('8 hapus utang: data utang hilang', await debt(a) == null);
    check('8 hapus utang: cicilan hilang', (await payments(a)).isEmpty);
    // Transaksi utang C sengaja memuat teks "[DEBT_ID:a]" di catatannya (skenario M1).
    final leftover = (await taggedTransactions(a)).where((t) => t['id'] != cTxId).toList();
    check('8 hapus utang: transaksi bertag Tes A hilang', leftover.isEmpty, leftover);
    check('8 hapus utang: saldo tidak dikembalikan', await balance() == before8, await balance());
    final cTx = await db.from('transactions').select('id').eq('id', cTxId);
    check('M1 hapus Tes A tidak ikut menghapus transaksi utang C', cTx.length == 1, cTx);

    // R1–R4: hapus dengan pilihan kembalikan saldo (migrasi 202609260002).
    Future<int> newDebt(String name, String type, int amount) async {
      final id = await rpc('create_debt', {
        'p_name': name, 'p_type': type, 'p_amount': amount,
        'p_loan_date': today, 'p_due_date': null, 'p_notes': null, 'p_wallet_id': walletId,
      }) as int;
      created.add(id);
      return id;
    }
    Future<void> pay(int debtId, int amount) =>
        rpc('add_debt_payment', {'p_debt_id': debtId, 'p_amount': amount, 'p_date': today, 'p_wallet_id': walletId});
    Future<void> remove(int debtId, bool refund) async {
      await rpc('delete_debt', {'p_debt_id': debtId, 'p_refund': refund});
      created.remove(debtId);
    }

    var start = await balance();
    final r1 = await newDebt('Refund Utang', 'payable', 1000000);
    await pay(r1, 400000);
    await remove(r1, true);
    check('R1 utang + cicilan, hapus & kembalikan: saldo kembali ke awal', await balance() == start, '${await balance()} vs $start');

    start = await balance();
    final r2 = await newDebt('Refund Piutang', 'receivable', 500000);
    await pay(r2, 200000);
    await remove(r2, true);
    check('R2 piutang + terima bayar, hapus & kembalikan: saldo kembali ke awal', await balance() == start, '${await balance()} vs $start');

    start = await balance();
    final r3 = await newDebt('Hapus Saja', 'payable', 100000);
    await remove(r3, false);
    check('R3 hapus saja: saldo tetap +100.000', await balance() == start + 100000, '${await balance()} vs ${start + 100000}');

    final r4 = await newDebt('Uang Terpakai', 'payable', 1000000);
    await db.from('wallets').update({'balance': 500000}).eq('id', walletId);
    String? err4;
    try {
      await remove(r4, true);
    } on PostgrestException catch (e) {
      err4 = e.message;
    }
    check('R4 saldo tidak cukup: kembalikan ditolak dengan pesan', err4?.contains('Hapus saja') ?? false, err4);
    check('R4 utang masih ada & saldo tidak berubah', await debt(r4) != null && await balance() == 500000);
    await remove(r4, false);
  } catch (e, st) {
    failures++;
    stdout.writeln('ERROR  $e\n$st');
  } finally {
    for (final id in created) {
      try {
        await rpc('delete_debt', {'p_debt_id': id});
      } catch (_) {}
    }
    await db.from('transactions').delete().eq('wallet_id', walletId);
    await db.from('wallets').delete().eq('id', walletId);
    await db.auth.signOut();
    stdout.writeln(failures == 0 ? '\nSEMUA LULUS' : '\n$failures GAGAL');
    exit(failures == 0 ? 0 : 1);
  }
}
