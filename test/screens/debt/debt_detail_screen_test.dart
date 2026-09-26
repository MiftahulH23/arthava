import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_detail_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  setUpAll(prewarmToastFont);

  DebtState state({bool paid = false}) => DebtState(
        isLoading: false,
        debts: [
          sampleDebt(
            dueDate: DateTime(2026, 9, 22),
            notes: 'Modal usaha',
            remaining: paid ? 0 : 1200000,
            status: paid ? 'paid' : 'active',
          ),
        ],
        payments: {
          1: [
            samplePayment(),
            samplePayment(id: 11, amount: 300000, date: DateTime(2026, 9, 1), walletId: null, walletName: null, transactionId: null),
          ],
        },
      );

  testWidgets('header, statistik, info, dan riwayat cicilan', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    expect(find.text('BS'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Terlambat 2 hari'), findsOneWidget);
    expect(find.text('Total Awal'), findsOneWidget);
    expect(find.text('Rp 2.000.000'), findsOneWidget);
    expect(find.text('Sisa Tagihan'), findsOneWidget);
    expect(find.text('40.0% Terbayar'), findsOneWidget);
    expect(find.text('Tanggal Pinjam'), findsOneWidget);
    expect(find.text('01 Agu 2026'), findsOneWidget);
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Modal usaha'), findsOneWidget);
    expect(find.text('RIWAYAT CICILAN'), findsOneWidget);
    expect(find.text('15 Sep 2026'), findsOneWidget);
    expect(find.text('Tanpa Dompet'), findsOneWidget);
    expect(find.text('Bayar Cicilan'), findsOneWidget);
    expect(fake.calls, contains('fetchPayments:1'));
  });

  testWidgets('utang lunas menyembunyikan tombol bayar', (tester) async {
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(FakeDebtNotifier(state(paid: true))));
    await tester.pump();
    expect(find.text('LUNAS'), findsOneWidget);
    expect(find.text('Bayar Cicilan'), findsNothing);
  });

  testWidgets('geser cicilan lalu Hapus + konfirmasi memanggil deletePayment', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.drag(find.text('15 Sep 2026'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    // Tiap baris punya tombol Hapus sendiri; ambil milik baris yang digeser.
    final row = find.ancestor(of: find.text('15 Sep 2026'), matching: find.byType(AppSwipeActions));
    await tester.tap(find.descendant(of: row, matching: find.text('Hapus')));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Cicilan?'), findsOneWidget);
    expect(find.text('Sisa tagihan bertambah Rp 500.000 dan saldo BCA dikembalikan.'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('deletePayment:1:10'));
    await flushToast(tester);
  });

  testWidgets('hapus utang bertautan dompet: pilihan "Hapus saja" + error tampil bila gagal', (tester) async {
    final fake = FakeDebtNotifier(state())..error = Exception('Utang tidak ditemukan.');
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.tap(find.byTooltip('Hapus utang'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Catatan?'), findsOneWidget);
    expect(
      find.text('Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen. Kembalikan saldo dompet seperti sebelum utang ini dicatat?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus saja'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('deleteDebt:1'));
    expect(find.text('Utang tidak ditemukan.'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('hapus & kembalikan saldo mengirim refund', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DebtDetailScreen(debtId: 1))),
      child: const Text('buka'),
    ))), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hapus utang'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus & kembalikan saldo'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('deleteDebt:1:refund'));
    expect(find.text('Utang dihapus dan saldo dikembalikan!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('utang tanpa tautan dompet: dialog dua tombol dan saldo tidak berubah', (tester) async {
    final unlinked = DebtState(
      isLoading: false,
      debts: [sampleDebt()],
      payments: {
        1: [samplePayment(walletId: null, walletName: null, transactionId: null)],
      },
    );
    final fake = FakeDebtNotifier(unlinked);
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();
    await tester.tap(find.byTooltip('Hapus utang'));
    await tester.pumpAndSettle();
    expect(
      find.text('Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen. Utang ini tidak terhubung ke saldo dompet, jadi saldo tidak berubah.'),
      findsOneWidget,
    );
    expect(find.text('Hapus & kembalikan saldo'), findsNothing);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('deleteDebt:1'));
    await flushToast(tester);
  });

  testWidgets('hapus utang tidak memunculkan "tidak ditemukan" saat kembali', (tester) async {
    final fake = _RemovingFake(state());
    await pumpApp(tester, Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DebtDetailScreen(debtId: 1))),
      child: const Text('buka'),
    ))), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hapus utang'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus saja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Data utang tidak ditemukan.'), findsNothing);
    await tester.pumpAndSettle();
    await flushToast(tester);
  });
}

class _RemovingFake extends FakeDebtNotifier {
  _RemovingFake(super.initial);

  @override
  Future<void> deleteDebt(int debtId, {bool refundWallet = false}) async {
    calls.add('deleteDebt:$debtId');
    state = state.copyWith(debts: state.debts.where((d) => d.id != debtId).toList());
  }
}
