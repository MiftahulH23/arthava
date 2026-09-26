import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Membuka pemilih lewat tombol "buka" lalu menyimpan hasilnya.
Future<void> pumpOpener(WidgetTester tester, Future<Object?> Function(BuildContext) open, void Function(Object?) done) {
  return pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () async => done(await open(context)), child: const Text('buka'))),
      ),
    ),
    size: const Size(390, 900),
  );
}

void main() {
  testWidgets('tanggal: judul, ketuk hari, Pilih mengembalikan tanggal itu', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 9, 26), firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tanggal'), findsOneWidget);
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 15));
  });

  testWidgets('tanggal: Batal mengembalikan null', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 9, 26), firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('tanggal: menjepit initialDate di luar rentang tanpa assertion', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 1, 1), firstDate: DateTime(2026, 9, 26), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 26));
  });

  testWidgets('bulan: ganti tahun, ketuk bulan, Pilih', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppMonthPicker(context: c, initialMonth: DateTime(2026, 9), firstYear: 2021, lastYear: 2031),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Bulan'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Tahun sebelumnya'));
    await tester.pump();
    expect(find.text('2025'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2025, 3));
  });

  testWidgets('bulan: tombol tahun nonaktif di batas', (tester) async {
    await pumpOpener(
      tester,
      (c) => showAppMonthPicker(context: c, initialMonth: DateTime(2021, 5), firstYear: 2021, lastYear: 2031),
      (_) {},
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final prev = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left));
    expect(prev.onPressed, isNull);
  });

  testWidgets('tahun: ketuk tahun, Pilih', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppYearPicker(context: c, initialYear: 2026, firstYear: 2020, lastYear: 2030),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tahun'), findsOneWidget);
    await tester.tap(find.text('2023'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, 2023);
  });

  testWidgets('rentang: pilih Dari lalu Sampai; Sampai lebih awal digeser ke Dari', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDateRangePicker(
        context: c,
        initialRange: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 10)),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      ),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Periode'), findsOneWidget);
    expect(find.text('Dari'), findsOneWidget);
    expect(find.text('Sampai'), findsOneWidget);
    // Baris "Dari" aktif: ketuk 20 -> Dari = 20, otomatis pindah ke "Sampai",
    // dan Sampai (10) yang lebih awal ikut digeser ke 20.
    await tester.tap(find.text('20'));
    await tester.pump();
    await tester.tap(find.text('25'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTimeRange(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 25)));
  });

  testWidgets('rentang: tanpa initialRange, Sampai = Dari bila hanya Dari yang diketuk', (tester) async {
    Object? result = 'belum';
    await pumpOpener(
      tester,
      (c) => showAppDateRangePicker(context: c, firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (r) => result = r,
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    final range = result! as DateTimeRange;
    expect(range.start, range.end);
  });
}
