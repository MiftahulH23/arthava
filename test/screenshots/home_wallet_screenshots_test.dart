@Tags(['screenshot'])
library;

import 'package:arthava/models/target_model.dart';
import 'package:arthava/providers/home_provider.dart';
import 'package:arthava/providers/home_summary.dart';
import 'package:arthava/providers/user_settings_provider.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:arthava/screens/all_features/all_features_screen.dart';
import 'package:arthava/screens/home/home_screen.dart';
import 'package:arthava/screens/settings/include_min_balance_row.dart';
import 'package:arthava/screens/wallet/wallet_screen.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/debt/debt_test_utils.dart';
import '../screens/home_screen_test.dart' as home;
import '../screens/wallet_screen_test.dart' as wallet;
import 'screenshot_harness.dart';

HomeState _home({bool include = true, int walletCount = 5}) {
  final wallets = [
    home.wallet(1, 'BCA', 9300000, fav: true, min: 50000),
    home.wallet(2, 'GoPay', 1850000),
    home.wallet(3, 'Tunai', 1300000),
    home.wallet(4, 'Jago', 750000),
    home.wallet(5, 'Dana', 10000),
  ].take(walletCount).toList();
  return HomeState(
    isLoading: false,
    userName: 'Akun Tes',
    monthlyIncome: 8500000,
    monthlyExpense: 3480000,
    includeMinBalance: include,
    wallets: wallets,
    summary: HomeSummary(
      budget: const BudgetSummary(totalSpent: 3480000, totalBudget: 5000000),
      target: TargetModel(id: 1, name: 'Liburan Bali', targetAmount: 6000000, savedAmount: 4200000),
      debt: sampleDebt(loanDate: DateTime(2026, 8, 1), dueDate: DateTime(2026, 10, 15)),
    ),
  );
}

List<Override> _homeOverrides(HomeState state) => [homeProvider.overrideWith(() => home.FakeHomeNotifier(state))];

List<Override> _walletOverrides({bool include = true}) => [
      walletProvider.overrideWith(() => wallet.FakeWalletNotifier(wallet.sample())),
      userSettingsProvider.overrideWith(() => wallet.FakeUserSettingsNotifier(include)),
    ];

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 beranda atas', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const HomeScreen(), overrides: _homeOverrides(_home()));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_01_home_top');
  }, skip: skip);

  testWidgets('02 beranda penuh (tinggi 1700)', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const HomeScreen(), overrides: _homeOverrides(_home()), size: const Size(390, 1700));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_02_home_full');
  }, skip: skip);

  testWidgets('03 beranda, pengaturan saldo minimal nonaktif, 2 dompet', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const HomeScreen(), overrides: _homeOverrides(_home(include: false, walletCount: 2)));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_03_home_min_off');
  }, skip: skip);

  testWidgets('04 semua fitur', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, AllFeaturesScreen(onOpen: (_) async {}), size: const Size(390, 1300));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_04_all_features');
  }, skip: skip);

  testWidgets('05 semua fitur, cari "tab"', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, AllFeaturesScreen(onOpen: (_) async {}));
    await tester.enterText(find.byType(TextField).first, 'tab');
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_05_all_features_search');
  }, skip: skip);

  testWidgets('06 dompet, tumpukan kartu', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const WalletScreen(), overrides: _walletOverrides());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_06_wallet_stack');
  }, skip: skip);

  testWidgets('07 dompet, pengaturan saldo minimal nonaktif', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const WalletScreen(), overrides: _walletOverrides(include: false));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_07_wallet_min_off');
  }, skip: skip);

  testWidgets('08 dompet, sheet aksi', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const WalletScreen(), overrides: _walletOverrides());
    await tester.pumpAndSettle();
    await tester.tap(find.text('GOPAY'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_08_wallet_action_sheet');
  }, skip: skip);

  testWidgets('09 dompet, sheet tambah', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const WalletScreen(), overrides: _walletOverrides());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_09_wallet_add_sheet');
  }, skip: skip);

  testWidgets('10 dompet, sheet transfer', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const WalletScreen(), overrides: _walletOverrides());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '9280000');
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_10_wallet_transfer_sheet');
  }, skip: skip);

  testWidgets('13 pengaturan, switch saldo minimal', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AppGroupedSection(children: [IncludeMinBalanceRow()]),
          ),
        ),
      ),
      overrides: [userSettingsProvider.overrideWith(() => wallet.FakeUserSettingsNotifier(false))],
      size: const Size(390, 300),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_13_settings_min_row');
  }, skip: skip);

  testWidgets('14 beranda web', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const HomeScreen(), overrides: _homeOverrides(_home()), size: const Size(1280, 1100));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b3_14_home_web');
  }, skip: skip);
}
