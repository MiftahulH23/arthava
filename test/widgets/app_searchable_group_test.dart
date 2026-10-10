import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_searchable_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Future<void> _pump(WidgetTester tester, List<String> items) {
  return pumpApp(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: AppSearchableGroup<String>(
          items: items,
          searchText: (s) => s,
          hint: 'Cari kategori',
          rowBuilder: (context, s) => AppListRow(title: s),
        ),
      ),
    ),
    size: const Size(390, 3000),
  );
}

void main() {
  const few = ['Makan', 'Transportasi', 'Belanja', 'Tagihan', 'Hiburan', 'Kesehatan', 'Kopi', 'Pulsa'];
  final many = [...few, 'Donasi', 'Olahraga', 'Pendidikan Anak'];

  testWidgets('8 item atau kurang: tanpa kolom cari, semua baris tampil', (tester) async {
    await _pump(tester, few);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AppListRow), findsNWidgets(8));
  });

  testWidgets('lebih dari 8: kolom cari muncul dan menyaring tanpa peka huruf besar', (tester) async {
    await _pump(tester, many);
    expect(find.text('Cari kategori'), findsOneWidget);
    expect(find.byType(AppListRow), findsNWidgets(11));
    await tester.enterText(find.byType(TextField), 'pEnDi');
    await tester.pump();
    expect(find.byType(AppListRow), findsOneWidget);
    expect(find.text('Pendidikan Anak'), findsOneWidget);
  });

  testWidgets('tidak ada yang cocok: pesan Tidak ditemukan', (tester) async {
    await _pump(tester, many);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.byType(AppListRow), findsNothing);
    expect(find.text('Tidak ditemukan'), findsOneWidget);
  });
}
