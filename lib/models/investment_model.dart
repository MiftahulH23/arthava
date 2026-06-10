class InvestmentModel {
  final int id;
  final String userId;
  final String name;
  final String type;
  final double capitalAmount;
  final double currentValue;
  final DateTime createdAt;

  InvestmentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.capitalAmount,
    required this.currentValue,
    required this.createdAt,
  });

  factory InvestmentModel.fromJson(Map<String, dynamic> json) {
    return InvestmentModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      type: json['type'],
      capitalAmount: (json['capital_amount'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'capital_amount': capitalAmount,
      'current_value': currentValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
