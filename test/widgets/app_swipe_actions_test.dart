import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
}
