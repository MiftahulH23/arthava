@Tags(['screenshot'])
library;

import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/investment_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/calendar_provider.dart';
import 'package:catat_uang_app/providers/category_provider.dart';
import 'package:catat_uang_app/providers/investment_provider.dart';
import 'package:catat_uang_app/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:catat_uang_app/screens/calendar/calendar_screen.dart';
import 'package:catat_uang_app/screens/export/export_screen.dart';
import 'package:catat_uang_app/screens/investment/investment_screen.dart';
import 'package:catat_uang_app/screens/manage_category/manage_category_screen.dart';
import 'package:catat_uang_app/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/calendar/calendar_screen_test.dart' as cal;
import '../screens/investment/investment_screen_test.dart' as inv;
import '../screens/manage_category/manage_category_screen_test.dart' as cat;
import 'screenshot_harness.dart';

InvestmentModel _inv(int id, String name, String type, double cap, double val) => InvestmentModel(
    id: id, userId: 'u', name: name, type: type, capitalAmount: cap, currentValue: val, createdAt: DateTime(2026, 9, 1));

final _invState = InvestmentState(
  isLoading: false,
  investments: [
    _inv(1, 'Saham BBCA', 'Saham', 8000000, 9440000),
    _inv(2, 'Bitcoin', 'Kripto', 1200000, 1149600),
    _inv(3, 'Reksadana Pasar Uang', 'Reksadana', 3000000, 3120000),
  ],
  wallets: const [
    {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#1E3A8A'},
  ],
  totalCapital: 12200000,
  totalValue: 13709600,
);

TransactionModel _trx(int id, String cat, bool isExpense, double amount, String note, int walletId) => TransactionModel(
      id: id,
      userId: 'u',
      categoryId: id,
      amount: amount,
      date: DateTime.now(),
      note: note,
      walletId: walletId,
      category: CategoryModel(id: id, name: cat, isExpense: isExpense, iconName: 'tag'),
    );

CalendarState _calState() {
  final today = normalizeCalendarDate(DateTime.now());
  return CalendarState(
    isLoading: false,
    walletNames: const {1: 'BCA', 2: 'GoPay'},
    walletColors: const {1: Color(0xFF1E3A8A), 2: Color(0xFFE65100)},
    groupedTransactions: {
      today: [
        _trx(1, 'Makan', true, 45000, 'Nasi Padang', 1),
        _trx(2, 'Transportasi', true, 32000, 'Gojek ke kantor', 2),
        _trx(3, 'Gaji', false, 8500000, 'Gaji September', 1),
      ],
      today.subtract(const Duration(days: 2)): [_trx(4, 'Belanja', true, 285000, 'Superindo', 1)],
    },
  );
}

final _catState = CategoryState(
  isLoading: false,
  isExpense: true,
  categories: [
    CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'food'),
    CategoryModel(id: 2, name: 'Transportasi', isExpense: true, iconName: 'car'),
    CategoryModel(id: 3, name: 'Belanja', isExpense: true, iconName: 'shopping'),
    CategoryModel(id: 5, name: 'Bensin', isExpense: true, iconName: 'tag', userId: 'u'),
    CategoryModel(id: 6, name: 'Kopi', isExpense: true, iconName: 'tag', userId: 'u'),
  ],
);

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 investasi', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const InvestmentScreen(),
        overrides: [investmentProvider.overrideWith(() => inv.FakeInvestmentNotifier(_invState))]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_01_investment');
  }, skip: skip);

  testWidgets('02 investasi, sheet aksi', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const InvestmentScreen(),
        overrides: [investmentProvider.overrideWith(() => inv.FakeInvestmentNotifier(_invState))]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saham BBCA'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_02_investment_actions');
  }, skip: skip);

  testWidgets('03 zakat', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const ZakatSedekahScreen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '85000000');
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_03_zakat');
  }, skip: skip);

  testWidgets('04 kalender', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const CalendarScreen(),
        overrides: [calendarProvider.overrideWith(() => cal.FakeCalendarNotifier(_calState()))], size: const Size(390, 1100));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_04_calendar');
  }, skip: skip);

  testWidgets('05 kelola kategori', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const ManageCategoryScreen(),
        overrides: [categoryProvider.overrideWith(() => cat.FakeCategoryNotifier(_catState))]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_05_categories');
  }, skip: skip);

  testWidgets('06 export', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const ExportScreen());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_06_export');
  }, skip: skip);

  testWidgets('07 AI advisor', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const AiAdvisorScreen());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b6_07_ai');
  }, skip: skip);
}
