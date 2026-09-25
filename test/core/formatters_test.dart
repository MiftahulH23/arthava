import 'package:catat_uang_app/core/formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _apply(String oldText, String newText) {
  return RupiahInputFormatter().formatEditUpdate(
    TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: oldText.length)),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length)),
  );
}

void main() {
  group('formatRupiah', () {
    test('memakai titik ribuan dan prefix Rp', () {
      expect(formatRupiah(1250000), 'Rp 1.250.000');
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(950), 'Rp 950');
    });
    test('negatif diawali minus', () {
      expect(formatRupiah(-45000), '-Rp 45.000');
    });
    test('dibulatkan ke rupiah terdekat', () {
      expect(formatRupiah(1999.6), 'Rp 2.000');
      expect(formatRupiah(-0.4), 'Rp 0');
    });
  });

  group('formatRupiahSigned', () {
    test('tanda mengikuti isIncome, nilai absolut', () {
      expect(formatRupiahSigned(45000, isIncome: true), '+Rp 45.000');
      expect(formatRupiahSigned(45000, isIncome: false), '-Rp 45.000');
      expect(formatRupiahSigned(-45000, isIncome: false), '-Rp 45.000');
    });
  });

  group('formatRupiahCompact', () {
    test('cabang juta', () {
      expect(formatRupiahCompact(8200000), 'Rp 8,2 jt');
      expect(formatRupiahCompact(5000000), 'Rp 5 jt');
      expect(formatRupiahCompact(1250000000), 'Rp 1.250 jt');
    });
    test('cabang ribu', () {
      expect(formatRupiahCompact(742000), 'Rp 742 rb');
      expect(formatRupiahCompact(1500), 'Rp 1,5 rb');
    });
    test('cabang polos', () {
      expect(formatRupiahCompact(950), 'Rp 950');
      expect(formatRupiahCompact(0), 'Rp 0');
    });
    test('negatif', () {
      expect(formatRupiahCompact(-3100000), '-Rp 3,1 jt');
    });
  });

  group('parseRupiah', () {
    test('membaca format lengkap', () {
      expect(parseRupiah('Rp 1.250.000'), 1250000);
      expect(parseRupiah('1.250.000'), 1250000);
    });
    test('kosong dan sampah jadi 0', () {
      expect(parseRupiah(''), 0);
      expect(parseRupiah('abc'), 0);
      expect(parseRupiah('Rp '), 0);
    });
    test('dibatasi 15 digit', () {
      expect(parseRupiah('1234567890123456789'), 123456789012345);
    });
    test('bagian desimal (,00 / ,50) dibuang, bukan digabung', () {
      expect(parseRupiah('Rp 1.250.000,00'), 1250000);
      expect(parseRupiah('1.250.000,50'), 1250000);
    });
  });

  group('RupiahInputFormatter', () {
    test('menyisipkan titik ribuan dan kursor di akhir', () {
      final v = _apply('', '1250000');
      expect(v.text, '1.250.000');
      expect(v.selection, const TextSelection.collapsed(offset: 9));
    });
    test('membersihkan teks tempelan campur', () {
      expect(_apply('', 'Rp 1.250.000,-').text, '1.250.000');
    });
    test('tempelan berdesimal tidak menggelembung 100x', () {
      expect(_apply('', 'Rp 1.250.000,00').text, '1.250.000');
      expect(_apply('', '45.000,5').text, '45.000');
    });
    test('menghapus semua digit menghasilkan string kosong', () {
      final v = _apply('5', '');
      expect(v.text, '');
      expect(v.selection, const TextSelection.collapsed(offset: 0));
    });
    test('membuang nol di depan', () {
      expect(_apply('', '000450').text, '450');
    });
    test('dibatasi 15 digit', () {
      final v = _apply('', '9999999999999999999');
      expect(v.text, '999.999.999.999.999');
      expect(v.selection.baseOffset, v.text.length);
    });
  });
}
