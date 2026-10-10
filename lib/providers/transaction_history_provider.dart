import 'package:arthava/core/money_rejection.dart';
import 'package:arthava/models/transaction_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arthava/core/transaction_tags.dart';

class TransactionHistoryState {
  final bool isLoading;
  final List<TransactionModel> transactions;
  final double totalAmount;
  final List<Map<String, dynamic>> categories;
  final List<int> selectedCategoryIds;
  final List<int> selectedWalletIds;
  final String filterType;
  final DateTime selectedDate;
  final DateTimeRange? selectedDateRange;
  final Map<int, String> walletNames;
  final Map<int, Color> walletColors;

  const TransactionHistoryState({
    this.isLoading = true,
    this.transactions = const [],
    this.totalAmount = 0,
    this.categories = const [],
    this.selectedCategoryIds = const [],
    this.selectedWalletIds = const [],
    this.filterType = 'Bulanan',
    required this.selectedDate,
    this.selectedDateRange,
    this.walletNames = const {},
    this.walletColors = const {},
  });

  TransactionHistoryState copyWith({
    bool? isLoading,
    List<TransactionModel>? transactions,
    double? totalAmount,
    List<Map<String, dynamic>>? categories,
    List<int>? selectedCategoryIds,
    List<int>? selectedWalletIds,
    String? filterType,
    DateTime? selectedDate,
    DateTimeRange? selectedDateRange,
    Map<int, String>? walletNames,
    Map<int, Color>? walletColors,
  }) {
    return TransactionHistoryState(
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      totalAmount: totalAmount ?? this.totalAmount,
      categories: categories ?? this.categories,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      selectedWalletIds: selectedWalletIds ?? this.selectedWalletIds,
      filterType: filterType ?? this.filterType,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      walletNames: walletNames ?? this.walletNames,
      walletColors: walletColors ?? this.walletColors,
    );
  }
}

