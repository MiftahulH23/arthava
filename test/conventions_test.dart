import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('Tidak ada GoogleFonts.poppins di lib/', () {
    final hits = <String>[];
    for (final f in _dartFiles('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('GoogleFonts.poppins')) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: 'Pakai AppTextStyles (spec §5)');
  });

  test('Tidak ada warna hardcoded di lib/screens dan lib/widgets', () {
    final pattern = RegExp(r'Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|deepPurple)');
    final hits = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final f in _dartFiles(dir)) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'Pakai AppColors (spec §4.1, §9.9)');
  });
}
