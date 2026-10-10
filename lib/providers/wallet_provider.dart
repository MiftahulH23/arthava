import 'package:arthava/models/wallet_model.dart';
import 'package:flutter/foundation.dart';
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
/// Saldo & saldo minimal dicek server (wallet_spend_guard), bukan di sini.
String? validateTransfer({
  required WalletModel source,
  required WalletModel dest,
  required double amount,
}) {
  if (amount <= 0) return 'Nominal tidak boleh kosong!';
  if (source.id == dest.id) return 'Dompet asal dan tujuan tidak boleh sama!';
  return null;
}

/// Menyimpan dompet baru dan mengembalikan id-nya. Top-level supaya bisa
/// dipanggil dari layar mana pun (form "Dompet Baru") tanpa bergantung pada
/// WalletNotifier yang sedang hidup.
Future<int> insertWallet({
  required String name,
  required double balance,
  required String color,
  double minBalance = 0,
}) async {
  final client = Supabase.instance.client;
  final row = await client
      .from('wallets')
      .insert({
        'user_id': client.auth.currentUser!.id,
        'name': name,
        'balance': balance,
        'color': color,
        'icon': 'wallet',
        'min_balance': minBalance,
      })
      .select('id')
      .single();
  return row['id'] as int;
}

Future<void> updateWalletRow({
  required int id,
  required String name,
  required double balance,
  required String color,
  double minBalance = 0,
}) async {
  await Supabase.instance.client.from('wallets').update({
    'name': name,
    'balance': balance,
    'color': color,
    'icon': 'wallet',
    'min_balance': minBalance,
  }).eq('id', id);
}

class WalletNotifier extends AutoDisposeNotifier<WalletState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  WalletState build() {
    // JANGAN panggil fetchWallets() langsung di sini: badan fungsi async
    // berjalan sinkron sampai `await` pertama, dan statement pertamanya
    // membaca `state` — padahal state baru diinisialisasi Riverpod SETELAH
    // build() return. Itu melempar StateError yang tertelan Future terbuang,
    // sehingga isLoading tidak pernah jadi false (loading selamanya).
    // Future.microtask menunda eksekusinya sampai build() selesai.
    Future.microtask(fetchWallets);
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
      debugPrint("Error fetch wallets: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<int> addWallet({
    required String name,
    required double balance,
    required String color,
    double minBalance = 0,
  }) async {
    final id = await insertWallet(name: name, balance: balance, color: color, minBalance: minBalance);
    await fetchWallets();
    return id;
  }

  Future<void> updateWallet({
    required int id,
    required String name,
    required double balance,
    required String color,
    double minBalance = 0,
  }) async {
    await updateWalletRow(id: id, name: name, balance: balance, color: color, minBalance: minBalance);
    await fetchWallets();
  }

  Future<void> deleteWallet(int id) async {
    await _supabase.from('wallets').delete().eq('id', id);
    await fetchWallets();
  }

  Future<void> setFavorite(int id, bool isFavorite) async {
    await _supabase.from('wallets').update({'is_favorite': isFavorite}).eq('id', id);
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

    // Validasi di atas memakai saldo di layar (umpan balik instan); server
    // memeriksa ulang saldo terbaru dan memindahkan uang atomik (Plan B4b).
    try {
      await _supabase.rpc('transfer_between_wallets', params: {
        'p_from': sourceId,
        'p_to': destId,
        'p_amount': amount,
      });
    } on PostgrestException catch (e) {
      // Saldo di layar mungkin sudah basi (itulah sebab server menolak): segarkan.
      await fetchWallets();
      // P0001 = RAISE dari RPC kita (pesan Indonesia); galat lain tetap pesan umum.
      throw Exception(e.code == 'P0001' ? e.message : 'Gagal memproses transfer.');
    } catch (e) {
      throw Exception('Gagal memproses transfer.');
    }
    await fetchWallets();
  }
}

final walletProvider = NotifierProvider.autoDispose<WalletNotifier, WalletState>(WalletNotifier.new);
