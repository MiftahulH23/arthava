import 'dart:async';

import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final DateTime kToday = DateTime(2026, 9, 24);

DebtModel sampleDebt({
  int id = 1,
  String name = 'Budi Santoso',
  DebtType type = DebtType.payable,
  double amount = 2000000,
  double remaining = 1200000,
  DateTime? loanDate,
  DateTime? dueDate,
  String? notes,
  String status = 'active',
  int? walletId,
  int? transactionId,
}) {
  return DebtModel(
    id: id,
    name: name,
    type: type,
    amount: amount,
    remainingAmount: remaining,
    loanDate: loanDate ?? DateTime(2026, 8, 1),
    dueDate: dueDate,
    notes: notes,
    status: status,
    walletId: walletId,
    transactionId: transactionId,
    createdAt: DateTime(2026, 8, id),
  );
}

DebtPaymentModel samplePayment({
  int id = 10,
  int debtId = 1,
  double amount = 500000,
  DateTime? date,
  int? walletId = 3,
  String? walletName = 'BCA',
  int? transactionId = 90,
}) {
  return DebtPaymentModel(
    id: id,
    debtId: debtId,
    walletId: walletId,
    walletName: walletName,
    transactionId: transactionId,
    amount: amount,
    date: date ?? DateTime(2026, 9, 15),
    createdAt: null,
  );
}

WalletModel sampleWallet({int id = 3, String name = 'BCA', double balance = 9300000, String color = '#4A6CF7'}) {
  return WalletModel(id: id, userId: 'u1', name: name, balance: balance, color: color);
}

class FakeDebtNotifier extends DebtNotifier {
  FakeDebtNotifier(this.initial);

  final DebtState initial;
  final List<String> calls = [];
  Completer<void>? gate;
  Object? error;

  @override
  DebtState build() => initial;

  Future<void> _record(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
  }

  @override
  Future<void> fetchData({bool silent = false}) async => calls.add('fetchData');

  @override
  Future<void> fetchPayments(int debtId) async => calls.add('fetchPayments:$debtId');

  @override
  Future<int> createDebt({
    required String name,
    required DebtType type,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
    int? walletId,
  }) async {
    await _record('createDebt:$name:${type.dbValue}:${amount.toInt()}:${loanDate.day}:${dueDate?.day}:$notes:$walletId');
    return 99;
  }

  @override
  Future<void> updateDebt({
    required int debtId,
    required String name,
    required double amount,
    required DateTime loanDate,
    DateTime? dueDate,
    String? notes,
  }) =>
      _record('updateDebt:$debtId:$name:${amount.toInt()}:$notes');

  @override
  Future<int> addPayment({required int debtId, required double amount, required DateTime date, int? walletId}) async {
    await _record('addPayment:$debtId:${amount.toInt()}:$walletId');
    return 5;
  }

  @override
  Future<void> updatePayment({required int debtId, required int paymentId, required double amount, required DateTime date}) =>
      _record('updatePayment:$debtId:$paymentId:${amount.toInt()}');

  @override
  Future<void> deletePayment({required int debtId, required int paymentId}) =>
      _record('deletePayment:$debtId:$paymentId');

  @override
  Future<void> deleteDebt(int debtId) => _record('deleteDebt:$debtId');
}

List<Override> debtOverrides(FakeDebtNotifier fake) => [
      debtProvider.overrideWith(() => fake),
      debtClockProvider.overrideWithValue(() => kToday),
    ];

/// Toast `AppNotification` masih memakai Poppins (dibereskan Plan B7). Unduhan
/// font yang gagal di test di-"telan" di zona terpisah, pola sama dengan
/// test/flutter_test_config.dart.
Future<void> prewarmToastFont() async {
  await runZonedGuarded(() async {
    GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500).fontFamily;
  }, (_, _) {});
}

/// Toast memakai Timer 3 detik + animasi 600 ms; habiskan supaya test tidak
/// gagal karena "A Timer is still pending".
Future<void> flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}
