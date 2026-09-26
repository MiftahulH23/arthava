import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppSelectRow menampilkan placeholder saat value null', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Kategori',
          placeholder: 'Pilih Kategori Pengeluaran',
          value: null,
          options: const [AppSelectOption(1, 'Makan'), AppSelectOption(2, 'Belanja')],
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Pilih Kategori Pengeluaran'), findsOneWidget);
  });

  testWidgets('AppSelectRow membuka sheet pemilih dan memanggil onChanged', (tester) async {
    int? picked;
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Kategori',
          value: 1,
          options: const [AppSelectOption(1, 'Makan'), AppSelectOption(2, 'Belanja')],
          onChanged: (v) => picked = v,
        ),
      ),
    );
    expect(find.text('Makan'), findsOneWidget);

    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    // Sheet bawah bergaya G17: header "Batal" + judul baris.
    expect(find.text('Batal'), findsOneWidget);
    await tester.tap(find.text('Belanja').last);
    await tester.pumpAndSettle();

    expect(picked, 2);
    expect(find.text('Batal'), findsNothing);
  });

  testWidgets('AppSelectRow: Batal tidak mengubah pilihan', (tester) async {
    var calls = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Kategori',
          value: 1,
          options: const [AppSelectOption(1, 'Makan'), AppSelectOption(2, 'Belanja')],
          onChanged: (_) => calls++,
        ),
      ),
    );
    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('AppSelectRow tanpa opsi tidak membuka sheet', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Dompet',
          placeholder: 'Belum ada dompet',
          value: null,
          options: const [],
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    expect(find.text('Batal'), findsNothing);
  });

  testWidgets('AppSelectRow dengan lebih dari 8 opsi menampilkan kolom cari', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Kategori',
          value: null,
          options: [for (var i = 0; i < 10; i++) AppSelectOption(i, 'Kategori $i')],
          onChanged: (_) {},
        ),
      ),
      size: const Size(390, 1400),
    );
    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shortLabel tampil di baris; label lengkap tetap di sheet pemilih', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSelectRow<int>(
          title: 'Dompet',
          value: 1,
          options: const [AppSelectOption(1, 'BCA (Sisa: Rp 9.300.000)', shortLabel: 'BCA')],
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('BCA (Sisa: Rp 9.300.000)'), findsNothing);
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    expect(find.text('BCA (Sisa: Rp 9.300.000)'), findsOneWidget);
  });
}