/// Provider `.family` per `isExpense` — satu-satunya provider di proyek ini
/// yang butuh parameter dari widget saat dibuat. TransactionHistoryScreen
/// dipakai dua kali di HomeScreen (tab Pemasukan & tab Pengeluaran) dengan
/// `isExpense` konstruktor berbeda, tapi hanya satu yang benar-benar berada
/// di widget tree dalam satu waktu (bukan IndexedStack) sehingga instance
/// family lama otomatis dibuang (autoDispose) saat berpindah tab — perilaku
/// setara dengan StatefulWidget lama yang selalu dibuat ulang lewat
/// `ValueKey('pemasukan_...')` / `ValueKey('pengeluaran_...')`.
class TransactionHistoryNotifier
    extends AutoDisposeFamilyNotifier<TransactionHistoryState, bool> {
  SupabaseClient get _supabase => Supabase.instance.client;
  bool get isExpense => arg;

  @override
  TransactionHistoryState build(bool isExpense) {
    // Jangan baca/tulis `state` secara sinkron di sini — lihat catatan yang
    // sama di WalletNotifier.build(). Future.microtask menunda fetch
    // pertama sampai build() selesai.
    Future.microtask(fetchAll);
    return TransactionHistoryState(
      selectedDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      selectedDate: DateTime.now(),
    );
  }

  /// Sama seperti `initState` layar aslinya: `_fetchCategories()`,
  /// `_fetchWallets()`, dan `_fetchTransactions()` dipanggil tanpa saling
  /// menunggu (fire-and-forget, paralel) — dipertahankan lewat Future.wait.
  Future<void> fetchAll() async {
    await Future.wait([fetchCategories(), fetchWallets(), fetchTransactions()]);
  }

  Future<void> fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId);

      final names = Map<int, String>.from(state.walletNames);
      final colors = Map<int, Color>.from(state.walletColors);
      for (var w in res as List) {
        names[w['id']] = w['name'].toString();
        final colorHex = w['color']?.toString() ?? '#1E3A8A';
        colors[w['id']] = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      }
      state = state.copyWith(walletNames: names, walletColors: colors);
    } catch (e) {
      debugPrint("Error wallets: $e");
    }
  }

  Future<void> fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', isExpense)
          .or('user_id.is.null,user_id.eq.$userId');

      state = state.copyWith(
        categories: List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint("Error categories: $e");
    }
  }

  Future<void> fetchTransactions() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      DateTime startDate;
      DateTime endDate;
      final selectedDate = state.selectedDate;

      if (state.filterType == 'Harian') {
        startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
      } else if (state.filterType == 'Tahunan') {
        startDate = DateTime(selectedDate.year, 1, 1);
        endDate = DateTime(selectedDate.year, 12, 31, 23, 59, 59);
      } else if (state.filterType == 'Periode' && state.selectedDateRange != null) {
        startDate = state.selectedDateRange!.start;
        endDate = DateTime(
          state.selectedDateRange!.end.year,
          state.selectedDateRange!.end.month,
          state.selectedDateRange!.end.day,
          23,
          59,
          59,
        );
      } else {
        startDate = DateTime(selectedDate.year, selectedDate.month, 1);
        endDate = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);
      }

      var query = _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .eq('categories.is_expense', isExpense)
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(endDate));

      if (state.selectedCategoryIds.isNotEmpty) {
        query = query.inFilter('category_id', state.selectedCategoryIds);
      }
      if (state.selectedWalletIds.isNotEmpty) {
        query = query.inFilter('wallet_id', state.selectedWalletIds);
      }

      final response = await query
          .order('date', ascending: false)
          .order('id', ascending: false);

      double total = 0;
      List<TransactionModel> loaded = [];

      for (var item in response as List) {
        if (item['categories'] == null) continue;

        final trx = TransactionModel.fromJson(item);
        final note = trx.note?.toString() ?? '';
        final catName = trx.category?.name.toLowerCase() ?? '';
        final isPureMutation = isInternalMutation(note, catName);

        loaded.add(trx);

        if (!isPureMutation) {
          total += trx.amount;
        }
      }

      state = state.copyWith(
        transactions: loaded,
        totalAmount: total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ==============================================================
  // [BUG FIX] FUNGSI DELETE SEKARANG NGEMBALIIN SALDO DOMPET
  // ==============================================================
  /// Mengembalikan pesan sukses/gagal persis seperti aslinya supaya
  /// pemanggil (widget) bisa menampilkannya lewat AppNotification tanpa
  /// mengubah string.
  Future<String> deleteTransaction(TransactionModel trx) async {
    if (isDebtMutation(trx.note)) {
      throw Exception('Transaksi ini dibuat dari fitur Utang & Piutang. Hapus lewat menu Utang & Piutang.');
    }
    try {
      // Satu transaksi database (Plan B4b): saldo dompet dikembalikan dan baris
      // dihapus sekaligus; hapus ganda tidak mengembalikan saldo dua kali.
      await _supabase.rpc('delete_transaction', params: {'p_id': trx.id});

      fetchWallets();
      fetchTransactions();

      return "Data dihapus & saldo dompet disesuaikan!";
    } on PostgrestException catch (e) {
      debugPrint("Delete error: $e");
      // P0001 = tolakan aturan (mis. menghapus pemasukan yang sudah terpakai).
      if (e.code == 'P0001') throw MoneyRejection(e.message);
      throw Exception("Gagal menghapus transaksi.");
    } catch (e) {
      debugPrint("Delete error: $e");
      throw Exception("Gagal menghapus transaksi.");
    }
  }

  void setFilterType(String type) {
    if (state.filterType != type) {
      state = state.copyWith(filterType: type);
      fetchTransactions();
    }
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    fetchTransactions();
  }

  void setSelectedDateRange(DateTimeRange range) {
    state = state.copyWith(selectedDateRange: range);
    fetchTransactions();
  }

  void toggleCategoryFilter(int id, bool selected) {
    final ids = List<int>.from(state.selectedCategoryIds);
    if (selected) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    state = state.copyWith(selectedCategoryIds: ids);
  }

  void toggleWalletFilter(int id, bool selected) {
    final ids = List<int>.from(state.selectedWalletIds);
    if (selected) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    state = state.copyWith(selectedWalletIds: ids);
  }

  void resetFilters() {
    state = state.copyWith(selectedCategoryIds: [], selectedWalletIds: []);
  }

  void applyFilters() {
    fetchTransactions();
  }
}

final transactionHistoryProvider = NotifierProvider.autoDispose
    .family<TransactionHistoryNotifier, TransactionHistoryState, bool>(
  TransactionHistoryNotifier.new,
);
