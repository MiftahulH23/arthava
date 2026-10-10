@Tags(['screenshot'])
library;

import 'package:arthava/models/debt_model.dart';
import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/providers/user_settings_provider.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:arthava/screens/debt/debt_form_sheet.dart';
import 'package:arthava/screens/wallet/wallet_screen.dart';
import 'package:arthava/widgets/app_dialogs.dart';
import 'package:arthava/widgets/app_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/debt/debt_test_utils.dart';
import '../screens/wallet_screen_test.dart' as wallet;
import 'screenshot_harness.dart';

Widget _opener(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => open(context), child: const Text('buka')))),
    );

Future<void> _shoot(WidgetTester tester, String name, void Function(BuildContext) open) async {
  await loadRealFonts(tester);
  await pumpScreen(tester, _opener(open));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  await saveScreenshot(tester, name);
}

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 pemilih tanggal', (tester) async {
    await _shoot(tester, 'b3b_01_date_picker', (c) {
      showAppDatePicker(context: c, initialDate: DateTime(2026, 9, 26), firstDate: DateTime(2020), lastDate: DateTime(2030));
    });
  }, skip: skip);

  testWidgets('02 pemilih bulan', (tester) async {
    await _shoot(tester, 'b3b_02_month_picker', (c) {
      showAppMonthPicker(context: c, initialMonth: DateTime(2026, 9), firstYear: 2021, lastYear: 2031);
    });
  }, skip: skip);

  testWidgets('03 pemilih tahun', (tester) async {
    await _shoot(tester, 'b3b_03_year_picker', (c) {
      showAppYearPicker(context: c, initialYear: 2026, firstYear: 2020, lastYear: 2030);
    });
  }, skip: skip);

  testWidgets('04 pemilih periode', (tester) async {
    await _shoot(tester, 'b3b_04_range_picker', (c) {
      showAppDateRangePicker(
        context: c,
        initialRange: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 10)),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
    });
  }, skip: skip);

  testWidgets('05 form utang lalu tanggal pinjam (sheet menumpuk)', (tester) async {
    await loadRealFonts(tester);
    final state = DebtState(isLoading: false, debts: const [], wallets: [sampleWallet()]);
    await pumpScreen(
      tester,
      _opener((c) => showDebtFormSheet(c, initialType: DebtType.payable)),
      overrides: debtOverrides(FakeDebtNotifier(state)),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanggal Pinjam'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3b_05_debt_form_date');
  }, skip: skip);

  testWidgets('06 dialog konfirmasi hapus di Dompet', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const WalletScreen(),
      overrides: [
        walletProvider.overrideWith(() => wallet.FakeWalletNotifier(wallet.sample())),
        userSettingsProvider.overrideWith(() => wallet.FakeUserSettingsNotifier(true)),
      ],
    );
    await tester.pumpAndSettle();
    showAppConfirmDialog(
      context: tester.element(find.text('Dompet Saya')),
      title: 'Hapus Dompet?',
      message: 'Yakin ingin menghapus BCA?',
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3b_06_confirm_dialog');
  }, skip: skip);
}
