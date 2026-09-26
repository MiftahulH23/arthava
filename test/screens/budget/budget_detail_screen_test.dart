import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_detail_screen.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeBudgetNotifier extends BudgetNotifier {
  _FakeBudgetNotifier(this._initial);
  final BudgetState _initial;
  final updates = <(int, double)>[];
  @override
  BudgetState build() => _initial;
  @override
  Future<void> updateBudgetAmount(int id, double amount) async => updates.add((id, amount));
}

final _food = CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'tag');
final _budget = BudgetModel(id: 10, categoryId: 1, amount: 1500000, month: 9, year: 2026, category: _food);
const BudgetDetailKey _key = (categoryId: 1, month: 9, year: 2026);

late _FakeBudgetNotifier _fake;

Future<void> _pump(WidgetTester tester, BudgetDetailData data) async {
  _fake = _FakeBudgetNotifier(BudgetState(isLoading: false, budgets: [_budget]));
  await pumpApp(
    tester,
    BudgetDetailScreen(budget: _budget),
    overrides: [
      budgetProvider.overrideWith(() => _fake),
      budgetDetailProvider(_key).overrideWith((ref) async => data),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan ring, ringkasan, chip sisa, dan riwayat', (tester) async {
    await _pump(
      tester,
      BudgetDetailData(
        transactions: [
          {'id': 1, 'amount': 45000, 'note': 'Nasi Padang', 'date': '2026-09-24', 'category_id': 1, 'wallet_id': 7},
          {'id': 2, 'amount': 120000, 'note': '', 'date': '2026-09-22', 'category_id': 1, 'wallet_id': null},
        ],
        totalSpent: 1230000,
        walletNames: {7: 'BCA'},
        walletColors: {7: const Color(0xFF4A6CF7)},
      ),
    );

    expect(find.text('Makan'), findsWidgets);
    expect(find.text('Terpakai'), findsOneWidget);
    expect(find.text('Limit Anggaran'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.textContaining('Sisa Anggaran:'), findsOneWidget);
    expect(find.text('Riwayat Pengeluaran'.toUpperCase()), findsOneWidget);
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('Tanpa catatan'), findsOneWidget);
    expect(find.text('Kas Utama'), findsOneWidget);
    expect(find.byType(AppNavAction), findsOneWidget);
  });

  testWidgets('over budget menampilkan chip "Over Budget:" merah (Review Focus #4)', (tester) async {
    await _pump(tester, const BudgetDetailData(totalSpent: 1700000));

    expect(find.text('113%'), findsOneWidget);
    final chip = tester.widget<AppChip>(find.byWidgetPredicate((w) => w is AppChip && w.label.startsWith('Over Budget:')));
    expect(chip.color, AppColors.expense);
  });

  testWidgets('tanpa transaksi menampilkan empty state', (tester) async {
    await _pump(tester, const BudgetDetailData());
    expect(find.text('Belum ada transaksi di kategori ini'), findsOneWidget);
  });

  testWidgets('tombol Edit membuka sheet "Edit Anggaran"', (tester) async {
    await _pump(tester, const BudgetDetailData());
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Anggaran'), findsOneWidget);
    expect(find.text('Ubah limit untuk kategori Makan'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });

  testWidgets('Simpan Perubahan: kosong tidak menyimpan; terisi → updateBudgetAmount + toast', (tester) async {
    await _pump(tester, const BudgetDetailData());
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(_fake.updates, isEmpty);
    expect(find.text('Edit Anggaran'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2000000');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_fake.updates, [(10, 2000000.0)]);
    expect(find.text('Limit berhasil diperbarui!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
