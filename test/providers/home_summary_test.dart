import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:flutter_test/flutter_test.dart';

TargetModel target(int id, double saved, double goal, {DateTime? deadline}) =>
    TargetModel(id: id, name: 'T$id', targetAmount: goal, savedAmount: saved, deadline: deadline);

RecurringTransactionModel bill(int id, DateTime next, {bool active = true, bool? isExpense = true}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u',
      categoryId: 1,
      amount: 100000,
      frequency: 'Bulanan',
      startDate: DateTime(2026, 1, 1),
      nextRunDate: next,
      isActive: active,
      category: isExpense == null ? null : {'name': 'Kos', 'is_expense': isExpense},
    );

// Dibangun lewat fromJson (kolom DB) supaya tidak bergantung pada urutan konstruktor B2.
DebtModel debt(int id, double remaining, {String type = 'payable', String status = 'active', DateTime? due}) =>
    DebtModel.fromJson({
      'id': id,
      'name': 'D$id',
      'type': type,
      'amount': 1000000,
      'remaining_amount': remaining,
      'loan_date': '2026-01-01',
      'due_date': due == null ? null : '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
      'status': status,
    });

void main() {
  group('summarizeBudgets', () {
    test('null bila tidak ada anggaran bulan ini', () {
      expect(summarizeBudgets(budgets: [], monthTransactions: []), isNull);
    });

    test('hanya pengeluaran pada kategori beranggaran, tanpa mutasi internal', () {
      final s = summarizeBudgets(
        budgets: [
          {'category_id': 1, 'amount': 1500000},
          {'category_id': 2, 'amount': 500000},
        ],
        monthTransactions: [
          {'amount': 100000, 'category_id': 1, 'note': 'makan', 'categories': {'is_expense': true}},
          {'amount': 50000, 'category_id': 2, 'note': null, 'categories': {'is_expense': true}},
          {'amount': 999, 'category_id': 3, 'note': '', 'categories': {'is_expense': true}}, // tidak dianggarkan
          {'amount': 700000, 'category_id': 1, 'note': 'gaji', 'categories': {'is_expense': false}}, // pemasukan
          {'amount': 250000, 'category_id': 1, 'note': 'x [SAVING_ID:3]', 'categories': {'is_expense': true}},
          {'amount': 300000, 'category_id': 1, 'note': 'y [DEBT_ID:9]', 'categories': {'is_expense': true}},
        ],
      )!;
      expect(s.totalBudget, 2000000);
      expect(s.totalSpent, 150000);
      expect(s.ratio, closeTo(0.075, 1e-9));
    });

    test('ratio 0 bila total anggaran 0 (tidak membagi dengan nol)', () {
      final s = summarizeBudgets(budgets: [{'category_id': 1, 'amount': 0}], monthTransactions: [])!;
      expect(s.ratio, 0);
    });
  });

  group('pickTarget', () {
    test('deadline terdekat di antara yang belum tercapai', () {
      final t = pickTarget([
        target(1, 10, 100, deadline: DateTime(2026, 12, 31)),
        target(2, 10, 100, deadline: DateTime(2026, 10, 1)),
        target(3, 100, 100, deadline: DateTime(2026, 9, 1)), // tercapai
      ]);
      expect(t!.id, 2);
    });

    test('tanpa deadline: progres tertinggi', () {
      final t = pickTarget([target(1, 10, 100), target(2, 80, 100), target(3, 30, 100)]);
      expect(t!.id, 2);
    });

    test('null bila semua tercapai', () {
      expect(pickTarget([target(1, 100, 100)]), isNull);
      expect(pickTarget([]), isNull);
    });
  });

  group('pickNextBill', () {
    test('jadwal aktif pengeluaran paling awal', () {
      final b = pickNextBill([
        bill(1, DateTime(2026, 10, 5)),
        bill(2, DateTime(2026, 10, 1)),
        bill(3, DateTime(2026, 9, 25), isExpense: false), // pemasukan
        bill(4, DateTime(2026, 9, 20), active: false), // nonaktif
      ]);
      expect(b!.id, 2);
    });

    test('kategori tidak terbaca dianggap pengeluaran', () {
      expect(pickNextBill([bill(1, DateTime(2026, 10, 1), isExpense: null)])!.id, 1);
    });

    test('null bila tidak ada tagihan', () {
      expect(pickNextBill([bill(1, DateTime(2026, 10, 1), isExpense: false)]), isNull);
    });
  });

  group('pickDebt', () {
    test('utang saya dengan jatuh tempo paling awal (yang terlambat duluan)', () {
      final d = pickDebt([
        debt(1, 500000, due: DateTime(2026, 11, 1)),
        debt(2, 200000, due: DateTime(2026, 9, 1)),
        debt(3, 900000, type: 'receivable', due: DateTime(2026, 8, 1)),
        debt(4, 0, due: DateTime(2026, 7, 1)),
        debt(5, 300000, status: 'paid', due: DateTime(2026, 7, 1)),
      ]);
      expect(d!.id, 2);
    });

    test('tanpa jatuh tempo: sisa terbesar', () {
      expect(pickDebt([debt(1, 100), debt(2, 900), debt(3, 500)])!.id, 2);
    });

    test('null bila bebas utang', () {
      expect(pickDebt([debt(1, 500, type: 'receivable')]), isNull);
    });
  });

  test('kartu Utang memakai aturan terlambat B2 (DebtModel.overdueDays)', () {
    final today = DateTime(2026, 9, 24);
    expect(pickDebt([debt(1, 500, due: DateTime(2026, 9, 22))])!.overdueDays(today), 2);
    expect(pickDebt([debt(1, 500, due: DateTime(2026, 9, 30))])!.overdueDays(today), 0);
  });
}
