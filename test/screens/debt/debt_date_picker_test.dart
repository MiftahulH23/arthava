import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_form_sheet.dart';
import 'package:catat_uang_app/screens/debt/debt_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

Widget _opener(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () => open(context), child: const Text('buka'))),
      ),
    );

void main() {
  final debt = sampleDebt(loanDate: DateTime(2026, 8, 1));
  final state = DebtState(isLoading: false, debts: [debt], wallets: [sampleWallet()]);

  testWidgets('tanggal pinjam dibuka sebagai sheet bersama, form tetap terbuka setelah Pilih', (tester) async {
    await pumpApp(
      tester,
      _opener((context) => showDebtFormSheet(context, initialType: DebtType.payable)),
      overrides: debtOverrides(FakeDebtNotifier(state)),
      size: const Size(390, 1400),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanggal Pinjam'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Tanggal Pinjam'), findsNWidgets(2)); // baris form + judul sheet pemilih
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('Catat Utang / Piutang'), findsOneWidget); // sheet form masih terbuka
  });

  testWidgets('tanggal pembayaran cicilan memakai sheet bersama', (tester) async {
    await pumpApp(
      tester,
      _opener((context) => showDebtPaymentSheet(context, debt: debt)),
      overrides: debtOverrides(FakeDebtNotifier(state)),
      size: const Size(390, 1400),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanggal Pembayaran'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });
}
