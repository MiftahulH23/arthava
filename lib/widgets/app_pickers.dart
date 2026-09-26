import 'dart:async';

import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pemilih tanggal/bulan/tahun/periode bersama (spec G17): semuanya sheet bawah
/// `showAppFormSheet` (Batal · judul) dengan tombol "Pilih" penuh. `null` = batal.

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clamp(DateTime d, DateTime first, DateTime last) {
  final day = _dateOnly(d);
  if (day.isBefore(_dateOnly(first))) return _dateOnly(first);
  if (day.isAfter(_dateOnly(last))) return _dateOnly(last);
  return day;
}

/// Kalender di kartu putih; warna aksen primary.
///
/// Kartu selalu terang, jadi skema warna & teks kalender dipaksa terang juga —
/// tanpa ini, mode gelap memberi angka terang di atas kartu putih (tak terbaca).
/// Bahasa kalender dipaksa id_ID (app tidak menyetel `locale`, jadi mengikuti
/// perangkat), sama seperti `DateFormat(..., 'id_ID')` di label sheet.
Widget _calendarCard(BuildContext context, Widget calendar) {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );
  return Localizations.override(
    context: context,
    locale: const Locale('id', 'ID'),
    child: Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        colorScheme: scheme,
        // Font aplikasi (spec G14): kalender Material tidak boleh jatuh ke Roboto bila
        // tema pemanggil tidak menyetelnya. Family diambil dari AppTextStyles (dibuat
        // sekali), bukan GoogleFonts di build() yang memicu pemuatan font tiap rebuild.
        textTheme: Typography.material2021(colorScheme: scheme).black.apply(fontFamily: AppTextStyles.body.fontFamily),
      ),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: calendar,
      ),
    ),
  );
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pilih Tanggal',
}) {
  var selected = _clamp(initialDate, firstDate, lastDate);
  return showAppFormSheet<DateTime>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _calendarCard(
            sheetContext,
            CalendarDatePicker(
              initialDate: selected,
              firstDate: _dateOnly(firstDate),
              lastDate: _dateOnly(lastDate),
              onDateChanged: (d) => setSheetState(() => selected = d),
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Pilih', onPressed: () => Navigator.of(sheetContext).pop(selected)),
        ],
      ),
    ),
  );
}

/// Grid pilihan (bulan/tahun): pill putih, terpilih = primary penuh.
Widget _choiceGrid({required List<String> labels, required int selectedIndex, required ValueChanged<int> onTap}) {
  return Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.all(12),
    child: GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            button: true,
            selected: i == selectedIndex,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selectedIndex ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[i],
                  style: AppTextStyles.bodyStrong.copyWith(color: i == selectedIndex ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<DateTime?> showAppMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  required int firstYear,
  required int lastYear,
  String title = 'Pilih Bulan',
}) {
  var year = initialMonth.year.clamp(firstYear, lastYear);
  var month = initialMonth.month;
  final labels = [for (var m = 1; m <= 12; m++) DateFormat('MMM', 'id_ID').format(DateTime(2024, m))];
  return showAppFormSheet<DateTime>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Tahun sebelumnya',
                color: AppColors.primary,
                icon: const Icon(Icons.chevron_left),
                onPressed: year > firstYear ? () => setSheetState(() => year--) : null,
              ),
              SizedBox(width: 88, child: Text('$year', textAlign: TextAlign.center, style: AppTextStyles.headline)),
              IconButton(
                tooltip: 'Tahun berikutnya',
                color: AppColors.primary,
                icon: const Icon(Icons.chevron_right),
                onPressed: year < lastYear ? () => setSheetState(() => year++) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _choiceGrid(labels: labels, selectedIndex: month - 1, onTap: (i) => setSheetState(() => month = i + 1)),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Pilih', onPressed: () => Navigator.of(sheetContext).pop(DateTime(year, month))),
        ],
      ),
    ),
  );
}

Future<int?> showAppYearPicker({
  required BuildContext context,
  required int initialYear,
  required int firstYear,
  required int lastYear,
  String title = 'Pilih Tahun',
}) {
  final years = [for (var y = firstYear; y <= lastYear; y++) y];
  var index = years.indexOf(initialYear.clamp(firstYear, lastYear));
  return showAppFormSheet<int>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _choiceGrid(labels: [for (final y in years) '$y'], selectedIndex: index, onTap: (i) => setSheetState(() => index = i)),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Pilih', onPressed: () => Navigator.of(sheetContext).pop(years[index])),
        ],
      ),
    ),
  );
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pilih Periode',
}) {
  final today = _clamp(DateTime.now(), firstDate, lastDate);
  var start = initialRange == null ? today : _clamp(initialRange.start, firstDate, lastDate);
  var end = initialRange == null ? start : _clamp(initialRange.end, firstDate, lastDate);
  if (end.isBefore(start)) end = start;
  var editingStart = true;
  // Ganti tahun di header kalender juga memanggil onDateChanged, tepat setelah
  // onDisplayedMonthChanged (Flutter `_handleYearChanged`). Tandai sesaat supaya
  // itu tidak dianggap ketukan tanggal (yang memindahkan edit ke "Sampai").
  var monthJustChanged = false;
  final fmt = DateFormat('d MMM yyyy', 'id_ID');
  return showAppFormSheet<DateTimeRange>(
    context: context,
    title: title,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Widget row(String label, DateTime value, bool active) => AppListRow(
              title: label,
              value: fmt.format(value),
              valueColor: active ? AppColors.primary : null,
              onTap: () => setSheetState(() => editingStart = label == 'Dari'),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroupedSection(children: [row('Dari', start, editingStart), row('Sampai', end, !editingStart)]),
            const SizedBox(height: 12),
            _calendarCard(
              sheetContext,
              CalendarDatePicker(
                // Key per baris: kalender pindah ke tanggal baris yang sedang diedit.
                key: ValueKey(editingStart),
                initialDate: editingStart ? start : end,
                firstDate: _dateOnly(editingStart ? firstDate : start),
                lastDate: _dateOnly(lastDate),
                onDisplayedMonthChanged: (_) {
                  monthJustChanged = true;
                  scheduleMicrotask(() => monthJustChanged = false);
                },
                onDateChanged: (d) => setSheetState(() {
                  final fromYearChange = monthJustChanged;
                  monthJustChanged = false;
                  if (editingStart) {
                    start = d;
                    if (end.isBefore(start)) end = start;
                    if (!fromYearChange) editingStart = false;
                  } else {
                    end = d;
                  }
                }),
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Pilih',
              onPressed: () => Navigator.of(sheetContext).pop(DateTimeRange(start: start, end: end)),
            ),
          ],
        );
      },
    ),
  );
}
