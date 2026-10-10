import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/models/debt_model.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_chip.dart';
import 'package:arthava/widgets/app_progress.dart';
import 'package:arthava/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

/// Warna utama per jenis (sama dengan layar lama: utang merah, piutang hijau).
Color debtMainColor(DebtModel debt) => debt.isPayable ? AppColors.expense : AppColors.income;

class DebtBadge extends StatelessWidget {
  const DebtBadge({required this.debt, required this.today, super.key});

  final DebtModel debt;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final kind = debt.badgeKind(today);
    if (kind == DebtBadgeKind.none) return const SizedBox.shrink();
    final color = switch (kind) {
      DebtBadgeKind.paid => AppColors.income,
      DebtBadgeKind.overdue => AppColors.expense,
      _ => AppColors.tintOrange,
    };
    return AppChip(label: debtBadgeLabel(debt, today), color: color);
  }
}

class DebtCard extends StatelessWidget {
  const DebtCard({required this.debt, required this.today, this.onTap, super.key});

  final DebtModel debt;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPaid = debt.isPaidOff;
    final accent = isPaid ? AppColors.income : debtMainColor(debt);
    final meta = debt.notes == null
        ? 'Dipinjam ${_dayFormat.format(debt.loanDate)}'
        : 'Dipinjam ${_dayFormat.format(debt.loanDate)} · ${debt.notes}';

    return AppSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  debt.isPayable ? 'Saya berutang ke:' : 'Piutang dari:',
                  style: AppTextStyles.caption,
                ),
              ),
              DebtBadge(debt: debt, today: today),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            debt.name,
            style: AppTextStyles.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(meta, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Uang', style: AppTextStyles.caption),
                    Text(formatRupiah(debt.amount), style: AppTextStyles.amountRow),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isPaid ? 'Sudah lunas' : 'Sisa Tagihan', style: AppTextStyles.caption),
                  Text(
                    formatRupiah(debt.remainingAmount),
                    style: AppTextStyles.amountRow.copyWith(color: accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(value: debt.progress, color: accent),
        ],
      ),
    );
  }
}

class DebtTotalsRow extends StatelessWidget {
  const DebtTotalsRow({required this.totalPayable, required this.totalReceivable, super.key});

  final double totalPayable;
  final double totalReceivable;

  Widget _tile(String label, double value, Color color) {
    return Expanded(
      child: AppSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatRupiah(value), style: AppTextStyles.amountRow.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile('Total Utang', totalPayable, AppColors.expense),
        const SizedBox(width: 12),
        _tile('Total Piutang', totalReceivable, AppColors.income),
      ],
    );
  }
}
