import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletState {
  final List<WalletModel> wallets;
  final bool isLoading;

  const WalletState({this.wallets = const [], this.isLoading = true});

  WalletState copyWith({List<WalletModel>? wallets, bool? isLoading}) {
    return WalletState(
      wallets: wallets ?? this.wallets,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Mengembalikan pesan error kalau transfer tidak valid, atau null kalau valid.
/// Diekstrak dari logic validasi di WalletScreen._showTransferSheet's tombol
/// "Transfer Sekarang" supaya bisa diuji unit tanpa Supabase.
String? validateTransfer({
  required WalletModel source,
  required WalletModel dest,
  required double amount,
}) {
  if (amount <= 0) return 'Nominal tidak boleh kosong!';
  if (source.id == dest.id) return 'Dompet asal dan tujuan tidak boleh sama!';
  if (source.balance < amount) return 'Saldo di ${source.name} tidak cukup!';
  return null;
}

class WalletNotifier extends AutoDisposeNotifier<WalletState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  WalletState build() {
    fetchWallets();
    return const WalletState();
  }

  Future<void> fetchWallets() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      state = state.copyWith(
        wallets: (res as List).map((e) => WalletModel.fromJson(e)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addWallet({
    required String name,
    required double balance,
    required String color,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('wallets').insert({
      'user_id': userId,
      'name': name,
      'balance': balance,
      'color': color,
      'icon': 'wallet',
    });
    await fetchWallets();
  }

  Future<void> updateWallet({
    required int id,
    required String name,
    required double balance,
    required String color,
  }) async {
    await _supabase.from('wallets').update({
      'name': name,
      'balance': balance,
      'color': color,
      'icon': 'wallet',
    }).eq('id', id);
    await fetchWallets();
  }

  Future<void> deleteWallet(int id) async {
    await _supabase.from('wallets').delete().eq('id', id);
    await fetchWallets();
  }

  Future<void> transfer({
    required int sourceId,
    required int destId,
    required double amount,
  }) async {
    final source = state.wallets.firstWhere((w) => w.id == sourceId);
    final dest = state.wallets.firstWhere((w) => w.id == destId);

    final error = validateTransfer(source: source, dest: dest, amount: amount);
    if (error != null) throw Exception(error);

    try {
      await _supabase.from('wallets').update({'balance': source.balance - amount}).eq('id', sourceId);
      await _supabase.from('wallets').update({'balance': dest.balance + amount}).eq('id', destId);
    } catch (e) {
      throw Exception('Gagal memproses transfer.');
    }
    await fetchWallets();
  }
}

final walletProvider = NotifierProvider.autoDispose<WalletNotifier, WalletState>(WalletNotifier.new);
