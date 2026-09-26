import 'dart:async';

import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_payment_sheet.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  setUpAll(prewarmToastFont);

  group('validateDebtPayment', () {
    test('kosong atau 0 ditolak', () {
      expect(validateDebtPayment(amountText: '', maxAmount: 100, affectWallet: false, walletId: null),
          'Nominal harus lebih dari 0.');
      expect(validateDebtPayment(amountText: '0', maxAmount: 100, affectWallet: false, walletId: null),
          'Nominal harus lebih dari 0.');
    });
    test('melebihi sisa ditolak dengan pesan lama', () {
      expect(validateDebtPayment(amountText: '1.000.001', maxAmount: 1000000, affectWallet: false, walletId: null),
          'Jumlah bayar tidak boleh melebihi sisa utang!');
    });
    test('dompet wajib bila switch aktif', () {
      expect(validateDebtPayment(amountText: '500.000', maxAmount: 1000000, affectWallet: true, walletId: null),
          'Silakan pilih dompet!');
    });
    test('valid mengembalikan null', () {
      expect(validateDebtPayment(amountText: '500.000', maxAmount: 1000000, affectWallet: true, walletId: 3), isNull);
    });
  });

  test('pesan konfirmasi hapus cicilan sesuai tautan dompet', () {
    expect(deletePaymentConfirmMessage(samplePayment()),
        'Sisa tagihan bertambah Rp 500.000 dan saldo BCA dikembalikan.');
    expect(deletePaymentConfirmMessage(samplePayment(transactionId: null)),
        'Sisa tagihan bertambah Rp 500.000. Cicilan lama ini tidak terhubung ke transaksi dompet, jadi saldo dompet tidak berubah.');
    expect(deletePaymentConfirmMessage(samplePayment(transactionId: null, walletId: null, walletName: null)),
        'Sisa tagihan bertambah Rp 500.000.');
  });

  Widget opener(DebtModel debt) => Consumer(builder: (context, ref, _) {
        return TextButton(
          onPressed: () => showDebtPaymentSheet(context, debt: debt),
          child: const Text('buka'),
        );
      });

  testWidgets('bayar cicilan tanpa dompet mengirim walletId null dan menampilkan toast lama', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt], wallets: [sampleWallet()]));
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Bayar Cicilan Utang'), findsOneWidget);
    expect(find.text('Sisa Tagihan Saat Ini'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('addPayment:1:500000:null'));
    expect(find.text('Pembayaran berhasil dicatat!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('switch dompet aktif mengirim walletId terpilih dan menampilkan info lama', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt], wallets: [sampleWallet()]));
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.tap(find.byKey(const ValueKey('debt-affect-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('Info: Saldo dompet akan BERKURANG karena Anda membayar utang.'), findsOneWidget);

    await tester.tap(find.text('Pilih Dompet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCA').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('addPayment:1:500000:3'));
    await flushToast(tester);
  });

  testWidgets('payment sheet submit sekali: tombol disabled saat menyimpan', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt]))..gate = Completer<void>();
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls.where((c) => c.startsWith('addPayment')).length, 1);

    fake.gate!.complete();
    await tester.pumpAndSettle();
    await flushToast(tester);
  });

  testWidgets('edit cicilan memanggil updatePayment dengan nominal baru', (tester) async {
    final debt = sampleDebt();
    final payment = samplePayment();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt]));
    await pumpApp(
      tester,
      Consumer(builder: (context, ref, _) => TextButton(
            onPressed: () => showDebtPaymentSheet(context, debt: debt, payment: payment),
            child: const Text('buka'),
          )),
      overrides: debtOverrides(fake),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Cicilan'), findsOneWidget);
    expect(find.text('Perubahan nominal ikut menyesuaikan saldo BCA.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '600000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('updatePayment:1:10:600000'));
    await flushToast(tester);
  });

  test('cicilan bertransaksi tapi dompetnya sudah dihapus tidak menjanjikan saldo kembali', () {
    final p = samplePayment(walletId: null, walletName: null, transactionId: 90);
    expect(p.affectsWallet, isFalse);
    expect(deletePaymentConfirmMessage(p), 'Sisa tagihan bertambah Rp 500.000.');
  });

  testWidgets('dua tap Simpan sebelum rebuild hanya mengirim satu pembayaran', (tester) async {
    final debt = sampleDebt();
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt]))..gate = Completer<void>();
    await pumpApp(tester, opener(debt), overrides: debtOverrides(fake));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.pump();
    final button = tester.widget<AppPrimaryButton>(find.widgetWithText(AppPrimaryButton, 'Simpan'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(fake.calls.where((c) => c.startsWith('addPayment')).length, 1);
    fake.gate!.complete();
    await tester.pumpAndSettle();
    await flushToast(tester);
  });
}
