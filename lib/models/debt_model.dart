import 'package:intl/intl.dart';

enum DebtType {
  payable,
  receivable;

  String get dbValue => this == DebtType.payable ? 'payable' : 'receivable';
}

enum DebtBadgeKind { paid, overdue, due, none }

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.parse(value as String);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

class DebtModel {
  final int id;
  final String name;
  final DebtType type;
  final double amount;
  final double remainingAmount;
  final DateTime loanDate;
  final DateTime? dueDate;
  final String? notes;
  final String status;
  final int? walletId;
  final int? transactionId;
  final DateTime? createdAt;

  const DebtModel({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.remainingAmount,
    required this.loanDate,
    required this.dueDate,
    required this.notes,
    required this.status,
    required this.walletId,
    required this.transactionId,
    required this.createdAt,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String?;
    final created = createdRaw == null ? null : DateTime.parse(createdRaw).toLocal();
    final rawNotes = (json['notes'] as String?)?.trim();
    return DebtModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] == 'receivable' ? DebtType.receivable : DebtType.payable,
      amount: (json['amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      loanDate: _parseDate(json['loan_date']) ??
          (created != null
              ? DateTime(created.year, created.month, created.day)
              : DateTime.now()),
      dueDate: _parseDate(json['due_date']),
      notes: (rawNotes == null || rawNotes.isEmpty) ? null : rawNotes,
      status: (json['status'] as String?) ?? 'active',
      walletId: (json['wallet_id'] as num?)?.toInt(),
      transactionId: (json['transaction_id'] as num?)?.toInt(),
      createdAt: created,
    );
  }

  bool get isPayable => type == DebtType.payable;

  double get paidAmount => (amount - remainingAmount).clamp(0, amount).toDouble();

  bool get isPaidOff => status == 'paid' || remainingAmount <= 0;

  double get progress => amount <= 0 ? 0 : (paidAmount / amount).clamp(0.0, 1.0).toDouble();

  bool isOverdue(DateTime today) =>
      !isPaidOff && dueDate != null && _dateOnly(dueDate!).isBefore(_dateOnly(today));

  int overdueDays(DateTime today) =>
      isOverdue(today) ? _dateOnly(today).difference(_dateOnly(dueDate!)).inDays : 0;

  DebtBadgeKind badgeKind(DateTime today) {
    if (isPaidOff) return DebtBadgeKind.paid;
    if (isOverdue(today)) return DebtBadgeKind.overdue;
    if (dueDate != null) return DebtBadgeKind.due;
    return DebtBadgeKind.none;
  }
}

String debtBadgeLabel(DebtModel debt, DateTime today) {
  switch (debt.badgeKind(today)) {
    case DebtBadgeKind.paid:
      return 'LUNAS';
    case DebtBadgeKind.overdue:
      return 'Terlambat ${debt.overdueDays(today)} hari';
    case DebtBadgeKind.due:
      return 'Tempo: ${DateFormat('dd MMM yyyy', 'id_ID').format(debt.dueDate!)}';
    case DebtBadgeKind.none:
      return '';
  }
}

String debtInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

List<DebtModel> sortDebts(Iterable<DebtModel> debts, DateTime today) {
  int rank(DebtModel d) {
    switch (d.badgeKind(today)) {
      case DebtBadgeKind.overdue:
        return 0;
      case DebtBadgeKind.due:
        return 1;
      case DebtBadgeKind.none:
        return 2;
      case DebtBadgeKind.paid:
        return 3;
    }
  }

  final list = debts.toList();
  list.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    if (rank(a) <= 1) {
      final byDue = a.dueDate!.compareTo(b.dueDate!);
      if (byDue != 0) return byDue;
    }
    final aTime = a.createdAt ?? a.loanDate;
    final bTime = b.createdAt ?? b.loanDate;
    return bTime.compareTo(aTime);
  });
  return list;
}
