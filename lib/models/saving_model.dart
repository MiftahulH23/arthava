class SavingModel {
  final int id;
  final String userId;
  final String name;
  final double amount;
  final String? location;
  final String? notes;
  final DateTime createdAt; 

  SavingModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.createdAt, 
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
      // [NEW] Mengambil data tanggal dari Supabase, jika kosong pakai waktu saat ini
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}