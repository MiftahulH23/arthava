import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

WalletModel w(int id, double balance, {bool fav = false, double min = 0}) => WalletModel(
      id: id,
      userId: 'u',
      name: 'W$id',
      balance: balance,
      isFavorite: fav,
      minBalance: min,
    );

void main() {
  group('homeWallets', () {
    test('tanpa favorit: 3 saldo terbesar, sisanya dihitung tersembunyi', () {
      final r = homeWallets([w(1, 100), w(2, 500), w(3, 300), w(4, 900), w(5, 50)]);
      expect(r.shown.map((e) => e.id), [4, 2, 3]);
      expect(r.hiddenCount, 2);
    });

    test('tepat 3 dompet tanpa favorit: semua tampil, tidak ada yang tersembunyi', () {
      final r = homeWallets([w(1, 100), w(2, 200), w(3, 300)]);
      expect(r.shown.length, 3);
      expect(r.hiddenCount, 0);
    });

    test('saldo sama diurutkan berdasarkan id supaya stabil', () {
      final r = homeWallets([w(3, 100), w(1, 100), w(2, 100)]);
      expect(r.shown.map((e) => e.id), [1, 2, 3]);
    });

    test('ada favorit: hanya favorit yang tampil walau saldonya kecil', () {
      final r = homeWallets([w(1, 900), w(2, 10, fav: true), w(3, 20, fav: true)]);
      expect(r.shown.map((e) => e.id), [2, 3]);
      expect(r.hiddenCount, 1);
    });

    test('lebih dari 5 favorit: maksimal 5 tampil', () {
      final wallets = [for (var i = 1; i <= 7; i++) w(i, i * 10.0, fav: true)];
      final r = homeWallets(wallets);
      expect(r.shown.length, 5);
      expect(r.shown.map((e) => e.id), [1, 2, 3, 4, 5]);
      expect(r.hiddenCount, 2);
    });

    test('list kosong', () {
      final r = homeWallets([]);
      expect(r.shown, isEmpty);
      expect(r.hiddenCount, 0);
    });
  });

  group('spendableTotal', () {
    test('pengaturan aktif: jumlah saldo apa adanya', () {
      expect(spendableTotal([w(1, 1000, min: 200), w(2, 500)], includeMinBalance: true), 1500);
    });

    test('pengaturan nonaktif: saldo dikurangi saldo minimal', () {
      expect(spendableTotal([w(1, 1000, min: 200), w(2, 500)], includeMinBalance: false), 1300);
    });

    test('spendableTotal clamps per dompet di 0 bila saldo minimal > saldo', () {
      expect(spendableTotal([w(1, 100, min: 300), w(2, 500)], includeMinBalance: false), 500);
      expect(spendableOf(w(1, 100, min: 300)), 0);
    });
  });
}
