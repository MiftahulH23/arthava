import 'package:arthava/models/debt_model.dart';
import 'package:arthava/models/debt_payment_model.dart';
import 'package:arthava/models/wallet_model.dart';
import 'package:arthava/services/debt_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jam yang dipakai layar Utang untuk menghitung "Terlambat N hari".
/// Di-override di test supaya hasilnya pasti.
final debtClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// State bersama DebtScreen dan DebtDetailScreen. Satu provider untuk kedua
/// layar supaya perubahan dari detail (bayar/edit/hapus) langsung terlihat di
/// daftar tanpa refetch manual setelah Navigator.pop.
class DebtState {
  final bool isLoading;
  final bool isSubmitting;
  final List<DebtModel> debts;
  final List<WalletModel> wallets;
  final Map<int, List<DebtPaymentModel>> payments;
  final Set<int> loadingPayments;

  const DebtState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.debts = const [],
    this.wallets = const [],
    this.payments = const {},
    this.loadingPayments = const {},
  });

  List<DebtModel> myDebts(DateTime today) => sortDebts(debts.where((d) => d.isPayable), today);

  List<DebtModel> theirDebts(DateTime today) => sortDebts(debts.where((d) => !d.isPayable), today);

  double get totalPayable => debts
      .where((d) => d.isPayable && !d.isPaidOff)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  double get totalReceivable => debts
      .where((d) => !d.isPayable && !d.isPaidOff)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  DebtModel? debtById(int id) {
    for (final d in debts) {
      if (d.id == id) return d;
    }
    return null;
  }

  DebtState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<DebtModel>? debts,
    List<WalletModel>? wallets,
    Map<int, List<DebtPaymentModel>>? payments,
    Set<int>? loadingPayments,
  }) {
    return DebtState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      debts: debts ?? this.debts,
      wallets: wallets ?? this.wallets,
      payments: payments ?? this.payments,
      loadingPayments: loadingPayments ?? this.loadingPayments,
    );
  }
}

class DebtNotifier extends AutoDisposeNotifier<DebtState> {
  DebtApi get _api => ref.read(debtApiProvider);

  bool _alive = true;

  @override
  DebtState build() {
    _alive = true;
    ref.onDispose(() => _alive = false);
    // Jangan sentuh `state` di sini: Riverpod baru menginisialisasi state
    // SETELAH build() return. Future.microtask menunda fetch pertama.
    Future.microtask(fetchData);
    return const DebtState();
  }

  void _update(DebtState Function(DebtState s) change) {
    if (!_alive) return;
    state = change(state);
  }

  /// `silent: true` dipakai setelah mutasi supaya layar tidak berganti
  /// jadi spinner penuh.
  Future<void> fetchData({bool silent = false}) async {
    if (!silent) _update((s) => s.copyWith(isLoading: true));
    try {
      // Berurutan (dompet dulu, lalu utang), sama seperti sebelum redesign.
      final wallets = await _api.fetchWallets();
      final debts = await _api.fetchDebts();
      _update((s) => s.copyWith(wallets: wallets, debts: debts, isLoading: false));
    } catch (e) {
      debugPrint('Error fetching debts: $e');
      _update((s) => s.copyWith(isLoading: false));
    }
  }

  Future<void> fetchPayments(int debtId) async {
    _update((s) => s.copyWith(loadingPayments: {...s.loadingPayments, debtId}));
    try {
      final list = await _api.fetchPayments(debtId);
      _update((s) => s.copyWith(
            payments: {...s.payments, debtId: list},
            loadingPayments: {...s.loadingPayments}..remove(debtId),
          ));
    } catch (e) {
      debugPrint('Error fetching debt payments: $e');
      _update((s) => s.copyWith(loadingPayments: {...s.loadingPayments}..remove(debtId)));
    }
  }

  Future<T> _submit<T>(Future<T> Function() action, {int? refreshPaymentsFor}) async {
    if (state.isSubmitting) {
      throw const DebtActionException('Sedang menyimpan, tunggu sebentar.');
    }
    _update((s) => s.copyWith(isSubmitting: true));
    try {
      final result = await action();
      await fetchData(silent: true);
      if (refreshPaymentsFor != null) await fetchPayments(refreshPaymentsFor);
      return result;
    } on DebtActionException {
      rethrow;
    } catch (e) {
      debugPrint('Debt action error: $e');
      throw const DebtActionException('Gagal menyimpan. Coba lagi.');
    } finally {
      _update((s) => s.copyWith(isSubmitting: false));
    }
  }

  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) {
    return _submit(() => _api.createDebt(
          name: name,
          type: type,
          amount: amount,
          loanDate: loanDate,
          dueDate: dueDate,
          notes: notes,
          walletId: walletId,
        ));
  }

  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) {
    return _submit(() => _api.updateDebt(
          debtId: debtId,
          name: name,
          amount: amount,
          loanDate: loanDate,
          dueDate: dueDate,
          notes: notes,
        ));
  }

  Future<int> addPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    int? walletId,
  }) {
    return _submit(
      () => _api.addPayment(debtId: debtId, amount: amount, date: date, walletId: walletId),
      refreshPaymentsFor: debtId,
    );
  }

  Future<void> updatePayment({
    required int debtId,
    required int paymentId,
    required double amount,
    required DateTime date,
  }) {
    return _submit(
      () => _api.updatePayment(paymentId: paymentId, amount: amount, date: date),
      refreshPaymentsFor: debtId,
    );
  }

  Future<void> deletePayment({required int debtId, required int paymentId}) {
    return _submit(() => _api.deletePayment(paymentId), refreshPaymentsFor: debtId);
  }

  Future<void> deleteDebt(int debtId, {bool refundWallet = false}) async {
    await _submit(() => _api.deleteDebt(debtId, refundWallet: refundWallet));
    _update((s) => s.copyWith(payments: {...s.payments}..remove(debtId)));
  }
}

final debtProvider = NotifierProvider.autoDispose<DebtNotifier, DebtState>(DebtNotifier.new);
