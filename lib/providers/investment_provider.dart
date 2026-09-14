import 'package:catat_uang_app/models/investment_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvestmentState {
  final bool isLoading;
  final List<InvestmentModel> investments;
  final List<Map<String, dynamic>> wallets;
  final double totalCapital;
  final double totalValue;

  const InvestmentState({
    this.isLoading = true,
    this.investments = const [],
    this.wallets = const [],
    this.totalCapital = 0,
    this.totalValue = 0,
  });

  InvestmentState copyWith({
    bool? isLoading,
    List<InvestmentModel>? investments,
    List<Map<String, dynamic>>? wallets,
    double? totalCapital,
    double? totalValue,
  }) {
    return InvestmentState(
      isLoading: isLoading ?? this.isLoading,
      investments: investments ?? this.investments,
      wallets: wallets ?? this.wallets,
      totalCapital: totalCapital ?? this.totalCapital,
      totalValue: totalValue ?? this.totalValue,
    );
  }
}

class InvestmentNotifier extends AutoDisposeNotifier<InvestmentState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  InvestmentState build() {
    // Sama seperti provider lain: jangan baca/tulis `state` secara sinkron
    // di sini karena state baru diinisialisasi Riverpod SETELAH build()
    // return. Future.microtask menunda fetch pertama sampai build() selesai.
    Future.microtask(fetchData);
    return const InvestmentState();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Diambil berurutan (bukan Future.wait) — persis urutan fetch di
      // _InvestmentScreenState._fetchData sebelum migrasi (wallets dulu,
      // baru investments, tanpa dijalankan paralel).
      final resWallets = await _supabase.from('wallets').select().eq('user_id', userId).order('name');
      final resInv = await _supabase.from('investments').select().eq('user_id', userId).order('created_at', ascending: false);

      double cap = 0;
      double val = 0;
      List<InvestmentModel> invs = [];

      for (var item in resInv) {
        final inv = InvestmentModel.fromJson(item);
        invs.add(inv);
        cap += inv.capitalAmount;
        val += inv.currentValue;
      }

      state = state.copyWith(
        wallets: List<Map<String, dynamic>>.from(resWallets),
        investments: invs,
        totalCapital: cap,
        totalValue: val,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error fetching investments: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<int> _getOrCreateCategory(String userId, String name, bool isExpense) async {
    final res = await _supabase
        .from('categories')
        .select('id')
        .eq('user_id', userId)
        .eq('is_expense', isExpense)
        .ilike('name', '%$name%')
        .maybeSingle();
    if (res != null) return res['id'] as int;

    final ins = await _supabase.from('categories').insert({
      'user_id': userId,
      'name': name,
      'is_expense': isExpense,
      'icon_name': 'chart-line-up',
    }).select('id').single();
    return ins['id'] as int;
  }

  /// Membeli aset investasi baru, dari `_showAddInvestmentSheet`. Melempar
  /// [Exception] dengan pesan yang sama persis dengan sebelum migrasi kalau
  /// saldo dompet tidak mencukupi.
  Future<void> buyInvestment({
    required String name,
    required String type,
    required double amount,
    required int walletId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final wallet = state.wallets.firstWhere((w) => w['id'] == walletId);
    if (amount > (wallet['balance'] as num).toDouble()) {
      throw Exception("Saldo dompet tidak mencukupi!");
    }

    final catId = await _getOrCreateCategory(userId, 'Investasi', true);

    // Insert Investment
    await _supabase.from('investments').insert({
      'user_id': userId,
      'name': name,
      'type': type,
      'capital_amount': amount,
      'current_value': amount,
    }).select().single();

    // Insert Transaction
    await _supabase.from('transactions').insert({
      'user_id': userId,
      'wallet_id': walletId,
      'category_id': catId,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'note': 'Beli Aset: $name',
    });

    // Update Wallet
    await _supabase.from('wallets').update({'balance': (wallet['balance'] as num).toDouble() - amount}).eq('id', walletId);

    await fetchData();
  }

  /// Top up (`isBuy: true`) atau jual (`isBuy: false`) sebagian aset, dari
  /// `_showBuySellSheet`. Melempar [Exception] dengan pesan yang sama persis
  /// dengan sebelum migrasi untuk kasus validasi.
  Future<void> buySellInvestment({
    required InvestmentModel inv,
    required bool isBuy,
    required double amount,
    required int walletId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final wallet = state.wallets.firstWhere((w) => w['id'] == walletId);

    if (isBuy && amount > (wallet['balance'] as num).toDouble()) {
      throw Exception("Saldo dompet tidak mencukupi!");
    }
    if (!isBuy && amount > inv.currentValue) {
      throw Exception("Nominal penarikan melebihi nilai aset saat ini!");
    }

    final catId = isBuy
        ? await _getOrCreateCategory(userId, 'Investasi', true)
        : await _getOrCreateCategory(userId, 'Hasil Jual Investasi', false);

    // Update Investment
    final newCapital = isBuy ? inv.capitalAmount + amount : (inv.capitalAmount - amount < 0 ? 0 : inv.capitalAmount - amount);
    final newValue = isBuy ? inv.currentValue + amount : (inv.currentValue - amount < 0 ? 0 : inv.currentValue - amount);

    await _supabase.from('investments').update({
      'capital_amount': newCapital,
      'current_value': newValue,
    }).eq('id', inv.id);

    // Insert Transaction
    await _supabase.from('transactions').insert({
      'user_id': userId,
      'wallet_id': walletId,
      'category_id': catId,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'note': isBuy ? 'Top Up Aset: ${inv.name}' : ' Jual Aset: ${inv.name}',
    });

    // Update Wallet
    final newBalance = isBuy ? (wallet['balance'] as num).toDouble() - amount : (wallet['balance'] as num).toDouble() + amount;
    await _supabase.from('wallets').update({'balance': newBalance}).eq('id', walletId);

    await fetchData();
  }

  Future<void> updateInvestmentValue(int id, double amount) async {
    await _supabase.from('investments').update({'current_value': amount}).eq('id', id);
    await fetchData();
  }

  Future<void> deleteInvestment(int id) async {
    await _supabase.from('investments').delete().eq('id', id);
    await fetchData();
  }
}

final investmentProvider = NotifierProvider.autoDispose<InvestmentNotifier, InvestmentState>(InvestmentNotifier.new);
