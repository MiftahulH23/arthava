import 'package:arthava/core/colors.dart';
import 'package:arthava/models/wallet_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson tanpa kolom baru (migration belum jalan) memakai default', () {
    final m = WalletModel.fromJson({'id': 1, 'user_id': 'u', 'name': 'BCA', 'balance': 1000, 'color': '#00796B'});
    expect(m.isFavorite, isFalse);
    expect(m.minBalance, 0);
    expect(m.displayColor, const Color(0xFF00796B));
  });

  test('fromJson membaca is_favorite dan min_balance', () {
    final m = WalletModel.fromJson({
      'id': 1, 'user_id': 'u', 'name': 'BCA', 'balance': 1000,
      'is_favorite': true, 'min_balance': 50000,
    });
    expect(m.isFavorite, isTrue);
    expect(m.minBalance, 50000);
  });

  test('warna dompet null / rusak jatuh ke warna default', () {
    expect(AppColors.fromWalletHex(null), const Color(0xFF1E3A8A));
    expect(AppColors.fromWalletHex('bukan-warna'), const Color(0xFF1E3A8A));
    expect(AppColors.walletColorChoices.first, '#1E3A8A');
    expect(AppColors.walletColorChoices.length, 8);
  });
}
