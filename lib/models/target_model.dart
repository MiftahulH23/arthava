class TargetModel {
  final int id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final String? storageLocation; // Kolom Baru

  TargetModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    this.deadline,
    this.storageLocation,
  });

  factory TargetModel.fromJson(Map<String, dynamic> json) {
    return TargetModel(
      id: json['id'],
      name: json['name'],
      targetAmount: (json['target_amount'] as num).toDouble(),
      savedAmount: (json['saved_amount'] as num).toDouble(),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      storageLocation: json['storage_location'], // Baca dari DB
    );
  }
}
