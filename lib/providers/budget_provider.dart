import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';

/// State gabungan untuk BudgetScreen (daftar anggaran per bulan) dan
/// BudgetDetailScreen (edit limit satu anggaran). Keduanya berbagi provider
/// ini karena BudgetDetailScreen hanya mengubah `amount` salah satu item di
/// daftar yang sama yang ditampilkan BudgetScreen — dengan satu provider,
/// perubahan itu langsung terlihat di BudgetScreen tanpa perlu refetch
/// manual setelah Navigator.pop dari layar detail.
class BudgetState {
  final bool isLoading;
  final DateTime selectedMonth;
  final List<BudgetModel> budgets;
  final Map<int, double> spendingMap;
  final List<CategoryModel> allCategories;
  final double totalBudget;
  final double totalSpent;

  BudgetState({
    this.isLoading = true,
    DateTime? selectedMonth,
    this.budgets = const [],
    this.spendingMap = const {},
    this.allCategories = const [],
    this.totalBudget = 0,
    this.totalSpent = 0,
  }) : selectedMonth = selectedMonth ?? DateTime.now();

  BudgetState copyWith({
    bool? isLoading,
    DateTime? selectedMonth,
    List<BudgetModel>? budgets,
    Map<int, double>? spendingMap,
    List<CategoryModel>? allCategories,
    double? totalBudget,
    double? totalSpent,
  }) {
    return BudgetState(
      isLoading: isLoading ?? this.isLoading,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      budgets: budgets ?? this.budgets,
      spendingMap: spendingMap ?? this.spendingMap,
      allCategories: allCategories ?? this.allCategories,
      totalBudget: totalBudget ?? this.totalBudget,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }
}

class BudgetNotifier extends AutoDisposeNotifier<BudgetState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  BudgetState build() {
    // Sama seperti provider lain: jangan baca/tulis `state` secara sinkron di
    // sini, karena state baru diinisialisasi Riverpod SETELAH build() return.
    // Future.microtask menunda fetch pertama sampai build() selesai.
    Future.microtask(_init);
    return BudgetState();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    await fetchCategories();
    await fetchBudgets();
    state = state.copyWith(isLoading: false);
  }

  void changeMonth(int offset) {
    state = state.copyWith(
      selectedMonth: DateTime(state.selectedMonth.year, state.selectedMonth.month + offset),
    );
    fetchBudgets();
  }

  void setMonth(DateTime month) {
    state = state.copyWith(selectedMonth: month);
    fetchBudgets();
  }

  Future<void> fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final catRes = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', true)
          .or('user_id.eq.$userId,user_id.is.null');
      state = state.copyWith(
        allCategories: (catRes as List).map((e) => CategoryModel.fromJson(e)).toList(),
      );
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> fetchBudgets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final selectedMonth = state.selectedMonth;
      final startMonth = DateFormat('yyyy-MM-01').format(selectedMonth);
      final nextMonth = DateFormat('yyyy-MM-01').format(DateTime(selectedMonth.year, selectedMonth.month + 1, 1));

      final budgetRes = await _supabase
          .from('budgets')
          .select('id, amount, category_id, month, year')
          .eq('user_id', userId)
          .eq('month', selectedMonth.month)
          .eq('year', selectedMonth.year);

      double tempTotalBudget = 0;
      final List<BudgetModel> budgets = [];

      for (var item in (budgetRes as List)) {
        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();
        tempTotalBudget += amount;
        final category = state.allCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () => CategoryModel(id: catId, name: "Dihapus", isExpense: true, iconName: "warning", userId: userId),
        );
        budgets.add(BudgetModel(id: item['id'], categoryId: catId, amount: amount, month: item['month'], year: item['year'], category: category));
      }

      // [UPDATE LOGIKA] Tambahin 'note' biar kita bisa filter mutasi tabungan
      final trxRes = await _supabase
          .from('transactions')
          .select('amount, category_id, note')
          .eq('user_id', userId)
          .gte('date', startMonth)
          .lt('date', nextMonth);
      Map<int, double> spending = {};
      double tempTotalSpent = 0;

      for (var item in trxRes) {
        final noteStr = item['note']?.toString() ?? '';
        // [FIX] Celah gaib ditutup. Tabungan nggak akan ngurangin budget lu!
        if (noteStr.contains('[SAVING_ID:') || isDebtMutation(noteStr)) continue;

        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();
        if (state.allCategories.any((c) => c.id == catId && c.isExpense)) {
          spending[catId] = (spending[catId] ?? 0) + amount;
          if (budgets.any((b) => b.categoryId == catId)) tempTotalSpent += amount;
        }
      }

      state = state.copyWith(
        budgets: budgets,
        spendingMap: spending,
        totalBudget: tempTotalBudget,
        totalSpent: tempTotalSpent,
      );
    } catch (e) {
      debugPrint("Error Budgets: $e");
    }
  }

  /// Return `false` kalau tidak ada anggaran bulan lalu untuk disalin (bukan
  /// error) supaya screen bisa menampilkan pesan "Tidak ada data..." yang
  /// sama persis dengan sebelum migrasi, alih-alih pesan generik.
  Future<bool> copyFromLastMonth() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final prevDate = DateTime(state.selectedMonth.year, state.selectedMonth.month - 1);
      final prevBudgetsRes = await _supabase
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .eq('month', prevDate.month)
          .eq('year', prevDate.year);
      final prevBudgets = prevBudgetsRes as List;

      if (prevBudgets.isEmpty) {
        return false;
      }

      List<Map<String, dynamic>> newBudgets = [];
      for (var item in prevBudgets) {
        newBudgets.add({
          'user_id': userId, 'category_id': item['category_id'], 'amount': item['amount'],
          'month': state.selectedMonth.month, 'year': state.selectedMonth.year,
        });
      }
      await _supabase.from('budgets').upsert(newBudgets, onConflict: 'user_id, category_id, month, year');
      await fetchBudgets();
      return true;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteBudget(int id) async {
    await _supabase.from('budgets').delete().eq('id', id);
    await fetchBudgets();
  }

  Future<void> addBudget({
    required int categoryId,
    required int month,
    required int year,
    required double amount,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final check = await _supabase
        .from('budgets')
        .select('id')
        .eq('user_id', userId)
        .eq('category_id', categoryId)
        .eq('month', month)
        .eq('year', year)
        .maybeSingle();
    if (check != null) throw "Anggaran kategori ini sudah ada!";

    await _supabase.from('budgets').insert({
      'user_id': userId, 'category_id': categoryId, 'month': month, 'year': year,
      'amount': amount,
    });

    if (month == state.selectedMonth.month && year == state.selectedMonth.year) {
      await fetchBudgets();
    }
  }

  Future<void> updateBudgetAmount(int id, double amount) async {
    await _supabase.from('budgets').update({'amount': amount}).eq('id', id);
    await fetchBudgets();
  }
}

final budgetProvider = NotifierProvider.autoDispose<BudgetNotifier, BudgetState>(BudgetNotifier.new);
