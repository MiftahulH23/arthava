import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Widget _opener(Future<void> Function(BuildContext) onOpen) => Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => onOpen(context), child: const Text('buka')),
      ),
    );

void main() {
  testWidgets('showAppFormSheet menampilkan header Batal·judul dan menutup saat Batal', (tester) async {
    await pumpApp(tester, _opener((context) => showAppFormSheet<void>(
      context: context,
      title: 'Buat Anggaran',
      builder: (_) => const Text('isi form'),
    )));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Buat Anggaran'), findsOneWidget);
    expect(find.text('isi form'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('isi form'), findsNothing);
  });

  testWidgets('showAppConfirmDialog true saat dikonfirmasi, false saat batal', (tester) async {
    final results = <bool>[];
    await pumpApp(tester, _opener((context) async {
      results.add(await showAppConfirmDialog(
        context: context, title: 'Hapus Transaksi?', message: 'Data ini akan dihapus permanen.',
      ));
    }));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });
}
