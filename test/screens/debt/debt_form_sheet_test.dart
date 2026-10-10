import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/screens/debt/debt_detail_screen.dart';
import 'package:arthava/screens/debt/debt_form_sheet.dart';
import 'package:arthava/screens/debt/debt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  setUpAll(prewarmToastFont);

  group('validateDebtForm', () {
    test('pesan lama dipertahankan', () {
      expect(validateDebtForm(name: '  ', amountText: '100', affectWallet: false, walletId: null),
          'Nama tidak boleh kosong!');
      expect(validateDebtForm(name: 'Budi', amountText: '', affectWallet: false, walletId: null),
          'Jumlah tidak boleh kosong!');
      expect(validateDebtForm(name: 'Budi', amountText: '100', affectWallet: true, walletId: null),
          'Silakan pilih dompet!');
    });
    test('nol ditolak dan batas minimal saat edit', () {
      expect(validateDebtForm(name: 'Budi', amountText: '0', affectWallet: false, walletId: null),
          'Nominal harus lebih dari 0.');
      expect(validateDebtForm(name: 'Budi', amountText: '700.000', affectWallet: false, walletId: null, minAmount: 800000),
          'Jumlah total tidak boleh kurang dari yang sudah dibayar.');
      expect(validateDebtForm(name: 'Budi', amountText: '800.000', affectWallet: false, walletId: null, minAmount: 800000),
          isNull);
    });
  });

  testWidgets('tombol + di daftar membuka sheet catat dan mengirim createDebt', (tester) async {
    final fake = FakeDebtNotifier(DebtState(isLoading: false, wallets: [sampleWallet()]));
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Catat Utang / Piutang'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Tanggal Pinjam'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '2000000');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Budi, Bank, dll'), 'Budi Santoso');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Modal usaha'), 'Modal usaha');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('createDebt:Budi Santoso:payable:2000000:24:null:Modal usaha:null'));
    expect(find.text('Utang/Piutang berhasil dicatat!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('tab Piutang membuat default jenis piutang dan hint lama', (tester) async {
    final fake = FakeDebtNotifier(const DebtState(isLoading: false));
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake));
    await tester.pump();
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Contoh: Andi, Teman, dll'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '150000');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Andi, Teman, dll'), 'Andi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(fake.calls.single, startsWith('createDebt:Andi:receivable:150000'));
    await flushToast(tester);
  });

  testWidgets('Edit di detail membuka sheet terisi dan mengirim updateDebt', (tester) async {
    final debt = sampleDebt(notes: 'Modal usaha');
    final fake = FakeDebtNotifier(DebtState(isLoading: false, debts: [debt], payments: const {1: []}));
    await pumpApp(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(fake));
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Utang'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsWidgets);
    expect(find.text('Catat transaksi ini ke Dompet?'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '2500000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('updateDebt:1:Budi Santoso:2500000:Modal usaha'));
    expect(find.text('Perubahan disimpan!'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('validasi nama kosong memakai toast lama dan tidak memanggil provider', (tester) async {
    final fake = FakeDebtNotifier(const DebtState(isLoading: false));
    await pumpApp(
      tester,
      Consumer(builder: (context, ref, _) => TextButton(
            onPressed: () => showDebtFormSheet(context),
            child: const Text('buka'),
          )),
      overrides: debtOverrides(fake),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '100000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama tidak boleh kosong!'), findsOneWidget);
    expect(fake.calls, isEmpty);
    await flushToast(tester);
  });
}
