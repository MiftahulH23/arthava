import 'package:arthava/core/colors.dart';
import 'package:arthava/screens/transaction_history/transaction_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('toggle kategori/dompet, reset, lalu terapkan', (tester) async {
    final selectedCats = <int>[];
    final selectedWallets = <int>[];
    var resetCount = 0;
    var applyCount = 0;

    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showTransactionFilterSheet(
                context: context,
                accentColor: AppColors.expense,
                readData: () => TransactionFilterData(
                  categories: const [
                    {'id': 1, 'name': 'Makan'},
                    {'id': 2, 'name': 'Transportasi'},
                  ],
                  walletNames: const {10: 'BCA', 11: 'GoPay'},
                  selectedCategoryIds: List.of(selectedCats),
                  selectedWalletIds: List.of(selectedWallets),
                ),
                onToggleCategory: (id, sel) => sel ? selectedCats.add(id) : selectedCats.remove(id),
                onToggleWallet: (id, sel) => sel ? selectedWallets.add(id) : selectedWallets.remove(id),
                onReset: () {
                  resetCount++;
                  selectedCats.clear();
                  selectedWallets.clear();
                },
                onApply: () => applyCount++,
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Filter Transaksi'), findsOneWidget);
    expect(find.text('KATEGORI'), findsOneWidget);
    expect(find.text('DOMPET'), findsOneWidget);

    await tester.tap(find.text('Makan'));
    await tester.pumpAndSettle();
    expect(selectedCats, [1]);

    await tester.tap(find.text('GoPay'));
    await tester.pumpAndSettle();
    expect(selectedWallets, [11]);

    await tester.tap(find.text('Makan'));
    await tester.pumpAndSettle();
    expect(selectedCats, isEmpty);

    // Reset ada di header, sejajar judul "Filter Transaksi" (permintaan user).
    expect(tester.getRect(find.text('Reset')).center.dy,
        closeTo(tester.getRect(find.text('Filter Transaksi')).center.dy, 1));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
    expect(selectedWallets, isEmpty);

    await tester.tap(find.text('Terapkan Filter'));
    await tester.pumpAndSettle();
    expect(applyCount, 1);
    expect(find.text('Filter Transaksi'), findsNothing);
  });
}
