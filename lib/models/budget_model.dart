import 'package:arthava/models/category_model.dart';

class BudgetModel {
  final int id;
  final int categoryId;
  final double amount;
  final int month;
  final int year;
  final CategoryModel? category;

  BudgetModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
    this.category,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'],
      categoryId: json['category_id'],
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] ?? DateTime.now().month, // Default jaga-jaga
      year: json['year'] ?? DateTime.now().year, // Default jaga-jaga
      category: json['categories'] != null
          ? CategoryModel.fromJson(json['categories'])
          : null,
    );
  }
}
