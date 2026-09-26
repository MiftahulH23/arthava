import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class FakeInputNotifier extends InputTransactionNotifier {
  int saveCalls = 0;

  @override
  InputTransactionState build() {
    // Seperti provider asli: data tiba setelah build, sehingga layar memilih
    // dompet pertama secara otomatis.
    Future.microtask(
      () => state = const InputTransactionState(
        wallets: [
          {'id': 1, 'name': 'BCA', 'balance': 100000, 'min_balance': 50000},
        ],
        categories: [
          {'id': 10, 'name': 'Makan', 'is_expense': true, 'icon_name': 'food'},
        ],
      ),
    );
    return const InputTransactionState();
  }

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
    saveCalls++;
    return const TransactionSaveResult(false, 'uji');
  }
}

void main() {
  Future<FakeInputNotifier> pumpInput(
    WidgetTester tester,
    String amount, {
    bool pickCategory = true,
    TransactionModel? edit,
  }) async {
    final fake = FakeInputNotifier();
    // Lebar 600: layar Input lama (sebelum B4) meluap di font test pada baris tanggal.
    await pumpApp(
      tester,
      InputTransactionScreen(initialIsExpense: true, transactionToEdit: edit),
      overrides: [inputTransactionProvider.overrideWith(() => fake)],
      size: const Size(600, 1400),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, amount);
    await tester.pump();
    if (pickCategory && edit == null) {
      // B4: kategori dipilih lewat baris "Kategori" -> sheet "Pilih Kategori".
      await tester.ensureVisible(find.text('Kategori'));
      await tester.tap(find.text('Kategori'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makan').last);
      await tester.pumpAndSettle();
    }
    return fake;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Simpan Transaksi'));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
  }

  testWidgets('pengeluaran melewati saldo minimal: dialog muncul, Batal tidak menyimpan', (tester) async {
    final fake = await pumpInput(tester, '60000');
    await tapSave(tester);
    expect(find.text('Di bawah saldo minimal'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Batal'));
    await tester.pumpAndSettle();
    expect(fake.saveCalls, 0);
  });

  testWidgets('pengeluaran melewati saldo minimal: Lanjutkan tetap menyimpan', (tester) async {
    final fake = await pumpInput(tester, '60000');
    await tapSave(tester);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Lanjutkan'));
    await tester.pumpAndSettle();
    expect(fake.saveCalls, 1);
    await tester.pump(const Duration(seconds: 4)); // tutup toast
  });

  testWidgets('pengeluaran masih di atas saldo minimal: tanpa dialog', (tester) async {
    final fake = await pumpInput(tester, '40000');
    await tapSave(tester);
    expect(find.text('Di bawah saldo minimal'), findsNothing);
    expect(fake.saveCalls, 1);
    await tester.pump(const Duration(seconds: 4)); // tutup toast
  });

  testWidgets('kategori belum dipilih: tanpa dialog, validasi lama yang bicara duluan', (tester) async {
    final fake = await pumpInput(tester, '60000', pickCategory: false);
    await tapSave(tester);
    expect(find.text('Di bawah saldo minimal'), findsNothing);
    expect(fake.saveCalls, 1);
    await tester.pump(const Duration(seconds: 4)); // tutup toast
  });

  TransactionModel oldExpense(double amount) => TransactionModel(
        id: 5,
        userId: 'u',
        categoryId: 10,
        amount: amount,
        date: DateTime(2026, 9, 20),
        note: 'makan siang',
        walletId: 1,
      );

  testWidgets('edit pengeluaran: saldo lama dikembalikan dulu, lalu dicek (30rb -> 90rb memicu dialog)', (tester) async {
    // Saldo 100rb sudah dipotong 30rb lama -> 130rb sebelum edit; 130rb - 90rb = 40rb < minimal 50rb.
    final fake = await pumpInput(tester, '90000', edit: oldExpense(30000));
    await tapSave(tester);
    expect(find.text('Di bawah saldo minimal'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Batal'));
    await tester.pumpAndSettle();
    expect(fake.saveCalls, 0);
  });

  testWidgets('edit pengeluaran: 30rb -> 70rb masih di atas minimal, tanpa dialog', (tester) async {
    final fake = await pumpInput(tester, '70000', edit: oldExpense(30000));
    await tapSave(tester);
    expect(find.text('Di bawah saldo minimal'), findsNothing);
    expect(fake.saveCalls, 1);
    await tester.pump(const Duration(seconds: 4)); // tutup toast
  });

  testWidgets('dompet pertama otomatis terpilih saat daftar dompet tiba', (tester) async {
    await pumpInput(tester, '1000', pickCategory: false);
    final walletRow = find.ancestor(of: find.text('Dompet'), matching: find.byType(AppListRow));
    expect(find.descendant(of: walletRow, matching: find.text('BCA')), findsOneWidget);
  });
}
