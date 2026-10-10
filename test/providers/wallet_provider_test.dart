import 'package:arthava/models/wallet_model.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WalletNotifier.build() tidak membaca state sebelum terinisialisasi', () async {
    // Regresi: sebelumnya build() memanggil fetchWallets() langsung. Badan
    // fungsi async berjalan sinkron sampai `await` pertama, dan statement
    // pertamanya (`state = state.copyWith(isLoading: true)`) membaca `state`
    // padahal Riverpod baru menginisialisasi state SETELAH build() return.
    // Hasilnya StateError yang tertelan Future terbuang: tidak ada crash,
    // tapi isLoading tidak pernah jadi false dan layar loading selamanya.
    //
    // Di sini Supabase memang belum diinisialisasi, jadi fetchWallets pasti
    // gagal — justru itu intinya: dengan perbaikan, error ditangkap catch
    // block dan isLoading turun ke false. Dengan bug lama, fetchWallets
    // tidak pernah sampai ke catch block-nya sehingga isLoading tetap true.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // walletProvider autoDispose: tanpa listener aktif, provider langsung
    // dibuang setelah read() dan dibangun ulang pada read() berikutnya
    // (isLoading balik ke true). listen() menahannya tetap hidup.
    container.listen(walletProvider, (previous, next) {}, fireImmediately: true);

    expect(container.read(walletProvider).isLoading, isTrue);

    // Beri kesempatan microtask + error handling berjalan.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(walletProvider).isLoading,
      isFalse,
      reason: 'fetchWallets harus selesai (sukses atau gagal) dan menurunkan isLoading',
    );
  });

  group('validateTransfer', () {
    final source = WalletModel(id: 1, userId: 'u1', name: 'BCA', balance: 100000);
    final dest = WalletModel(id: 2, userId: 'u1', name: 'GoPay', balance: 50000);

    test('mengembalikan null (valid) jika saldo cukup dan wallet berbeda', () {
      final error = validateTransfer(source: source, dest: dest, amount: 50000);
      expect(error, isNull);
    });

    test('saldo tidak lagi dicek di app (server menolak dengan saldo minimal)', () {
      final error = validateTransfer(source: source, dest: dest, amount: 150000);
      expect(error, isNull);
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
