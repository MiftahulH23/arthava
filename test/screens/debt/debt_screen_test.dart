import 'package:arthava/models/debt_model.dart';
import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/screens/debt/debt_screen.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:flutter/cupertino.dart';
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

  testWidgets('geser layar ke kiri pindah ke Piutang, ke kanan kembali', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())));
    await tester.pump();
    await tester.timedDrag(find.text('Total Utang'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Piutang dari:'), findsWidgets);
    await tester.timedDrag(find.text('Total Utang'), const Offset(250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Piutang dari:'), findsNothing);
  });

  testWidgets('geser kartu utang lalu Hapus: dialog lama, deleteDebt terpanggil', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Catatan?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('deleteDebt:2'));
    expect(find.text('Data berhasil dihapus!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('hapus dari daftar memuat riwayat cicilan dulu sebelum memilih dialog', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('fetchPayments:2'));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('deleteDebt')), isEmpty);
  });

  testWidgets('geser kartu utang lalu Edit membuka form terisi', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Utang'), findsOneWidget);
    expect(find.text('Rina'), findsWidgets);
  });

  testWidgets('hapus dari daftar: cicilan yang menyentuh dompet memunculkan pilihan kembalikan saldo', (tester) async {
    final fake = FakeDebtNotifier(state())..paymentsOnFetch = {2: [samplePayment(id: 11, debtId: 2)]};
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus & kembalikan saldo'), findsOneWidget);
    expect(find.textContaining('tidak terhubung ke saldo'), findsNothing);
    await tester.tap(find.text('Hapus & kembalikan saldo'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('deleteDebt:2:refund'));
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('hapus dari daftar: gagal memuat cicilan tidak menghapus dan tidak salah klaim', (tester) async {
    await prewarmToastFont();
    final fake = FakeDebtNotifier(state())..failFetchPayments = true;
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('fetchPayments:2'));
    expect(find.textContaining('tidak terhubung ke saldo'), findsNothing);
    expect(find.text('Hapus Catatan?'), findsNothing);
    expect(find.text('Gagal memuat cicilan. Coba lagi.'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('deleteDebt')), isEmpty);
    await flushToast(tester);
  });
}
