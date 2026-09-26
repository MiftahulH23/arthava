import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('transaksi bertag DEBT_ID tampil read-only dengan banner Utang dan tag tersembunyi', (tester) async {
    final trx = TransactionModel(
      id: 1,
      userId: 'u1',
      categoryId: 10,
      amount: 500000,
      date: DateTime(2026, 9, 15),
      note: 'Bayar utang ke Budi [DEBT_ID:12]',
      category: CategoryModel.fromJson({
        'id': 10,
        'user_id': 'u1',
        'name': 'Sistem: Uang Keluar (Utang/Piutang)',
        'is_expense': true,
        'icon_name': 'bank',
      }),
      walletId: 3,
    );

    // Lebar 600: layar Input lama (sebelum B4) meluap di font test pada baris tanggal.
    await pumpApp(tester, InputTransactionScreen(initialIsExpense: true, transactionToEdit: trx), size: const Size(600, 1000));
    await tester.pump();

    expect(find.textContaining('fitur Utang & Piutang'), findsOneWidget);
    expect(find.textContaining('[DEBT_ID:'), findsNothing);
    expect(find.text('Bayar utang ke Budi'), findsOneWidget);
  });
}
