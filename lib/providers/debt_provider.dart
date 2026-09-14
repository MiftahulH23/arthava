import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// State gabungan untuk DebtScreen (daftar utang/piutang) dan
/// DebtDetailScreen (detail + riwayat cicilan satu utang). Keduanya berbagi
/// provider ini karena mencatat pembayaran dari layar detail mengubah
/// `remaining_amount`/`status` milik item yang sama yang ditampilkan
/// DebtScreen — dengan satu provider, perubahan itu langsung terlihat di
/// kedua layar tanpa refetch manual setelah Navigator.pop.
class DebtState {
  final bool isLoading;
  final List<Map<String, dynamic>> myDebts;
  final List<Map<String, dynamic>> theirDebts;
  final List<Map<String, dynamic>> wallets;

  const DebtState({
    this.isLoading = true,
    this.myDebts = const [],
    this.theirDebts = const [],
    this.wallets = const [],
  });

  /// Gabungan `myDebts` + `theirDebts`, dipakai DebtDetailScreen untuk
  /// mencari versi terkini satu utang lewat `firstWhere`.
  List<Map<String, dynamic>> get allDebts => [...myDebts, ...theirDebts];

  DebtState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? myDebts,
    List<Map<String, dynamic>>? theirDebts,
    List<Map<String, dynamic>>? wallets,
  }) {
    return DebtState(
      isLoading: isLoading ?? this.isLoading,
      myDebts: myDebts ?? this.myDebts,
      theirDebts: theirDebts ?? this.theirDebts,
      wallets: wallets ?? this.wallets,
    );
  }
}

class DebtNotifier extends AutoDisposeNotifier<DebtState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  DebtState build() {
    // Sama seperti provider lain: jangan baca/tulis `state` secara sinkron
    // di sini karena state baru diinisialisasi Riverpod SETELAH build()
    // return. Future.microtask menunda fetch pertama sampai build() selesai.
    Future.microtask(fetchData);
    return const DebtState();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Diambil berurutan (bukan Future.wait) — persis urutan fetch di
      // _DebtScreenState._fetchData sebelum migrasi (wallets dulu, baru
      // debts, tanpa dijalankan paralel).
      final resWallets =
          await _supabase.from('wallets').select().eq('user_id', userId);

      final resDebts = await _supabase
          .from('debts')
          .select()
          .eq('user_id', userId)
          .order('status', ascending: true) // 'active' comes before 'paid'
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> myDebts = [];
      List<Map<String, dynamic>> theirDebts = [];

      for (var item in resDebts as List) {
        if (item['type'] == 'payable') {
          myDebts.add(Map<String, dynamic>.from(item));
        } else {
          theirDebts.add(Map<String, dynamic>.from(item));
        }
      }

