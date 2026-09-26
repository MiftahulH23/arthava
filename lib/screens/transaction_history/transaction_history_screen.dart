import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/transaction_history_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_filter_sheet.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_grouping.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_chip_tabs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_period_picker.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final bool isExpense;

  /// Widget pemilih Pemasukan/Pengeluaran dari [TransactionsTabScreen],
  /// ditampilkan tepat di bawah judul besar.
  final Widget? typeSwitcher;

  const TransactionHistoryScreen({super.key, required this.isExpense, this.typeSwitcher});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  // Tag [SAVING_ID:..] / [DEBT_ID:..] dibersihkan lewat stripTransactionTags (lib/core/transaction_tags.dart, Plan B2).

  TransactionHistoryNotifier get _notifier =>
      ref.read(transactionHistoryProvider(widget.isExpense).notifier);

  Color get _semanticColor => widget.isExpense ? AppColors.expense : AppColors.income;

  Future<void> _deleteTransaction(TransactionModel trx) async {
    try {
      final message = await _notifier.deleteTransaction(trx);
      if (mounted) {
        AppNotification.success(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, "Gagal menghapus transaksi.");
      }
    }
  }

  void _pickDate(TransactionHistoryState state) {
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
    showTransactionFilterSheet(
      context: context,
      accentColor: _semanticColor,
      readData: () {
        final s = ref.read(transactionHistoryProvider(widget.isExpense));
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

  Future<void> _openTransaction(TransactionModel trx) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InputTransactionScreen(
          initialIsExpense: widget.isExpense,
          transactionToEdit: trx,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _notifier.fetchWallets();
      _notifier.fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider(widget.isExpense));
    final color = _semanticColor;
    final activeFilterCount = state.selectedCategoryIds.length + state.selectedWalletIds.length;

    return AppPageScaffold(
      embedded: true,
      title: 'Transaksi',
      children: [
        if (widget.typeSwitcher != null) widget.typeSwitcher!,
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
        AppSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Real", style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(state.totalAmount),
                      style: AppTextStyles.title.copyWith(color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppIconTile(
                icon: widget.isExpense ? PhosphorIconsBold.trendDown : PhosphorIconsBold.trendUp,
                color: color,
                round: true,
              ),
            ],
          ),
        ),
        ..._buildTransactionList(state),
      ],
    );
  }

  List<Widget> _buildTransactionList(TransactionHistoryState state) {
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    if (state.transactions.isEmpty) {
      return const [
        AppEmptyState(icon: PhosphorIconsRegular.receipt, title: 'Tidak ada transaksi'),
      ];
    }
    return [
      for (final (day, items) in groupTransactionsByDate(state.transactions))
        AppGroupedSection(
          header: DateFormat('EEEE, d MMM', 'id_ID').format(day),
          children: [for (final trx in items) _buildTransactionRow(trx, state)],
        ),
    ];
  }

  Widget _buildTransactionRow(TransactionModel trx, TransactionHistoryState state) {
    // Deteksi tag memakai helper bersama Plan B2 (lib/core/transaction_tags.dart),
    // supaya aturan "mutasi internal" identik di provider dan layar.
    final isSavingRow = isSavingMutation(trx.note, trx.category?.name);
    final isDebtRow = isDebtMutation(trx.note);
    final isMutation = isSavingRow || isDebtRow;

    final cleanNote = stripTransactionTags(trx.note);
    final categoryName = trx.category?.name ?? "Umum";
    final walletName = state.walletNames[trx.walletId];
    final walletColor = state.walletColors[trx.walletId] ?? AppColors.tintGray;

    Widget? badge;
    if (isSavingRow) {
      badge = const AppChip(label: 'Mutasi Internal', color: AppColors.tintTeal);
    } else if (isDebtRow) {
      badge = const AppChip(label: 'Utang/Piutang', color: AppColors.tintSky);
    } else if (walletName != null) {
      badge = AppChip(label: walletName, color: walletColor, icon: PhosphorIconsFill.wallet);
    }

    // Chip didahulukan: lebar aslinya sampai 65% baris (catatan yang dipotong
    // lebih dulu); di atas itu teks chip terpotong "…", tidak pernah meluap.
    // Baris sangat sempit (nominal besar): catatan disembunyikan, chip dapat semua.
    final subtitle = LayoutBuilder(
      builder: (context, constraints) {
        final showNote = cleanNote.isNotEmpty && (badge == null || constraints.maxWidth >= 80);
        return Row(
          children: [
            if (showNote)
              Flexible(
                child: Text(
                  cleanNote,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (showNote && badge != null) const SizedBox(width: 6),
            if (badge != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * (showNote ? 0.65 : 1)),
                child: badge,
              ),
          ],
        );
      },
    );

    final row = AppListRow(
      leading: AppIconTile(
        icon: isSavingRow
            ? PhosphorIconsFill.bank
            : (isDebtRow ? PhosphorIconsFill.handCoins : categoryIcon(categoryName)),
        color: isMutation ? AppColors.tintGray : categoryColor(categoryName),
      ),
      title: categoryName,
      titleColor: isMutation ? AppColors.textSecondary : null,
      subtitleWidget: subtitle,
      trailing: Text(
        isMutation
            ? formatRupiah(trx.amount)
            : formatRupiahSigned(trx.amount, isIncome: !widget.isExpense),
        style: AppTextStyles.amountRow.copyWith(
          color: isMutation ? AppColors.textSecondary : _semanticColor,
          decoration: isMutation ? TextDecoration.lineThrough : null,
        ),
      ),
      onTap: isDebtRow ? null : () => _openTransaction(trx),
    );

    if (isMutation) return row;

    return AppSwipeActions(
      key: ValueKey(trx.id),
      deleteConfirmTitle: 'Hapus Transaksi?',
      deleteConfirmMessage: 'Data ini akan dihapus permanen.',
      onDelete: () => _deleteTransaction(trx),
      child: row,
    );
  }
}
