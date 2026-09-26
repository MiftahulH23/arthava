import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/investment_model.dart';
import 'package:catat_uang_app/providers/investment_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:catat_uang_app/widgets/app_wallet_select_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InvestmentScreen extends ConsumerWidget {
  const InvestmentScreen({super.key});

  static final _inputFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  void _showAddInvestmentSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final amountController = TextEditingController();
    final wallets = ref.read(investmentProvider).wallets;
    int? selectedWalletId = wallets.isNotEmpty ? wallets.first['id'] as int : null;
    bool isSubmitting = false;

    showAppFormSheet(
      context: context,
      title: 'Investasi Baru',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppAmountField(controller: amountController, label: 'Modal Awal', color: AppColors.primary),
            const SizedBox(height: 14),
            const _FieldLabel('Nama Aset (Misal: Saham BBCA, Emas Antam)'),
            AppTextField(controller: nameController, hint: 'Saham BBCA'),
            const SizedBox(height: 14),
            const _FieldLabel('Jenis (Misal: Saham, Reksadana, Kripto)'),
            AppTextField(controller: typeController, hint: 'Saham'),
            const SizedBox(height: 14),
            AppWalletSelectRow(
              header: 'Sumber Dana',
              wallets: wallets,
              selectedId: selectedWalletId,
              onChanged: (v) => setSheetState(() => selectedWalletId = v),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Beli Aset',
              loading: isSubmitting,
              onPressed: () async {
                if (nameController.text.isEmpty || typeController.text.isEmpty || amountController.text.isEmpty) {
                  AppNotification.error(sheetContext, "Semua kolom wajib diisi!");
                  return;
                }
                if (selectedWalletId == null) {
                  AppNotification.error(sheetContext, "Pilih dompet!");
                  return;
                }
                final amount = parseRupiah(amountController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  await ref.read(investmentProvider.notifier).buyInvestment(
                        name: nameController.text.trim(),
                        type: typeController.text.trim(),
                        amount: amount,
                        walletId: selectedWalletId!,
                      );
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    AppNotification.success(sheetContext, "Investasi berhasil dibeli!");
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, e.toString().replaceFirst('Exception: ', ''));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, InvestmentModel inv) {
    showAppFormSheet(
      context: context,
      title: inv.name,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(inv.type, style: AppTextStyles.subhead, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          AppGroupedSection(
            children: [
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.plusCircle, color: AppColors.income),
                title: "Beli Tambahan (Top Up)",
                showChevron: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBuySellSheet(context, ref, inv, true);
                },
              ),
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.minusCircle, color: AppColors.expense),
                title: "Jual Aset (Withdraw)",
                showChevron: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBuySellSheet(context, ref, inv, false);
                },
              ),
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.arrowsClockwise, color: AppColors.primary),
                title: "Update Nilai Terkini",
                subtitle: "Sesuaikan dengan harga pasar saat ini",
                showChevron: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showUpdateValueSheet(context, ref, inv);
                },
              ),
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.trash, color: AppColors.tintGray),
                title: "Hapus Portofolio",
                titleColor: AppColors.textSecondary,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  // Semua hapus di app dikonfirmasi dulu (G12/G17); dulu langsung terhapus.
                  final confirmed = await showAppConfirmDialog(
                    context: context,
                    title: 'Hapus Portofolio?',
                    message: "Aset '${inv.name}' dihapus dari daftar. Saldo dompet tidak berubah.",
                  );
                  if (!confirmed || !context.mounted) return;
                  await ref.read(investmentProvider.notifier).deleteInvestment(inv.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBuySellSheet(BuildContext context, WidgetRef ref, InvestmentModel inv, bool isBuy) {
    final amountController = TextEditingController();
    final wallets = ref.read(investmentProvider).wallets;
    int? selectedWalletId = wallets.isNotEmpty ? wallets.first['id'] as int : null;
    bool isSubmitting = false;
    final color = isBuy ? AppColors.income : AppColors.expense;

    showAppFormSheet(
      context: context,
      title: isBuy ? "Top Up: ${inv.name}" : "Jual: ${inv.name}",
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppAmountField(controller: amountController, label: 'Nominal (Rp)', color: color, autofocus: true),
            const SizedBox(height: 14),
            AppWalletSelectRow(
              header: isBuy ? "Sumber Dana" : "Masuk ke Dompet",
              wallets: wallets,
              selectedId: selectedWalletId,
              onChanged: (v) => setSheetState(() => selectedWalletId = v),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: isBuy ? "Proses Pembelian" : "Proses Penjualan",
              color: color,
              loading: isSubmitting,
              onPressed: () async {
                if (amountController.text.isEmpty) return;
                if (selectedWalletId == null) return;
                final amount = parseRupiah(amountController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  await ref.read(investmentProvider.notifier).buySellInvestment(
                        inv: inv,
                        isBuy: isBuy,
                        amount: amount,
                        walletId: selectedWalletId!,
                      );
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    AppNotification.success(sheetContext, isBuy ? "Top up berhasil!" : "Penjualan berhasil!");
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, e.toString().replaceFirst('Exception: ', ''));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateValueSheet(BuildContext context, WidgetRef ref, InvestmentModel inv) {
    final amountController = TextEditingController(text: _inputFormat.format(inv.currentValue).trim());
    bool isSubmitting = false;

    showAppFormSheet(
      context: context,
      title: "Update Nilai: ${inv.name}",
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                "Update nilai terkini aset sesuai harga pasar. Ini tidak akan memotong saldo dompetmu.",
                style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 14),
            AppAmountField(controller: amountController, label: 'Nilai Saat Ini (Rp)', color: AppColors.primary),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: "Simpan Pembaruan",
              loading: isSubmitting,
              onPressed: () async {
                if (amountController.text.isEmpty) return;
                final amount = parseRupiah(amountController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  await ref.read(investmentProvider.notifier).updateInvestmentValue(inv.id, amount);
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    AppNotification.success(sheetContext, "Nilai berhasil diperbarui!");
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, "Error: $e");
                  }
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
    final invState = ref.watch(investmentProvider);
    final totalCapital = invState.totalCapital;
    final totalValue = invState.totalValue;
    final investments = invState.investments;

    final double totalReturn = totalCapital > 0 ? ((totalValue - totalCapital) / totalCapital) * 100 : 0;
    final bool isProfit = totalValue >= totalCapital;

    return AppPageScaffold(
      title: 'Investasi',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: () => _showAddInvestmentSheet(context, ref))],
      onRefresh: () => ref.read(investmentProvider.notifier).fetchData(),
      children: invState.isLoading
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ]
          : [
              AppHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppHeroLabel('Total Nilai Investasi'),
                    const SizedBox(height: 4),
                    AppHeroAmount(formatRupiah(totalValue)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppHeroLabel('Total Modal'),
                              const SizedBox(height: 2),
                              Text(
                                formatRupiah(totalCapital),
                                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        _ReturnPill(percent: totalReturn, isProfit: isProfit),
                      ],
                    ),
                  ],
                ),
              ),
              if (investments.isEmpty)
                const AppEmptyState(icon: PhosphorIconsRegular.chartLineUp, title: 'Belum ada aset investasi.')
              else
                AppGroupedSection(
                  header: 'Daftar Portofolio',
                  children: [
                    for (final inv in investments)
                      _InvestmentRow(inv: inv, onTap: () => _showActionSheet(context, ref, inv)),
                  ],
                ),
            ],
    );
  }
}

