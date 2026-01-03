import 'package:catat_uang_app/models/category_model.dart';

class TransactionModel {
  final int id;
  final double amount;
  final DateTime date;
  final String? note;
  final int categoryId;
  final CategoryModel? category; // Data lengkap kategorinya (Nama, Icon)

  TransactionModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
    required this.categoryId,
    this.category,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      note: json['note'],
      categoryId: json['category_id'],
      category: json['categories'] != null 
          ? CategoryModel.fromJson(json['categories']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date.toIso8601String(), // Ubah tanggal jadi string
      'note': note,
      'category_id': categoryId,
    };
  }
}