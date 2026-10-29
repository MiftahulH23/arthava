import 'package:arthava/core/money_rejection.dart';
import 'package:arthava/models/category_model.dart';
import 'package:arthava/models/transaction_model.dart';
import 'package:arthava/providers/transaction_history_provider.dart';
import 'package:arthava/screens/transaction_history/transaction_history_screen.dart';
import 'package:arthava/screens/transaction_history/transactions_tab_screen.dart';
import 'package:arthava/widgets/app_swipe_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/pump_app.dart';

final _createdFakes = <FakeTransactionHistoryNotifier>[];

class FakeTransactionHistoryNotifier extends TransactionHistoryNotifier {
  FakeTransactionHistoryNotifier(this.seed) {
    _createdFakes.add(this);
  }

  final TransactionHistoryState seed;
  final deleted = <TransactionModel>[];
  String? rejectWith;

  @override
  TransactionHistoryState build(bool isExpense) => seed;

  @override
  Future<String> deleteTransaction(TransactionModel trx) async {
    if (rejectWith != null) throw MoneyRejection(rejectWith!);
    deleted.add(trx);
    return 'Data dihapus & saldo dompet disesuaikan!';
  }

  @override
  void setFilterType(String type) => state = state.copyWith(filterType: type);
}

TransactionModel _trx(
  int id,
  DateTime date, {
  String category = 'Makan',
  String? note,
  double amount = 45000,
  int? walletId = 1,
}) =>
    TransactionModel(
      id: id,
      userId: 'u',
      categoryId: 1,
      amount: amount,
      date: date,
      note: note,
      walletId: walletId,
      category: CategoryModel(id: 1, name: category, isExpense: true, iconName: 'tag'),
    );

TransactionHistoryState _state(List<TransactionModel> trxs, {bool isLoading = false}) =>
    TransactionHistoryState(
      isLoading: isLoading,
      transactions: trxs,
      totalAmount: trxs.fold(0, (s, t) => s + t.amount),
      selectedDate: DateTime(2026, 9, 24),
      walletNames: const {1: 'BCA'},
      walletColors: const {1: Color(0xFF4A6CF7)},
    );

Future<void> _pump(WidgetTester tester, Widget child, TransactionHistoryState seed) async {
  _createdFakes.clear();
  await pumpApp(
    tester,
    child,
    overrides: [
      transactionHistoryProvider.overrideWith(() => FakeTransactionHistoryNotifier(seed)),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  final sep24 = DateTime(2026, 9, 24);
  final sep23 = DateTime(2026, 9, 23);

  testWidgets('judul, chip periode, pill, total, dan grup tanggal', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([
        _trx(2, sep24, note: 'Nasi Padang'),
        _trx(1, sep23, category: 'Transportasi', note: 'Grab'),
      ]),
    );

    expect(find.text('Transaksi'), findsOneWidget);
    for (final label in ['Harian', 'Bulanan', 'Tahunan', 'Periode']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Total Real'), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMM', 'id_ID').format(sep24).toUpperCase()), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMM', 'id_ID').format(sep23).toUpperCase()), findsOneWidget);
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('BCA'), findsNWidgets(2));
  });

  testWidgets('empty state tetap menampilkan pill Filter', (tester) async {
    await _pump(tester, const TransactionHistoryScreen(isExpense: true), _state([]));
    expect(find.text('Tidak ada transaksi'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('loading menampilkan spinner', (tester) async {
    await pumpApp(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      overrides: [
        transactionHistoryProvider.overrideWith(
          () => FakeTransactionHistoryNotifier(_state([], isLoading: true)),
        ),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('baris mutasi tidak punya swipe dan menampilkan chip', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([_trx(5, sep24, category: 'Tabungan', note: 'Setor [SAVING_ID:9]')]),
    );
    expect(find.text('Mutasi Internal'), findsOneWidget);
    expect(find.text('Setor'), findsOneWidget);
    expect(find.textContaining('SAVING_ID'), findsNothing);
    expect(find.byType(AppSwipeActions), findsNothing);
  });

  testWidgets('swipe hapus memanggil notifier setelah konfirmasi', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([_trx(7, sep24, note: 'Nasi Padang')]),
    );
    await tester.drag(find.text('Nasi Padang'), const Offset(-240, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(_createdFakes.single.deleted.map((t) => t.id), [7]);
    await tester.pump(const Duration(seconds: 4)); // tunggu timer toast AppNotification (3 detik)
  });

  testWidgets('teks panjang tidak overflow', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([
        _trx(8, sep24,
            category: 'Kategori Dengan Nama Yang Sangat Sangat Panjang Sekali',
            note: 'Catatan yang juga sangat panjang sampai tidak muat di satu baris layar HP',
            amount: 123456789),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TransactionsTabScreen: segmented memanggil onActiveTabChanged', (tester) async {
    final values = <bool>[];
    await _pump(
      tester,
      TransactionsTabScreen(refreshCounter: 0, onActiveTabChanged: values.add),
      _state([]),
    );
    expect(values, [false]); // dari postFrameCallback initState
    expect(find.text('Transaksi'), findsOneWidget);
    await tester.tap(find.text('Pengeluaran'));
    await tester.pumpAndSettle();
    expect(values.last, isTrue);
    expect(find.text('Transaksi'), findsOneWidget);
  });

  testWidgets('chip mutasi tampil utuh; catatan yang dipotong lebih dulu', (tester) async {
    _createdFakes.clear();
    final seed = _state([
      _trx(9, DateTime(2026, 9, 23), category: 'Tabungan', note: 'Setor Liburan Bali ke celengan keluarga [SAVING_ID:3]'),
    ]);
    await pumpApp(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      overrides: [transactionHistoryProvider.overrideWith(() => FakeTransactionHistoryNotifier(seed))],
      size: const Size(560, 1200),
    );
    await tester.pumpAndSettle();
    final chip = tester.renderObject<RenderParagraph>(find.text('Mutasi Internal'));
    expect(chip.didExceedMaxLines, isFalse);
  });

  testWidgets('hapus ditolak server menampilkan pesan tolakan, bukan pesan umum', (tester) async {
    await _pump(
      tester,
      const TransactionHistoryScreen(isExpense: true),
      _state([_trx(7, sep24, note: 'Nasi Padang')]),
    );
    _createdFakes.last.rejectWith = 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000';
    await tester.drag(find.text('Nasi Padang'), const Offset(-240, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000'), findsOneWidget);
    expect(find.text('Gagal menghapus transaksi.'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('TransactionsTabScreen: geser layar ke kiri pindah ke Pengeluaran', (tester) async {
    final values = <bool>[];
    await _pump(
      tester,
      TransactionsTabScreen(refreshCounter: 0, onActiveTabChanged: values.add),
      _state([]),
    );
    await tester.timedDrag(find.text('Transaksi'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(values.last, isTrue);
  });

  testWidgets('TransactionsTabScreen: saat digeser hanya isi yang ikut, judul & filter tetap', (tester) async {
    await _pump(
      tester,
      TransactionsTabScreen(refreshCounter: 0, onActiveTabChanged: (_) {}),
      _state([]),
    );
    final title = tester.getTopLeft(find.text('Transaksi'));
    final filter = tester.getTopLeft(find.text('Filter'));
    final total = tester.getTopLeft(find.text('Total Real'));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Total Real')));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Transaksi')), title);
    expect(tester.getTopLeft(find.text('Filter')), filter);
    expect(tester.getTopLeft(find.text('Total Real')).dx, lessThan(total.dx - 60));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
