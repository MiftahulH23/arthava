import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_detail_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  /// Warna status anggaran. Threshold sama persis dengan versi lama:
  /// > 100% merah, > 80% oranye, selain itu warna utama.
  static Color statusColor(double progress) {
    if (progress > 1) return AppColors.expense;
    if (progress > 0.8) return AppColors.tintOrange;
    return AppColors.primary;
  }

  void _changeMonth(WidgetRef ref, int offset) {
    ref.read(budgetProvider.notifier).changeMonth(offset);
  }

  /// Sheet "Pilih Periode" (dulu AlertDialog) — pemilih bulan bersama
  /// (Plan B3b, spec G17). Mengembalikan bulan terpilih atau null bila batal.
  /// Dipakai pill bulan di header dan baris "Periode Anggaran" di sheet "Buat Anggaran".
  static Future<DateTime?> _pickPeriod(BuildContext context, DateTime initial) {
    final currentYear = DateTime.now().year;
    return showAppMonthPicker(
      context: context,
      title: 'Pilih Periode',
      initialMonth: initial,
      firstYear: currentYear - 5,
      lastYear: currentYear + 5,
    );
  }

  Future<void> _openMonthPicker(BuildContext context, WidgetRef ref, DateTime selectedMonth) async {
    final picked = await _pickPeriod(context, selectedMonth);
    if (!context.mounted || picked == null) return;
    ref.read(budgetProvider.notifier).setMonth(picked);
  }

  Future<void> _copyFromLastMonth(BuildContext context, WidgetRef ref) async {
    try {
      final copied = await ref.read(budgetProvider.notifier).copyFromLastMonth();
      if (!copied) {
        if (context.mounted) AppNotification.error(context, "Tidak ada data anggaran bulan lalu.");
        return;
      }
      if (context.mounted) AppNotification.success(context, "Berhasil menyalin anggaran!");
    } catch (e) {
      if (context.mounted) AppNotification.error(context, "Gagal menyalin: $e");
    }
  }

  Future<void> _deleteBudget(WidgetRef ref, int id) async {
    await ref.read(budgetProvider.notifier).deleteBudget(id);
  }

  void _showFormSheet(BuildContext context, WidgetRef ref, DateTime selectedMonth, List<CategoryModel> allCategories) {
    int? selectedCatId;
    DateTime period = DateTime(selectedMonth.year, selectedMonth.month);
    final amountController = TextEditingController();

    showAppFormSheet<void>(
      context: context,
      title: 'Buat Anggaran',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroupedSection(
              children: [
                AppListRow(
                  leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.primary),
                  title: 'Periode Anggaran',
                  value: DateFormat('MMM yyyy', 'id_ID').format(period),
                  showChevron: true,
                  onTap: () async {
                    final picked = await _pickPeriod(context, period);
                    if (picked != null) setSheetState(() => period = picked);
                  },
                ),
                AppSelectRow<int>(
                  leading: const AppIconTile(icon: PhosphorIconsFill.tag, color: AppColors.expense),
                  title: 'Kategori',
                  placeholder: 'Pilih Kategori',
                  value: selectedCatId,
                  options: [for (final c in allCategories) AppSelectOption(c.id, c.name)],
                  onChanged: (v) => setSheetState(() => selectedCatId = v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              child: AppAmountField(
                controller: amountController,
                label: 'Batas Maksimal (Limit)',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Simpan Anggaran',
              onPressed: () async {
                if (selectedCatId == null || amountController.text.isEmpty) return;
                try {
                  await ref.read(budgetProvider.notifier).addBudget(
                        categoryId: selectedCatId!,
                        month: period.month,
                        year: period.year,
                        amount: parseRupiah(amountController.text).toDouble(),
                      );
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) AppNotification.success(context, "Berhasil ditambahkan!");
                } catch (e) {
                  if (context.mounted) AppNotification.error(context, e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetProvider);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(state.selectedMonth);
    final double totalProgress = state.totalBudget == 0 ? 0 : state.totalSpent / state.totalBudget;

    return AppPageScaffold(
      title: 'Anggaran',
      backLabel: 'Beranda',
      actions: [
        AppNavAction.add(
          onPressed: () => _showFormSheet(context, ref, state.selectedMonth, state.allCategories),
        ),
      ],
      children: [
        Row(
          children: [
            AppPill(label: '', icon: PhosphorIconsBold.caretLeft, onTap: () => _changeMonth(ref, -1)),
            const SizedBox(width: 8),
            Expanded(
              child: AppPill(
                label: monthLabel,
                icon: PhosphorIconsFill.calendarBlank,
                trailing: const Icon(PhosphorIconsRegular.caretDown, size: 16, color: AppColors.textSecondary),
                expand: true,
                onTap: () => _openMonthPicker(context, ref, state.selectedMonth),
              ),
            ),
            const SizedBox(width: 8),
            AppPill(label: '', icon: PhosphorIconsBold.caretRight, onTap: () => _changeMonth(ref, 1)),
          ],
        ),
        AppHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppHeroLabel('Terpakai Bulan Ini'),
                        const SizedBox(height: 4),
                        AppHeroAmount(formatRupiah(state.totalSpent), fontSize: 26),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppHeroLabel('Total Anggaran'),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(state.totalBudget),
                        style: AppTextStyles.headline.copyWith(color: AppColors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppProgressBar(
                value: totalProgress,
                color: state.totalSpent > state.totalBudget ? AppColors.expense : AppColors.white,
                onDark: true,
              ),
            ],
          ),
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (state.budgets.isEmpty)
          AppEmptyState(
            icon: PhosphorIconsFill.chartDonut,
            title: 'Belum ada anggaran',
            action: AppPillButton(
              label: 'Salin Bulan Lalu',
              icon: PhosphorIconsBold.copy,
              onPressed: () => _copyFromLastMonth(context, ref),
            ),
          )
        else
          AppGroupedSection(
            children: [
              for (final budget in state.budgets)
                Builder(
                  builder: (context) {
                    final spent = state.spendingMap[budget.categoryId] ?? 0;
                    final progress = budget.amount == 0 ? 0.0 : spent / budget.amount;
                    final color = statusColor(progress);
                    return AppSwipeActions(
                      key: ValueKey(budget.id),
                      deleteConfirmTitle: 'Hapus?',
                      deleteConfirmMessage: 'Yakin hapus anggaran ini?',
                      onDelete: () => _deleteBudget(ref, budget.id),
                      child: _BudgetRow(
                        icon: categoryIcon(budget.category?.name ?? ''),
                        name: budget.category?.name ?? "-",
                        spent: spent,
                        limit: budget.amount,
                        progress: progress,
                        color: color,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget)),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// Baris anggaran sesuai mockup: nama kiri + "Rp terpakai / Rp limit" kanan
/// di satu baris, progress selebar konten di bawahnya.
class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.icon,
    required this.name,
    required this.spent,
    required this.limit,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final double spent;
  final double limit;
  final double progress;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AppIconTile(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: AppTextStyles.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: formatRupiah(spent),
                                  style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: " / ${formatRupiah(limit)}", style: AppTextStyles.caption),
                              ],
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppProgressBar(value: progress, color: color, height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
