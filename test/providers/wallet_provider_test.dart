import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTransfer', () {
    final source = WalletModel(id: 1, userId: 'u1', name: 'BCA', balance: 100000);
    final dest = WalletModel(id: 2, userId: 'u1', name: 'GoPay', balance: 50000);

    test('mengembalikan null (valid) jika saldo cukup dan wallet berbeda', () {
      final error = validateTransfer(source: source, dest: dest, amount: 50000);
      expect(error, isNull);
    });

    test('menolak jika saldo sumber tidak cukup', () {
      final error = validateTransfer(source: source, dest: dest, amount: 150000);
      expect(error, isNotNull);
    });

    test('menolak jika sumber dan tujuan sama', () {
      final error = validateTransfer(source: source, dest: source, amount: 1000);
      expect(error, isNotNull);
    });

    test('menolak jika amount nol atau negatif', () {
      final error = validateTransfer(source: source, dest: dest, amount: 0);
      expect(error, isNotNull);
    });
  });
}
