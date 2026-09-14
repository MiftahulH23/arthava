import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileState {
  /// Nama terbaru dari tabel `profiles`, dipakai untuk menyinkronkan
  /// textfield kalau beda dengan metadata Auth yang dipakai sebagai nilai
  /// awal. Null berarti belum selesai di-fetch (atau tidak berubah).
  final String? latestName;
  final bool isSaving;

  const EditProfileState({this.latestName, this.isSaving = false});

  EditProfileState copyWith({String? latestName, bool? isSaving}) {
    return EditProfileState(
      latestName: latestName ?? this.latestName,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class EditProfileNotifier extends AutoDisposeNotifier<EditProfileState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  EditProfileState build() {
    // Sama seperti WalletNotifier: tunda fetch ke microtask supaya tidak
    // membaca `state` sebelum Riverpod selesai menginisialisasinya di
    // build() ini.
    Future.microtask(fetchLatestName);
    return const EditProfileState();
  }

  /// Cek lagi ke database untuk memastikan data paling update (metadata
  /// Auth dipakai sebagai nilai awal yang sudah sinkron secara synchronous).
  Future<void> fetchLatestName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && data['name'] != null) {
        state = state.copyWith(latestName: data['name'] as String);
      }
    } catch (e) {
      debugPrint("Gagal load profile db: $e");
    }
  }

  Future<void> updateProfile(String name) async {
    state = state.copyWith(isSaving: true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Update ke Tabel Profiles
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Update ke User Metadata (Penting biar cache lokal juga update)
      await _supabase.auth.updateUser(UserAttributes(data: {'name': name}));
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final editProfileProvider =
    NotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>(
  EditProfileNotifier.new,
);
