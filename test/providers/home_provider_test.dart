import 'package:arthava/providers/home_provider.dart';
import 'package:arthava/providers/home_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeState default: pengaturan saldo minimal aktif, ringkasan kosong', () {
    const s = HomeState();
    expect(s.includeMinBalance, isTrue);
    expect(s.wallets, isEmpty);
    expect(s.summary.budget, isNull);
    expect(s.summary.debt, isNull);
  });

  test('copyWith mempertahankan summary dan includeMinBalance', () {
    const summary = HomeSummary(budget: BudgetSummary(totalSpent: 1, totalBudget: 2));
    final s = const HomeState().copyWith(summary: summary, includeMinBalance: false);
    final s2 = s.copyWith(userName: 'X');
    expect(s2.summary.budget!.totalBudget, 2);
    expect(s2.includeMinBalance, isFalse);
  });
}
