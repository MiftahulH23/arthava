import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_filter_sheet.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_period_picker.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:catat_uang_app/widgets/app_swipe_tabs.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  static const List<Color> _chartColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.tintSky,
    AppColors.tintPink,
    AppColors.tintIndigo,
    AppColors.tintTeal,
    AppColors.tintAmber,
    AppColors.tintBrown,
  ];

  int _touchedIndex = -1;

  StatsNotifier get _notifier => ref.read(statsProvider.notifier);

  void _pickDate(StatsState state) {
    showAppPeriodPicker(
      context: context,
      filterType: state.filterType,
      selectedDate: state.selectedDate,
      selectedDateRange: state.selectedDateRange,
      onDateSelected: _notifier.setSelectedDate,
      onRangeSelected: _notifier.setSelectedDateRange,
    );
  }

  void _showFilterSheet() {
    final isExpense = ref.read(statsProvider).isExpense;
    showTransactionFilterSheet(
      context: context,
      accentColor: isExpense ? AppColors.expense : AppColors.income,
      readData: () {
        final s = ref.read(statsProvider);
        return TransactionFilterData(
          categories: s.categories,
          walletNames: s.walletNames,
          selectedCategoryIds: s.selectedCategoryIds,
          selectedWalletIds: s.selectedWalletIds,
        );
      },
      onToggleCategory: _notifier.toggleCategoryFilter,
      onToggleWallet: _notifier.toggleWalletFilter,
      onReset: _notifier.resetFilters,
      onApply: _notifier.applyFilters,
    );
  }

  List<PieChartSectionData> _buildSections(StatsState state) {
    final sections = <PieChartSectionData>[];
    double otherAmount = 0;
    int currentIndex = 0;
    for (int i = 0; i < state.categoryData.length; i++) {
      final item = state.categoryData[i];
      final percentage = (item['amount'] / state.totalAmount) * 100;

      if (i < 5 && percentage >= 2) {
        final isTouched = currentIndex == _touchedIndex;
        sections.add(
          PieChartSectionData(
            color: _chartColors[i % _chartColors.length],
            value: item['amount'],
            title: isTouched
                ? '${item['name']}\n${percentage.toStringAsFixed(1)}%'
                : '${percentage.toStringAsFixed(0)}%',
            radius: isTouched ? 40 : 32,
            titleStyle: AppTextStyles.caption.copyWith(
              fontSize: isTouched ? 11 : 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: isTouched ? const [Shadow(color: Colors.black45, blurRadius: 2)] : null,
            ),
          ),
        );
        currentIndex++;
      } else {
        otherAmount += (item['amount'] as num).toDouble();
      }
    }

    if (otherAmount > 0) {
      final otherPercentage = (otherAmount / state.totalAmount) * 100;
      final isTouched = currentIndex == _touchedIndex;
      final remainingCount = state.categoryData.length - currentIndex;
      final labelText = "Gabungan\n($remainingCount)";
      sections.add(
        PieChartSectionData(
          color: AppColors.tintGray,
          value: otherAmount,
          title: isTouched
              ? '$labelText\n${otherPercentage.toStringAsFixed(1)}%'
              : '${otherPercentage.toStringAsFixed(0)}%\n$labelText',
          radius: isTouched ? 40 : 32,
          titleStyle: AppTextStyles.caption.copyWith(
            fontSize: isTouched ? 10 : 8,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: isTouched ? const [Shadow(color: Colors.black45, blurRadius: 2)] : null,
          ),
        ),
      );
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsProvider);
    final activeColor = state.isExpense ? AppColors.expense : AppColors.income;
    final activeFilterCount = state.selectedCategoryIds.length + state.selectedWalletIds.length;

    return AppSwipeTabs(
      index: state.isExpense ? 1 : 0,
      count: 2,
      onChanged: (i) => _notifier.setIsExpense(i == 1),
      child: AppPageScaffold(
        embedded: true,
        title: 'Statistik',
        children: [
          AppSegmentedControl(
            labels: const ['Pemasukan', 'Pengeluaran'],
            selectedIndex: state.isExpense ? 1 : 0,
            selectedLabelColors: const [AppColors.income, AppColors.expense],
            onChanged: (i) => _notifier.setIsExpense(i == 1),
          ),
          AppChipTabs(
            labels: kPeriodFilterTypes,
            selectedIndex: kPeriodFilterTypes.indexOf(state.filterType),
            onChanged: (index) => _notifier.setFilterType(kPeriodFilterTypes[index]),
          ),
          Row(
            children: [
              Expanded(
                child: AppPill(
                  expand: true,
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: periodLabel(state.filterType, state.selectedDate, state.selectedDateRange),
                  trailing: const Icon(PhosphorIconsRegular.caretDown, size: 14, color: AppColors.textSecondary),
                  onTap: () => _pickDate(state),
                ),
              ),
              const SizedBox(width: 8),
              AppPill(
                icon: PhosphorIconsRegular.funnel,
                label: 'Filter',
                badgeCount: activeFilterCount,
                onTap: _showFilterSheet,
              ),
            ],
          ),
          AppSwipeTabBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (state.categoryData.isEmpty)
                  const AppEmptyState(icon: PhosphorIconsRegular.chartPieSlice, title: 'Tidak ada data')
                else ...[
                  AppSurfaceCard(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 148,
                          height: 148,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (event is FlTapUpEvent) {
                                          if (pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection == null ||
                                              pieTouchResponse.touchedSection!.touchedSectionIndex == -1) {
                                            _touchedIndex = -1;
                                          } else {
                                            final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                            _touchedIndex = _touchedIndex == newIndex ? -1 : newIndex;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: _buildSections(state),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Total", style: AppTextStyles.caption),
                                  Text(
                                    formatRupiahCompact(state.totalAmount),
                                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StatLine(
                                label: "Total ${state.isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                                value: formatRupiah(state.totalAmount),
                                valueColor: activeColor,
                              ),
                              if (state.totalAmount > 0) ...[
                                const SizedBox(height: 12),
                                _StatLine(label: "Rata-rata harian", value: formatRupiah(state.dailyAverage)),
                                if (state.highestTransaction != null) ...[
                                  const SizedBox(height: 12),
                                  _StatLine(
                                    label: "Terbesar (${state.highestTransaction!['note']})",
                                    value: formatRupiah(state.highestTransaction!['amount'] as num),
                                    valueColor: activeColor,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppGroupedSection(
                    header: 'Kategori',
                    children: [
                      for (var i = 0; i < state.categoryData.length; i++)
                        _CategoryRankRow(
                          rank: i + 1,
                          color: _chartColors[i % _chartColors.length],
                          item: state.categoryData[i],
                          totalAmount: state.totalAmount,
                          walletNames: state.walletNames,
                          walletColors: state.walletColors,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.amountRow.copyWith(color: valueColor ?? AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.14), AppColors.surface),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: AppTextStyles.bodyStrong.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CategoryRankRow extends StatefulWidget {
  const _CategoryRankRow({
    required this.rank,
    required this.color,
    required this.item,
    required this.totalAmount,
    required this.walletNames,
    required this.walletColors,
  });

  final int rank;
  final Color color;
  final Map<String, dynamic> item;
  final double totalAmount;
  final Map<int, String> walletNames;
  final Map<int, Color> walletColors;

  @override
  State<_CategoryRankRow> createState() => _CategoryRankRowState();
}

class _CategoryRankRowState extends State<_CategoryRankRow> {
  // Tag [SAVING_ID:..] / [DEBT_ID:..] dibersihkan lewat stripTransactionTags (lib/core/transaction_tags.dart, Plan B2).
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amount = (item['amount'] as num).toDouble();
    final percentage = widget.totalAmount == 0 ? 0.0 : (amount / widget.totalAmount) * 100;
    final transactions = item['transactions'] as List;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListRow(
          leading: _RankBadge(rank: widget.rank, color: widget.color),
          title: item['name'].toString(),
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: "${item['count']} Transaksi · "),
                    TextSpan(
                      text: "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(color: widget.color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 6),
              AppProgressBar(value: percentage / 100, color: widget.color, height: 6),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatRupiah(amount), style: AppTextStyles.amountRow),
              const SizedBox(width: 4),
              Icon(
                _expanded ? PhosphorIconsRegular.caretUp : PhosphorIconsRegular.caretDown,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(children: [for (final t in transactions) _buildTransactionLine(t as Map<String, dynamic>)]),
          ),
      ],
    );
  }

  Widget _buildTransactionLine(Map<String, dynamic> t) {
    final wId = t['wallet_id'];
    final wName = widget.walletNames[wId] ?? 'Kas Utama';
    final wColor = widget.walletColors[wId] ?? AppColors.tintGray;
    final cleanNote = stripTransactionTags(t['note']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanNote.isNotEmpty ? cleanNote : 'Tanpa catatan',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(DateFormat('dd MMM yyyy').format(DateTime.parse(t['date'])), style: AppTextStyles.caption),
                    const SizedBox(width: 8),
                    // Flexible: nama dompet panjang terpotong "…", bukan meluap.
                    Flexible(
                      child: AppChip(label: wName, color: wColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Text(formatRupiah((t['amount'] as num).toDouble()), style: AppTextStyles.amountRow),
        ],
      ),
    );
  }
}
