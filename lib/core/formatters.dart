import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern('id_ID');
final NumberFormat _compact = NumberFormat('#,##0.#', 'id_ID');

/// "Rp 1.250.000"; negatif -> "-Rp 1.250.000". Dibulatkan ke rupiah.
String formatRupiah(num value) {
  final rounded = value.round();
  final text = 'Rp ${_grouped.format(rounded.abs())}';
  return rounded < 0 ? '-$text' : text;
}

/// "+Rp 45.000" bila [isIncome], "-Rp 45.000" bila tidak. Nilai selalu absolut.
String formatRupiahSigned(num value, {required bool isIncome}) {
  return '${isIncome ? '+' : '-'}${formatRupiah(value.abs())}';
}

/// "Rp 8,2 jt", "Rp 742 rb", "Rp 950". Untuk ruang sempit (kartu hero, widget).
String formatRupiahCompact(num value) {
  final abs = value.abs();
  final String body;
  if (abs >= 1000000) {
    body = 'Rp ${_compact.format(abs / 1000000)} jt';
  } else if (abs >= 1000) {
    body = 'Rp ${_compact.format(abs / 1000)} rb';
  } else {
    body = 'Rp ${_grouped.format(abs.round())}';
  }
  return value < 0 && abs.round() != 0 ? '-$body' : body;
}

// Buang bagian desimal gaya Indonesia (",00", ",5") di akhir teks tempelan
// sebelum mengambil digit; tanpa ini "1.250.000,00" terbaca 100x lipat.
final RegExp _trailingDecimal = RegExp(r',\d{1,2}\s*$');

String _digitsOnly(String text) =>
    text.trim().replaceFirst(_trailingDecimal, '').replaceAll(RegExp(r'[^0-9]'), '');

/// Mengambil digit saja (maks [RupiahInputFormatter.maxDigits]); kosong/sampah -> 0.
int parseRupiah(String text) {
  var digits = _digitsOnly(text);
  if (digits.isEmpty) return 0;
  if (digits.length > RupiahInputFormatter.maxDigits) {
    digits = digits.substring(0, RupiahInputFormatter.maxDigits);
  }
  return int.tryParse(digits) ?? 0;
}

/// Hanya digit, sisip titik ribuan, maks 15 digit, kursor selalu di akhir.
class RupiahInputFormatter extends TextInputFormatter {
  static const int maxDigits = 15;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = _digitsOnly(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final text = _grouped.format(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
