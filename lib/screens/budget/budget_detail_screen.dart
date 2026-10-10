import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/models/budget_model.dart';
import 'package:arthava/providers/budget_provider.dart';
import 'package:arthava/screens/budget/budget_screen.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_amount_display.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_chip.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_progress.dart';
import 'package:arthava/widgets/app_sheet.dart';
import 'package:arthava/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BudgetDetailScreen extends ConsumerWidget {
  final BudgetModel budget;

  const BudgetDetailScreen({super.key, required this.budget});

  void _showEditSheet(BuildContext context, WidgetRef ref, BudgetModel currentBudget) {
    final amountController = TextEditingController(
      text: NumberFormat.decimalPattern('id_ID').format(currentBudget.amount.round()),
    );

    showAppFormSheet<void>(
      context: context,
      title: 'Edit Anggaran',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Ubah limit untuk kategori ${currentBudget.category?.name}",
            style: AppTextStyles.subhead,
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
            label: 'Simpan Perubahan',
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              final cleanAmount = parseRupiah(amountController.text).toDouble();
              try {
                await ref.read(budgetProvider.notifier).updateBudgetAmount(currentBudget.id, cleanAmount);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) AppNotification.success(context, "Limit berhasil diperbarui!");
              } catch (e) {
                if (context.mounted) AppNotification.error(context, "Gagal update limit");
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Versi terkini dari budgetProvider supaya edit limit langsung tampil;
    // fallback ke budget awal bila item sudah tidak ada di state.
    final budgetState = ref.watch(budgetProvider);
    final currentBudget = budgetState.budgets.firstWhere(
      (b) => b.id == budget.id,
      orElse: () => budget,
    );

    final detailAsync = ref.watch(
      budgetDetailProvider((categoryId: budget.categoryId, month: budget.month, year: budget.year)),
    );
    final detail = detailAsync.valueOrNull ?? const BudgetDetailData();
    final totalSpent = detail.totalSpent;

    final progress = currentBudget.amount == 0 ? 0.0 : totalSpent / currentBudget.amount;
    final color = BudgetScreen.statusColor(progress);
    final sisa = currentBudget.amount - totalSpent;

    return AppPageScaffold(
      title: currentBudget.category?.name ?? "Detail Anggaran",
      backLabel: 'Anggaran',
      actions: [
        AppNavAction.text('Edit', onPressed: () => _showEditSheet(context, ref, currentBudget)),
      ],
      children: detailAsync.isLoading
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ]
          : [
              AppSurfaceCard(
                child: Row(
                  children: [
                    AppProgressRing(
                      value: progress,
                      color: color,
                      center: Text('${(progress * 100).round()}%', style: AppTextStyles.title),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terpakai', style: AppTextStyles.caption),
                          Text(formatRupiah(totalSpent), style: AppTextStyles.headline),
                          const SizedBox(height: 8),
                          Text('Limit Anggaran', style: AppTextStyles.caption),
                          Text(formatRupiah(currentBudget.amount), style: AppTextStyles.headline),
                          const SizedBox(height: 10),
                          AppChip(
                            label: "${sisa >= 0 ? "Sisa Anggaran:" : "Over Budget:"} ${formatRupiah(sisa.abs())}",
                            color: sisa >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.transactions.isEmpty)
                const AppEmptyState(
                  icon: PhosphorIconsRegular.receipt,
                  title: 'Belum ada transaksi di kategori ini',
                )
              else
                AppGroupedSection(
                  header: 'Riwayat Pengeluaran',
                  children: [
                    for (final trx in detail.transactions)
                      Builder(
                        builder: (context) {
                          final rawNote = trx['note']?.toString() ?? '';
                          final cleanNote = rawNote.isNotEmpty ? rawNote : "Tanpa catatan";
                          final wId = trx['wallet_id'];
                          final wName = detail.walletNames[wId] ?? 'Kas Utama';
                          final wColor = detail.walletColors[wId] ?? AppColors.tintGray;
                          return AppListRow(
                            leading: const AppIconTile(icon: PhosphorIconsFill.receipt, color: AppColors.primary),
                            title: cleanNote,
                            subtitleWidget: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              // Wrap: chip dompet turun ke baris berikut bila tidak muat.
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(DateTime.parse(trx['date'])),
                                    style: AppTextStyles.caption,
                                  ),
                                  AppChip(label: wName, color: wColor, icon: PhosphorIconsFill.wallet),
                                ],
                              ),
                            ),
                            trailing: Text(
                              formatRupiahSigned(trx['amount'] as num, isIncome: false),
                              style: AppTextStyles.amountRow.copyWith(color: AppColors.expense),
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
