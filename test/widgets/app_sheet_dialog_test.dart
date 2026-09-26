import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('tombol Batal di sheet minimal 44 dan berupa tombol', (tester) async {
    await pumpApp(tester, Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => showAppFormSheet<void>(context: context, title: 'Buat Anggaran', builder: (_) => const Text('isi')),
      child: const Text('buka'),
    ))));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    final batal = find.ancestor(of: find.text('Batal'), matching: find.byType(Semantics)).first;
    expect(tester.getSize(batal).height, greaterThanOrEqualTo(44));
    expect(tester.getSemantics(find.text('Batal')), containsSemantics(isButton: true));
  });

  testWidgets('showAppChoiceDialog mengembalikan nilai pilihan, null saat Batal', (tester) async {
    final results = <String?>[];
    await pumpApp(tester, Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () async => results.add(await showAppChoiceDialog<String>(
        context: context,
        title: 'Hapus Catatan?',
        message: 'Pilih cara menghapus.',
        choices: const [
          AppDialogChoice(label: 'Hapus & kembalikan saldo', value: 'refund'),
          AppDialogChoice(label: 'Hapus saja', value: 'keep', destructive: true),
        ],
      )),
      child: const Text('buka'),
    ))));
    for (final tapLabel in ['Hapus & kembalikan saldo', 'Hapus saja', 'Batal']) {
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih cara menghapus.'), findsOneWidget);
      await tester.tap(find.widgetWithText(CupertinoDialogAction, tapLabel));
      await tester.pumpAndSettle();
    }
    expect(results, ['refund', 'keep', null]);
  });

  testWidgets('teks dialog memakai font aplikasi (bukan font sistem iOS)', (tester) async {
    await pumpApp(tester, Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => showAppChoiceDialog<bool>(
        context: context,
        title: 'Hapus Catatan?',
        message: 'Pesan.',
        choices: const [
          AppDialogChoice(label: 'Hapus & kembalikan saldo', value: true),
          AppDialogChoice(label: 'Hapus saja', value: false, destructive: true),
        ],
      ),
      child: const Text('buka'),
    ))));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    for (final label in ['Hapus Catatan?', 'Pesan.', 'Hapus & kembalikan saldo', 'Hapus saja', 'Batal']) {
      final family = tester.renderObject<RenderParagraph>(find.text(label)).text.style?.fontFamily ?? '';
      expect(family, contains('PlusJakartaSans'), reason: label);
    }
    final destructive = tester.renderObject<RenderParagraph>(find.text('Hapus saja')).text.style!.color;
    expect(destructive, AppColors.expense);
  });
}
