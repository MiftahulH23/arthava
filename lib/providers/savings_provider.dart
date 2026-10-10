import 'package:arthava/core/money_rejection.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/models/saving_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// State gabungan untuk SavingsScreen (daftar tabungan yang dikelompokkan
/// per nama) dan SavingDetailScreen (riwayat setor/tarik satu kelompok
/// tabungan). Keduanya berbagi provider ini karena mengedit/menghapus satu
/// baris riwayat di layar detail mengubah total & saldo dompet yang juga
/// ditampilkan SavingsScreen — dengan satu provider, perubahan itu langsung
/// terlihat di kedua layar tanpa refetch manual setelah Navigator.pop.
class SavingsState {
  final bool isLoading;
  final Map<String, List<SavingModel>> groupedSavings;
  final double totalSavings;
  final List<Map<String, dynamic>> wallets;

  const SavingsState({
    this.isLoading = true,
    this.groupedSavings = const {},
    this.totalSavings = 0,
    this.wallets = const [],
  });

  SavingsState copyWith({
    bool? isLoading,
    Map<String, List<SavingModel>>? groupedSavings,
    double? totalSavings,
    List<Map<String, dynamic>>? wallets,
  }) {
    return SavingsState(
      isLoading: isLoading ?? this.isLoading,
      groupedSavings: groupedSavings ?? this.groupedSavings,
      totalSavings: totalSavings ?? this.totalSavings,
      wallets: wallets ?? this.wallets,
    );
  }
}

