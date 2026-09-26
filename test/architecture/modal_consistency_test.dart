import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Semua modal di app harus sama bentuknya (keputusan user 2026-09-26):
/// - konfirmasi / pilihan → `showAppConfirmDialog` / `showAppChoiceDialog`
///   (lib/widgets/app_dialogs.dart, gaya dialog iOS);
/// - form / daftar → `showAppFormSheet`;
/// - tanggal / bulan / tahun / periode → `showApp*Picker` (lib/widgets/app_pickers.dart).
/// Pemanggilan dialog/sheet mentah di layar dilarang.
final _forbidden = RegExp(
  r'\b(showDialog|showAdaptiveDialog|showCupertinoDialog|showModalBottomSheet|showBottomSheet'
  r'|showCupertinoModalPopup|showCupertinoSheet|showGeneralDialog|showAppBottomSheet'
  r'|showDatePicker|showDateRangePicker|showTimePicker)\s*[<(]'
  r'|\b(AlertDialog|CupertinoAlertDialog|SimpleDialog)(\.adaptive)?\s*\(',
);

/// File tempat komponen modal bersama didefinisikan.
const _shared = {
  'lib/widgets/app_dialogs.dart',
  'lib/widgets/app_sheet.dart',
  'lib/widgets/app_bottom_sheet.dart',
  'lib/widgets/app_pickers.dart',
};

/// Layar lama yang belum didesain ulang, dan plan yang wajib membersihkannya.
/// Hapus entri saat plan-nya merapikan layar itu; daftar ini harus kosong di akhir Phase B.
const _legacy = <String, String>{
  'lib/screens/export/export_screen.dart': 'B6',
  'lib/screens/investment/investment_screen.dart': 'B6',
  'lib/screens/manage_category/manage_category_screen.dart': 'B6',
};

/// Baris (1-based) yang memanggil modal mentah. Komentar `//` dan `/* */`
/// diabaikan (diganti spasi, jadi nomor baris tetap); nama dan `(` boleh
/// terpisah baris.
List<int> modalCallLines(String source) {
  final code = source.replaceAllMapped(
    RegExp(r'/\*[\s\S]*?\*/|//[^\n]*'),
    (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
  );
  return [
    for (final m in _forbidden.allMatches(code)) '\n'.allMatches(code.substring(0, m.start)).length + 1,
  ];
}

Map<String, List<int>> _violations() {
  final result = <String, List<int>>{};
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    if (_shared.contains(path)) continue;
    final lines = modalCallLines(file.readAsStringSync());
    if (lines.isNotEmpty) result[path] = lines;
  }
  return result;
}

void main() {
  group('modalCallLines', () {
    test('menangkap panggilan biasa, adaptive, dan yang terpisah baris', () {
      const src = 'a();\n'
          'showDialog(context: c);\n'
          'showAdaptiveDialog<void>(context: c);\n'
          'AlertDialog.adaptive(title: t);\n'
          'Scaffold.of(c).showBottomSheet(\n'
          '  (_) => w);\n'
          'showModalBottomSheet\n'
          '  (context: c);\n';
      expect(modalCallLines(src), [2, 3, 4, 5, 7]);
    });

    test('mengabaikan komentar baris dan blok, serta nama komponen bersama', () {
      const src = '// showDialog(context: c);\n'
          '/* AlertDialog(\n'
          '   ) */\n'
          'showAppConfirmDialog(context: c);\n'
          'showAppFormSheet(context: c);\n'
          'final isAlertDialogOpen = true;\n';
      expect(modalCallLines(src), isEmpty);
    });
  });

  test('modal hanya lewat komponen bersama (app_dialogs / showAppFormSheet)', () {
    final offenders = {
      for (final e in _violations().entries)
        if (!_legacy.containsKey(e.key)) e.key: e.value,
    };
    expect(offenders, isEmpty, reason: 'Pakai showAppConfirmDialog / showAppChoiceDialog / showAppFormSheet (baris di atas).');
  });

  test('daftar layar lama tidak memuat file yang sudah bersih', () {
    final violations = _violations();
    final cleaned = _legacy.keys.where((path) => !violations.containsKey(path)).toList();
    expect(cleaned, isEmpty, reason: 'Hapus file ini dari _legacy: modalnya sudah memakai komponen bersama.');
  });
}
