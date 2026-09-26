import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/calendar_provider.dart';
import 'package:catat_uang_app/screens/calendar/calendar_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class FakeCalendarNotifier extends CalendarNotifier {
  FakeCalendarNotifier(this.initial);
  final CalendarState initial;

  @override
  CalendarState build() => initial;
}

TransactionModel _trx({required int id, required String cat, required bool isExpense, required double amount, String? note}) {
  return TransactionModel(
    id: id,
    userId: 'u1',
    categoryId: id,
    amount: amount,
    date: DateTime.now(),
    note: note,
    category: CategoryModel(id: id, name: cat, isExpense: isExpense, iconName: 'tag'),
    walletId: 1,
  );
}

CalendarState _state(List<TransactionModel> today) => CalendarState(
      isLoading: false,
      groupedTransactions: {normalizeCalendarDate(DateTime.now()): today},
      walletNames: const {1: 'BCA'},
      walletColors: const {1: Color(0xFF4A6CF7)},
    );

void main() {
  testWidgets('menampilkan kalender, total harian, dan transaksi hari ini', (tester) async {
    final fake = FakeCalendarNotifier(_state([
      _trx(id: 1, cat: 'Makan', isExpense: true, amount: 45000, note: 'Nasi Padang'),
      _trx(id: 2, cat: 'Gaji', isExpense: false, amount: 8000000),
    ]));
    await pumpApp(tester, const CalendarScreen(), overrides: [calendarProvider.overrideWith(() => fake)]);
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Kalender Keuangan'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.now())), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('- Rp 45.000'), findsOneWidget);
    expect(find.text('+ Rp 8.000.000'), findsOneWidget);
    expect(find.text('Tanpa catatan'), findsOneWidget);
    expect(find.text('BCA'), findsNWidgets(2));
  });

  testWidgets('empty state saat hari terpilih tanpa transaksi', (tester) async {
    final fake = FakeCalendarNotifier(_state(const []));
    await pumpApp(tester, const CalendarScreen(), overrides: [calendarProvider.overrideWith(() => fake)]);
    await tester.pump();
    expect(find.text('Tidak ada transaksi hari ini'), findsOneWidget);
  });

  testWidgets('chevron kanan memindah judul bulan', (tester) async {
    final fake = FakeCalendarNotifier(_state(const []));
    await pumpApp(tester, const CalendarScreen(), overrides: [calendarProvider.overrideWith(() => fake)]);
    await tester.pump();

    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, 1);
    await tester.tap(find.byIcon(PhosphorIconsBold.caretRight));
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(next)), findsOneWidget);
  });
}
