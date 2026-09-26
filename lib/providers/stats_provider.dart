import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';

class StatsState {
  final bool isLoading;
  final bool isExpense;
  final String filterType;
  final DateTime selectedDate;
  final DateTimeRange? selectedDateRange;
  final double totalAmount;
  final double dailyAverage;
  final Map<String, dynamic>? highestTransaction;
  final List<Map<String, dynamic>> categoryData;
  final List<Map<String, dynamic>> categories;
  final List<int> selectedCategoryIds;
  final List<int> selectedWalletIds;
  final Map<int, String> walletNames;
  final Map<int, Color> walletColors;

  const StatsState({
    this.isLoading = true,
    this.isExpense = true,
    this.filterType = 'Bulanan',
    required this.selectedDate,
    this.selectedDateRange,
    this.totalAmount = 0,
    this.dailyAverage = 0,
    this.highestTransaction,
    this.categoryData = const [],
    this.categories = const [],
    this.selectedCategoryIds = const [],
    this.selectedWalletIds = const [],
    this.walletNames = const {},
    this.walletColors = const {},
  });

  StatsState copyWith({
    bool? isLoading,
    bool? isExpense,
    String? filterType,
    DateTime? selectedDate,
    DateTimeRange? selectedDateRange,
    double? totalAmount,
    double? dailyAverage,
    Map<String, dynamic>? highestTransaction,
    bool clearHighestTransaction = false,
    List<Map<String, dynamic>>? categoryData,
    List<Map<String, dynamic>>? categories,
    List<int>? selectedCategoryIds,
    List<int>? selectedWalletIds,
    Map<int, String>? walletNames,
    Map<int, Color>? walletColors,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      isExpense: isExpense ?? this.isExpense,
      filterType: filterType ?? this.filterType,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      totalAmount: totalAmount ?? this.totalAmount,
      dailyAverage: dailyAverage ?? this.dailyAverage,
      highestTransaction: clearHighestTransaction
          ? null
          : (highestTransaction ?? this.highestTransaction),
      categoryData: categoryData ?? this.categoryData,
      categories: categories ?? this.categories,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      selectedWalletIds: selectedWalletIds ?? this.selectedWalletIds,
      walletNames: walletNames ?? this.walletNames,
      walletColors: walletColors ?? this.walletColors,
    );
  }
}

class StatsNotifier extends AutoDisposeNotifier<StatsState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  StatsState build() {
    // Jangan baca/tulis `state` secara sinkron di sini — lihat catatan yang
    // sama di WalletNotifier.build(). Future.microtask menunda fetch
    // pertama sampai build() selesai.
    Future.microtask(fetchAll);
    return StatsState(
      selectedDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      selectedDate: DateTime.now(),
    );
  }

  /// Sama seperti `initState` layar aslinya: `_fetchWallets()`,
  /// `_fetchCategories()`, dan `_fetchStats()` dipanggil tanpa saling
  /// menunggu (fire-and-forget, paralel) — dipertahankan lewat Future.wait.
  Future<void> fetchAll() async {
    await Future.wait([fetchWallets(), fetchCategories(), fetchStats()]);
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
          .eq('is_expense', state.isExpense)
          .or('user_id.is.null,user_id.eq.$userId');

      state = state.copyWith(categories: List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint("Error categories: $e");
    }
  }

  Future<void> fetchStats() async {
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
          .eq('categories.is_expense', state.isExpense)
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(endDate));

      if (state.selectedCategoryIds.isNotEmpty) {
        query = query.inFilter('category_id', state.selectedCategoryIds);
      }
      if (state.selectedWalletIds.isNotEmpty) {
        query = query.inFilter('wallet_id', state.selectedWalletIds);
      }

      final response = await query;

      double total = 0;
      Map<String, Map<String, dynamic>> grouped = {};
      double maxAmount = 0;
      Map<String, dynamic>? maxTransaction;

      for (var item in response as List) {
        if (item['categories'] == null) continue;

        final note = item['note']?.toString() ?? '';
        final catName = item['categories']['name']?.toString().toLowerCase() ?? '';
        final isPureMutation = isInternalMutation(note, catName);

        if (isPureMutation) continue;

        final amount = (item['amount'] as num).toDouble();
        final catId = item['category_id'].toString();
        final cName = item['categories']['name'];

        total += amount;

        if (amount > maxAmount) {
          maxAmount = amount;
          maxTransaction = {
            'amount': amount,
            'name': cName,
            'note': note.isNotEmpty ? note : cName,
            'date': item['date'],
          };
        }

        if (grouped.containsKey(catId)) {
          grouped[catId]!['amount'] += amount;
          grouped[catId]!['count'] += 1;
          grouped[catId]!['transactions'].add(item);
        } else {
          grouped[catId] = {
            'name': cName,
            'amount': amount,
            'count': 1,
            'transactions': [item],
          };
        }
      }

      final sortedList = grouped.values.toList()
        ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      DateTime calculationEndDate = endDate;
      final now = DateTime.now();
      if (calculationEndDate.isAfter(now)) {
        calculationEndDate = now;
      }

      int days = calculationEndDate.difference(startDate).inDays + 1;
      if (days < 1) days = 1;
      final avg = total / days;

      state = state.copyWith(
        totalAmount: total,
        dailyAverage: avg,
        highestTransaction: maxTransaction,
        clearHighestTransaction: maxTransaction == null,
        categoryData: sortedList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setIsExpense(bool isExpense) {
    state = state.copyWith(isExpense: isExpense, selectedCategoryIds: []);
    fetchCategories();
    fetchStats();
  }

  void setFilterType(String type) {
    if (state.filterType != type) {
      state = state.copyWith(filterType: type);
      fetchStats();
    }
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    fetchStats();
  }

  void setSelectedDateRange(DateTimeRange range) {
    state = state.copyWith(selectedDateRange: range);
    fetchStats();
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
    fetchStats();
  }
}

final statsProvider = NotifierProvider.autoDispose<StatsNotifier, StatsState>(
  StatsNotifier.new,
);
