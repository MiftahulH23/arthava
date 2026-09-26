import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSettingsState {
  /// true = saldo minimal ikut dihitung di total saldo (perilaku lama).
  final bool includeMinBalance;
  final bool isLoading;

  const UserSettingsState({this.includeMinBalance = true, this.isLoading = true});

  UserSettingsState copyWith({bool? includeMinBalance, bool? isLoading}) {
    return UserSettingsState(
      includeMinBalance: includeMinBalance ?? this.includeMinBalance,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserSettingsNotifier extends AutoDisposeNotifier<UserSettingsState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  UserSettingsState build() {
    // Jangan sentuh `state` secara sinkron di build() (lihat WalletNotifier).
    Future.microtask(fetch);
    return const UserSettingsState();
  }

  Future<void> fetch() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final data = await _supabase
          .from('profiles')
          .select('include_min_balance')
          .eq('id', user.id)
          .maybeSingle();
      state = state.copyWith(
        includeMinBalance: (data?['include_min_balance'] as bool?) ?? true,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error fetch user settings: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  /// Optimistis: state langsung berubah, dikembalikan bila penyimpanan gagal (lalu rethrow).
  Future<void> setIncludeMinBalance(bool value) async {
    final previous = state.includeMinBalance;
    state = state.copyWith(includeMinBalance: value);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('profiles').update({'include_min_balance': value}).eq('id', userId);
    } catch (e) {
      state = state.copyWith(includeMinBalance: previous);
      rethrow;
    }
  }
}

final userSettingsProvider =
    NotifierProvider.autoDispose<UserSettingsNotifier, UserSettingsState>(UserSettingsNotifier.new);
