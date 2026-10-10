import 'package:arthava/widgets/app_pickers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tipe periode filter transaksi/statistik, urutan sama dengan tab lama.
const List<String> kPeriodFilterTypes = ['Harian', 'Bulanan', 'Tahunan', 'Periode'];

/// Label tombol tanggal sesuai tipe periode (dulu `dateLabel` di build()).
String periodLabel(String filterType, DateTime selectedDate, DateTimeRange? selectedDateRange) {
  switch (filterType) {
    case 'Harian':
      return DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate);
    case 'Tahunan':
      return DateFormat('yyyy', 'id_ID').format(selectedDate);
    case 'Periode':
      return selectedDateRange != null
          ? "${DateFormat('dd MMM', 'id_ID').format(selectedDateRange.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(selectedDateRange.end)}"
          : "Pilih Periode";
    default:
      return DateFormat('MMMM yyyy', 'id_ID').format(selectedDate);
  }
}

/// Menampilkan pemilih sesuai [filterType]. Percabangan sama dengan `_pickDate`
/// lama di TransactionHistoryScreen & StatsScreen: Harian = tanggal,
/// Tahunan = tahun, Periode = rentang tanggal, lainnya (Bulanan) = bulan + tahun.
/// Semua memakai sheet bersama `lib/widgets/app_pickers.dart` (spec G17).
Future<void> showAppPeriodPicker({
  required BuildContext context,
  required String filterType,
  required DateTime selectedDate,
  required DateTimeRange? selectedDateRange,
  required ValueChanged<DateTime> onDateSelected,
  required ValueChanged<DateTimeRange> onRangeSelected,
}) async {
  if (filterType == 'Harian') {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) onDateSelected(picked);
  } else if (filterType == 'Tahunan') {
    final year = await showAppYearPicker(
      context: context,
      initialYear: selectedDate.year,
      firstYear: 2020,
      lastYear: 2030,
    );
    // Sama seperti YearPicker lama: bulan yang sedang dipilih dipertahankan.
    if (year != null) onDateSelected(DateTime(year, selectedDate.month));
  } else if (filterType == 'Periode') {
    final picked = await showAppDateRangePicker(
      context: context,
      initialRange: selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) onRangeSelected(picked);
  } else {
    final currentYear = DateTime.now().year;
    final picked = await showAppMonthPicker(
      context: context,
      initialMonth: selectedDate,
      firstYear: currentYear - 5,
      lastYear: currentYear + 5,
    );
    if (picked != null) onDateSelected(picked);
  }
}
