import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('mode biasa punya Scaffold, judul besar, dan jarak antar blok 14', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Anggaran',
      children: [SizedBox(key: Key('a'), height: 10), SizedBox(key: Key('b'), height: 10)],
    ));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Anggaran'), findsOneWidget);
    final a = tester.getBottomLeft(find.byKey(const Key('a')));
    final b = tester.getTopLeft(find.byKey(const Key('b')));
    expect(b.dy - a.dy, AppPageScaffold.blockGap);
    expect(a.dx, AppPageScaffold.horizontalPadding);
  });

  testWidgets('embedded tanpa Scaffold dan menambah padding bawah navbar', (tester) async {
    await pumpApp(tester, const MediaQuery(
      data: MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(bottom: 100)),
      child: AppPageScaffold(title: 'Transaksi', embedded: true, children: [Text('isi')]),
    ));
    expect(find.byType(Scaffold), findsNothing);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.padding! as EdgeInsets).bottom, 124);
  });

  testWidgets('tombol kembali memakai backLabel dan menutup halaman', (tester) async {
    await pumpApp(tester, Builder(builder: (context) {
      return Scaffold(body: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const AppPageScaffold(title: 'Detail', backLabel: 'Beranda', children: []),
        )),
        child: const Text('buka'),
      ));
    }));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget);
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('AppNavAction.add dan .text memanggil onPressed', (tester) async {
    var added = 0;
    var edited = 0;
    await pumpApp(tester, AppPageScaffold(
      title: 'Utang',
      actions: [
        AppNavAction.text('Edit', onPressed: () => edited++),
        AppNavAction.add(onPressed: () => added++),
      ],
      children: const [],
    ));
    await tester.tap(find.text('Edit'));
    await tester.tap(find.byTooltip('Tambah'));
    expect(edited, 1);
    expect(added, 1);
  });

  testWidgets('largeTitle false menaruh judul kecil di nav dan titleWidget di list', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Detail Utang',
      largeTitle: false,
      titleWidget: Text('BS'),
      children: [],
    ));
    expect(find.text('Detail Utang'), findsOneWidget);
    expect(find.text('BS'), findsOneWidget);
  });

  testWidgets('bottomBar dirender di luar list', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Export',
      bottomBar: Text('Cetak'),
      children: [],
    ));
    expect(find.descendant(of: find.byType(ListView), matching: find.text('Cetak')), findsNothing);
    expect(find.text('Cetak'), findsOneWidget);
  });

  testWidgets('aksi nav teks minimal 44 dan dikenali sebagai tombol', (tester) async {
    await pumpApp(tester, AppPageScaffold(title: 'Utang', actions: [AppNavAction.text('Edit', onPressed: () {})], children: const []));
    expect(tester.getSize(find.byType(AppNavAction)).height, greaterThanOrEqualTo(44));
    expect(tester.getSemantics(find.byType(AppNavAction)), containsSemantics(isButton: true, label: 'Edit'));
  });

  testWidgets('AppNavAction.icon menerima tooltip', (tester) async {
    await pumpApp(tester, AppPageScaffold(
      title: 'Utang',
      actions: [AppNavAction.icon(Icons.delete, tooltip: 'Hapus', onPressed: () {})],
      children: const [],
    ));
    expect(find.byTooltip('Hapus'), findsOneWidget);
  });

  testWidgets('label kembali panjang tidak menimpa judul kecil di 360', (tester) async {
    await pumpApp(tester, const AppPageScaffold(
      title: 'Detail Utang Panjang',
      backLabel: 'Utang & Piutang Saya',
      largeTitle: false,
      children: [],
    ), size: const Size(360, 740));
    final back = tester.getRect(find.text('Utang & Piutang Saya'));
    final title = tester.getRect(find.text('Detail Utang Panjang'));
    expect(back.right, lessThanOrEqualTo(title.left));
  });

  testWidgets('dua aksi kanan (Edit + ikon) dengan judul kecil muat di 360', (tester) async {
    await pumpApp(tester, AppPageScaffold(
      title: 'Detail Utang',
      backLabel: 'Utang',
      largeTitle: false,
      actions: [
        AppNavAction.text('Edit', onPressed: () {}),
        AppNavAction.icon(Icons.delete, tooltip: 'Hapus utang', onPressed: () {}),
      ],
      children: const [],
    ), size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('Detail Utang'));
    final edit = tester.getRect(find.text('Edit'));
    expect(title.right, lessThanOrEqualTo(edit.left));
  });

  testWidgets('leading menggantikan tombol kembali', (tester) async {
    var tapped = false;
    await pumpApp(
      tester,
      AppPageScaffold(
        title: 'Tambah Transaksi',
        largeTitle: false,
        backLabel: 'Beranda',
        leading: AppNavAction.text('Batal', onPressed: () => tapped = true),
        children: const [SizedBox.shrink()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsNothing);
    await tester.tap(find.text('Batal'));
    expect(tapped, isTrue);
  });

  testWidgets('leading tanpa backLabel tetap memunculkan nav bar', (tester) async {
    await pumpApp(
      tester,
      AppPageScaffold(
        title: 'Dompet Saya',
        leading: AppNavAction.text('Batal', onPressed: () {}),
        children: const [SizedBox.shrink()],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Batal'), findsOneWidget);
  });
}
