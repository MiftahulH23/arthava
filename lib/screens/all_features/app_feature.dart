import 'package:arthava/core/colors.dart';
import 'package:arthava/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:arthava/screens/budget/budget_screen.dart';
import 'package:arthava/screens/calendar/calendar_screen.dart';
import 'package:arthava/screens/debt/debt_screen.dart';
import 'package:arthava/screens/export/export_screen.dart';
import 'package:arthava/screens/investment/investment_screen.dart';
import 'package:arthava/screens/manage_category/manage_category_screen.dart';
import 'package:arthava/screens/recurring/recurring_screen.dart';
import 'package:arthava/screens/savings/savings_screen.dart';
import 'package:arthava/screens/target/target_screen.dart';
import 'package:arthava/screens/wallet/wallet_screen.dart';
import 'package:arthava/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum AppFeatureGroup {
  harian('Harian'),
  perencanaan('Perencanaan'),
  asetKewajiban('Aset & Kewajiban'),
  alat('Alat');

  const AppFeatureGroup(this.label);
  final String label;
}

/// Refresh Beranda yang dijalankan setelah layar fitur ditutup — dipindahkan
/// persis dari callback grid Beranda lama (lihat tabel di Plan B3 Task 4), kecuali
/// Anggaran & Target yang kini me-refresh karena Beranda punya kartu ringkasannya.
enum HomeRefreshAfter { none, homeData, homeDataAndTabs }

enum AppFeature {
  wallet('Dompet', PhosphorIconsFill.wallet, AppColors.tintBrown, AppFeatureGroup.harian, HomeRefreshAfter.homeData),
  calendar('Kalender', PhosphorIconsFill.calendar, AppColors.tintPink, AppFeatureGroup.harian, HomeRefreshAfter.none),
  category('Kategori', PhosphorIconsFill.squaresFour, AppColors.tintOrange, AppFeatureGroup.harian, HomeRefreshAfter.none),
  budget('Anggaran', PhosphorIconsFill.chartDonut, AppColors.tintIndigo, AppFeatureGroup.perencanaan, HomeRefreshAfter.homeData),
  target('Target Keuangan', PhosphorIconsFill.target, AppColors.tintGreen, AppFeatureGroup.perencanaan, HomeRefreshAfter.homeData),
  savings('Buku Tabungan', PhosphorIconsFill.piggyBank, AppColors.tintTeal, AppFeatureGroup.perencanaan, HomeRefreshAfter.homeDataAndTabs),
  recurring('Tagihan & Pemasukan Rutin', PhosphorIconsFill.calendarPlus, AppColors.tintRed, AppFeatureGroup.perencanaan, HomeRefreshAfter.homeDataAndTabs),
  investment('Investasi', PhosphorIconsFill.chartLineUp, AppColors.tintAmber, AppFeatureGroup.asetKewajiban, HomeRefreshAfter.homeData),
  debt('Utang & Piutang', PhosphorIconsFill.handCoins, AppColors.tintSky, AppFeatureGroup.asetKewajiban, HomeRefreshAfter.homeDataAndTabs),
  zakat('Zakat & Sedekah', PhosphorIconsFill.handHeart, AppColors.tintGreen, AppFeatureGroup.asetKewajiban, HomeRefreshAfter.homeData),
  aiAdvisor('AI Advisor', PhosphorIconsFill.robot, AppColors.tintIndigo, AppFeatureGroup.alat, HomeRefreshAfter.none),
  exportReport('Export Laporan', PhosphorIconsFill.filePdf, AppColors.tintBlue, AppFeatureGroup.alat, HomeRefreshAfter.none);

  const AppFeature(this.label, this.icon, this.color, this.group, this.refreshAfter);

  final String label;
  final IconData icon;
  final Color color;
  final AppFeatureGroup group;
  final HomeRefreshAfter refreshAfter;

  Widget buildScreen() => switch (this) {
        AppFeature.wallet => const WalletScreen(),
        AppFeature.calendar => const CalendarScreen(),
        AppFeature.category => const ManageCategoryScreen(),
        AppFeature.budget => const BudgetScreen(),
        AppFeature.target => const TargetScreen(),
        AppFeature.savings => const SavingsScreen(),
        AppFeature.recurring => const RecurringScreen(),
        AppFeature.investment => const InvestmentScreen(),
        AppFeature.debt => const DebtScreen(),
        AppFeature.zakat => const ZakatSedekahScreen(),
        AppFeature.aiAdvisor => const AiAdvisorScreen(),
        AppFeature.exportReport => const ExportScreen(),
      };
}

/// Fitur per grup yang labelnya mengandung [query] (tanpa peka huruf besar/kecil).
/// Grup tanpa hasil tidak disertakan; urutan grup & fitur mengikuti deklarasi enum.
Map<AppFeatureGroup, List<AppFeature>> filterFeatures(String query) {
  final q = query.trim().toLowerCase();
  final result = <AppFeatureGroup, List<AppFeature>>{};
  for (final group in AppFeatureGroup.values) {
    final items = AppFeature.values
        .where((f) => f.group == group && (q.isEmpty || f.label.toLowerCase().contains(q)))
        .toList();
    if (items.isNotEmpty) result[group] = items;
  }
  return result;
}
