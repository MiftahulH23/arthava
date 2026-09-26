import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/home_summary.dart';

/// State untuk tab "Home" HomeScreen: profil singkat, ringkasan saldo
/// bulan berjalan, total tabungan/investasi, dan daftar dompet. Tidak
/// termasuk `_selectedIndex`/`_refreshCounter` HomeScreen — itu murni UI
/// state milik widget (bottom nav & pemicu invalidasi provider lain),
/// bukan data yang diambil dari Supabase.
class HomeState {
  final String userName;
  final double monthlyIncome;
  final double monthlyExpense;
  final double totalSavings;
  final double totalInvestments;
  final List<WalletModel> wallets;
  final double totalWalletBalance;
  final bool isLoading;
  /// profiles.include_min_balance — true = saldo minimal ikut dihitung (perilaku lama).
  final bool includeMinBalance;
  final HomeSummary summary;

  const HomeState({
    this.userName = "Memuat...",
    this.monthlyIncome = 0,
    this.monthlyExpense = 0,
    this.totalSavings = 0,
    this.totalInvestments = 0,
    this.wallets = const [],
    this.totalWalletBalance = 0,
    this.isLoading = true,
    this.includeMinBalance = true,
    this.summary = const HomeSummary(),
  });

  HomeState copyWith({
    String? userName,
    double? monthlyIncome,
    double? monthlyExpense,
    double? totalSavings,
    double? totalInvestments,
    List<WalletModel>? wallets,
    double? totalWalletBalance,
    bool? isLoading,
    bool? includeMinBalance,
    HomeSummary? summary,
  }) {
    return HomeState(
      userName: userName ?? this.userName,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      totalSavings: totalSavings ?? this.totalSavings,
      totalInvestments: totalInvestments ?? this.totalInvestments,
      wallets: wallets ?? this.wallets,
      totalWalletBalance: totalWalletBalance ?? this.totalWalletBalance,
      isLoading: isLoading ?? this.isLoading,
      includeMinBalance: includeMinBalance ?? this.includeMinBalance,
      summary: summary ?? this.summary,
    );
  }
}

class HomeNotifier extends AutoDisposeNotifier<HomeState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  HomeState build() {
    // Jangan baca/tulis `state` secara sinkron di sini — lihat catatan yang
    // sama di WalletNotifier.build(). Future.microtask menunda fetch
    // pertama sampai build() selesai.
    Future.microtask(refreshData);
    return const HomeState();
  }

  /// Sama seperti `_refreshData` layar aslinya: `_checkRecurringTransactions`
  /// ditunggu dulu (bisa mengubah saldo dompet & membuat transaksi baru),
  /// baru `_getUserProfile` dan `_fetchHomeData` dijalankan paralel lewat
  /// Future.wait.
  Future<void> refreshData() async {
    await checkRecurringTransactions();
    await Future.wait([getUserProfile(), fetchHomeData(), fetchSummary()]);
  }

  Future<void> checkRecurringTransactions() async {
    try {
      // Server menjalankan setiap jadwal jatuh tempo tepat sekali, termasuk saldo
      // dompet dan next_run_date, dalam satu transaksi (Plan B4b).
      await _supabase.rpc('run_due_recurring');
    } catch (e) {
      debugPrint("Error Recurring Executor: $e");
    }
  }

  Future<void> getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      state = state.copyWith(
        userName: data != null
            ? data['name']
            : (user.userMetadata?['name'] ?? "User"),
        // Kolom migration 202609260003; default true bila belum ada.
        includeMinBalance: (data?['include_min_balance'] as bool?) ?? true,
      );
    } catch (e) {
      debugPrint("Error user: $e");
    }
  }

  Future<void> fetchHomeData() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();

      final allTrxResponse = await _supabase
          .from('transactions')
          .select('amount, date, note, categories(name, is_expense)')
          .eq('user_id', userId);
      final savingsResponse = await _supabase
          .from('savings')
          .select('amount')
          .eq('user_id', userId);
      final invResponse = await _supabase
          .from('investments')
          .select('current_value')
          .eq('user_id', userId);
      final walletsResponse = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      double tempTotalSavings = 0;
      for (var row in savingsResponse as List) {
        tempTotalSavings += (row['amount'] as num).toDouble();
      }

      double tempTotalInv = 0;
      for (var row in invResponse as List) {
        tempTotalInv += (row['current_value'] as num).toDouble();
      }

      double tempTotalWallet = 0;
      for (var w in walletsResponse as List) {
        tempTotalWallet += (w['balance'] as num).toDouble();
      }

      double displayIncome = 0;
      double displayExpense = 0;

      for (var item in allTrxResponse) {
        final amount = (item['amount'] as num).toDouble();
        final date = DateTime.parse(item['date']);
        final isExpense = item['categories']['is_expense'] as bool;
        final note = item['note']?.toString() ?? '';
        final catName = item['categories']['name'].toString().toLowerCase();

        final isPureMutation = isInternalMutation(note, catName);

        if (date.year == now.year && date.month == now.month) {
          if (isExpense) {
            if (!isPureMutation) displayExpense += amount;
          } else {
            if (!isPureMutation) displayIncome += amount;
          }
        }
      }

      state = state.copyWith(
        monthlyIncome: displayIncome,
        monthlyExpense: displayExpense,
        totalSavings: tempTotalSavings,
        totalInvestments: tempTotalInv,
        wallets: (walletsResponse as List).map((e) => WalletModel.fromJson(e)).toList(),
        totalWalletBalance: tempTotalWallet,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Data empat kartu ringkasan Beranda. Lima query independen dijalankan paralel.
  Future<void> fetchSummary() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final startMonth = DateFormat('yyyy-MM-01').format(now);
      final nextMonth = DateFormat('yyyy-MM-01').format(DateTime(now.year, now.month + 1, 1));

      final results = await Future.wait<dynamic>([
        _supabase
            .from('budgets')
            .select('category_id, amount')
            .eq('user_id', userId)
            .eq('month', now.month)
            .eq('year', now.year),
        _supabase
            .from('transactions')
            .select('amount, category_id, note, categories(is_expense)')
            .eq('user_id', userId)
            .gte('date', startMonth)
            .lt('date', nextMonth),
        _supabase.from('targets').select().eq('user_id', userId),
        _supabase
            .from('recurring_transactions')
            .select('*, categories(name, is_expense)')
            .eq('user_id', userId)
            .eq('is_active', true),
        _supabase
            .from('debts')
            .select()
            .eq('user_id', userId)
            .eq('type', 'payable')
            .eq('status', 'active'),
      ]);

      state = state.copyWith(
        summary: HomeSummary(
          budget: summarizeBudgets(
            budgets: List<Map<String, dynamic>>.from(results[0] as List),
            monthTransactions: List<Map<String, dynamic>>.from(results[1] as List),
          ),
          target: pickTarget(
            (results[2] as List).map((e) => TargetModel.fromJson(e)).toList(),
          ),
          nextBill: pickNextBill(
            (results[3] as List).map((e) => RecurringTransactionModel.fromJson(e)).toList(),
          ),
          debt: pickDebt(
            (results[4] as List).map((e) => DebtModel.fromJson(e)).toList(),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error home summary: $e");
    }
  }
}

final homeProvider = NotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
