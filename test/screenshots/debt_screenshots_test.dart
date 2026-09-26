@Tags(['screenshot'])
library;

import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_detail_screen.dart';
import 'package:catat_uang_app/screens/debt/debt_form_sheet.dart';
import 'package:catat_uang_app/screens/debt/debt_payment_sheet.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/debt/debt_test_utils.dart';
import 'screenshot_harness.dart';

DebtState _state() {
  final budi = sampleDebt(
    id: 1,
    name: 'Budi Santoso',
    amount: 2000000,
    remaining: 1200000,
    loanDate: DateTime(2026, 8, 1),
    dueDate: DateTime(2026, 9, 22),
    notes: 'Modal usaha',
    transactionId: 70,
    walletId: 3,
  );
  final rina = sampleDebt(
    id: 2,
    name: 'Rina',
    amount: 750000,
    remaining: 750000,
    loanDate: DateTime(2026, 9, 20),
    dueDate: DateTime(2026, 11, 15),
    notes: 'Patungan kado',
  );
  final jago = sampleDebt(id: 3, name: 'Bank Jago', amount: 5000000, remaining: 0, status: 'paid', loanDate: DateTime(2026, 1, 3));
  final andi = sampleDebt(
    id: 4,
    name: 'Andi Pratama',
    type: DebtType.receivable,
    amount: 1500000,
    remaining: 1000000,
    loanDate: DateTime(2026, 9, 1),
    dueDate: DateTime(2026, 10, 30),
    notes: 'Pinjam untuk servis motor',
  );
  return DebtState(
    isLoading: false,
    debts: [budi, rina, jago, andi],
    wallets: [sampleWallet(), sampleWallet(id: 4, name: 'GoPay', balance: 1850000, color: '#F0913A')],
    payments: {
      1: [
        samplePayment(id: 10, amount: 500000, date: DateTime(2026, 9, 15)),
        samplePayment(id: 11, amount: 300000, date: DateTime(2026, 9, 1), walletId: null, walletName: null, transactionId: null),
      ],
    },
  );
}

Widget _opener(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => open(context), child: const Text('buka')))),
    );

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 daftar utang (Utang Saya)', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(_state())));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'debt_01_list_utang');
  }, skip: skip);

  testWidgets('02 daftar piutang', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(_state())));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AppSegmentedControl), matching: find.text('Piutang')));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'debt_02_list_piutang');
  }, skip: skip);

  testWidgets('03 detail utang, cicilan digeser', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const DebtDetailScreen(debtId: 1), overrides: debtOverrides(FakeDebtNotifier(_state())));
    await tester.pumpAndSettle();
    final row = find.ancestor(of: find.text('15 Sep 2026'), matching: find.byType(AppSwipeActions));
    await tester.drag(row, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'debt_03_detail_swiped');
  }, skip: skip);

  testWidgets('04 form catat utang, switch dompet aktif', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      _opener((context) => showDebtFormSheet(context, initialType: DebtType.payable)),
      overrides: debtOverrides(FakeDebtNotifier(_state())),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2000000');
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'debt_04_form_sheet');
  }, skip: skip);

  testWidgets('05 sheet bayar cicilan', (tester) async {
    await loadRealFonts(tester);
    final state = _state();
    await pumpScreen(
      tester,
      _opener((context) => showDebtPaymentSheet(context, debt: state.debts.first)),
      overrides: debtOverrides(FakeDebtNotifier(state)),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '400000');
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'debt_05_payment_sheet');
  }, skip: skip);
}
