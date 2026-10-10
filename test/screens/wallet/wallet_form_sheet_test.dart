import 'dart:async';

import 'package:arthava/screens/wallet/wallet_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openForm(
    WidgetTester tester, {
    required Future<int> Function(String name, double balance, String color, double minBalance) insert,
    required Future<void> Function() onSaved,
    required void Function(int? id) onResult,
  }) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(await showWalletFormSheet(context, onSaved: onSaved, insertOverride: insert)),
            child: const Text('buka'),
          ),
        ),
      ),
      size: const Size(390, 1200),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Masukkan nama dompet'), 'Jago');
    await tester.enterText(find.widgetWithText(TextField, '0').first, '10000');
  }

  testWidgets('ketuk ganda Simpan Dompet hanya membuat satu dompet', (tester) async {
    var inserts = 0;
    final gate = Completer<void>();
    await openForm(
      tester,
      insert: (name, balance, color, min) async {
        inserts++;
        await gate.future;
        return 7;
      },
      onSaved: () async {},
      onResult: (_) {},
    );
    await tester.ensureVisible(find.text('Simpan Dompet'));
    await tester.tap(find.text('Simpan Dompet'));
    await tester.tap(find.text('Simpan Dompet'), warnIfMissed: false);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(inserts, 1);
  });

  testWidgets('dompet tersimpan tapi refresh gagal: tetap sukses dan mengembalikan id', (tester) async {
    int? result;
    await openForm(
      tester,
      insert: (name, balance, color, min) async => 9,
      onSaved: () async => throw Exception('offline'),
      onResult: (id) => result = id,
    );
    await tester.ensureVisible(find.text('Simpan Dompet'));
    await tester.tap(find.text('Simpan Dompet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Gagal menyimpan dompet.'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(result, 9);
  });
}
