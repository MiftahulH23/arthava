import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final List<Map<String, dynamic>> wallets;
  final double totalWalletBalance;
  final bool isLoading;

  const HomeState({
    this.userName = "Memuat...",
    this.monthlyIncome = 0,
    this.monthlyExpense = 0,
    this.totalSavings = 0,
    this.totalInvestments = 0,
    this.wallets = const [],
    this.totalWalletBalance = 0,
    this.isLoading = true,
  });

  HomeState copyWith({
    String? userName,
    double? monthlyIncome,
    double? monthlyExpense,
    double? totalSavings,
    double? totalInvestments,
    List<Map<String, dynamic>>? wallets,
    double? totalWalletBalance,
    bool? isLoading,
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
    await Future.wait([getUserProfile(), fetchHomeData()]);
  }

  Future<void> checkRecurringTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      final response = await _supabase
          .from('recurring_transactions')
          .select('*, categories(is_expense)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .lte('next_run_date', todayStr);

      final List<dynamic> dueTransactions = response;

      for (var item in dueTransactions) {
        DateTime nextRun = DateTime.parse(item['next_run_date']);
        String freq = item['frequency'];
        final walletId = item['wallet_id'];
        final isExpense = item['categories']?['is_expense'] ?? true;
        final amount = (item['amount'] as num).toDouble();
        int executionCount = 0;

        while (nextRun.isBefore(today) ||
            nextRun.isAtSameMomentAs(
              DateTime(today.year, today.month, today.day),
            )) {
          await _supabase.from('transactions').insert({
            'user_id': item['user_id'],
            'category_id': item['category_id'],
            'wallet_id': walletId,
            'amount': amount,
            'date': DateFormat('yyyy-MM-dd').format(nextRun),
            'note': '${item['note'] ?? ''} (Otomatis: $freq)'.trim(),
          });
          executionCount++;
          if (freq == 'Harian') {
            nextRun = nextRun.add(const Duration(days: 1));
          } else if (freq == 'Mingguan') {
            nextRun = nextRun.add(const Duration(days: 7));
          } else if (freq == 'Bulanan') {
            nextRun = DateTime(nextRun.year, nextRun.month + 1, nextRun.day);
          } else if (freq == 'Tahunan') {
            nextRun = DateTime(nextRun.year + 1, nextRun.month, nextRun.day);
          }
        }

        if (executionCount > 0 && walletId != null) {
          final walletRes = await _supabase
              .from('wallets')
              .select('balance')
              .eq('id', walletId)
              .single();
          double currentBal = (walletRes['balance'] as num).toDouble();
          double totalAmountToProcess = amount * executionCount;
          double newBalance = isExpense
              ? currentBal - totalAmountToProcess
              : currentBal + totalAmountToProcess;
          await _supabase
              .from('wallets')
              .update({'balance': newBalance})
              .eq('id', walletId);
        }

        await _supabase
            .from('recurring_transactions')
            .update({'next_run_date': DateFormat('yyyy-MM-dd').format(nextRun)})
            .eq('id', item['id']);
      }
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

        final isPureMutation =
            note.contains('[SAVING_ID:') &&
            (catName.contains('tabung') || catName.contains('cair'));

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
        wallets: List<Map<String, dynamic>>.from(walletsResponse),
        totalWalletBalance: tempTotalWallet,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final homeProvider = NotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
