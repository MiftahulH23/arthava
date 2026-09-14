import 'package:catat_uang_app/models/saving_model.dart';
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

  Future<int> _getOrCreateCategory(String name, bool isExpense) async {
    final userId = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('categories')
        .select('id')
        .eq('user_id', userId)
        .eq('is_expense', isExpense)
        .ilike('name', '%$name%')
        .maybeSingle();
    if (res != null) return res['id'] as int;
    final ins = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': name,
          'is_expense': isExpense,
          'icon_name': 'bank',
        })
        .select('id')
        .single();
    return ins['id'] as int;
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
    try {
      final userId = _supabase.auth.currentUser!.id;

      final catId = isDeposit
          ? await _getOrCreateCategory('Tabungan', true)
          : await _getOrCreateCategory('Pencairan Tabungan', false);

      final wallet = state.wallets.firstWhere((w) => w['id'] == walletId);
      final currentBalance = (wallet['balance'] as num).toDouble();

      if (isDeposit && amount > currentBalance) {
        return "Saldo dompet tidak cukup!";
      }

      String? savedLoc = location;
      String? savedNote = notes;
      if (savedLoc == null && savedNote == null) {
        final existing = state.groupedSavings[savingName];
        if (existing != null && existing.isNotEmpty) {
          savedLoc = existing.last.location;
          savedNote = existing.last.notes;
        }
      }

      final finalAmount = isDeposit ? amount : -amount;
      final insertedSaving = await _supabase
          .from('savings')
          .insert({
            'user_id': userId,
            'name': savingName,
            'amount': finalAmount,
            'location': savedLoc,
            'notes': savedNote,
          })
          .select('id')
          .single();

      final noteMarker = "[SAVING_ID:${insertedSaving['id']}]";
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'category_id': catId,
        'wallet_id': walletId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'note':
            (isDeposit
                    ? "Nabung ke $savingName $noteMarker"
                    : "Pencairan $savingName $noteMarker")
                .trim(),
      });

      final newBalance = isDeposit
          ? currentBalance - amount
          : currentBalance + amount;
      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', walletId);

      // Sama seperti sebelum migrasi: refetch tidak ditunggu (fire-and-forget)
      // supaya notifikasi sukses langsung tampil tanpa menunggu refresh.
      fetchWallets();
      fetchSavings();
      return null;
    } catch (e) {
      return "Gagal menyimpan transaksi!";
    }
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
    final finalAmount = isDeposit ? rawAmount : -rawAmount;
    final noteMarker = "[SAVING_ID:${saving.id}]";
    final trxRes = await _supabase
        .from('transactions')
        .select('id, amount, wallet_id')
        .like('note', '%$noteMarker%')
        .maybeSingle();

    if (trxRes != null && trxRes['wallet_id'] != null) {
      final walletId = trxRes['wallet_id'];
      final oldTrxAmount = (trxRes['amount'] as num).toDouble();

      final walletRes = await _supabase
          .from('wallets')
          .select('balance')
          .eq('id', walletId)
          .single();
      double currentBal = (walletRes['balance'] as num).toDouble();

      double revertAmount = saving.amount > 0 ? oldTrxAmount : -oldTrxAmount;
      double balanceAfterRevert = currentBal + revertAmount;

      double applyAmount = isDeposit ? rawAmount : -rawAmount;
      double finalWalletBalance = balanceAfterRevert - applyAmount;

      await _supabase
          .from('wallets')
          .update({'balance': finalWalletBalance})
          .eq('id', walletId);
    }

    await _supabase
        .from('savings')
        .update({'amount': finalAmount, 'location': location, 'notes': notes})
        .eq('id', saving.id);

    await _supabase
        .from('transactions')
        .update({'amount': rawAmount})
        .like('note', '%$noteMarker%');

    await fetchSavings();
    await fetchWallets();
  }

  /// Menghapus satu baris riwayat setor/tarik dan mengembalikan saldo
  /// dompet terkait (dari `_deleteSaving` di SavingDetailScreen).
  Future<void> deleteSavingItem(SavingModel item) async {
    final noteMarker = "[SAVING_ID:${item.id}]";

    final trxRes = await _supabase
        .from('transactions')
        .select('id, amount, wallet_id')
        .like('note', '%$noteMarker%')
        .maybeSingle();

    if (trxRes != null && trxRes['wallet_id'] != null) {
      final walletId = trxRes['wallet_id'];
      final trxAmount = (trxRes['amount'] as num).toDouble();

      final walletRes = await _supabase
          .from('wallets')
          .select('balance')
          .eq('id', walletId)
          .single();
      double currentBal = (walletRes['balance'] as num).toDouble();

      double refundAmount = item.amount > 0 ? trxAmount : -trxAmount;
      await _supabase
          .from('wallets')
          .update({'balance': currentBal + refundAmount})
          .eq('id', walletId);
    }

    await _supabase.from('transactions').delete().like('note', '%$noteMarker%');
    await _supabase.from('savings').delete().eq('id', item.id);

    await fetchSavings();
    await fetchWallets();
  }
}

final savingsProvider =
    NotifierProvider.autoDispose<SavingsNotifier, SavingsState>(
  SavingsNotifier.new,
);
