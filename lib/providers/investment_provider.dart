import 'package:arthava/models/investment_model.dart';
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

  /// [showLoading] false: segarkan diam-diam (mis. setelah tolakan server,
  /// supaya daftar di belakang sheet yang masih terbuka tidak berganti spinner).
  Future<void> fetchData({bool showLoading = true}) async {
    if (showLoading) state = state.copyWith(isLoading: true);
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

  /// Menjalankan RPC uang; tolakan server (P0001) dilempar sebagai [Exception]
  /// dengan pesan aslinya, sama seperti validasi lama di app.
  Future<void> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      await _supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') {
        fetchData(showLoading: false);
        throw Exception(e.message);
      }
      rethrow;
    }
  }

  /// Membeli aset investasi baru, dari `_showAddInvestmentSheet`. Atomik di
  /// database (RPC buy_investment, migration 202609260008); melempar
  /// [Exception] "Saldo dompet tidak mencukupi!" bila saldo kurang.
  Future<void> buyInvestment({
    required String name,
    required String type,
    required double amount,
    required int walletId,
  }) async {
    await _rpc('buy_investment', {
      'p_name': name,
      'p_type': type,
      'p_amount': amount,
      'p_wallet_id': walletId,
      'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });
    await fetchData();
  }

  /// Top up (`isBuy: true`) atau jual (`isBuy: false`) sebagian aset, dari
  /// `_showBuySellSheet`. Atomik di database (RPC buy_sell_investment);
  /// pesan tolakan sama dengan validasi lama.
  Future<void> buySellInvestment({
    required InvestmentModel inv,
    required bool isBuy,
    required double amount,
    required int walletId,
  }) async {
    await _rpc('buy_sell_investment', {
      'p_investment_id': inv.id,
      'p_is_buy': isBuy,
      'p_amount': amount,
      'p_wallet_id': walletId,
      'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });
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
