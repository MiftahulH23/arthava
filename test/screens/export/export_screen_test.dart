import 'package:catat_uang_app/screens/export/export_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/pump_app.dart';

// Seam: _supabase adalah getter dan hanya dipakai di _generatePdf, jadi
// layar bisa di-render tanpa Supabase. Tombol cetak tidak diketuk di test.
void main() {
  testWidgets('mode Satu Bulan menampilkan bulan berjalan', (tester) async {
    await pumpApp(tester, const ExportScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Export Laporan'), findsOneWidget);
    expect(find.text('Cetak Laporan Keuangan'), findsOneWidget);
    expect(find.text('Bulan Laporan'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())), findsOneWidget);
    expect(find.text('Cetak Laporan PDF'), findsOneWidget);
  });

  testWidgets('mode Pilih Tanggal menampilkan rentang awal bulan s/d hari ini', (tester) async {
    await pumpApp(tester, const ExportScreen());
    await tester.pump();

    await tester.tap(find.text('Pilih Tanggal'));
    await tester.pump();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final label =
        "${DateFormat('dd MMM yy', 'id_ID').format(start)} - ${DateFormat('dd MMM yy', 'id_ID').format(now)}";
    expect(find.text('Rentang Tanggal'), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    expect(find.text('Bulan Laporan'), findsNothing);
  });

  testWidgets('memilih bulan di dialog mengganti nilai baris', (tester) async {
    await pumpApp(tester, const ExportScreen());
    await tester.pump();

    await tester.tap(find.text('Bulan Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Periode'), findsOneWidget);

    await tester.tap(find.text('Jan'));
    await tester.pump();
    await tester.tap(find.text('Pilih')); // pemilih bersama (Plan B3b): ketuk bulan, lalu "Pilih"
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('MMMM yyyy', 'id_ID').format(DateTime(DateTime.now().year, 1))), findsOneWidget);
  });
}
