import 'dart:async';

import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class FakeInputNotifier extends InputTransactionNotifier {
  int saveCalls = 0;

  /// Bila diisi, saveTransaction menunggu gate ini (meniru jaringan lambat).
  Completer<void>? gate;

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
    if (gate != null) await gate!.future;
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

  testWidgets('tidak ada kategori untuk jenis ini: baris Kategori tanpa chevron (tidak bisa diketuk)', (tester) async {
    // Fake hanya punya kategori pengeluaran; buka sebagai pemasukan.
    await pumpApp(
      tester,
      const InputTransactionScreen(initialIsExpense: false),
      overrides: [inputTransactionProvider.overrideWith(() => FakeInputNotifier())],
      size: const Size(600, 1400),
    );
    await tester.pumpAndSettle();
    final row = find.ancestor(of: find.text('Kategori'), matching: find.byType(AppListRow));
    expect(find.descendant(of: row, matching: find.byIcon(PhosphorIconsRegular.caretRight)), findsNothing);
  });

  testWidgets('Pilih Kategori dengan banyak kategori: ada kolom cari yang menyaring', (tester) async {
    await pumpApp(
      tester,
      const InputTransactionScreen(initialIsExpense: true),
      overrides: [inputTransactionProvider.overrideWith(_ManyCategoriesNotifier.new)],
      size: const Size(600, 1400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    expect(find.text('Cari kategori'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Cari kategori'), 'kategori 1');
    await tester.pump();
    // "Kategori 1" dan "Kategori 10".."Kategori 19" cocok; "Kategori 2" tidak.
    expect(find.text('Kategori 2'), findsNothing);
    await tester.tap(find.text('Kategori 12'));
    await tester.pumpAndSettle();
    final row = find.ancestor(of: find.text('Kategori'), matching: find.byType(AppListRow));
    expect(find.descendant(of: row, matching: find.text('Kategori 12')), findsOneWidget);
  });

  testWidgets('tap Simpan dua kali cepat hanya menyimpan sekali', (tester) async {
    final fake = await pumpInput(tester, '40000');
    fake.gate = Completer<void>();
    await tester.ensureVisible(find.text('Simpan Transaksi'));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pump();
    fake.gate!.complete();
    await tester.pumpAndSettle();
    expect(fake.saveCalls, 1);
    await tester.pump(const Duration(seconds: 4)); // tutup toast
  });
}

class _ManyCategoriesNotifier extends InputTransactionNotifier {
  @override
  InputTransactionState build() {
    Future.microtask(
      () => state = InputTransactionState(
        wallets: const [
          {'id': 1, 'name': 'BCA', 'balance': 100000, 'min_balance': 0},
        ],
        categories: [
          for (var i = 1; i <= 30; i++) {'id': i, 'name': 'Kategori $i', 'is_expense': true},
        ],
      ),
    );
    return const InputTransactionState();
  }
}
