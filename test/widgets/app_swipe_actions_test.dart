import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<void> pumpRow(WidgetTester tester, {VoidCallback? onEdit, VoidCallback? onDelete, VoidCallback? onRowTap}) {
    return pumpApp(tester, Scaffold(body: AppSwipeActions(
      onEdit: onEdit,
      onDelete: onDelete,
      deleteConfirmTitle: 'Hapus Transaksi?',
      child: ListTile(title: const Text('Makan'), onTap: onRowTap),
    )));
  }

  testWidgets('geser kiri memperlihatkan Edit dan Hapus', (tester) async {
    await pumpRow(tester, onEdit: () {}, onDelete: () {});
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Makan')).dx, lessThan(0));
  });

  testWidgets('onDelete hanya dipanggil setelah konfirmasi', (tester) async {
    var deleted = 0;
    await pumpRow(tester, onDelete: () => deleted++);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('tap baris saat terbuka menutup tanpa memicu onTap baris', (tester) async {
    var rowTaps = 0;
    await pumpRow(tester, onEdit: () {}, onRowTap: () => rowTaps++);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    // Ketuk bagian baris yang masih terlihat (teks sendiri bergeser keluar layar).
    final rowCenterY = tester.getCenter(find.byType(AppSwipeActions)).dy;
    await tester.tapAt(Offset(200, rowCenterY));
    await tester.pumpAndSettle();
    expect(rowTaps, 0);
    expect(tester.getTopLeft(find.text('Makan')).dx, greaterThanOrEqualTo(0));
    await tester.tap(find.text('Makan'));
    expect(rowTaps, 1);
  });

  testWidgets('tanpa aksi mengembalikan child apa adanya', (tester) async {
    await pumpRow(tester);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus'), findsNothing);
  });

  testWidgets('child di atas Material surface opaque (ripple terlihat, aksi tak tembus)', (tester) async {
    await pumpRow(tester, onDelete: () {});
    final material = tester.widget<Material>(find.ancestor(of: find.text('Makan'), matching: find.byType(Material)).first);
    expect(material.color, AppColors.surface);
  });

  testWidgets('Edit dan Hapus tersedia sebagai aksi pembaca layar', (tester) async {
    final handle = tester.ensureSemantics();
    var edited = 0;
    await pumpRow(tester, onEdit: () => edited++, onDelete: () {});
    final node = tester.getSemantics(find.byType(AppSwipeActions));
    final labels = node.getSemanticsData().customSemanticsActionIds!
        .map((id) => CustomSemanticsAction.getAction(id)!.label)
        .toList();
    expect(labels, containsAll(['Edit', 'Hapus']));
    handle.dispose();
  });

  Future<void> pumpList(WidgetTester tester) {
    return pumpApp(tester, Scaffold(body: ListView(children: [
      for (final name in ['Makan', 'Bensin'])
        AppSwipeActions(onDelete: () {}, child: ListTile(title: Text(name))),
      const SizedBox(height: 2000),
    ])));
  }

  testWidgets('membuka baris lain menutup baris yang sedang terbuka', (tester) async {
    await pumpList(tester);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Makan')).dx, lessThan(0));
    await tester.drag(find.text('Bensin'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Bensin')).dx, lessThan(0));
    expect(tester.getTopLeft(find.byType(ListTile).first).dx, 0);
  });

  testWidgets('scroll list menutup baris yang terbuka', (tester) async {
    await pumpList(tester);
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ListTile).first).dx, lessThan(0));
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ListTile).first).dx, 0);
  });

  testWidgets('deleteConfirmTitle & deleteConfirmMessage tampil di dialog hapus', (tester) async {
    var deleted = false;
    await pumpApp(
      tester,
      Scaffold(
        body: AppSwipeActions(
          deleteConfirmTitle: 'Hapus Transaksi?',
          deleteConfirmMessage: 'Data transaksi akan dihapus permanen.',
          onDelete: () => deleted = true,
          child: const SizedBox(height: 56, width: 390, child: Text('Makan')),
        ),
      ),
    );
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    expect(find.text('Data transaksi akan dihapus permanen.'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
