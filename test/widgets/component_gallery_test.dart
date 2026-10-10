import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/widgets/app_amount_display.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_callout.dart';
import 'package:arthava/widgets/app_chip.dart';
import 'package:arthava/widgets/app_chip_tabs.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_hero_card.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_progress.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:arthava/widgets/app_summary_widget.dart';
import 'package:arthava/widgets/app_surface_card.dart';
import 'package:arthava/widgets/app_swipe_actions.dart';
import 'package:arthava/widgets/app_switch.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

Widget _gallery(TextEditingController text, TextEditingController amount) {
  return AppPageScaffold(
    title: 'Galeri Komponen',
    backLabel: 'Beranda',
    actions: [AppNavAction.add(onPressed: () {})],
    bottomBar: AppPrimaryButton(label: 'Simpan', onPressed: () {}),
    children: [
      AppHeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppHeroLabel('Total Saldo Keseluruhan'),
          AppHeroAmount(formatRupiah(12450000)),
          const SizedBox(height: 10),
          const AppProgressBar(value: 0.7, color: Colors.white, onDark: true),
        ]),
      ),
      AppSegmentedControl(
        labels: const ['Pemasukan', 'Pengeluaran'],
        selectedIndex: 1,
        selectedLabelColors: const [AppColors.income, AppColors.expense],
        onChanged: (_) {},
      ),
      AppChipTabs(labels: const ['Harian', 'Bulanan', 'Tahunan', 'Periode'], selectedIndex: 1, onChanged: (_) {}),
      const Row(children: [
        Expanded(child: AppPill(label: 'September 2026', icon: PhosphorIconsRegular.calendarBlank, expand: true)),
        SizedBox(width: 8),
        AppPill(label: 'Filter', icon: PhosphorIconsRegular.funnel, badgeCount: 2),
      ]),
      AppGroupedSection(header: 'Dompet', headerAction: 'Kelola', onHeaderAction: () {}, children: [
        const AppListRow(
          leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.tintBlue, filled: true),
          title: 'BCA',
          trailing: Text('Rp 9.300.000'),
        ),
        AppSwipeActions(
          onEdit: () {},
          onDelete: () {},
          child: const AppListRow(
            leading: AppIconTile(icon: PhosphorIconsRegular.forkKnife, color: AppColors.tintOrange),
            title: 'Makan',
            subtitleWidget: AppChip(label: 'BCA', icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue),
            trailing: Text('-Rp 45.000'),
          ),
        ),
        const AppListRow(title: 'Bulan Laporan', value: 'September 2026', showChevron: true),
        AppListRow(title: 'Catat ke Dompet?', trailing: AppSwitch(value: true, onChanged: (_) {})),
      ]),
      const Row(children: [
        Expanded(child: AppSummaryWidget(
          icon: PhosphorIconsRegular.chartPie, label: 'Anggaran', color: AppColors.primary,
          children: [Text('Rp 3,48 jt'), AppProgressBar(value: 0.7, color: AppColors.primary, height: 6)],
        )),
        SizedBox(width: 12),
        Expanded(child: AppSummaryWidget(
          icon: PhosphorIconsRegular.handCoins, label: 'Utang', color: AppColors.expense,
          children: [Text('Budi Santoso'), AppChip(label: 'Terlambat 2 hari', color: AppColors.expense)],
        )),
      ]),
      const AppSurfaceCard(child: Row(children: [
        AppProgressRing(value: 0.82, color: AppColors.tintOrange, size: 90, center: Text('82%')),
        SizedBox(width: 12),
        Expanded(child: AppCallout(
          icon: PhosphorIconsRegular.lightbulb,
          tone: AppCalloutTone.accent,
          child: Text('Nabung Rp 84.000 / hari agar tercapai.'),
        )),
      ])),
      const AppCallout(icon: PhosphorIconsRegular.info, child: Text('Kalkulator Zakat Maal menghitung 2.5%.')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        AppPillButton(label: 'Setor', icon: PhosphorIconsRegular.arrowDown, onPressed: () {}),
        AppPillButton(label: 'Tarik', icon: PhosphorIconsRegular.arrowUp, color: AppColors.tintOrange, onPressed: () {}),
        AppPillButton(label: 'Tambah', filled: true, onPressed: () {}),
      ]),
      AppTextField(controller: text, hint: 'Cari fitur', icon: PhosphorIconsRegular.magnifyingGlass),
      AppAmountField(controller: amount, label: 'Nominal'),
      const AppAmountDisplay(label: 'Jumlah Uang', amountText: 'Rp 2.000.000'),
      const AppEmptyState(icon: PhosphorIconsRegular.receipt, title: 'Tidak ada transaksi'),
    ],
  );
}

void main() {
  for (final size in const [Size(390, 844), Size(360, 740)]) {
    testWidgets('galeri komponen dirender tanpa exception di ${size.width.toInt()}', (tester) async {
      final text = TextEditingController();
      final amount = TextEditingController();
      addTearDown(text.dispose);
      addTearDown(amount.dispose);
      await pumpApp(tester, _gallery(text, amount), size: size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tidak ada transaksi'), findsOneWidget);
    });
  }
}
