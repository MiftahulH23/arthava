import 'package:arthava/widgets/app_period_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  final date = DateTime(2026, 9, 24);

  test('kPeriodFilterTypes urutannya persis seperti tab lama', () {
    expect(kPeriodFilterTypes, ['Harian', 'Bulanan', 'Tahunan', 'Periode']);
  });

  test('label per tipe periode sama seperti dateLabel lama', () {
    expect(periodLabel('Harian', date, null), '24 Sep 2026');
    expect(periodLabel('Bulanan', date, null), 'September 2026');
    expect(periodLabel('Tahunan', date, null), '2026');
    expect(
      periodLabel('Periode', date, DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 24))),
      '01 Sep - 24 Sep 26',
    );
    expect(periodLabel('Periode', date, null), 'Pilih Periode');
  });

  group('showAppPeriodPicker', () {
    Future<void> open(
      WidgetTester tester,
      String type, {
      required ValueChanged<DateTime> onDate,
      required ValueChanged<DateTimeRange> onRange,
    }) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppPeriodPicker(
                  context: context,
                  filterType: type,
                  selectedDate: date,
                  selectedDateRange: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 10)),
                  onDateSelected: onDate,
                  onRangeSelected: onRange,
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
        size: const Size(390, 900),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    Future<void> pilih(WidgetTester tester) async {
      await tester.tap(find.text('Pilih'));
      await tester.pumpAndSettle();
    }

    testWidgets('Harian: sheet Pilih Tanggal -> onDateSelected', (tester) async {
      DateTime? got;
      await open(tester, 'Harian', onDate: (d) => got = d, onRange: (_) {});
      expect(find.text('Pilih Tanggal'), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.pump();
      await pilih(tester);
      expect(got, DateTime(2026, 9, 15));
    });

    testWidgets('Tahunan: sheet Pilih Tahun -> DateTime(tahun, bulan lama)', (tester) async {
      DateTime? got;
      await open(tester, 'Tahunan', onDate: (d) => got = d, onRange: (_) {});
      expect(find.text('Pilih Tahun'), findsOneWidget);
      await tester.tap(find.text('2024'));
      await tester.pump();
      await pilih(tester);
      expect(got, DateTime(2024, 9));
    });

    testWidgets('Periode: sheet Pilih Periode -> onRangeSelected', (tester) async {
      DateTimeRange? got;
      await open(tester, 'Periode', onDate: (_) {}, onRange: (r) => got = r);
      expect(find.text('Pilih Periode'), findsOneWidget);
      await pilih(tester);
      expect(got, DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 10)));
    });

    testWidgets('Bulanan: sheet Pilih Bulan -> DateTime(tahun, bulan)', (tester) async {
      DateTime? got;
      await open(tester, 'Bulanan', onDate: (d) => got = d, onRange: (_) {});
      expect(find.text('Pilih Bulan'), findsOneWidget);
      await tester.tap(find.text('Mar'));
      await tester.pump();
      await pilih(tester);
      expect(got, DateTime(2026, 3));
    });

    testWidgets('Batal: tidak memanggil callback apa pun', (tester) async {
      var calls = 0;
      await open(tester, 'Harian', onDate: (_) => calls++, onRange: (_) => calls++);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });
  });
}
