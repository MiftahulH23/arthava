import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputTransactionState {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> wallets;
  final Map<String, double> savingsBalances;
  final List<String> savingNamesList;
  final int? tabunganCategoryId;
  final bool isSaving;

  const InputTransactionState({
    this.categories = const [],
    this.wallets = const [],
    this.savingsBalances = const {},
    this.savingNamesList = const [],
    this.tabunganCategoryId,
    this.isSaving = false,
  });

  InputTransactionState copyWith({
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? wallets,
    Map<String, double>? savingsBalances,
    List<String>? savingNamesList,
    int? tabunganCategoryId,
    bool clearTabunganCategoryId = false,
    bool? isSaving,
  }) {
    return InputTransactionState(
      categories: categories ?? this.categories,
      wallets: wallets ?? this.wallets,
      savingsBalances: savingsBalances ?? this.savingsBalances,
      savingNamesList: savingNamesList ?? this.savingNamesList,
      tabunganCategoryId: clearTabunganCategoryId
          ? null
          : (tabunganCategoryId ?? this.tabunganCategoryId),
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Hasil `saveTransaction`: `success` menentukan apakah widget menampilkan
/// AppNotification.success lalu `Navigator.pop(context, true)`, atau
/// AppNotification.error tanpa pop — persis alur `_saveTransaction` asli.
class TransactionSaveResult {
  final bool success;
  final String message;
  const TransactionSaveResult(this.success, this.message);
}

class InputTransactionNotifier extends AutoDisposeNotifier<InputTransactionState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  InputTransactionState build() {
    // Jangan baca/tulis `state` secara sinkron di sini — lihat catatan yang
    // sama di WalletNotifier.build(). Future.microtask menunda fetch
    // pertama sampai build() selesai.
    Future.microtask(fetchAll);
    return const InputTransactionState();
  }

  /// Sama seperti `initState` layar aslinya: `_fetchCategories()`,
  /// `_fetchSavingsBalances()`, dan `_fetchWallets()` dipanggil tanpa saling
  /// menunggu (fire-and-forget, paralel) — dipertahankan lewat Future.wait.
  Future<void> fetchAll() async {
    await Future.wait([fetchCategories(), fetchSavingsBalances(), fetchWallets()]);
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

  Future<void> fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .or('user_id.eq.$userId,user_id.is.null');

      final categories = List<Map<String, dynamic>>.from(response);
      int? tabunganCategoryId;
      try {
        final tabungCat = categories.firstWhere(
          (c) => c['name'].toString().toLowerCase().contains('tabung'),
        );
        tabunganCategoryId = tabungCat['id'];
      } catch (e) {
        tabunganCategoryId = null;
      }

      state = state.copyWith(
        categories: categories,
        tabunganCategoryId: tabunganCategoryId,
        clearTabunganCategoryId: tabunganCategoryId == null,
      );
    } catch (e) {}
  }

  Future<void> fetchSavingsBalances() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('savings')
          .select('name, amount')
          .eq('user_id', userId);
      Map<String, double> balances = {};
      for (var item in res) {
        String name = item['name'].toString().trim();
        balances[name] = (balances[name] ?? 0) + (item['amount'] as num).toDouble();
      }
      final names = <String>[];
      for (var key in balances.keys) {
        if (balances[key]! > 0) names.add(key);
      }
      state = state.copyWith(savingsBalances: balances, savingNamesList: names);
    } catch (e) {}
  }

  Future<TransactionSaveResult> saveTransaction({
    required String amountText,
    required String noteText,
    required int? selectedCategoryId,
    required int? selectedWalletId,
    required bool isExpense,
    required bool isFromSaving,
    required String? selectedSavingName,
    required DateTime selectedDate,
    required String? hiddenSavingMarker,
    required bool isReadOnly,
    required TransactionModel? transactionToEdit,
    required bool initialIsExpense,
  }) async {
    if (amountText.isEmpty || selectedCategoryId == null) {
      return const TransactionSaveResult(false, "Jumlah dan Kategori wajib diisi!");
    }
    if (state.wallets.isEmpty && !isFromSaving) {
      return const TransactionSaveResult(
        false,
        "Kamu belum membuat dompet. Silakan buat di Beranda > Dompet.",
      );
    }
    if (!isFromSaving && selectedWalletId == null) {
      return const TransactionSaveResult(false, "Pilih dompet sumber dana!");
    }
    if (isExpense &&
        isFromSaving &&
        selectedSavingName == null &&
        transactionToEdit == null) {
      return const TransactionSaveResult(false, "Pilih tabungan yang ingin digunakan!");
    }
    if (selectedCategoryId == state.tabunganCategoryId && !isReadOnly) {
      return const TransactionSaveResult(
        false,
        "Untuk nabung, silakan gunakan menu Tabungan di Beranda.",
      );
    }

    final cleanAmount = amountText.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.parse(cleanAmount);

    if (isExpense && isFromSaving && transactionToEdit == null) {
      double currentBal = state.savingsBalances[selectedSavingName] ?? 0;
      if (amount > currentBal) {
        final limitRp = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(currentBal);
        return TransactionSaveResult(false, "Saldo tabungan tidak cukup! Sisa: $limitRp");
      }
      state = state.copyWith(isSaving: true);
      try {
        // Satu transaksi database (Plan B4b): kurangi tabungan + catat pencairan &
        // pengeluaran bertanda [SAVING_ID:x]; sisa tabungan dicek ulang di server.
        await _supabase.rpc('spend_from_saving', params: {
          'p_saving_name': selectedSavingName,
          'p_category_id': selectedCategoryId,
          'p_amount': amount,
          'p_date': DateFormat('yyyy-MM-dd').format(selectedDate),
          'p_note': noteText,
        });

        return const TransactionSaveResult(true, "Berhasil! Uang dipotong dari tabungan.");
      } on PostgrestException catch (e) {
        const prefix = 'SAVING_INSUFFICIENT:';
        if (e.message.startsWith(prefix)) {
          final left = double.tryParse(e.message.substring(prefix.length)) ?? 0;
          final limitRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(left);
          return TransactionSaveResult(false, "Saldo tabungan tidak cukup! Sisa: $limitRp");
        }
        return const TransactionSaveResult(false, "Gagal memproses data.");
      } catch (e) {
        return const TransactionSaveResult(false, "Gagal memproses data.");
      } finally {
        state = state.copyWith(isSaving: false);
      }
    }

    state = state.copyWith(isSaving: true);
    try {
      String finalNote = noteText.trim();
      if (hiddenSavingMarker != null) {
        finalNote = finalNote.isEmpty
            ? hiddenSavingMarker
            : '$finalNote $hiddenSavingMarker';
      }

      // Satu transaksi database (Plan B4b): catat/ubah transaksi dan saldo dompet
      // sekaligus. Saat edit, efek lama dibalik berdasarkan kategori lama di server.
      await _supabase.rpc('save_transaction', params: {
        'p_id': transactionToEdit?.id,
        'p_category_id': selectedCategoryId,
        'p_wallet_id': selectedWalletId,
        'p_amount': amount,
        'p_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'p_note': finalNote,
      });

      return transactionToEdit == null
          ? const TransactionSaveResult(true, "Transaksi berhasil & Saldo dompet terupdate!")
          : const TransactionSaveResult(true, "Transaksi berhasil diperbarui!");
    } on PostgrestException catch (e) {
      // P0001 = tolakan aturan (mis. saldo dompet kurang): tampilkan apa adanya.
      return TransactionSaveResult(false, e.code == 'P0001' ? e.message : "Gagal: ${e.message}");
    } catch (e) {
      return TransactionSaveResult(false, "Gagal: ${e.toString()}");
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final inputTransactionProvider =
    NotifierProvider.autoDispose<InputTransactionNotifier, InputTransactionState>(
  InputTransactionNotifier.new,
);
