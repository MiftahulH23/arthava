class WalletModel {
  final int id;
  final String userId;
  final String name;
  final double balance;
  final String? color;
  final String? icon;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.color,
    this.icon,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      balance: (json['balance'] as num).toDouble(),
      color: json['color'],
      icon: json['icon'],
    );
  }
}