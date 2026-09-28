import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class FakeHomeNotifier extends HomeNotifier {
  FakeHomeNotifier(this.fixed);
  final HomeState fixed;

  @override
  HomeState build() => fixed;
}

WalletModel wallet(int id, String name, double balance, {bool fav = false, double min = 0}) =>
    WalletModel(id: id, userId: 'u', name: name, balance: balance, color: '#1E3A8A', isFavorite: fav, minBalance: min);

Future<void> pumpHome(WidgetTester tester, HomeState state) {
  return pumpApp(
    tester,
    const HomeScreen(),
    overrides: [homeProvider.overrideWith(() => FakeHomeNotifier(state))],
    size: const Size(390, 1800),
  );
}

void main() {
  testWidgets('menampilkan 3 dompet saldo terbesar + Lihat semua, tanpa grid menu lama', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        userName: 'Akun Tes',
        wallets: [
          wallet(1, 'BCA', 9300000),
          wallet(2, 'GoPay', 1850000),
          wallet(3, 'Tunai', 1300000),
          wallet(4, 'Jago', 750000),
          wallet(5, 'Dana', 10000),
        ],
      ),
    );
    expect(find.text('Halo, Bos!'), findsOneWidget);
    expect(find.text('AT'), findsOneWidget);
    expect(find.text('DOMPET'), findsOneWidget);
    expect(find.text('Kelola'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('Jago'), findsNothing);
    expect(find.text('Lihat semua (5 dompet)'), findsOneWidget);
    expect(find.text('Semua Fitur'), findsOneWidget);
    expect(find.text('AI Advisor'), findsNothing); // grid 12 menu sudah hilang
  });

  testWidgets('ringkasan kosong menampilkan empty state tiap kartu', (tester) async {
    await pumpHome(tester, HomeState(isLoading: false, wallets: [wallet(1, 'BCA', 100)]));
    expect(find.text('RINGKASAN'), findsOneWidget);
    expect(find.text('Belum ada anggaran'), findsOneWidget);
    expect(find.text('Belum ada target'), findsOneWidget);
    expect(find.text('Tidak ada tagihan'), findsOneWidget);
    expect(find.text('Bebas utang'), findsOneWidget);
  });

  testWidgets('tanpa dompet: baris Buat Dompet Pertama dan total Rp 0', (tester) async {
    await pumpHome(tester, const HomeState(isLoading: false));
    expect(find.text('Buat Dompet Pertama'), findsOneWidget);
    expect(find.textContaining('Lihat semua'), findsNothing);
    expect(find.text('Rp 0'), findsWidgets);
  });

  testWidgets('pengaturan saldo minimal nonaktif: total & baris memakai uang yang bisa dipakai', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        includeMinBalance: false,
        wallets: [wallet(1, 'BCA', 1000000, min: 250000), wallet(2, 'GoPay', 400000)],
      ),
    );
    expect(find.text('Rp 1.150.000'), findsOneWidget); // 750.000 + 400.000
    expect(find.text('Sudah dikurangi saldo minimal'), findsOneWidget);
    // Spasi tak-putus: "Rp" tidak terpisah dari angkanya saat baris membungkus.
    expect(find.text('Bisa dipakai Rp 750.000'), findsOneWidget);
  });

  testWidgets('kartu ringkasan menampilkan data yang dipilih', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        wallets: [wallet(1, 'BCA', 100)],
        summary: const HomeSummary(budget: BudgetSummary(totalSpent: 3480000, totalBudget: 5000000)),
      ),
    );
    expect(find.text('Rp 3,5 jt'), findsOneWidget);
    expect(find.text('dari Rp 5 jt bulan ini'), findsOneWidget);
  });

  testWidgets('layout web: menampilkan grup Semua Fitur langsung, tanpa grid Menu & Fitur', (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: [
        homeProvider.overrideWith(
          () => FakeHomeNotifier(HomeState(isLoading: false, wallets: [wallet(1, 'BCA', 100)])),
        ),
      ],
      size: const Size(1280, 2400),
    );
    expect(find.text('Menu & Fitur'), findsNothing);
    expect(find.text('Semua Fitur'), findsOneWidget);
    expect(find.text('PERENCANAAN'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget); // label NavigationRail
  });

  testWidgets('kartu Tagihan tanpa kategori memakai catatan', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        wallets: [wallet(1, 'BCA', 100)],
        summary: HomeSummary(
          nextBill: RecurringTransactionModel(
            id: 1,
            userId: 'u',
            categoryId: 3,
            amount: 150000,
            note: 'Internet rumah',
            frequency: 'monthly',
            startDate: DateTime(2026, 9, 1),
            nextRunDate: DateTime(2026, 10, 1),
            isActive: true,
          ),
        ),
      ),
    );
    expect(find.text('Internet rumah'), findsOneWidget);
  });

  testWidgets('layout web: di ujung scroll, baris terakhir tidak tertutup tombol Tambah Transaksi', (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: [
        homeProvider.overrideWith(
          () => FakeHomeNotifier(HomeState(isLoading: false, wallets: [wallet(1, 'BCA', 100)])),
        ),
      ],
      size: const Size(1280, 900),
    );
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final lastRow = tester.getRect(find.ancestor(of: find.text('Export Laporan'), matching: find.byType(AppListRow)));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(lastRow.bottom + 16, lessThanOrEqualTo(fab.top));
  });

  testWidgets('tagihan tertahan tampil sebagai pemberitahuan di Beranda', (tester) async {
    await pumpHome(
      tester,
      HomeState(
        isLoading: false,
        wallets: [wallet(1, 'BCA', 5000)],
        summary: HomeSummary(
          blockedBills: [
            RecurringTransactionModel(
              id: 4,
              userId: 'u',
              categoryId: 3,
              amount: 1500000,
              note: 'Bayar Kos',
              frequency: 'Bulanan',
              startDate: DateTime(2026, 9, 1),
              nextRunDate: DateTime(2026, 9, 1),
              isActive: true,
              blockedReason: 'Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000',
            ),
          ],
        ),
      ),
    );
    expect(find.text('Tagihan Bayar Kos belum terbayar'), findsOneWidget);
    expect(find.text('Saldo dompet BCA tidak cukup! Bisa dipakai: Rp 5.000'), findsOneWidget);
  });
}
