import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Semua modal di app harus sama bentuknya (keputusan user 2026-09-26):
/// - konfirmasi / pilihan → `showAppConfirmDialog` / `showAppChoiceDialog`
///   (lib/widgets/app_dialogs.dart, gaya dialog iOS);
/// - form / daftar → `showAppFormSheet`.
/// Pemanggilan dialog/sheet mentah di layar dilarang.
final _forbidden = RegExp(
  r'\b(showDialog|showCupertinoDialog|showModalBottomSheet|showCupertinoModalPopup|showGeneralDialog|showAppBottomSheet)\s*[<(]'
  r'|\b(AlertDialog|CupertinoAlertDialog|SimpleDialog)\s*\(',
);

/// Layar lama yang belum didesain ulang, dan plan yang wajib membersihkannya.
/// Hapus entri saat plan-nya merapikan layar itu; daftar ini harus kosong di akhir Phase B.
const _legacy = <String, String>{
  'lib/screens/input_transaction/input_transaction_screen.dart': 'B4',
  'lib/screens/stats/stats_screen.dart': 'B4',
  'lib/screens/transaction_history/transaction_history_screen.dart': 'B4',
  'lib/screens/budget/budget_screen.dart': 'B5',
  'lib/screens/budget/budget_detail_screen.dart': 'B5',
  'lib/screens/recurring/recurring_screen.dart': 'B5',
  'lib/screens/savings/saving_detail_screen.dart': 'B5',
  'lib/screens/savings/savings_screen.dart': 'B5',
  'lib/screens/target/target_screen.dart': 'B5',
  'lib/screens/export/export_screen.dart': 'B6',
  'lib/screens/investment/investment_screen.dart': 'B6',
  'lib/screens/manage_category/manage_category_screen.dart': 'B6',
};

Map<String, List<String>> _violations() {
  final result = <String, List<String>>{};
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    // Tempat komponen modal bersama didefinisikan.
    const shared = {'lib/widgets/app_dialogs.dart', 'lib/widgets/app_sheet.dart', 'lib/widgets/app_bottom_sheet.dart'};
    if (shared.contains(path)) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();
      if (line.startsWith('//')) continue;
      if (_forbidden.hasMatch(line)) (result[path] ??= []).add('${i + 1}: $line');
    }
  }
  return result;
}

void main() {
  test('modal hanya lewat komponen bersama (app_dialogs / showAppFormSheet)', () {
    final offenders = {
      for (final e in _violations().entries)
        if (!_legacy.containsKey(e.key)) e.key: e.value,
    };
    expect(offenders, isEmpty, reason: 'Pakai showAppConfirmDialog / showAppChoiceDialog / showAppFormSheet.');
  });

  test('daftar layar lama tidak memuat file yang sudah bersih', () {
    final violations = _violations();
    final cleaned = _legacy.keys.where((path) => !violations.containsKey(path)).toList();
    expect(cleaned, isEmpty, reason: 'Hapus file ini dari _legacy: modalnya sudah memakai komponen bersama.');
  });
}
