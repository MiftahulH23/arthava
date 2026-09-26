import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  final today = DateTime(2026, 9, 24);

  DebtModel debt({
    int id = 1,
    DebtType type = DebtType.payable,
    double amount = 2000000,
    double remaining = 1200000,
    DateTime? due,
    String status = 'active',
    DateTime? created,
  }) {
    return DebtModel(
      id: id,
      name: 'Budi Santoso',
      type: type,
      amount: amount,
      remainingAmount: remaining,
      loanDate: DateTime(2026, 8, 1),
      dueDate: due,
      notes: null,
      status: status,
      walletId: null,
      transactionId: null,
      createdAt: created,
    );
  }

  group('DebtModel.fromJson', () {
    test('memetakan kolom baru dan lama', () {
      final m = DebtModel.fromJson({
        'id': 7,
        'user_id': 'u1',
        'name': 'Rina',
        'type': 'receivable',
        'amount': 750000,
        'remaining_amount': 500000.5,
        'loan_date': '2026-09-20',
        'due_date': '2026-11-15',
        'notes': '  Patungan kado  ',
        'status': 'active',
        'wallet_id': 3,
        'transaction_id': 44,
        'created_at': '2026-09-20T10:00:00+00:00',
      });
      expect(m.id, 7);
      expect(m.type, DebtType.receivable);
      expect(m.isPayable, isFalse);
      expect(m.amount, 750000);
      expect(m.remainingAmount, 500000.5);
      expect(m.loanDate, DateTime(2026, 9, 20));
      expect(m.dueDate, DateTime(2026, 11, 15));
      expect(m.notes, 'Patungan kado');
      expect(m.walletId, 3);
      expect(m.transactionId, 44);
    });

    test('catatan kosong jadi null, loan_date hilang jatuh ke created_at', () {
      final m = DebtModel.fromJson({
        'id': 1,
        'name': 'X',
        'type': 'payable',
        'amount': 1,
        'remaining_amount': 1,
        'notes': '   ',
        'status': null,
        'created_at': '2026-01-03T01:00:00+00:00',
      });
      expect(m.notes, isNull);
      expect(m.status, 'active');
      expect(m.loanDate.year, 2026);
      expect(m.loanDate.month, 1);
    });
  });

  group('status & badge', () {
    test('isPaidOff dari status atau sisa <= 0', () {
      expect(debt(status: 'paid').isPaidOff, isTrue);
      expect(debt(remaining: 0).isPaidOff, isTrue);
      expect(debt().isPaidOff, isFalse);
    });

    test('progress dan paidAmount', () {
      expect(debt().paidAmount, 800000);
      expect(debt().progress, closeTo(0.4, 1e-9));
      expect(debt(amount: 0, remaining: 0).progress, 0);
    });

    test('terlambat dihitung per tanggal, bukan jam', () {
      final d = debt(due: DateTime(2026, 9, 22, 23, 59));
      expect(d.isOverdue(DateTime(2026, 9, 24, 0, 1)), isTrue);
      expect(d.overdueDays(today), 2);
      expect(debt(due: today).isOverdue(today), isFalse);
      expect(debt(due: DateTime(2026, 9, 1), status: 'paid').isOverdue(today), isFalse);
    });

    test('badgeKind dan label', () {
      expect(debt(status: 'paid').badgeKind(today), DebtBadgeKind.paid);
      expect(debtBadgeLabel(debt(status: 'paid'), today), 'LUNAS');
      expect(debt(due: DateTime(2026, 9, 22)).badgeKind(today), DebtBadgeKind.overdue);
      expect(debtBadgeLabel(debt(due: DateTime(2026, 9, 22)), today), 'Terlambat 2 hari');
      expect(debt(due: DateTime(2026, 11, 15)).badgeKind(today), DebtBadgeKind.due);
      expect(debtBadgeLabel(debt(due: DateTime(2026, 11, 15)), today), 'Tempo: 15 Nov 2026');
      expect(debt().badgeKind(today), DebtBadgeKind.none);
      expect(debtBadgeLabel(debt(), today), '');
    });
  });

  test('debtInitials', () {
    expect(debtInitials('Budi Santoso'), 'BS');
    expect(debtInitials('rina'), 'R');
    expect(debtInitials('  Bank   Jago Syariah '), 'BJ');
    expect(debtInitials(''), '?');
  });

  test('sortDebts: terlambat -> jatuh tempo terdekat -> tanpa tempo -> lunas', () {
    final lunas = debt(id: 1, status: 'paid');
    final tanpaTempoLama = debt(id: 2, created: DateTime(2026, 1, 1));
    final tanpaTempoBaru = debt(id: 3, created: DateTime(2026, 9, 1));
    final tempoJauh = debt(id: 4, due: DateTime(2026, 12, 1));
    final tempoDekat = debt(id: 5, due: DateTime(2026, 10, 1));
    final telatBaru = debt(id: 6, due: DateTime(2026, 9, 23));
    final telatLama = debt(id: 7, due: DateTime(2026, 9, 1));

    final sorted = sortDebts(
      [lunas, tanpaTempoLama, tempoJauh, telatBaru, tanpaTempoBaru, tempoDekat, telatLama],
      today,
    );
    expect(sorted.map((d) => d.id).toList(), [7, 6, 5, 4, 3, 2, 1]);
  });

  test('DebtPaymentModel.fromJson membaca nama dompet dan tautan transaksi', () {
    final p = DebtPaymentModel.fromJson({
      'id': 11,
      'debt_id': 7,
      'user_id': 'u1',
      'wallet_id': 3,
      'amount': 500000,
      'date': '2026-09-15',
      'transaction_id': 90,
      'created_at': '2026-09-15T02:00:00+00:00',
      'wallets': {'name': 'BCA'},
    });
    expect(p.id, 11);
    expect(p.debtId, 7);
    expect(p.walletName, 'BCA');
    expect(p.affectsWallet, isTrue);
    expect(p.date, DateTime(2026, 9, 15));

    final legacy = DebtPaymentModel.fromJson({
      'id': 12,
      'debt_id': 7,
      'wallet_id': null,
      'amount': 300000,
      'date': '2026-09-01',
      'wallets': null,
    });
    expect(legacy.walletName, isNull);
    expect(legacy.affectsWallet, isFalse);
  });
}
