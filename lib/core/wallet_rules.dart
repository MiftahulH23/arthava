import 'package:arthava/models/wallet_model.dart';

const int kHomeFavoriteLimit = 5;
const int kHomeTopWalletCount = 3;

/// Dompet yang tampil di Beranda (spec §7.2): semua favorit (maks 5) bila ada;
/// bila tidak ada favorit, 3 dompet dengan saldo terbesar.
({List<WalletModel> shown, int hiddenCount}) homeWallets(List<WalletModel> wallets) {
  final favorites = wallets.where((w) => w.isFavorite).toList();
  final List<WalletModel> shown;
  if (favorites.isNotEmpty) {
    shown = favorites.take(kHomeFavoriteLimit).toList();
  } else {
    final sorted = [...wallets]
      ..sort((a, b) {
        final byBalance = b.balance.compareTo(a.balance);
        return byBalance != 0 ? byBalance : a.id.compareTo(b.id);
      });
    shown = sorted.take(kHomeTopWalletCount).toList();
  }
  return (shown: shown, hiddenCount: wallets.length - shown.length);
}

/// Uang yang benar-benar bisa dipakai dari satu dompet: saldo − saldo minimal, minimal 0.
double spendableOf(WalletModel w) {
  final value = w.balance - w.minBalance;
  return value < 0 ? 0 : value;
}

/// Total saldo di Beranda. `includeMinBalance == true` = perilaku lama (jumlah saldo apa adanya).
double spendableTotal(List<WalletModel> wallets, {required bool includeMinBalance}) {
  var total = 0.0;
  for (final w in wallets) {
    total += includeMinBalance ? w.balance : spendableOf(w);
  }
  return total;
}
