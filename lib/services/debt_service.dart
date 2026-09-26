import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error dari aksi Utang & Piutang yang pesannya siap ditampilkan ke user.
/// Pesan dari fungsi RPC (Task 1 migrasi) sudah berbahasa Indonesia.
class DebtActionException implements Exception {
  final String message;
  const DebtActionException(this.message);

  @override
  String toString() => message;
}

Future<T> runDebtRpc<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on PostgrestException catch (e) {
    throw DebtActionException(e.message);
  }
}

abstract class DebtApi {
  Future<List<DebtModel>> fetchDebts();
  Future<List<WalletModel>> fetchWallets();
  Future<List<DebtPaymentModel>> fetchPayments(int debtId);

  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  });

  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  });

  Future<int> addPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    int? walletId,
  });

  Future<void> updatePayment({
    required int paymentId,
    required double amount,
    required DateTime date,
  });

  Future<void> deletePayment(int paymentId);
  Future<void> deleteDebt(int debtId);
}

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class SupabaseDebtApi implements DebtApi {
  SupabaseDebtApi(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DebtActionException('Sesi login berakhir. Silakan masuk lagi.');
    }
    return user.id;
  }

  @override
  Future<List<DebtModel>> fetchDebts() async {
    final res = await _client.from('debts').select().eq('user_id', _userId);
    return (res as List)
        .map((e) => DebtModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<WalletModel>> fetchWallets() async {
    final res = await _client.from('wallets').select().eq('user_id', _userId);
    return (res as List)
        .map((e) => WalletModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<DebtPaymentModel>> fetchPayments(int debtId) async {
    final res = await _client
        .from('debt_payments')
        .select('*, wallets(name)')
        .eq('debt_id', debtId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => DebtPaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) {
    return runDebtRpc(() async {
      final res = await _client.rpc('create_debt', params: {
        'p_name': name,
        'p_type': type.dbValue,
        'p_amount': amount,
        'p_loan_date': _day(loanDate),
        'p_due_date': dueDate == null ? null : _day(dueDate),
        'p_notes': notes,
        'p_wallet_id': walletId,
      });
      return (res as num).toInt();
    });
  }

  @override
  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) {
    return runDebtRpc(() async {
      await _client.rpc('update_debt', params: {
        'p_debt_id': debtId,
        'p_name': name,
        'p_amount': amount,
        'p_loan_date': _day(loanDate),
        'p_due_date': dueDate == null ? null : _day(dueDate),
        'p_notes': notes,
      });
    });
  }

  @override
  Future<int> addPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    int? walletId,
  }) {
    return runDebtRpc(() async {
      final res = await _client.rpc('add_debt_payment', params: {
        'p_debt_id': debtId,
        'p_amount': amount,
        'p_date': _day(date),
        'p_wallet_id': walletId,
      });
      return (res as num).toInt();
    });
  }

  @override
  Future<void> updatePayment({
    required int paymentId,
    required double amount,
    required DateTime date,
  }) {
    return runDebtRpc(() async {
      await _client.rpc('update_debt_payment', params: {
        'p_payment_id': paymentId,
        'p_amount': amount,
        'p_date': _day(date),
      });
    });
  }

  @override
  Future<void> deletePayment(int paymentId) {
    return runDebtRpc(() async {
      await _client.rpc('delete_debt_payment', params: {'p_payment_id': paymentId});
    });
  }

  @override
  Future<void> deleteDebt(int debtId) {
    return runDebtRpc(() async {
      await _client.rpc('delete_debt', params: {'p_debt_id': debtId});
    });
  }
}

final debtApiProvider = Provider<DebtApi>((ref) => SupabaseDebtApi(Supabase.instance.client));
