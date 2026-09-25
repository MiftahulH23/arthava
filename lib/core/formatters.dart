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

/// "+Rp 45.000" bila [isIncome], "-Rp 45.000" bila tidak. Nilai selalu absolut;
/// nominal yang dibulatkan jadi 0 tampil "Rp 0" tanpa tanda.
String formatRupiahSigned(num value, {required bool isIncome}) {
  if (value.round() == 0) return formatRupiah(0);
  return '${isIncome ? '+' : '-'}${formatRupiah(value.abs())}';
}

double _round1(num x) => (x * 10).round() / 10;

/// "Rp 8,2 jt", "Rp 742 rb", "Rp 950". Untuk ruang sempit (kartu hero, widget).
/// Satuan dipilih dari nilai SETELAH pembulatan, jadi 999.950 -> "Rp 1 jt".
String formatRupiahCompact(num value) {
  final abs = value.abs();
  final String body;
  if (abs >= 1000000 || _round1(abs / 1000) >= 1000) {
    body = 'Rp ${_compact.format(abs / 1000000)} jt';
  } else if (abs.round() >= 1000) {
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

/// Hanya digit, sisip titik ribuan, maks 15 digit. Kursor dipertahankan
/// relatif terhadap digit di kanannya, dan backspace tepat setelah titik
/// menghapus digit sebelum titik (bukan diam).
class RupiahInputFormatter extends TextInputFormatter {
  static const int maxDigits = 15;

  static int _countDigits(String text) => RegExp(r'[0-9]').allMatches(text).length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = newValue.text.trimRight().replaceFirst(_trailingDecimal, '');
    var cursor = newValue.selection.isValid ? newValue.selection.baseOffset : raw.length;
    if (cursor > raw.length) cursor = raw.length;

    final deletedSeparatorOnly = oldValue.selection.isCollapsed &&
        newValue.text.length < oldValue.text.length &&
        _digitsOnly(newValue.text) == _digitsOnly(oldValue.text);
    if (deletedSeparatorOnly) {
      final before = raw.substring(0, cursor);
      final i = before.lastIndexOf(RegExp(r'[0-9]'));
      if (i >= 0) {
        raw = raw.substring(0, i) + raw.substring(i + 1);
        cursor = i;
      }
    }

    var digitsAfter = _countDigits(raw.substring(cursor));
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    if (digitsAfter > digits.length) digitsAfter = digits.length;

    final text = _grouped.format(int.parse(digits));
    var offset = text.length;
    for (var seen = 0; seen < digitsAfter && offset > 0;) {
      offset--;
      if (RegExp(r'[0-9]').hasMatch(text[offset])) seen++;
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}
