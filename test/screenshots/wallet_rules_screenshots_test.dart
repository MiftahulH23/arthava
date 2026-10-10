@Tags(['screenshot'])
library;

import 'package:arthava/models/recurring_transaction_model.dart';
import 'package:arthava/models/transaction_model.dart';
import 'package:arthava/models/wallet_model.dart';
import 'package:arthava/providers/home_provider.dart';
import 'package:arthava/providers/home_summary.dart';
import 'package:arthava/providers/input_transaction_provider.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:arthava/screens/home/home_screen.dart';
import 'package:arthava/screens/input_transaction/input_transaction_screen.dart';
import 'package:arthava/screens/wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshot_harness.dart';

class _Wallets extends WalletNotifier {
  @override
  WalletState build() => WalletState(isLoading: false, wallets: [
        WalletModel(id: 1, userId: 'u', name: 'BCA', balance: 1250000, color: '#1E3A8A', minBalance: 50000),
        WalletModel(id: 2, userId: 'u', name: 'GoPay', balance: 185000, color: '#E65100'),
      ]);
  @override
  Future<void> fetchWallets() async {}
}

class _Input extends InputTransactionNotifier {
  _Input({this.wallets = true, this.reject});
  final bool wallets;
  final String? reject;

  @override
  InputTransactionState build() => InputTransactionState(
        wallets: wallets
            ? const [
                {'id': 1, 'name': 'BCA', 'balance': 1250000, 'color': '#1E3A8A', 'min_balance': 50000},
                {'id': 2, 'name': 'GoPay', 'balance': 185000, 'color': '#E65100', 'min_balance': 0},
              ]
            : const [],
        categories: const [
          {'id': 10, 'name': 'Makan', 'is_expense': true},
        ],
      );

  @override
  Future<TransactionSaveResult> saveTransaction({
    required String amountText,
    required String noteText,
    required int? selectedCategoryId,
    required int? selectedWalletId,
    required bool isExpense,
    required bool isFromSaving,
    required String? selectedSavingName,
    required DateTime selectedDate,
    required String? hiddenSavingMarker,
    required bool isReadOnly,
    required TransactionModel? transactionToEdit,
    required bool initialIsExpense,
  }) async =>
      TransactionSaveResult(false, reject ?? 'uji');
}

class _Home extends HomeNotifier {
  @override
  HomeState build() => HomeState(
        isLoading: false,
        userName: 'Miftahul',
        wallets: [WalletModel(id: 1, userId: 'u', name: 'BCA', balance: 25000, color: '#1E3A8A')],
        totalWalletBalance: 25000,
        summary: HomeSummary(blockedBills: [
          RecurringTransactionModel(
            id: 1,
            userId: 'u',
            categoryId: 3,
            amount: 1500000,
            note: 'Bayar Kos',
            frequency: 'Bulanan',
            startDate: DateTime(2026, 9, 1),
            nextRunDate: DateTime(2026, 9, 1),
            isActive: true,
            walletId: 1,
            blockedReason: 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 25.000',
          ),
        ]),
      );
  @override
  Future<void> refreshData() async {}
}

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 transfer dengan tombol tukar', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const WalletScreen(), overrides: [walletProvider.overrideWith(_Wallets.new)]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'wr_01_transfer');
  }, skip: skip);

  testWidgets('02 pilih dompet dengan + Dompet Baru', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const InputTransactionScreen(initialIsExpense: true),
        overrides: [inputTransactionProvider.overrideWith(() => _Input())]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dompet').last); // baris Dompet (bukan segmented)
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'wr_02_wallet_picker');
  }, skip: skip);

  testWidgets('03 tambah transaksi tanpa dompet', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const InputTransactionScreen(initialIsExpense: true),
        overrides: [inputTransactionProvider.overrideWith(() => _Input(wallets: false))]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'wr_03_no_wallet');
  }, skip: skip);

  testWidgets('04 beranda dengan tagihan tertahan', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const HomeScreen(), overrides: [homeProvider.overrideWith(_Home.new)], size: const Size(390, 1100));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'wr_04_home_blocked');
  }, skip: skip);

  testWidgets('05 tolakan saldo', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const InputTransactionScreen(initialIsExpense: true),
        overrides: [
          inputTransactionProvider.overrideWith(
            () => _Input(reject: 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 1.200.000'),
          ),
        ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1500000');
    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Transaksi'));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await saveScreenshot(tester, 'wr_05_rejection');
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }, skip: skip);
}