class SavingsNotifier extends AutoDisposeNotifier<SavingsState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  SavingsState build() {
    // Jangan baca/tulis `state` secara sinkron di sini — state baru
    // diinisialisasi Riverpod SETELAH build() return. Future.microtask
    // menunda fetch pertama sampai build() selesai.
    Future.microtask(fetchAll);
    return const SavingsState();
  }

  /// Sama seperti `_SavingsScreenState.initState` sebelum migrasi:
  /// `_fetchWallets()` dan `_fetchSavings()` dipanggil tanpa saling
  /// menunggu (fire-and-forget, berjalan paralel) — dipertahankan lewat
  /// Future.wait.
  Future<void> fetchAll() async {
    await Future.wait([fetchWallets(), fetchSavings()]);
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

  Future<void> fetchSavings() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('savings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      double total = 0;
      Map<String, List<SavingModel>> tempGrouped = {};

      for (var item in res) {
        final saving = SavingModel.fromJson(item);
        total += saving.amount;
        String groupName = saving.name.trim();
        String groupKey = groupName.toLowerCase();
        String existingKey = tempGrouped.keys.firstWhere(
          (k) => k.toLowerCase() == groupKey,
          orElse: () => groupName,
        );
        if (!tempGrouped.containsKey(existingKey)) {
          tempGrouped[existingKey] = [];
        }
        tempGrouped[existingKey]!.add(saving);
      }

      state = state.copyWith(
        groupedSavings: tempGrouped,
        totalSavings: total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Setor/tarik dana untuk satu kelompok tabungan. Dipakai baik dari
  /// SavingsScreen (setoran awal & tombol Setor/Tarik di kartu) maupun
  /// alurnya sendiri. Mengembalikan pesan error yang persis sama dengan
  /// teks aslinya (bukan throw) supaya pemanggil bisa menampilkannya lewat
  /// AppNotification tanpa mengubah string, dan null kalau berhasil.
  Future<String?> processSavingTransaction({
    required bool isDeposit,
    required String savingName,
    required double amount,
    required int walletId,
    String? location,
    String? notes,
  }) async {
    // Satu transaksi database (RPC saving_transaction, migration 202609260006):
    // cek saldo dompet/tabungan, baris tabungan, transaksi bertanda, saldo dompet.
    try {
      await _supabase.rpc('saving_transaction', params: {
        'p_is_deposit': isDeposit,
        'p_saving_name': savingName,
        'p_amount': amount,
        'p_wallet_id': walletId,
        'p_location': location,
        'p_notes': notes,
        'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    } on PostgrestException catch (e) {
      const prefix = 'SAVING_INSUFFICIENT:';
      if (e.code == 'P0001' && e.message.startsWith(prefix)) {
        fetchSavings();
        final left = double.tryParse(e.message.substring(prefix.length)) ?? 0;
        return "Saldo tabungan tidak cukup! Sisa: ${formatRupiah(left)}";
      }
      // Tolakan server lain (saldo dompet kurang, nominal 0, dompet terhapus).
      if (e.code == 'P0001') {
        fetchWallets();
        return e.message;
      }
      return "Gagal menyimpan transaksi!";
    } catch (e) {
      return "Gagal menyimpan transaksi!";
    }

    // Sama seperti sebelum migrasi: refetch tidak ditunggu (fire-and-forget)
    // supaya notifikasi sukses langsung tampil tanpa menunggu refresh.
    fetchWallets();
    fetchSavings();
    return null;
  }

  /// Membuat kelompok tabungan baru tanpa setoran awal (dari
  /// `_showAddTitleSheet` saat nominal dikosongkan).
  Future<void> addEmptyGroup({
    required String name,
    required String location,
    required String notes,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('savings').insert({
      'user_id': userId,
      'name': name,
      'amount': 0,
      'location': location,
      'notes': notes,
    });
    await fetchSavings();
  }

  /// Mengganti nama/lokasi/catatan seluruh baris dalam satu kelompok
  /// tabungan (dari `_showEditSheet` di SavingsScreen).
  Future<void> renameGroup({
    required String oldName,
    required String newName,
    required String location,
    required String notes,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('savings')
        .update({'name': newName, 'location': location, 'notes': notes})
        .eq('user_id', userId)
        .eq('name', oldName);
    await fetchSavings();
  }

  /// Menghapus seluruh baris dalam satu kelompok tabungan (dari
  /// `_confirmDelete` di SavingsScreen). Saldo dompet TIDAK dikembalikan
  /// otomatis — sama seperti perilaku aslinya.
  Future<void> deleteGroup(String groupName) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('savings')
        .delete()
        .eq('user_id', userId)
        .eq('name', groupName);
    await fetchSavings();
  }

  /// Mengubah satu baris riwayat setor/tarik (dari `_showEditSheet` di
  /// SavingDetailScreen), termasuk membalikkan lalu menerapkan ulang mutasi
  /// saldo dompet terkait.
  Future<void> editSavingItem({
    required SavingModel saving,
    required double rawAmount,
    required bool isDeposit,
    required String location,
    required String notes,
  }) async {
    // Atomik di database (RPC edit_saving_item, migration 202609260006).
    try {
      await _supabase.rpc('edit_saving_item', params: {
        'p_saving_id': saving.id,
        'p_amount': rawAmount,
        'p_is_deposit': isDeposit,
        'p_location': location,
        'p_notes': notes,
      });
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw MoneyRejection(e.message);
      rethrow;
    }

    await fetchSavings();
    await fetchWallets();
  }

  /// Menghapus satu baris riwayat setor/tarik dan mengembalikan saldo
  /// dompet terkait (dari `_deleteSaving` di SavingDetailScreen).
  Future<void> deleteSavingItem(SavingModel item) async {
    // Atomik di database (RPC delete_saving_item, migration 202609260006);
    // juga baris "pakai tabungan" yang punya dua transaksi bertanda sama.
    try {
      await _supabase.rpc('delete_saving_item', params: {'p_saving_id': item.id});
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw MoneyRejection(e.message);
      rethrow;
    }

    await fetchSavings();
    await fetchWallets();
  }
}

final savingsProvider =
    NotifierProvider.autoDispose<SavingsNotifier, SavingsState>(
  SavingsNotifier.new,
);
