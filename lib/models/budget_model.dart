import 'package:catat_uang_app/models/category_model.dart';

class BudgetModel {
  final int id;
  final int categoryId;
  final double amount; // Limit anggaran
  final CategoryModel? category; // Data kategori (nama, icon, warna)

  BudgetModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    this.category,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'],
      categoryId: json['category_id'],
      amount: (json['amount'] as num).toDouble(),
      category: json['categories'] != null
          ? CategoryModel.fromJson(json['categories'])
          : null,
    );
  }
}
