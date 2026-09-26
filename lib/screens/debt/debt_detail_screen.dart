import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_payment_sheet.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:catat_uang_app/screens/debt/debt_form_sheet.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(debtProvider.notifier).fetchPayments(widget.debtId));
  }

  Future<void> _deleteDebt(DebtModel debt) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Hapus Catatan?',
      message:
          'Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen. Saldo dompet tidak akan dikembalikan otomatis.',
    );
    if (!confirm || !mounted) return;
    try {
      await ref.read(debtProvider.notifier).deleteDebt(debt.id);
      if (!mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, 'Data berhasil dihapus!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePayment(DebtModel debt, DebtPaymentModel payment) async {
    try {
      await ref.read(debtProvider.notifier).deletePayment(debtId: debt.id, paymentId: payment.id);
      if (!mounted) return;
      AppNotification.success(context, 'Cicilan dihapus!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtState = ref.watch(debtProvider);
    final today = ref.watch(debtClockProvider)();
    final debt = debtState.debtById(widget.debtId);

    if (debt == null) {
      return AppPageScaffold(
        title: 'Detail Utang',
        largeTitle: false,
        backLabel: 'Utang',
        children: [
          if (debtState.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: AppEmptyState(icon: PhosphorIconsRegular.handCoins, title: 'Data utang tidak ditemukan.'),
            ),
        ],
      );
    }

    final mainColor = debtMainColor(debt);
    final accent = debt.isPaidOff ? AppColors.income : mainColor;
    final payments = debtState.payments[debt.id];
    final loadingPayments = payments == null && debtState.loadingPayments.contains(debt.id);
    final overdue = debt.isOverdue(today);

    return AppPageScaffold(
      title: debt.isPayable ? 'Detail Utang' : 'Detail Piutang',
      largeTitle: false,
      backLabel: 'Utang',
      titleWidget: _DebtHeader(debt: debt, today: today, color: mainColor),
      actions: [
        AppNavAction.text('Edit', onPressed: () => showDebtFormSheet(context, debt: debt)),
        AppNavAction.icon(
          PhosphorIconsRegular.trash,
          color: AppColors.expense,
          tooltip: 'Hapus utang',
          onPressed: () => _deleteDebt(debt),
        ),
      ],
      bottomBar: debt.isPaidOff
          ? null
          : AppPrimaryButton(
              label: debt.isPayable ? 'Bayar Cicilan' : 'Terima Pembayaran',
              icon: PhosphorIconsBold.money,
              color: mainColor,
              onPressed: () => showDebtPaymentSheet(context, debt: debt),
            ),
      children: [
        AppSurfaceCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Awal', style: AppTextStyles.caption),
                        Text(formatRupiah(debt.amount), style: AppTextStyles.headline),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Sisa Tagihan', style: AppTextStyles.caption),
                      Text(
                        formatRupiah(debt.remainingAmount),
                        style: AppTextStyles.headline.copyWith(color: accent),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppProgressBar(value: debt.progress, color: accent, height: 10),
              const SizedBox(height: 8),
              Text(
                '${(debt.progress * 100).toStringAsFixed(1)}% Terbayar',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        AppGroupedSection(
          insetSeparators: false,
          children: [
            AppListRow(title: 'Tanggal Pinjam', value: _dayFormat.format(debt.loanDate)),
            AppListRow(
              title: 'Jatuh Tempo',
              trailing: Text(
                debt.dueDate == null ? '-' : _dayFormat.format(debt.dueDate!),
                style: AppTextStyles.subhead.copyWith(color: overdue ? AppColors.expense : AppColors.textSecondary),
              ),
            ),
            if (debt.notes != null) AppListRow(title: 'Catatan', value: debt.notes),
          ],
        ),
        AppGroupedSection(
          header: 'Riwayat Cicilan',
          children: [
            if (loadingPayments)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (payments == null || payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text(
                  'Belum ada riwayat pembayaran.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subhead.copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              for (final p in payments)
                AppSwipeActions(
                  key: ValueKey('payment-${p.id}'),
                  deleteConfirmTitle: 'Hapus Cicilan?',
                  deleteConfirmMessage: deletePaymentConfirmMessage(p),
                  onEdit: () => showDebtPaymentSheet(context, debt: debt, payment: p),
                  onDelete: () => _deletePayment(debt, p),
                  child: AppListRow(
                    leading: AppIconTile(
                      icon: debt.isPayable ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown,
                      color: debt.isPayable ? AppColors.income : AppColors.expense,
                      round: true,
                    ),
                    title: _dayFormat.format(p.date),
                    subtitle: p.walletName ?? 'Tanpa Dompet',
                    trailing: Text(formatRupiah(p.amount), style: AppTextStyles.amountRow),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _DebtHeader extends StatelessWidget {
  const _DebtHeader({required this.debt, required this.today, required this.color});

  final DebtModel debt;
  final DateTime today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
            child: Text(debtInitials(debt.name), style: AppTextStyles.title.copyWith(color: color)),
          ),
          const SizedBox(height: 10),
          Text(debt.name, style: AppTextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          DebtBadge(debt: debt, today: today),
        ],
      ),
    );
  }
}
