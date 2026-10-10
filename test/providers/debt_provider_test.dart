import 'dart:async';

import 'package:arthava/models/debt_model.dart';
import 'package:arthava/models/debt_payment_model.dart';
import 'package:arthava/models/wallet_model.dart';
import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/services/debt_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DebtModel _debt(int id, {DebtType type = DebtType.payable, double remaining = 100, String status = 'active', DateTime? due}) {
  return DebtModel(
    id: id,
    name: 'D$id',
    type: type,
    amount: 100,
    remainingAmount: remaining,
    loanDate: DateTime(2026, 9, 1),
    dueDate: due,
    notes: null,
    status: status,
    walletId: null,
    transactionId: null,
    createdAt: DateTime(2026, 9, id),
  );
}

class FakeDebtApi implements DebtApi {
  List<DebtModel> debts = [];
  List<WalletModel> wallets = [];
  Map<int, List<DebtPaymentModel>> payments = {};
  final calls = <String>[];
  Completer<void>? gate;
  Object? throwOnMutation;

  Future<void> _mutate(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (throwOnMutation != null) throw throwOnMutation!;
  }

  @override
  Future<List<DebtModel>> fetchDebts() async {
    calls.add('fetchDebts');
    return debts;
  }

  @override
  Future<List<WalletModel>> fetchWallets() async {
    calls.add('fetchWallets');
    return wallets;
  }

  @override
  Future<List<DebtPaymentModel>> fetchPayments(int debtId) async {
    calls.add('fetchPayments:$debtId');
    if (gate != null) await gate!.future;
    return payments[debtId] ?? const [];
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
  }) async {
    await _mutate('createDebt:$name:${type.dbValue}:$amount:$walletId');
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
      _mutate('updateDebt:$debtId:$name:$amount');

  @override
  Future<int> addPayment({required int debtId, required double amount, required DateTime date, int? walletId}) async {
    await _mutate('addPayment:$debtId:$amount:$walletId');
    return 5;
  }

  @override
  Future<void> updatePayment({required int paymentId, required double amount, required DateTime date}) =>
      _mutate('updatePayment:$paymentId:$amount');

  @override
  Future<void> deletePayment(int paymentId) => _mutate('deletePayment:$paymentId');

  @override
  Future<void> deleteDebt(int debtId, {bool refundWallet = false}) =>
      _mutate('deleteDebt:$debtId${refundWallet ? ':refund' : ''}');
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeDebtApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeDebtApi()
      ..debts = [
        _debt(1),
        _debt(2, remaining: 0, status: 'paid'),
        _debt(3, type: DebtType.receivable, remaining: 40),
        _debt(4, type: DebtType.receivable, remaining: 0, status: 'paid'),
        _debt(5, due: DateTime(2026, 9, 20)),
      ];
    container = ProviderContainer(overrides: [
      debtApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    container.listen(debtProvider, (_, _) {}, fireImmediately: true);
  });

  test('build() tidak menyentuh state sinkron dan memuat dompet lalu utang berurutan', () async {
    expect(container.read(debtProvider).isLoading, isTrue);
    await _settle();
    final s = container.read(debtProvider);
    expect(s.isLoading, isFalse);
    expect(s.debts, hasLength(5));
    expect(api.calls.take(2).toList(), ['fetchWallets', 'fetchDebts']);
  });

  test('total hanya menjumlahkan sisa utang/piutang yang belum lunas', () async {
    await _settle();
    final s = container.read(debtProvider);
    expect(s.totalPayable, 200);
    expect(s.totalReceivable, 40);
  });

  test('myDebts/theirDebts dipisah per jenis dan diurutkan (terlambat dulu, lunas terakhir)', () async {
    await _settle();
    final s = container.read(debtProvider);
    final today = DateTime(2026, 9, 24);
    expect(s.myDebts(today).map((d) => d.id).toList(), [5, 1, 2]);
    expect(s.theirDebts(today).map((d) => d.id).toList(), [3, 4]);
    expect(s.debtById(3)?.name, 'D3');
    expect(s.debtById(404), isNull);
  });

  test('isSubmitting guard: aksi kedua saat menyimpan ditolak dan hanya satu RPC terkirim', () async {
    await _settle();
    api.gate = Completer<void>();
    final notifier = container.read(debtProvider.notifier);

    final first = notifier.addPayment(debtId: 1, amount: 10, date: DateTime(2026, 9, 24));
    expect(container.read(debtProvider).isSubmitting, isTrue);
    await expectLater(
      notifier.addPayment(debtId: 1, amount: 10, date: DateTime(2026, 9, 24)),
      throwsA(isA<DebtActionException>()),
    );
    api.gate!.complete();
    await first;

    expect(api.calls.where((c) => c.startsWith('addPayment')).length, 1);
    expect(container.read(debtProvider).isSubmitting, isFalse);
  });

  test('mutasi sukses memuat ulang data tanpa spinner layar penuh dan memuat cicilan utang tsb', () async {
    await _settle();
    api.calls.clear();
    await container.read(debtProvider.notifier).addPayment(debtId: 1, amount: 10, date: DateTime(2026, 9, 24), walletId: null);
    expect(api.calls, ['addPayment:1:10.0:null', 'fetchWallets', 'fetchDebts', 'fetchPayments:1']);
    expect(container.read(debtProvider).isLoading, isFalse);
  });

  test('error server diteruskan apa adanya dan isSubmitting kembali false', () async {
    await _settle();
    api.throwOnMutation = const DebtActionException('Jumlah bayar tidak boleh melebihi sisa utang!');
    await expectLater(
      container.read(debtProvider.notifier).addPayment(debtId: 1, amount: 999, date: DateTime(2026, 9, 24)),
      throwsA(isA<DebtActionException>().having((e) => e.message, 'message', 'Jumlah bayar tidak boleh melebihi sisa utang!')),
    );
    expect(container.read(debtProvider).isSubmitting, isFalse);
  });

  test('error tak dikenal dibungkus pesan ramah', () async {
    await _settle();
    api.throwOnMutation = StateError('boom');
    await expectLater(
      container.read(debtProvider.notifier).deleteDebt(1),
      throwsA(isA<DebtActionException>().having((e) => e.message, 'message', 'Gagal menyimpan. Coba lagi.')),
    );
  });

  test('deleteDebt membuang cache cicilan utang tersebut', () async {
    await _settle();
    api.payments[1] = [
      DebtPaymentModel(id: 9, debtId: 1, walletId: null, walletName: null, transactionId: null, amount: 10, date: DateTime(2026, 9, 2), createdAt: null),
    ];
    final notifier = container.read(debtProvider.notifier);
    await notifier.fetchPayments(1);
    expect(container.read(debtProvider).payments[1], hasLength(1));
    await notifier.deleteDebt(1);
    expect(container.read(debtProvider).payments.containsKey(1), isFalse);
  });

  test('menulis state setelah provider dibuang tidak melempar', () async {
    final ownApi = FakeDebtApi();
    final own = ProviderContainer(overrides: [debtApiProvider.overrideWithValue(ownApi)]);
    final sub = own.listen(debtProvider, (_, _) {}, fireImmediately: true);
    await _settle();
    ownApi.gate = Completer<void>();
    final pending = own.read(debtProvider.notifier).fetchPayments(1);
    sub.close();
    own.dispose();
    ownApi.gate!.complete();
    await pending; // tidak boleh melempar StateError
  });
}
