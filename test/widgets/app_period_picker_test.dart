import 'package:catat_uang_app/widgets/app_period_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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
}
