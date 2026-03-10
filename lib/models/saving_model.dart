class SavingModel {
  final int id;
  final String userId;
  final String name;
  final double amount;
  final String? location;
  final String? notes;

  SavingModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    this.location,
    this.notes,
  });

  factory SavingModel.fromJson(Map<String, dynamic> json) {
    return SavingModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      location: json['location'],
      notes: json['notes'],
    );
  }
}