import 'package:arthava/models/category_model.dart';

class TransactionModel {
  final int id;
  final String userId;
  final int categoryId;
  final double amount;
  final DateTime date;
  final String? note;
  final CategoryModel? category;
  final int? walletId; // [NEW] Ini yang bikin error kemaren, sekarang udah aman!

  TransactionModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.note,
    this.category,
    this.walletId, // [NEW]
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      note: json['note'],
      category: json['categories'] != null
          ? CategoryModel.fromJson(json['categories'])
          : null,
      walletId: json['wallet_id'], // [NEW] Supaya narik data dompet dari database
    );
  }
}