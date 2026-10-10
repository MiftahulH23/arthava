@Tags(['screenshot'])
library;

import 'package:arthava/models/budget_model.dart';
import 'package:arthava/models/category_model.dart';
import 'package:arthava/models/recurring_transaction_model.dart';
import 'package:arthava/models/saving_model.dart';
import 'package:arthava/models/target_model.dart';
import 'package:arthava/providers/budget_provider.dart';
import 'package:arthava/providers/recurring_provider.dart';
import 'package:arthava/providers/savings_provider.dart';
import 'package:arthava/providers/target_provider.dart';
import 'package:arthava/screens/budget/budget_detail_screen.dart';
import 'package:arthava/screens/budget/budget_screen.dart';
import 'package:arthava/screens/recurring/recurring_screen.dart';
import 'package:arthava/screens/savings/saving_detail_screen.dart';
import 'package:arthava/screens/savings/savings_screen.dart';
import 'package:arthava/screens/target/target_screen.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshot_harness.dart';

class _Budget extends BudgetNotifier {
  @override
  BudgetState build() => _budgetState;
}

class _Target extends TargetNotifier {
  @override
  TargetState build() => _targetState;
}

class _Savings extends SavingsNotifier {
  @override
  SavingsState build() => _savingsState;
}

class _Recurring extends RecurringNotifier {
  @override
  RecurringState build() => _recurringState;
}

CategoryModel _cat(int id, String name) => CategoryModel(id: id, name: name, isExpense: true, iconName: 'tag');

final _cats = [_cat(1, 'Makan'), _cat(2, 'Transportasi'), _cat(3, 'Belanja'), _cat(4, 'Hiburan')];

BudgetModel _b(int id, int cat, double amount) =>
    BudgetModel(id: id, categoryId: cat, amount: amount, month: 9, year: 2026, category: _cats[cat - 1]);

final _budgetState = BudgetState(
  isLoading: false,
  selectedMonth: DateTime(2026, 9),
  budgets: [_b(10, 1, 1500000), _b(11, 2, 800000), _b(12, 3, 1500000), _b(13, 4, 1200000)],
  spendingMap: const {1: 1230000, 2: 560000, 3: 1690000, 4: 0},
  allCategories: _cats,
  totalBudget: 5000000,
  totalSpent: 3480000,
);

final _targetState = TargetState(
  isLoading: false,
  totalSavings: 7300000,
  savingNames: const ['Dana Darurat'],
  wallets: const [
    {'id': 1, 'name': 'BCA', 'balance': 9300000},
    {'id': 2, 'name': 'GoPay', 'balance': 420000},
  ],
  targets: [
    TargetModel(
      id: 1,
      name: 'Beli iPhone 15',
      targetAmount: 15000000,
      savedAmount: 6750000,
      deadline: DateTime.now().add(const Duration(days: 98)),
      storageLocation: 'Dana Darurat',
    ),
    TargetModel(id: 2, name: 'Liburan Bali', targetAmount: 550000, savedAmount: 550000),
  ],
);

SavingModel _s(int id, String name, double amount, {String? location, String? notes, int day = 24}) => SavingModel(
      id: id,
      userId: 'u',
      name: name,
      amount: amount,
      location: location,
      notes: notes,
      createdAt: DateTime(2026, 9, day, 9, 12),
    );

final _savingsState = SavingsState(
  isLoading: false,
  totalSavings: 24500000,
  wallets: const [
    {'id': 1, 'name': 'BCA', 'balance': 9300000},
  ],
  groupedSavings: {
    'Dana Darurat': [
      _s(1, 'Dana Darurat', 18000000, location: 'Bank BCA', notes: 'Gaji September'),
      _s(2, 'Dana Darurat', -250000, location: 'Bank BCA', day: 20),
    ],
    'Liburan Bali': [_s(3, 'Liburan Bali', 6500000, location: 'Bank Jago')],
  },
);

