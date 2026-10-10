import 'package:arthava/widgets/app_wallet_select_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  final wallets = [
    {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#4A6CF7'},
    {'id': 2, 'name': 'GoPay', 'balance': 1850000, 'color': '#F0913A'},
  ];

  testWidgets('menampilkan dompet terpilih beserta saldonya', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: AppWalletSelectRow(header: 'Sumber Dana', wallets: wallets, selectedId: 1, onChanged: (_) {})),
    );
    expect(find.text('SUMBER DANA'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Rp 9.300.000'), findsOneWidget);
  });

  testWidgets('menampilkan label kosong bila belum ada dompet', (tester) async {
    await pumpApp(tester, Scaffold(body: AppWalletSelectRow(wallets: const [], selectedId: null, onChanged: (_) {})));
    expect(find.text('Belum ada dompet'), findsOneWidget);
  });

  testWidgets('ketuk baris membuka pemilih dan memilih dompet lain', (tester) async {
    int? picked;
    await pumpApp(
      tester,
      Scaffold(body: AppWalletSelectRow(wallets: wallets, selectedId: 1, onChanged: (v) => picked = v)),
    );
    await tester.tap(find.text('BCA'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Dompet'), findsOneWidget);
    await tester.tap(find.text('GoPay').last);
    await tester.pumpAndSettle();
    expect(picked, 2);
  });

  testWidgets('onCreate tanpa dompet: "Buat Dompet" memanggil onCreate dan memilih hasilnya', (tester) async {
    int? picked;
    await pumpApp(
      tester,
      Scaffold(
        body: AppWalletSelectRow(
          wallets: const [],
          selectedId: null,
          onChanged: (v) => picked = v,
          onCreate: () async => 7,
        ),
      ),
    );
    expect(find.text('Buat Dompet'), findsOneWidget);
    await tester.tap(find.text('Buat Dompet'));
    await tester.pumpAndSettle();
    expect(picked, 7);
  });
}
