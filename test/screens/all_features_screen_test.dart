import 'package:catat_uang_app/screens/all_features/all_features_screen.dart';
import 'package:catat_uang_app/screens/all_features/app_feature.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('filterFeatures: kosong = 4 grup berisi 12 fitur', () {
    final g = filterFeatures('');
    expect(g.keys, AppFeatureGroup.values);
    expect(g.values.expand((e) => e).length, 12);
    expect(g[AppFeatureGroup.harian], [AppFeature.wallet, AppFeature.calendar, AppFeature.category]);
  });

  test('filterFeatures: tidak peka huruf besar/kecil, grup kosong disembunyikan', () {
    final g = filterFeatures('  TABUNG ');
    expect(g.keys, [AppFeatureGroup.perencanaan]);
    expect(g[AppFeatureGroup.perencanaan], [AppFeature.savings]);
    expect(filterFeatures('xyz'), isEmpty);
  });

  test('refreshAfter sesuai tabel grid lama + kartu ringkasan', () {
    expect(AppFeature.recurring.refreshAfter, HomeRefreshAfter.homeDataAndTabs);
    expect(AppFeature.savings.refreshAfter, HomeRefreshAfter.homeDataAndTabs);
    expect(AppFeature.debt.refreshAfter, HomeRefreshAfter.homeDataAndTabs);
    expect(AppFeature.wallet.refreshAfter, HomeRefreshAfter.homeData);
    expect(AppFeature.investment.refreshAfter, HomeRefreshAfter.homeData);
    expect(AppFeature.zakat.refreshAfter, HomeRefreshAfter.homeData);
    // Baru di B3: kartu ringkasan Anggaran & Target di Beranda harus ikut segar.
    expect(AppFeature.budget.refreshAfter, HomeRefreshAfter.homeData);
    expect(AppFeature.target.refreshAfter, HomeRefreshAfter.homeData);
    for (final f in [AppFeature.category,
        AppFeature.exportReport, AppFeature.aiAdvisor, AppFeature.calendar]) {
      expect(f.refreshAfter, HomeRefreshAfter.none, reason: f.name);
    }
  });

  testWidgets('menampilkan 4 label grup dan 12 baris', (tester) async {
    await pumpApp(tester, AllFeaturesScreen(onOpen: (_) {}), size: const Size(390, 1600));
    expect(find.text('Semua Fitur'), findsOneWidget);
    for (final label in ['HARIAN', 'PERENCANAAN', 'ASET & KEWAJIBAN', 'ALAT']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(AppListRow), findsNWidgets(12));
  });

  testWidgets('cari memfilter baris; tanpa hasil menampilkan empty state', (tester) async {
    await pumpApp(tester, AllFeaturesScreen(onOpen: (_) {}), size: const Size(390, 1600));
    await tester.enterText(find.byType(TextField), 'tabung');
    await tester.pump();
    expect(find.text('Buku Tabungan'), findsOneWidget);
    expect(find.text('Dompet'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Fitur tidak ditemukan'), findsOneWidget);
  });

  testWidgets('ketuk baris memanggil onOpen dengan fitur yang benar', (tester) async {
    final opened = <AppFeature>[];
    await pumpApp(tester, AllFeaturesScreen(onOpen: opened.add), size: const Size(390, 1600));
    await tester.tap(find.text('Kalender'));
    await tester.pump();
    expect(opened, [AppFeature.calendar]);
  });
}
