import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _fakes = <FakeInputTransactionNotifier>[];

class FakeInputTransactionNotifier extends InputTransactionNotifier {
  FakeInputTransactionNotifier() {
    _fakes.add(this);
  }

  final saveCalls = <Map<String, Object?>>[];

  @override
  InputTransactionState build() => const InputTransactionState(
        wallets: [
          {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#4A6CF7'},
        ],
        categories: [
          {'id': 1, 'name': 'Makan', 'is_expense': true},
          {'id': 2, 'name': 'Gaji', 'is_expense': false},
        ],
        savingNamesList: ['Dana Darurat'],
        savingsBalances: {'Dana Darurat': 18000000},
      );

  @override
  Future<TransactionSaveResult> saveTransaction({
    required String amountText,
    required String noteText,
    required int? selectedCategoryId,
    required int? selectedWalletId,
    required bool isExpense,
    required bool isFromSaving,
    required String? selectedSavingName,
    required DateTime selectedDate,
    required String? hiddenSavingMarker,
    required bool isReadOnly,
    required TransactionModel? transactionToEdit,
    required bool initialIsExpense,
  }) async {
    saveCalls.add({'amountText': amountText, 'isExpense': isExpense, 'categoryId': selectedCategoryId});
    return const TransactionSaveResult(false, "Jumlah dan Kategori wajib diisi!");
  }
}

Future<void> _pump(WidgetTester tester, InputTransactionScreen screen) async {
  _fakes.clear();
  await pumpApp(tester, screen,
      overrides: [inputTransactionProvider.overrideWith(FakeInputTransactionNotifier.new)]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tambah pengeluaran: header, nominal, scan, sumber dana, simpan', (tester) async {
    await _pump(tester, const InputTransactionScreen(initialIsExpense: true));
    expect(find.text('Tambah Transaksi'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Nominal'), findsOneWidget);
    expect(find.text('Scan Struk AI'), findsOneWidget);
    expect(find.text('SUMBER DANA'), findsOneWidget);
    expect(find.text('Tabungan'), findsWidgets);
    expect(find.text('Pilih Dompet...'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('CATATAN (OPSIONAL)'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsOneWidget);
  });

  testWidgets('pemasukan: tanpa Scan Struk, header Simpan Ke', (tester) async {
    await _pump(tester, const InputTransactionScreen());
    expect(find.text('Scan Struk AI'), findsNothing);
    expect(find.text('SIMPAN KE'), findsOneWidget);
  });

  testWidgets('pilih dompet dan kategori lewat sheet', (tester) async {
    await _pump(tester, const InputTransactionScreen(initialIsExpense: true));
    await tester.tap(find.text('Pilih Dompet...'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Dompet'), findsOneWidget);
    await tester.tap(find.text('BCA').last);
    await tester.pumpAndSettle();
    expect(find.text('BCA'), findsOneWidget);

    await tester.tap(find.text('Pilih Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan').last);
    await tester.pumpAndSettle();
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Gaji'), findsNothing); // kategori difilter per tipe
  });

  testWidgets('simpan memanggil notifier dengan argumen dari form', (tester) async {
    await _pump(tester, const InputTransactionScreen(initialIsExpense: true));
    await tester.enterText(find.byType(EditableText).first, '45000');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(_fakes.single.saveCalls.single['isExpense'], isTrue);
    expect(_fakes.single.saveCalls.single['amountText'], '45.000');
    await tester.pump(const Duration(seconds: 4)); // timer toast AppNotification
  });

  testWidgets('read-only mengunci segmented & tombol Kembali', (tester) async {
    await _pump(
      tester,
      InputTransactionScreen(
        initialIsExpense: true,
        transactionToEdit: TransactionModel(
          id: 1,
          userId: 'u',
          categoryId: 1,
          amount: 45000,
          date: DateTime(2026, 9, 24),
          note: 'Pakai tabungan [SAVING_ID:3]',
          walletId: 1,
        ),
      ),
    );
    expect(find.text('Detail Transaksi'), findsOneWidget);
    expect(find.textContaining('catatan otomatis dari fitur Tabungan'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Scan Struk AI'), findsNothing);
    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Struk AI'), findsNothing); // tetap pengeluaran, toggle terkunci
  });
}
