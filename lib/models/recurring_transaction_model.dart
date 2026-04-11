class RecurringTransactionModel {
  final int id;
  final String userId;
  final int categoryId;
  final double amount;
  final String? note;
  final String frequency;
  final DateTime startDate;
  final DateTime nextRunDate;
  final bool isActive;
  final Map<String, dynamic>? category;
  final int? walletId;

  RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    this.note,
    required this.frequency,
    required this.startDate,
    required this.nextRunDate,
    required this.isActive,
    this.category,
    this.walletId,
  });

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      id: json['id'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      amount: (json['amount'] as num).toDouble(),
      note: json['note'],
      frequency: json['frequency'],
      startDate: DateTime.parse(json['start_date']),
      nextRunDate: DateTime.parse(json['next_run_date']),
      isActive: json['is_active'],
      category: json['categories'], // Akan berisi relasi ke tabel categories
      walletId: json['wallet_id'],
    );
  }
}