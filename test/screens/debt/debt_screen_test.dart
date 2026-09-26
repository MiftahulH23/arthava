import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'debt_test_utils.dart';

void main() {
  DebtState state() => DebtState(
        isLoading: false,
        debts: [
          sampleDebt(id: 1, dueDate: DateTime(2026, 9, 22), notes: 'Modal usaha'),
          sampleDebt(id: 2, name: 'Rina', amount: 750000, remaining: 750000, dueDate: DateTime(2026, 11, 15)),
          sampleDebt(id: 3, name: 'Bank Jago', amount: 5000000, remaining: 0, status: 'paid'),
          sampleDebt(id: 4, name: 'Andi', type: DebtType.receivable, amount: 1500000, remaining: 1500000),
        ],
      );

  testWidgets('judul, total, segmented, dan kartu utang saya', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake));
    await tester.pump();

    expect(find.text('Utang & Piutang'), findsOneWidget);
    expect(find.text('Total Utang'), findsOneWidget);
    expect(find.text('Rp 1.950.000'), findsOneWidget); // 1.200.000 + 750.000
    expect(find.text('Total Piutang'), findsOneWidget);
    expect(find.text('Rp 1.500.000'), findsWidgets);
    expect(find.byType(AppSegmentedControl), findsOneWidget);

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Terlambat 2 hari'), findsOneWidget);
    expect(find.text('Tempo: 15 Nov 2026'), findsOneWidget);
    expect(find.text('LUNAS'), findsOneWidget);
    expect(find.text('Dipinjam 01 Agu 2026 · Modal usaha'), findsOneWidget);
    expect(find.text('Andi'), findsNothing);
  });

  testWidgets('urutan kartu: terlambat, tempo, lunas', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())));
    await tester.pump();
    final budi = tester.getTopLeft(find.text('Budi Santoso')).dy;
    final rina = tester.getTopLeft(find.text('Rina')).dy;
    final jago = tester.getTopLeft(find.text('Bank Jago')).dy;
    expect(budi, lessThan(rina));
    expect(rina, lessThan(jago));
  });

  testWidgets('pindah ke Piutang menampilkan label "Piutang dari:"', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())));
    await tester.pump();
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();
    expect(find.text('Andi'), findsOneWidget);
    expect(find.text('Piutang dari:'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsNothing);
  });

  testWidgets('empty state per tab memakai teks lama', (tester) async {
    await pumpApp(tester, const DebtScreen(),
        overrides: debtOverrides(FakeDebtNotifier(const DebtState(isLoading: false))));
    await tester.pump();
    expect(find.text('Belum ada utang yang dicatat.\nAlhamdulillah!'), findsOneWidget);
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada orang yang ngutang ke kamu.'), findsOneWidget);
  });

  testWidgets('loading menampilkan spinner', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(const DebtState())));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