class _ReturnPill extends StatelessWidget {
  const _ReturnPill({required this.percent, required this.isProfit});

  final double percent;
  final bool isProfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isProfit ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            "${isProfit ? '+' : ''}${percent.toStringAsFixed(2)}%",
            style: AppTextStyles.subhead.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InvestmentRow extends StatelessWidget {
  const _InvestmentRow({required this.inv, required this.onTap});

  final InvestmentModel inv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double ret = inv.capitalAmount > 0 ? ((inv.currentValue - inv.capitalAmount) / inv.capitalAmount) * 100 : 0;
    final bool profit = inv.currentValue >= inv.capitalAmount;
    return AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsFill.chartLineUp, color: AppColors.primary),
      title: inv.name,
      // Spasi tak-putus: "Rp" tidak terpisah dari angkanya saat subjudul turun baris.
      subtitle: '${inv.type} · Modal: ${formatRupiah(inv.capitalAmount).replaceFirst(' ', ' ')}',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatRupiah(inv.currentValue), style: AppTextStyles.amountRow),
          const SizedBox(height: 2),
          Text(
            "${profit ? '+' : ''}${ret.toStringAsFixed(2)}%",
            style: AppTextStyles.caption.copyWith(
              color: profit ? AppColors.income : AppColors.expense,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text, style: AppTextStyles.subhead),
    );
  }
}
