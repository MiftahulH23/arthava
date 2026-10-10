import 'package:arthava/core/transaction_tags.dart';
import 'package:arthava/models/debt_model.dart';
import 'package:arthava/models/recurring_transaction_model.dart';
import 'package:arthava/models/target_model.dart';

class BudgetSummary {
  final double totalSpent;
  final double totalBudget;

  const BudgetSummary({required this.totalSpent, required this.totalBudget});

  double get ratio => totalBudget <= 0 ? 0 : totalSpent / totalBudget;
}

/// Data empat kartu ringkasan Beranda (spec §7.2). null = tampilkan empty state.
class HomeSummary {
  final BudgetSummary? budget;
  final TargetModel? target;
  final RecurringTransactionModel? nextBill;
  final DebtModel? debt;

  /// Jadwal aktif yang tertahan karena saldo dompet kurang.
  final List<RecurringTransactionModel> blockedBills;

  const HomeSummary({this.budget, this.target, this.nextBill, this.debt, this.blockedBills = const []});
}

/// Transaksi yang hanya memindahkan uang (tabungan / utang-piutang), bukan
/// pengeluaran sungguhan. Sama dengan pengecualian di budget_provider.
bool isInternalMutationNote(String? note) =>
    (note ?? '').contains('[SAVING_ID:') || isDebtMutation(note);

BudgetSummary? summarizeBudgets({
  required List<Map<String, dynamic>> budgets,
  required List<Map<String, dynamic>> monthTransactions,
}) {
  if (budgets.isEmpty) return null;
  final budgetCategoryIds = <int>{};
  var totalBudget = 0.0;
  for (final b in budgets) {
    budgetCategoryIds.add(b['category_id'] as int);
    totalBudget += (b['amount'] as num).toDouble();
  }
  var totalSpent = 0.0;
  for (final t in monthTransactions) {
    if (isInternalMutationNote(t['note']?.toString())) continue;
    final catId = t['category_id'] as int?;
    final isExpense = (t['categories']?['is_expense'] as bool?) ?? false;
    if (catId == null || !isExpense || !budgetCategoryIds.contains(catId)) continue;
    totalSpent += (t['amount'] as num).toDouble();
  }
  return BudgetSummary(totalSpent: totalSpent, totalBudget: totalBudget);
}

double _progress(TargetModel t) => t.targetAmount <= 0 ? 0 : t.savedAmount / t.targetAmount;

TargetModel? pickTarget(List<TargetModel> targets) {
  final open = targets.where((t) => t.savedAmount < t.targetAmount).toList();
  if (open.isEmpty) return null;
  final withDeadline = open.where((t) => t.deadline != null).toList()
    ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  if (withDeadline.isNotEmpty) return withDeadline.first;
  open.sort((a, b) => _progress(b).compareTo(_progress(a)));
  return open.first;
}

RecurringTransactionModel? pickNextBill(List<RecurringTransactionModel> items) {
  final bills = items
      .where((r) => r.isActive && ((r.category?['is_expense'] as bool?) ?? true))
      .toList()
    ..sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));
  return bills.isEmpty ? null : bills.first;
}

/// Jadwal aktif yang tertahan karena saldo dompet kurang (run_due_recurring).
List<RecurringTransactionModel> pickBlockedBills(List<RecurringTransactionModel> items) =>
    items.where((r) => r.isActive && (r.blockedReason ?? '').isNotEmpty).toList();

DebtModel? pickDebt(List<DebtModel> debts) {
  final open = debts
      .where((d) => d.type == DebtType.payable && !d.isPaidOff)
      .toList();
  if (open.isEmpty) return null;
  final dated = open.where((d) => d.dueDate != null).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  if (dated.isNotEmpty) return dated.first;
  open.sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount));
  return open.first;
}
