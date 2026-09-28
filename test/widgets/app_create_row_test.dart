import 'package:catat_uang_app/widgets/app_create_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppCreateRow menampilkan "+ label" dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppCreateRow(label: 'Dompet Baru', onTap: () => taps++)));
    await tester.tap(find.text('Dompet Baru'));
    expect(taps, 1);
  });
}
