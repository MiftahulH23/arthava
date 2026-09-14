import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecurringState {
  final bool isLoading;
  final List<RecurringTransactionModel> recurringList;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> wallets;

  const RecurringState({
    this.isLoading = true,
    this.recurringList = const [],
    this.categories = const [],
    this.wallets = const [],
  });

  /// Peta id dompet -> nama, dibangun dari `wallets` (dipakai untuk badge
  /// nama dompet di kartu jadwal).
  Map<int, String> get walletNames => {
        for (final w in wallets) w['id'] as int: w['name'].toString(),
      };

  RecurringState copyWith({
    bool? isLoading,
    List<RecurringTransactionModel>? recurringList,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? wallets,
  }) {
    return RecurringState(
      isLoading: isLoading ?? this.isLoading,
      recurringList: recurringList ?? this.recurringList,
      categories: categories ?? this.categories,
      wallets: wallets ?? this.wallets,
    );
  }
}

class RecurringNotifier extends AutoDisposeNotifier<RecurringState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  RecurringState build() {
    // Jangan baca/tulis `state` secara sinkron di sini — state baru
    // diinisialisasi Riverpod SETELAH build() return. Future.microtask
    // menunda fetch pertama sampai build() selesai.
    Future.microtask(fetchAll);
    return const RecurringState();
  }

  /// Sama seperti `_RecurringScreenState.initState` sebelum migrasi:
  /// `_fetchWallets()`, `_fetchCategories()`, `_fetchData()` dipanggil
  /// tanpa saling menunggu (fire-and-forget, berjalan paralel) —
  /// dipertahankan lewat Future.wait.
  Future<void> fetchAll() async {
    await Future.wait([fetchWallets(), fetchCategories(), fetchData()]);
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
      final res = await _supabase
          .from('categories')
          .select()
          .or('user_id.is.null,user_id.eq.$userId');
      state = state.copyWith(
        categories: List<Map<String, dynamic>>.from(res),
      );
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('recurring_transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      state = state.copyWith(
        recurringList: (res as List)
            .map((e) => RecurringTransactionModel.fromJson(e))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleActive(RecurringTransactionModel item, bool value) async {
    await _supabase
        .from('recurring_transactions')
        .update({'is_active': value})
        .eq('id', item.id);
    await fetchData();
  }

  Future<void> deleteItem(int id) async {
    await _supabase.from('recurring_transactions').delete().eq('id', id);
    await fetchData();
  }

  Future<void> addRecurring(Map<String, dynamic> data) async {
    await _supabase.from('recurring_transactions').insert(data);
    await fetchData();
  }

  Future<void> updateRecurring(int id, Map<String, dynamic> data) async {
    await _supabase.from('recurring_transactions').update(data).eq('id', id);
    await fetchData();
  }
}

final recurringProvider =
    NotifierProvider.autoDispose<RecurringNotifier, RecurringState>(
  RecurringNotifier.new,
);
