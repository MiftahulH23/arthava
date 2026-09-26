class DebtPaymentModel {
  final int id;
  final int debtId;
  final int? walletId;
  final String? walletName;
  final int? transactionId;
  final double amount;
  final DateTime date;
  final DateTime? createdAt;

  const DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.walletId,
    required this.walletName,
    required this.transactionId,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  factory DebtPaymentModel.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallets'];
    final parsedDate = DateTime.parse(json['date'] as String);
    final createdRaw = json['created_at'] as String?;
    return DebtPaymentModel(
      id: (json['id'] as num).toInt(),
      debtId: (json['debt_id'] as num).toInt(),
      walletId: (json['wallet_id'] as num?)?.toInt(),
      walletName: wallet is Map ? wallet['name'] as String? : null,
      transactionId: (json['transaction_id'] as num?)?.toInt(),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      createdAt: createdRaw == null ? null : DateTime.parse(createdRaw).toLocal(),
    );
  }

  bool get affectsWallet => transactionId != null;
}