RecurringTransactionModel _r(int id, String cat, bool expense, double amount, bool active, String note) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u',
      categoryId: id,
      amount: amount,
      note: note,
      frequency: 'Bulanan',
      startDate: DateTime(2026, 9, 1),
      nextRunDate: DateTime(2026, 10, 1),
      isActive: active,
      category: {'id': id, 'name': cat, 'is_expense': expense},
      walletId: 1,
    );

final _recurringState = RecurringState(
  isLoading: false,
  wallets: const [
    {'id': 1, 'name': 'BCA'},
  ],
  categories: const [
    {'id': 1, 'name': 'Tempat Tinggal', 'is_expense': true},
    {'id': 2, 'name': 'Gaji', 'is_expense': false},
    {'id': 3, 'name': 'Internet', 'is_expense': true},
  ],
  recurringList: [
    _r(1, 'Tempat Tinggal', true, 1500000, true, 'Bayar Kos'),
    _r(2, 'Gaji', false, 8500000, true, 'Gaji Bulanan'),
    _r(3, 'Internet', true, 350000, false, 'Tagihan WiFi'),
  ],
);

void main() {
  final skip = !screenshotFontsAvailable;
  final budget = budgetProvider.overrideWith(_Budget.new);

  testWidgets('01 anggaran', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const BudgetScreen(), overrides: [budget]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_01_budget');
  }, skip: skip);

  testWidgets('02 sheet buat anggaran', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const BudgetScreen(), overrides: [budget]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_02_budget_sheet');
  }, skip: skip);

  testWidgets('03 detail anggaran', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      BudgetDetailScreen(budget: _budgetState.budgets.first),
      overrides: [
        budget,
        budgetDetailProvider((categoryId: 1, month: 9, year: 2026)).overrideWith(
          (ref) async => const BudgetDetailData(
            totalSpent: 1230000,
            walletNames: {1: 'BCA', 2: 'GoPay'},
            walletColors: {1: Color(0xFF1E3A8A), 2: Color(0xFFE65100)},
            transactions: [
              {'id': 1, 'amount': 45000, 'note': 'Nasi Padang', 'date': '2026-09-24', 'category_id': 1, 'wallet_id': 1},
              {'id': 2, 'amount': 28000, 'note': 'Kopi susu', 'date': '2026-09-23', 'category_id': 1, 'wallet_id': 2},
              {'id': 3, 'amount': 120000, 'note': '', 'date': '2026-09-22', 'category_id': 1, 'wallet_id': null},
            ],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_03_budget_detail');
  }, skip: skip);

  testWidgets('04 target keuangan', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const TargetScreen(), overrides: [targetProvider.overrideWith(_Target.new)], size: const Size(390, 1000));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_04_target');
  }, skip: skip);

  testWidgets('05 sheet nabung', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const TargetScreen(), overrides: [targetProvider.overrideWith(_Target.new)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is AppPillButton && w.label == 'Nabung' && w.onPressed != null));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_05_target_deposit_sheet');
  }, skip: skip);

  testWidgets('06 buku tabungan', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const SavingsScreen(), overrides: [savingsProvider.overrideWith(_Savings.new)]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_06_savings');
  }, skip: skip);

  testWidgets('07 detail tabungan', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const SavingDetailScreen(savingName: 'Dana Darurat'),
      overrides: [savingsProvider.overrideWith(_Savings.new)],
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_07_saving_detail');
  }, skip: skip);

  testWidgets('08 tagihan & pemasukan rutin', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const RecurringScreen(), overrides: [recurringProvider.overrideWith(_Recurring.new)]);
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_08_recurring');
  }, skip: skip);

  testWidgets('09 sheet buat jadwal', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const RecurringScreen(),
      overrides: [recurringProvider.overrideWith(_Recurring.new)],
      size: const Size(390, 1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b5_09_recurring_sheet');
  }, skip: skip);
}
