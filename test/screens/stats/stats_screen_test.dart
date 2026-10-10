import 'package:arthava/providers/stats_provider.dart';
import 'package:arthava/screens/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _fakes = <FakeStatsNotifier>[];

class FakeStatsNotifier extends StatsNotifier {
  FakeStatsNotifier(this.seed) {
    _fakes.add(this);
  }

  final StatsState seed;
  final isExpenseCalls = <bool>[];

  @override
  StatsState build() => seed;

  @override
  void setIsExpense(bool isExpense) {
    isExpenseCalls.add(isExpense);
    state = state.copyWith(isExpense: isExpense);
  }
}

StatsState _seed({bool isLoading = false, List<Map<String, dynamic>>? data}) => StatsState(
      isLoading: isLoading,
      isExpense: true,
      selectedDate: DateTime(2026, 9, 24),
      totalAmount: 1000000,
      dailyAverage: 130000,
      highestTransaction: const {'amount': 500000.0, 'name': 'Kos', 'note': 'Bayar kos', 'date': '2026-09-01'},
      walletNames: const {1: 'BCA'},
      walletColors: const {1: Color(0xFF4A6CF7)},
      categoryData: data ??
          [
            {
              'name': 'Tempat Tinggal',
              'amount': 500000.0,
              'count': 1,
              'transactions': [
                {'note': 'Bayar kos', 'date': '2026-09-01', 'wallet_id': 1, 'amount': 500000},
              ],
            },
            {
              'name': 'Makan',
              'amount': 300000.0,
              'count': 2,
              'transactions': [
                {'note': 'Nasi Padang [SAVING_ID:3]', 'date': '2026-09-24', 'wallet_id': 1, 'amount': 150000},
                {'note': '', 'date': '2026-09-23', 'wallet_id': 99, 'amount': 150000},
              ],
            },
            {'name': 'Transportasi', 'amount': 200000.0, 'count': 3, 'transactions': []},
          ],
    );

Future<void> _pump(WidgetTester tester, StatsState seed) async {
  _fakes.clear();
  await pumpApp(tester, const StatsScreen(),
      overrides: [statsProvider.overrideWith(() => FakeStatsNotifier(seed))]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan judul, kontrol, ringkasan, dan grup kategori', (tester) async {
    await _pump(tester, _seed());
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Total Pengeluaran'), findsOneWidget);
    expect(find.text('Rata-rata harian'), findsOneWidget);
    expect(find.text('Terbesar (Bayar kos)'), findsOneWidget);
    expect(find.text('KATEGORI'), findsOneWidget);
    expect(find.text('Tempat Tinggal'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // badge peringkat
  });

  testWidgets('baris kategori bisa di-expand menampilkan transaksi', (tester) async {
    await _pump(tester, _seed());
    expect(find.text('Nasi Padang'), findsNothing);
    await tester.tap(find.text('Makan'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Padang'), findsOneWidget);
    expect(find.text('Tanpa catatan'), findsOneWidget);
    expect(find.text('Kas Utama'), findsOneWidget);
    expect(find.textContaining('SAVING_ID'), findsNothing);
  });

  testWidgets('segmented memanggil setIsExpense', (tester) async {
    await _pump(tester, _seed());
    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(_fakes.single.isExpenseCalls, [false]);
  });

  testWidgets('empty dan loading', (tester) async {
    await _pump(tester, _seed(data: []));
    expect(find.text('Tidak ada data'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);

    // Buang pohon lama dulu: ProviderScope yang sama tidak menerima override notifier baru.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, const StatsScreen(),
        overrides: [statsProvider.overrideWith(() => FakeStatsNotifier(_seed(isLoading: true)))]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('geser layar pindah Pengeluaran → Pemasukan', (tester) async {
    await _pump(tester, _seed());
    await tester.timedDrag(find.text('Statistik'), const Offset(250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(_fakes.single.isExpenseCalls, [false]);
  });
}
