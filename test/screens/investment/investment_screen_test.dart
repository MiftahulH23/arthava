import 'package:catat_uang_app/models/investment_model.dart';
import 'package:catat_uang_app/providers/investment_provider.dart';
import 'package:catat_uang_app/screens/investment/investment_screen.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class FakeInvestmentNotifier extends InvestmentNotifier {
  FakeInvestmentNotifier(this.initial);
  final InvestmentState initial;
  final List<String> calls = [];
  Exception? buySellError;

  @override
  InvestmentState build() => initial;

  @override
  Future<void> fetchData({bool showLoading = true}) async => calls.add('fetchData');

  @override
  Future<void> buyInvestment({required String name, required String type, required double amount, required int walletId}) async {
    calls.add('buy:$name:$type:$amount:$walletId');
  }

  @override
  Future<void> buySellInvestment({required InvestmentModel inv, required bool isBuy, required double amount, required int walletId}) async {
    calls.add('buySell:${inv.id}:$isBuy:$amount:$walletId');
    if (buySellError != null) throw buySellError!;
  }

  @override
  Future<void> deleteInvestment(int id) async => calls.add('delete:$id');
}

InvestmentModel _inv(int id, String name, String type, double cap, double val) => InvestmentModel(
      id: id, userId: 'u1', name: name, type: type, capitalAmount: cap, currentValue: val, createdAt: DateTime(2026, 9, 1));

final _wallets = [
  {'id': 1, 'name': 'BCA', 'balance': 9300000, 'color': '#4A6CF7'},
];

InvestmentState _state({List<InvestmentModel>? investments}) {
  // Nilai dipilih supaya persen tepat di 2 desimal (hindari pembulatan float 18.125).
  final invs = investments ?? [_inv(1, 'Saham BBCA', 'Saham', 8000000, 9440000), _inv(2, 'Bitcoin', 'Kripto', 1200000, 1149600)];
  final cap = invs.fold<double>(0, (s, i) => s + i.capitalAmount);
  final val = invs.fold<double>(0, (s, i) => s + i.currentValue);
  return InvestmentState(isLoading: false, investments: invs, wallets: _wallets, totalCapital: cap, totalValue: val);
}

void main() {
  testWidgets('menampilkan hero, portofolio, dan persentase untung/rugi', (tester) async {
    final fake = FakeInvestmentNotifier(_state());
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Investasi'), findsOneWidget);
    expect(find.text('Total Nilai Investasi'), findsOneWidget);
    expect(find.text('Rp 10.589.600'), findsOneWidget); // total nilai
    expect(find.text('Saham BBCA'), findsOneWidget);
    expect(find.text('+18.00%'), findsOneWidget);
    expect(find.text('-4.20%'), findsOneWidget);
  });

  testWidgets('empty state saat belum ada aset', (tester) async {
    final fake = FakeInvestmentNotifier(_state(investments: const []));
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();
    expect(find.text('Belum ada aset investasi.'), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet Investasi Baru dan validasi kolom kosong', (tester) async {
    final fake = FakeInvestmentNotifier(_state());
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();

    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();
    expect(find.text('Investasi Baru'), findsOneWidget);

    await tester.tap(find.text('Beli Aset'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi!'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('buy:')), isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('jual gagal tetap di sheet dan menampilkan pesan', (tester) async {
    final fake = FakeInvestmentNotifier(_state())
      ..buySellError = Exception('Nominal penarikan melebihi nilai aset saat ini!');
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pump();

    await tester.tap(find.text('Saham BBCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jual Aset (Withdraw)'));
    await tester.pumpAndSettle();
    expect(find.text('Jual: Saham BBCA'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(AppAmountField), matching: find.byType(EditableText)),
      '20000000',
    );
    await tester.tap(find.text('Proses Penjualan'));
    await tester.pump();

    expect(fake.calls, contains('buySell:1:false:20000000.0:1'));
    expect(find.text('Nominal penarikan melebihi nilai aset saat ini!'), findsOneWidget);
    expect(find.text('Jual: Saham BBCA'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  Future<FakeInvestmentNotifier> openActions(WidgetTester tester) async {
    final fake = FakeInvestmentNotifier(_state());
    await pumpApp(tester, const InvestmentScreen(), overrides: [investmentProvider.overrideWith(() => fake)]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saham BBCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Portofolio'));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('Hapus Portofolio minta konfirmasi; Batal tidak menghapus', (tester) async {
    final fake = await openActions(tester);
    expect(find.text('Hapus Portofolio?'), findsOneWidget);
    await tester.tap(find.text('Batal').last);
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('delete')), isEmpty);
  });

  testWidgets('Hapus Portofolio dikonfirmasi → deleteInvestment(id)', (tester) async {
    final fake = await openActions(tester);
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(fake.calls, contains('delete:1'));
  });

  testWidgets('subjudul modal tidak memisah "Rp" dari angkanya', (tester) async {
    await pumpApp(tester, const InvestmentScreen(),
        overrides: [investmentProvider.overrideWith(() => FakeInvestmentNotifier(_state()))]);
    await tester.pumpAndSettle();
    expect(find.text('Saham · Modal: Rp 8.000.000'), findsOneWidget);
  });
}
