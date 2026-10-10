import 'package:arthava/widgets/app_pickers.dart';
import 'package:arthava/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  testWidgets('kalender memakai font aplikasi (Plus Jakarta Sans), bukan Roboto bawaan', (tester) async {
    await pumpOpener(
      tester,
      (c) => showAppDatePicker(context: c, initialDate: DateTime(2026, 9, 26), firstDate: DateTime(2020), lastDate: DateTime(2030)),
      (_) {},
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final day = tester.widget<Text>(find.text('15'));
    final style = DefaultTextStyle.of(tester.element(find.text('15'))).style.merge(day.style);
    // google_fonts memberi nama family per bobot, mis. PlusJakartaSans_500.
    expect(style.fontFamily, startsWith('PlusJakartaSans'));
  });

  testWidgets('mode gelap: angka kalender tetap gelap di kartu putih (terbaca)', (tester) async {
    await pumpApp(
      tester,
      Theme(
        data: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark)),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 26),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('15')).style!.color, AppColors.textPrimary);
  });

  testWidgets('rentang: ganti tahun saat mengedit Dari tidak loncat ke Sampai', (tester) async {
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
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    // Masih mengedit "Dari": ketuk 15 = tanggal mulai, baru pindah ke "Sampai".
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(result, DateTimeRange(start: DateTime(2025, 9, 15), end: DateTime(2026, 9, 10)));
  });

  testWidgets('kalender selalu berbahasa Indonesia walau bahasa perangkat Inggris', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 26),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('R'), findsOneWidget); // Rabu (header hari id_ID); Inggris tidak punya "R"
  });
}
