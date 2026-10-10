import 'package:arthava/models/wallet_model.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:arthava/screens/wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeWallets extends WalletNotifier {
  final transfers = <(int, int, double)>[];

  @override
  WalletState build() => WalletState(isLoading: false, wallets: [
        WalletModel(id: 1, userId: 'u', name: 'A', balance: 100000, color: '#1E3A8A'),
        WalletModel(id: 2, userId: 'u', name: 'B', balance: 50000, color: '#E65100'),
      ]);

  @override
  Future<void> fetchWallets() async {}

  @override
  Future<void> transfer({required int sourceId, required int destId, required double amount}) async =>
      transfers.add((sourceId, destId, amount));
}

Future<_FakeWallets> _openTransfer(WidgetTester tester) async {
  final fake = _FakeWallets();
  await pumpApp(tester, const WalletScreen(), overrides: [walletProvider.overrideWith(() => fake)], size: const Size(390, 1400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transfer'));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _send(WidgetTester tester, String amount) async {
  await tester.enterText(find.byType(TextField).last, amount);
  await tester.tap(find.text('Transfer Sekarang'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('tombol tukar membalik sumber dan tujuan', (tester) async {
    final fake = await _openTransfer(tester);
    await tester.tap(find.byTooltip('Tukar arah'));
    await tester.pumpAndSettle();
    await _send(tester, '10000');
    expect(fake.transfers, [(2, 1, 10000.0)]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('memilih sumber = tujuan menukar kedua sisi, tanpa pesan error', (tester) async {
    final fake = await _openTransfer(tester);
    await tester.tap(find.text('Dari Dompet (Sumber)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    expect(find.text('Dompet asal dan tujuan tidak boleh sama!'), findsNothing);
    await _send(tester, '10000');
    expect(fake.transfers, [(2, 1, 10000.0)]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });


  testWidgets('satu dompet: Transfer tetap ada dan menawarkan membuat dompet kedua', (tester) async {
    final fake = _OneWallet();
    await pumpApp(tester, const WalletScreen(), overrides: [walletProvider.overrideWith(() => fake)], size: const Size(390, 1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Butuh 2 dompet'), findsOneWidget);
    expect(find.text('Buat Dompet'), findsOneWidget);
  });
}

class _OneWallet extends WalletNotifier {
  @override
  WalletState build() => WalletState(isLoading: false, wallets: [
        WalletModel(id: 1, userId: 'u', name: 'A', balance: 100000, color: '#1E3A8A'),
      ]);

  @override
  Future<void> fetchWallets() async {}
}
