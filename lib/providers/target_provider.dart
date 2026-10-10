import 'package:arthava/models/target_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// State untuk TargetScreen: daftar target keuangan, total gabungan saldo
/// yang sudah terkumpul, dompet (untuk setoran), dan nama-nama kelompok
/// tabungan (untuk autocomplete lokasi penyimpanan & sinkronisasi saldo).
class TargetState {
  final bool isLoading;
  final List<TargetModel> targets;
  final double totalSavings;
  final List<Map<String, dynamic>> wallets;
  final List<String> savingNames;

  const TargetState({
    this.isLoading = true,
    this.targets = const [],
    this.totalSavings = 0,
    this.wallets = const [],
    this.savingNames = const [],
  });

  TargetState copyWith({
    bool? isLoading,
    List<TargetModel>? targets,
    double? totalSavings,
    List<Map<String, dynamic>>? wallets,
    List<String>? savingNames,
  }) {
    return TargetState(
      isLoading: isLoading ?? this.isLoading,
      targets: targets ?? this.targets,
      totalSavings: totalSavings ?? this.totalSavings,
      wallets: wallets ?? this.wallets,
      savingNames: savingNames ?? this.savingNames,
    );
  }
}

class TargetNotifier extends AutoDisposeNotifier<TargetState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  TargetState build() {
    // Jangan baca/tulis `state` secara sinkron di sini — state baru
    // diinisialisasi Riverpod SETELAH build() return. Future.microtask
    // menunda fetch pertama sampai build() selesai.
    Future.microtask(fetchAll);
    return const TargetState();
  }

  /// Sama seperti `_TargetScreenState.initState` sebelum migrasi:
  /// `_fetchWallets()` dan `_fetchTargets()` dipanggil tanpa saling
  /// menunggu (fire-and-forget, berjalan paralel) — dipertahankan lewat
  /// Future.wait.
  Future<void> fetchAll() async {
    await Future.wait([fetchWallets(), fetchTargets()]);
  }

  Future<void> fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('name');
      state = state.copyWith(wallets: List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint("Error fetch wallets: $e");
    }
  }

  Future<void> fetchTargets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Fetch Tabungan (Savings) to sync balances automatically
      final savingRes = await _supabase
          .from('savings')
          .select('name, amount')
          .eq('user_id', userId);
      Map<String, double> savingBalances = {};
      for (var item in savingRes) {
        String name = item['name'].toString().trim();
        double amt = (item['amount'] as num).toDouble();
        savingBalances[name] = (savingBalances[name] ?? 0) + amt;
      }

      // 2. Fetch Targets
      final res = await _supabase
          .from('targets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<TargetModel> data = (res as List)
          .map((e) => TargetModel.fromJson(e))
          .toList();

      double total = 0;
      for (var t in data) {
        if (t.storageLocation != null &&
            savingBalances.containsKey(t.storageLocation!.trim())) {
          // Overwrite manual savedAmount with synced Tabungan balance
          t.savedAmount = savingBalances[t.storageLocation!.trim()]!;
        }
        total += t.savedAmount;
      }

      state = state.copyWith(
        savingNames: savingBalances.keys.toList(),
        targets: data,
        totalSavings: total,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error Target: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  /// Membuat target baru (dari `_showAddSheet`).
  Future<void> addTarget({
    required String name,
    required double targetAmount,
    String? storageLocation,
    DateTime? deadline,
  }) async {
    await _supabase.from('targets').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'name': name,
      'target_amount': targetAmount,
      'storage_location': storageLocation,
      'deadline': deadline?.toIso8601String(),
    });
    await fetchTargets();
  }

  /// Mengubah target yang sudah ada (dari `_showEditSheet`).
  Future<void> editTarget({
    required int id,
    required String name,
    required double targetAmount,
    required double savedAmount,
    String? storageLocation,
    DateTime? deadline,
  }) async {
    await _supabase
        .from('targets')
        .update({
          'name': name,
          'target_amount': targetAmount,
          'saved_amount': savedAmount,
          'storage_location': storageLocation,
          'deadline': deadline?.toIso8601String(),
        })
        .eq('id', id);
    await fetchTargets();
  }

  /// Setor dana ke satu target (dari `_showDepositSheet`). Mengembalikan
  /// pesan error yang persis sama dengan teks aslinya untuk kasus saldo
  /// dompet tidak cukup (bukan throw) supaya pemanggil bisa menampilkannya
  /// lewat AppNotification tanpa mengubah string, dan null kalau berhasil.
  /// Error lain (mis. kegagalan jaringan) dibiarkan menjalar sebagai
  /// exception, persis seperti try/catch di layar aslinya yang hanya
  /// men-debugPrint tanpa notifikasi.
  Future<String?> depositToTarget({
    required TargetModel target,
    required double rawAmount,
    required int walletId,
  }) async {
    // Satu transaksi database (RPC deposit_to_target, migration
    // 202609260006): potong dompet, catat transaksi, tambah tabungan/target.
    // Dulu baca-saldo-lalu-tulis dari app: dua setoran bersamaan kehilangan satu.
    try {
      await _supabase.rpc('deposit_to_target', params: {
        'p_target_id': target.id,
        'p_wallet_id': walletId,
        'p_amount': rawAmount,
        'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    } on PostgrestException catch (e) {
      // Tolakan server (saldo kurang, nominal 0, dompet/target terhapus):
      // pesannya ditampilkan apa adanya.
      if (e.code == 'P0001') {
        fetchWallets();
        return e.message;
      }
      rethrow;
    }

    // Sama seperti sebelum migrasi: refetch tidak ditunggu (fire-and-forget)
    // supaya notifikasi sukses langsung tampil tanpa menunggu refresh.
    fetchWallets();
    fetchTargets();
    return null;
  }

  /// Menghapus target (dari `_confirmDelete`). Saldo dompet TIDAK
  /// dikembalikan otomatis — sama seperti perilaku aslinya.
  Future<void> deleteTarget(int id) async {
    await _supabase.from('targets').delete().eq('id', id);
    await fetchTargets();
  }
}

final targetProvider = NotifierProvider.autoDispose<TargetNotifier, TargetState>(
  TargetNotifier.new,
);
