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

  Future<int> _getOrCreateWithdrawCategory() async {
    final userId = _supabase.auth.currentUser!.id;
    final checkRes = await _supabase
        .from('categories')
        .select('id')
        .eq('is_expense', false)
        .ilike('name', '%Cair%')
        .eq('user_id', userId)
        .maybeSingle();
    if (checkRes != null) return checkRes['id'] as int;
    final insertRes = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': 'Pencairan Tabungan',
          'is_expense': false,
          'icon_name': 'bank',
        })
        .select('id')
        .single();
    return insertRes['id'] as int;
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
    final userId = _supabase.auth.currentUser!.id;

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
        final insertedSaving = await _supabase
            .from('savings')
            .insert({
              'user_id': userId,
              'name': selectedSavingName,
              'amount': -amount,
              'notes': noteText.trim().isNotEmpty
                  ? noteText.trim()
                  : 'Dipakai untuk pengeluaran',
            })
            .select('id')
            .single();

        final savingId = insertedSaving['id'];
        final noteMarker = "[SAVING_ID:$savingId]";
        final incomeCatId = await _getOrCreateWithdrawCategory();

        await _supabase.from('transactions').insert({
          'user_id': userId,
          'category_id': incomeCatId,
          'amount': amount,
          'date': DateFormat('yyyy-MM-dd').format(selectedDate),
          'note': 'Pencairan otomatis $noteMarker',
        });

        String finalNote = noteText.trim();
        finalNote = finalNote.isEmpty ? noteMarker : '$finalNote $noteMarker';

        await _supabase.from('transactions').insert({
          'user_id': userId,
          'category_id': selectedCategoryId,
          'amount': amount,
          'date': DateFormat('yyyy-MM-dd').format(selectedDate),
          'note': finalNote,
        });

        return const TransactionSaveResult(true, "Berhasil! Uang dipotong dari tabungan.");
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

      final data = {
        'user_id': userId,
        'category_id': selectedCategoryId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'note': finalNote,
        'wallet_id': selectedWalletId,
      };

      double balanceChange = isExpense ? -(amount.toDouble()) : amount.toDouble();

      if (transactionToEdit == null) {
        await _supabase.from('transactions').insert(data);
        final currentWalletRes = await _supabase
            .from('wallets')
            .select('balance')
            .eq('id', selectedWalletId!)
            .single();
        final currentBalance = (currentWalletRes['balance'] as num).toDouble();
        await _supabase
            .from('wallets')
            .update({'balance': currentBalance + balanceChange})
            .eq('id', selectedWalletId);

        return const TransactionSaveResult(
          true,
          "Transaksi berhasil & Saldo dompet terupdate!",
        );
      } else {
        final oldTrx = transactionToEdit;
        final oldWalletRes = await _supabase
            .from('wallets')
            .select('balance')
            .eq('id', oldTrx.walletId!)
            .single();
        final oldBalance = (oldWalletRes['balance'] as num).toDouble();

        double reverseChange = initialIsExpense
            ? oldTrx.amount.toDouble()
            : -(oldTrx.amount.toDouble());
        await _supabase
            .from('wallets')
            .update({'balance': oldBalance + reverseChange})
            .eq('id', oldTrx.walletId!);

        await _supabase.from('transactions').update(data).eq('id', oldTrx.id);

        final newWalletRes = await _supabase
            .from('wallets')
            .select('balance')
            .eq('id', selectedWalletId!)
            .single();
        final newBalance = (newWalletRes['balance'] as num).toDouble();
        await _supabase
            .from('wallets')
            .update({'balance': newBalance + balanceChange})
            .eq('id', selectedWalletId);

        return const TransactionSaveResult(true, "Transaksi berhasil diperbarui!");
      }
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
