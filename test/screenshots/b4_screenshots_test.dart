@Tags(['screenshot'])
library;

import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/providers/transaction_history_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/stats/stats_screen.dart';
import 'package:catat_uang_app/screens/transaction_history/transactions_tab_screen.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/input_transaction/input_transaction_min_balance_test.dart' as input;
import '../screens/stats/stats_screen_test.dart' as stats;
import '../screens/transaction_history/transaction_history_screen_test.dart' as history;
import 'screenshot_harness.dart';

TransactionModel _trx(int id, DateTime date, String category, double amount, {String? note, int walletId = 1}) =>
    TransactionModel(
      id: id,
      userId: 'u',
      categoryId: id,
      amount: amount,
      date: date,
      note: note,
      walletId: walletId,
      category: CategoryModel(id: id, name: category, isExpense: true, iconName: 'tag'),
    );

TransactionHistoryState _history() {
  final trxs = [
    _trx(1, DateTime(2026, 9, 24), 'Makan', 45000, note: 'Nasi Padang'),
    _trx(2, DateTime(2026, 9, 24), 'Transportasi', 32000, note: 'Gojek ke kantor', walletId: 2),
    _trx(3, DateTime(2026, 9, 23), 'Tabungan', 500000, note: 'Setor Liburan Bali [SAVING_ID:3]'),
    _trx(4, DateTime(2026, 9, 23), 'Sistem: Uang Keluar (Utang/Piutang)', 400000, note: 'Bayar utang ke Budi [DEBT_ID:12]'),
    _trx(5, DateTime(2026, 9, 22), 'Belanja', 285000, note: 'Belanja bulanan Superindo'),
  ];
  return TransactionHistoryState(
    isLoading: false,
    transactions: trxs,
    totalAmount: 362000,
    selectedDate: DateTime(2026, 9, 24),
    walletNames: const {1: 'BCA', 2: 'GoPay'},
    walletColors: const {1: Color(0xFF1E3A8A), 2: Color(0xFFE65100)},
    // Di app diisi fetchCategories() dari tabel categories (per jenis transaksi).
    categories: const [
      {'id': 1, 'name': 'Makan', 'is_expense': true},
      {'id': 2, 'name': 'Transportasi', 'is_expense': true},
      {'id': 5, 'name': 'Belanja', 'is_expense': true},
      {'id': 6, 'name': 'Tagihan', 'is_expense': true},
      {'id': 7, 'name': 'Hiburan', 'is_expense': true},
    ],
    selectedCategoryIds: const [1],
  );
}

StatsState _stats() => StatsState(
      isLoading: false,
      isExpense: true,
      selectedDate: DateTime(2026, 9, 24),
      totalAmount: 3480000,
      dailyAverage: 145000,
      highestTransaction: const {'amount': 1500000.0, 'name': 'Tempat Tinggal', 'note': 'Bayar kos', 'date': '2026-09-01'},
      walletNames: const {1: 'BCA', 2: 'GoPay'},
      walletColors: const {1: Color(0xFF1E3A8A), 2: Color(0xFFE65100)},
      categoryData: [
        {
          'name': 'Tempat Tinggal',
          'amount': 1500000.0,
          'count': 1,
          'transactions': [
            {'note': 'Bayar kos', 'date': '2026-09-01', 'wallet_id': 1, 'amount': 1500000},
          ],
        },
        {
          'name': 'Makan',
          'amount': 980000.0,
          'count': 18,
          'transactions': [
            {'note': 'Nasi Padang', 'date': '2026-09-24', 'wallet_id': 1, 'amount': 45000},
            {'note': 'Kopi', 'date': '2026-09-23', 'wallet_id': 2, 'amount': 28000},
          ],
        },
        {'name': 'Transportasi', 'amount': 520000.0, 'count': 14, 'transactions': []},
        {'name': 'Belanja', 'amount': 480000.0, 'count': 5, 'transactions': []},
      ],
    );

Widget _tab() => const Scaffold(body: TransactionsTabScreen(refreshCounter: 0, initialIsExpense: true));

void main() {
  final skip = !screenshotFontsAvailable;
  final historyOverride = transactionHistoryProvider.overrideWith(() => history.FakeTransactionHistoryNotifier(_history()));

  testWidgets('01 transaksi pengeluaran', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, _tab(), overrides: [historyOverride]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_01_transactions');
  }, skip: skip);

  testWidgets('02 transaksi, baris digeser', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, _tab(), overrides: [historyOverride]);
    await tester.pumpAndSettle();
    final row = find.ancestor(of: find.text('Nasi Padang'), matching: find.byType(AppSwipeActions));
    await tester.drag(row, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_02_transactions_swiped');
  }, skip: skip);

  testWidgets('03 transaksi, sheet filter', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, _tab(), overrides: [historyOverride]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_03_filter_sheet');
  }, skip: skip);

  testWidgets('04 statistik, kategori di-expand', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const Scaffold(body: StatsScreen()),
      overrides: [statsProvider.overrideWith(() => stats.FakeStatsNotifier(_stats()))],
      size: const Size(390, 1300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tempat Tinggal').last);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_04_stats');
  }, skip: skip);

  testWidgets('05 tambah transaksi pengeluaran', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const InputTransactionScreen(initialIsExpense: true),
      overrides: [inputTransactionProvider.overrideWith(() => input.FakeInputNotifier())],
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '45000');
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_05_input_expense');
  }, skip: skip);

  testWidgets('06 tambah transaksi, sheet pilih dompet', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const InputTransactionScreen(initialIsExpense: true),
      overrides: [inputTransactionProvider.overrideWith(() => input.FakeInputNotifier())],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dompet').last); // baris Dompet (bukan segmented)
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_06_wallet_sheet');
  }, skip: skip);

  testWidgets('07 transaksi tabungan (read-only)', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      InputTransactionScreen(
        initialIsExpense: true,
        transactionToEdit: _trx(3, DateTime(2026, 9, 23), 'Tabungan', 500000, note: 'Setor Liburan Bali [SAVING_ID:3]'),
      ),
      overrides: [inputTransactionProvider.overrideWith(() => input.FakeInputNotifier())],
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b4_07_input_readonly');
  }, skip: skip);
}
