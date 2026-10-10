import 'package:arthava/core/colors.dart';
import 'package:flutter/painting.dart';

class WalletModel {
  final int id;
  final String userId;
  final String name;
  final double balance;
  final String? color;
  final String? icon;
  final bool isFavorite;
  final double minBalance;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.color,
    this.icon,
    this.isFavorite = false,
    this.minBalance = 0,
  });

  Color get displayColor => AppColors.fromWalletHex(color);

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      balance: (json['balance'] as num).toDouble(),
      color: json['color'],
      icon: json['icon'],
      // Kolom baru (migration 202609260003). Default dipakai bila kolom belum ada.
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      minBalance: (json['min_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
