import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/screens/savings/saving_detail_screen.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeSavingsNotifier extends SavingsNotifier {
  _FakeSavingsNotifier(this._initial);
  final SavingsState _initial;
  var editCalls = 0;
  @override
  SavingsState build() => _initial;
  @override
  Future<void> editSavingItem({
    required SavingModel saving,
    required double rawAmount,
    required bool isDeposit,
    required String location,
    required String notes,
  }) async {
    editCalls++;
    lastEdit = (saving.id, rawAmount, isDeposit, location, notes);
  }

  (int, double, bool, String, String)? lastEdit;
  final deleted = <int>[];
  @override
  Future<void> deleteSavingItem(SavingModel item) async => deleted.add(item.id);
}

SavingModel _item(int id, double amount, {String? location, String? notes}) => SavingModel(
      id: id,
      userId: 'u1',
      name: 'Dana Darurat',
      amount: amount,
      location: location,
      notes: notes,
      createdAt: DateTime(2026, 9, 24, 9, 12),
    );

void main() {
  late _FakeSavingsNotifier notifier;

  Future<void> pump(WidgetTester tester) async {
    notifier = _FakeSavingsNotifier(
      SavingsState(
        isLoading: false,
        groupedSavings: {
          'Dana Darurat': [
            _item(1, 1000000, location: 'Bank BCA', notes: 'Gaji September'),
            _item(2, -250000),
          ],
        },
        wallets: const [
          {'id': 7, 'name': 'BCA', 'balance': 9300000},
        ],
      ),
    );
    await pumpApp(
      tester,
      const SavingDetailScreen(savingName: 'Dana Darurat'),
      overrides: [savingsProvider.overrideWith(() => notifier)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan hero saldo dan riwayat setor/tarik', (tester) async {
    await pump(tester);

    expect(find.text('Dana Darurat'), findsWidgets);
    expect(find.text('Total Saldo Tabungan'), findsOneWidget);
    expect(find.text('Setoran Tabungan'), findsOneWidget);
    expect(find.text('Penarikan Dana'), findsOneWidget);
    expect(find.text('Bank BCA'), findsOneWidget);
    expect(find.text('Gaji September'), findsOneWidget);
    expect(find.text('24 Sep 2026, 09:12'), findsNWidgets(2));
    expect(find.textContaining('+ Rp'), findsOneWidget);
    expect(find.textContaining('- Rp'), findsOneWidget);
  });

  testWidgets('Edit dengan nominal kosong tidak crash dan tidak menyimpan (Review Focus #2)', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(PhosphorIconsRegular.pencilSimple).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Setoran'), findsOneWidget);

    final amountField = find.descendant(of: find.byType(AppAmountField), matching: find.byType(TextField));
    await tester.enterText(amountField, '');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(notifier.editCalls, 0);
    expect(find.text('Edit Setoran'), findsOneWidget);
  });

  testWidgets('Edit Tarikan menyimpan nominal & teks trim → "Perubahan disimpan!"', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(PhosphorIconsRegular.pencilSimple).last);
    await tester.pumpAndSettle();
    expect(find.text('Edit Tarikan'), findsOneWidget);

    final amountField = find.descendant(of: find.byType(AppAmountField), matching: find.byType(TextField));
    await tester.enterText(amountField, '300000');
    await tester.enterText(find.widgetWithText(TextField, 'Tulis catatan...'), ' Servis motor ');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.lastEdit, (2, 300000.0, false, '', 'Servis motor'));
    expect(find.text('Perubahan disimpan!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('hapus histori: dialog teks lama → deleteSavingItem + toast', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(PhosphorIconsRegular.trash).first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Histori?'), findsOneWidget);
    expect(find.text('Catatan ini dihapus dan saldonya dikembalikan ke dompet.'), findsOneWidget);
    await tester.tap(find.text('Hapus').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.deleted, [1]);
    expect(find.text('Data dihapus & Saldo Dompet dikembalikan!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
