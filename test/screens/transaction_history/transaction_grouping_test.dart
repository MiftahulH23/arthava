import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _trx(int id, DateTime date) => TransactionModel(
      id: id,
      userId: 'u',
      categoryId: 1,
      amount: 1000,
      date: date,
    );

void main() {
  test('list kosong menghasilkan list kosong', () {
    expect(groupTransactionsByDate([]), isEmpty);
  });

  test('mengelompokkan per hari dan mempertahankan urutan (desc dari provider)', () {
    final groups = groupTransactionsByDate([
      _trx(3, DateTime(2026, 9, 24)),
      _trx(2, DateTime(2026, 9, 24)),
      _trx(1, DateTime(2026, 9, 23)),
    ]);
    expect(groups.length, 2);
    expect(groups[0].$1, DateTime(2026, 9, 24));
    expect(groups[0].$2.map((t) => t.id), [3, 2]);
    expect(groups[1].$1, DateTime(2026, 9, 23));
    expect(groups[1].$2.map((t) => t.id), [1]);
  });

  test('jam berbeda di hari yang sama masuk satu grup, kunci jam 00:00', () {
    final groups = groupTransactionsByDate([
      _trx(1, DateTime(2026, 9, 24, 23, 59)),
      _trx(2, DateTime(2026, 9, 24, 0, 1)),
    ]);
    expect(groups.length, 1);
    expect(groups.single.$1, DateTime(2026, 9, 24));
  });

  test('input tidak terurut: hari yang sama tetap satu grup, urutan kemunculan pertama', () {
    final groups = groupTransactionsByDate([
      _trx(1, DateTime(2026, 9, 24)),
      _trx(2, DateTime(2026, 9, 20)),
      _trx(3, DateTime(2026, 9, 24)),
    ]);
    expect(groups.map((g) => g.$1), [DateTime(2026, 9, 24), DateTime(2026, 9, 20)]);
    expect(groups[0].$2.map((t) => t.id), [1, 3]);
  });
}
