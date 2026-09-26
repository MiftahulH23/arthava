import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: AppTextStyles.groupLabel),
    );

class SavingDetailScreen extends ConsumerStatefulWidget {
  final String savingName;
  const SavingDetailScreen({super.key, required this.savingName});

  @override
  ConsumerState<SavingDetailScreen> createState() => _SavingDetailScreenState();
}

class _SavingDetailScreenState extends ConsumerState<SavingDetailScreen> {
  // Getter (bukan field initializer) supaya State bisa dibuat di widget test
  // tanpa Supabase terinisialisasi; aksesnya ada di dalam try di bawah.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = true;
  Map<int, int> _savingToWallet = {};

  @override
  void initState() {
    super.initState();
    _fetchSavingToWallet();
  }

  Future<void> _fetchSavingToWallet() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final trxRes = await _supabase
          .from('transactions')
          .select('note, wallet_id')
          .eq('user_id', userId)
          .ilike('note', '%[SAVING_ID:%');

      final Map<int, int> tempSavingWallet = {};
      for (var t in trxRes) {
        final String note = t['note']?.toString() ?? '';
        final int? wId = t['wallet_id'] as int?;
        if (wId != null) {
          final match = RegExp(r'\[SAVING_ID:(\d+)\]').firstMatch(note);
          if (match != null) {
            final int sId = int.parse(match.group(1)!);
            tempSavingWallet[sId] = wId;
          }
        }
      }

      if (mounted) {
        setState(() {
          _savingToWallet = tempSavingWallet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSaving(SavingModel item) async {
    try {
      await ref.read(savingsProvider.notifier).deleteSavingItem(item);
      if (mounted) AppNotification.success(context, "Data dihapus & Saldo Dompet dikembalikan!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data.");
    }
  }

  Future<void> _confirmDeleteItem(SavingModel item) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Histori?",
      message: "Catatan ini dihapus dan saldonya dikembalikan ke dompet.",
    );
    if (!confirmed || !mounted) return;
    _deleteSaving(item);
  }

  void _showEditSheet(SavingModel saving) {
    final bool isDeposit = saving.amount >= 0;
    final amountController = TextEditingController(
      text: NumberFormat.decimalPattern('id_ID').format(saving.amount.abs().round()),
    );
    final locationController = TextEditingController(text: saving.location ?? '');
    final notesController = TextEditingController(text: saving.notes ?? '');

    showAppFormSheet<void>(
      context: context,
      title: "Edit ${isDeposit ? 'Setoran' : 'Tarikan'}",
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurfaceCard(
            child: AppAmountField(
              controller: amountController,
              label: "Nominal",
              color: isDeposit ? AppColors.income : AppColors.expense,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel("Tempat Simpan"),
          AppTextField(controller: locationController, hint: "Contoh: Bank BCA", icon: PhosphorIconsFill.mapPin),
          const SizedBox(height: 14),
          _fieldLabel("Catatan"),
          AppTextField(controller: notesController, hint: "Tulis catatan...", maxLines: 2),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: "Simpan Perubahan",
            onPressed: () async {
              final double rawAmount = parseRupiah(amountController.text).toDouble();
              // [LOGIKA] Dulu double.parse('') melempar FormatException di luar try.
              if (rawAmount <= 0) return;
              try {
                await ref.read(savingsProvider.notifier).editSavingItem(
                      saving: saving,
                      rawAmount: rawAmount,
                      isDeposit: isDeposit,
                      location: locationController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  AppNotification.success(context, "Perubahan disimpan!");
                }
              } catch (e) {
                if (context.mounted) AppNotification.error(context, "Gagal update data.");
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(SavingModel item, Map<int, String> walletNames) {
    final isWithdrawal = item.amount < 0;
    final Color cardColor = isWithdrawal ? AppColors.expense : AppColors.income;
    final walletId = _savingToWallet[item.id];
    final walletName = walletId != null ? walletNames[walletId] : null;
    final hasLocation = item.location != null && item.location!.isNotEmpty;

    return AppListRow(
      leading: AppIconTile(
        icon: isWithdrawal ? PhosphorIconsFill.arrowUpRight : PhosphorIconsFill.downloadSimple,
        color: cardColor,
      ),
      title: isWithdrawal ? "Penarikan Dana" : "Setoran Tabungan",
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (walletName != null || hasLocation)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (walletName != null)
                    AppChip(
                      label: isWithdrawal ? "Ke: $walletName" : "Dari: $walletName",
                      color: AppColors.primary,
                      icon: PhosphorIconsFill.wallet,
                    ),
                  if (hasLocation) AppChip(label: item.location!, icon: PhosphorIconsFill.mapPin),
                ],
              ),
            ),
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.notes!, style: AppTextStyles.caption),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt),
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            (isWithdrawal ? "- " : "+ ") + formatRupiah(item.amount.abs()),
            style: AppTextStyles.amountRow.copyWith(color: cardColor),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNavAction.icon(
                PhosphorIconsRegular.pencilSimple,
                color: AppColors.tintBlue,
                onPressed: () => _showEditSheet(item),
              ),
              AppNavAction.icon(
                PhosphorIconsRegular.trash,
                color: AppColors.expense,
                onPressed: () => _confirmDeleteItem(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savingsState = ref.watch(savingsProvider);
    final history = savingsState.groupedSavings[widget.savingName] ?? [];
    final currentBalance = history.fold<double>(0, (sum, item) => sum + item.amount);
    final Map<int, String> walletNames = {
      for (final w in savingsState.wallets) w['id'] as int: w['name'].toString(),
    };
    final isLoading = savingsState.isLoading || _isLoading;

    return AppPageScaffold(
      title: widget.savingName,
      backLabel: 'Buku Tabungan',
      children: [
        AppHeroCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppHeroLabel("Total Saldo Tabungan"),
                    const SizedBox(height: 6),
                    AppHeroAmount(formatRupiah(currentBalance), fontSize: 28),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: const Icon(PhosphorIconsFill.piggyBank, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (history.isNotEmpty)
          AppGroupedSection(
            header: 'Riwayat',
            children: [for (final item in history) _buildHistoryRow(item, walletNames)],
          ),
      ],
    );
  }
}
