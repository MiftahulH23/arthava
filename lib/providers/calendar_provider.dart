import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';

DateTime normalizeCalendarDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

class CalendarState {
  final Map<DateTime, List<TransactionModel>> groupedTransactions;
  final Map<String, String> savingNames;
  final Map<int, String> walletNames;
  final Map<int, Color> walletColors;
  final bool isLoading;

  const CalendarState({
    this.groupedTransactions = const {},
    this.savingNames = const {},
    this.walletNames = const {},
    this.walletColors = const {},
    this.isLoading = true,
  });

  CalendarState copyWith({
    Map<DateTime, List<TransactionModel>>? groupedTransactions,
    Map<String, String>? savingNames,
    Map<int, String>? walletNames,
    Map<int, Color>? walletColors,
    bool? isLoading,
  }) {
    return CalendarState(
      groupedTransactions: groupedTransactions ?? this.groupedTransactions,
      savingNames: savingNames ?? this.savingNames,
      walletNames: walletNames ?? this.walletNames,
      walletColors: walletColors ?? this.walletColors,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<TransactionModel> eventsForDay(DateTime day) {
    return groupedTransactions[normalizeCalendarDate(day)] ?? [];
  }
}

class CalendarNotifier extends AutoDisposeNotifier<CalendarState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  CalendarState build() {
    // Sama seperti WalletNotifier: jangan baca/tulis `state` secara sinkron
    // di sini karena state baru diinisialisasi Riverpod SETELAH build()
    // return. Future.microtask menunda fetch pertama sampai build() selesai.
    Future.microtask(_loadAll);
    return const CalendarState();
  }

  Future<void> _loadAll() async {
    // Dijalankan paralel (bukan berurutan) supaya waktu tunggu total sama
    // dengan fetch terlama, bukan jumlah keduanya — sesuai perilaku asli
    // (initState memanggil keduanya tanpa await berurutan). Aman karena
    // fetchWallets dan fetchTransactions tidak saling baca data satu sama
    // lain dan masing-masing hanya menulis field state miliknya sendiri.
    await Future.wait([fetchWallets(), fetchTransactions()]);
  }

  // [NEW] Ambil nama & warna dompet buat badge
  Future<void> fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId);

      final names = <int, String>{};
      final colors = <int, Color>{};
      for (var w in res as List) {
        names[w['id']] = w['name'].toString();
        final colorHex = w['color']?.toString() ?? '#1E3A8A';
        colors[w['id']] = Color(
          int.parse(colorHex.replaceFirst('#', '0xFF')),
        );
      }
      state = state.copyWith(walletNames: names, walletColors: colors);
    } catch (e) {
      debugPrint("Error wallets: $e");
    }
  }

  Future<void> fetchTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Ambil nama tabungan buat kamus
      final savingsRes = await _supabase
          .from('savings')
          .select('id, name')
          .eq('user_id', userId);
      Map<String, String> tempSavings = {};
      for (var row in savingsRes as List) {
        tempSavings[row['id'].toString()] = row['name'].toString();
      }

      // 2. Ambil data transaksinya
      final res = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('date', ascending: false);

      Map<DateTime, List<TransactionModel>> tempGroups = {};

      for (var item in res) {
        final trx = TransactionModel.fromJson(item);
        final normalizedDate = normalizeCalendarDate(trx.date);

        final note = trx.note ?? '';
        final isPureMutation = isInternalMutation(note, trx.category?.name);

        if (!isPureMutation) {
          if (tempGroups[normalizedDate] == null) {
            tempGroups[normalizedDate] = [];
          }
          tempGroups[normalizedDate]!.add(trx);
        }
      }

      state = state.copyWith(
        savingNames: tempSavings,
        groupedTransactions: tempGroups,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final calendarProvider =
    NotifierProvider.autoDispose<CalendarNotifier, CalendarState>(
      CalendarNotifier.new,
    );
