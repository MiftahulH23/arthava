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