      state = state.copyWith(
        wallets: List<Map<String, dynamic>>.from(resWallets),
        myDebts: myDebts,
        theirDebts: theirDebts,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error fetching debts: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<int> _getOrCreateCategory(
    String userId,
    String name,
    bool isExpense,
  ) async {
    final catRes = await _supabase
        .from('categories')
        .select()
        .eq('user_id', userId)
        .eq('name', name)
        .maybeSingle();
    if (catRes != null) return catRes['id'] as int;

    final insertedCat = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': name,
          'icon_name': 'bank',
          'is_expense': isExpense,
        })
        .select()
        .single();
    return insertedCat['id'] as int;
  }

  /// Menambahkan catatan utang/piutang baru, dari `_showAddDebtSheet` di
  /// DebtScreen. `affectWallet`/`walletId` opsional untuk langsung mencatat
  /// mutasi saldo dompet + histori transaksi. Melempar [Exception] dengan
  /// pesan yang sama persis dengan sebelum migrasi untuk kasus saldo tidak
  /// mencukupi, supaya layar bisa menampilkannya lewat AppNotification.
  Future<void> addDebt({
    required String name,
    required String debtType, // 'payable' | 'receivable'
    required double amount,
    DateTime? dueDate,
    bool affectWallet = false,
    int? walletId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    if (affectWallet && walletId != null) {
      final w = state.wallets.firstWhere((w) => w['id'] == walletId);
      final currentBalance = (w['balance'] as num).toDouble();
      double newBalance;
      if (debtType == 'payable') {
        newBalance = currentBalance + amount;
      } else {
        if (currentBalance < amount) {
          throw Exception("Saldo dompet tidak mencukupi untuk dipinjamkan!");
        }
        newBalance = currentBalance - amount;
      }

      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', walletId);

      // Create Transaction history for the wallet
      // We should find a category or create a system category for debt
      bool isExp = debtType == 'receivable';
      String catName = isExp ? 'Utang/Piutang' : 'Utang/Piutang';
      final sysCatId = await _getOrCreateCategory(userId, catName, isExp);

      await _supabase.from('transactions').insert({
        'user_id': userId,
        'wallet_id': walletId,
        'category_id': sysCatId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'note': debtType == 'payable'
            ? 'Pinjaman diterima dari $name'
            : 'Memberi pinjaman ke $name',
      });
    }

    await _supabase.from('debts').insert({
      'user_id': userId,
      'name': name,
      'type': debtType,
      'amount': amount,
      'remaining_amount': amount,
      'due_date': dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate) : null,
    });

    await fetchData();
  }

  /// Mencatat cicilan/pembayaran untuk satu utang, dari
  /// `_showAddPaymentSheet` di DebtDetailScreen. Melempar [Exception] untuk
  /// kasus validasi (jumlah melebihi sisa tagihan / saldo dompet kurang)
  /// dengan pesan yang sama persis dengan sebelum migrasi.
  Future<void> addPayment({
    required Map<String, dynamic> debt,
    required double amount,
    required DateTime date,
    bool affectWallet = false,
    int? walletId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final debtId = debt['id'] as int;
    final isPayable = debt['type'] == 'payable';
    final remainingAmount = (debt['remaining_amount'] as num).toDouble();

    if (amount > remainingAmount) {
      throw Exception("Jumlah bayar tidak boleh melebihi sisa utang!");
    }

    if (affectWallet && walletId != null) {
      final w = state.wallets.firstWhere((w) => w['id'] == walletId);
      final currentBalance = (w['balance'] as num).toDouble();
      double newBalance;
      if (isPayable) {
        if (currentBalance < amount) {
          throw Exception("Saldo dompet tidak mencukupi!");
        }
        newBalance = currentBalance - amount;
      } else {
        newBalance = currentBalance + amount;
      }

      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', walletId);

      bool isExp = isPayable;
      String catName = isExp
          ? 'Sistem: Uang Keluar (Utang/Piutang)'
          : 'Sistem: Uang Masuk (Utang/Piutang)';
      final sysCatId = await _getOrCreateCategory(userId, catName, isExp);

      await _supabase.from('transactions').insert({
        'user_id': userId,
        'wallet_id': walletId,
        'category_id': sysCatId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'note': isPayable
            ? 'Bayar utang ke ${debt['name']}'
            : 'Menerima bayaran dari ${debt['name']}',
      });
    }

    // Insert payment record
    await _supabase.from('debt_payments').insert({
      'debt_id': debtId,
      'user_id': userId,
      'wallet_id': walletId,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(date),
    });

    // Update remaining amount and status
    final newRemaining = remainingAmount - amount;
    await _supabase.from('debts').update({
      'remaining_amount': newRemaining,
      'status': newRemaining <= 0 ? 'paid' : 'active',
    }).eq('id', debtId);

    await fetchData();
  }

  Future<void> deleteDebt(int id) async {
    await _supabase.from('debts').delete().eq('id', id);
    await fetchData();
  }
}

final debtProvider = NotifierProvider.autoDispose<DebtNotifier, DebtState>(DebtNotifier.new);
