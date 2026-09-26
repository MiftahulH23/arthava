import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/screens/savings/saving_detail_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text.toUpperCase(), style: AppTextStyles.groupLabel),
    );

/// Label dompet sama persis dengan versi lama: "Nama (Sisa: 9.300.000)" tanpa "Rp".
String _walletOptionLabel(Map<String, dynamic> w) =>
    "${w['name']} (Sisa: ${NumberFormat.decimalPattern('id_ID').format((w['balance'] as num).round())})";

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  void _showAddTitleSheet() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();
    final amountController = TextEditingController();
    final initialWallets = ref.read(savingsProvider).wallets;
    int? selectedWalletId = initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null;
    var busy = false; // cegah ketuk ganda menyetor dua kali

    showAppFormSheet<void>(
      context: context,
      title: 'Buat Tabungan',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final wallets = ref.read(savingsProvider).wallets;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel("Nama Tabungan"),
              AppTextField(controller: nameController, hint: "Contoh: Dana Darurat", icon: PhosphorIconsFill.vault),
              const SizedBox(height: 14),
              _fieldLabel("Tempat Simpan (Opsional)"),
              AppTextField(controller: locationController, hint: "Contoh: Bank BCA", icon: PhosphorIconsFill.bank),
              const SizedBox(height: 14),
              _fieldLabel("Catatan (Opsional)"),
              AppTextField(controller: notesController, hint: "Tulis catatan singkat...", maxLines: 2),
              const SizedBox(height: 14),
              AppGroupedSection(
                header: "Tarik Dari Dompet Mana?",
                children: [
                  AppSelectRow<int>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                    title: "Dompet",
                    placeholder: "Pilih Dompet",
                    value: selectedWalletId,
                    options: [for (final w in wallets) AppSelectOption(w['id'] as int, _walletOptionLabel(w), shortLabel: "${w['name']}")],
                    onChanged: (v) => setSheetState(() => selectedWalletId = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(
                  controller: amountController,
                  label: "Setoran Awal (Opsional)",
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: "Simpan Tabungan",
                loading: busy,
                onPressed: () async {
                  if (busy) return;
                  if (nameController.text.isEmpty) {
                    AppNotification.error(context, "Nama tabungan tidak boleh kosong!");
                    return;
                  }

                  double amt = 0;
                  if (amountController.text.isNotEmpty) {
                    amt = parseRupiah(amountController.text).toDouble();
                  }

                  if (amt > 0 && selectedWalletId == null) {
                    AppNotification.error(context, "Pilih dompet untuk setoran awal!");
                    return;
                  }

                  busy = true;
                  setSheetState(() {});
                  try {
                    if (amt > 0) {
                      final error = await ref.read(savingsProvider.notifier).processSavingTransaction(
                            isDeposit: true,
                            savingName: nameController.text.trim(),
                            amount: amt,
                            walletId: selectedWalletId!,
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                          );
                      if (context.mounted) {
                        if (error != null) {
                          AppNotification.error(context, error);
                        } else {
                          AppNotification.success(context, "Berhasil Menabung!");
                        }
                      }
                    } else {
                      await ref.read(savingsProvider.notifier).addEmptyGroup(
                            name: nameController.text.trim(),
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                          );
                      if (context.mounted) {
                        AppNotification.success(context, "Tabungan berhasil dibuat!");
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) AppNotification.error(context, "Gagal membuat tabungan.");
                  } finally {
                    busy = false;
                    if (context.mounted) setSheetState(() {});
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSheet(String oldName, String oldLocation, String oldNotes) {
    final nameController = TextEditingController(text: oldName);
    final locationController = TextEditingController(text: oldLocation);
    final notesController = TextEditingController(text: oldNotes);

    showAppFormSheet<void>(
      context: context,
      title: 'Edit Tabungan',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel("Nama Tabungan"),
          AppTextField(controller: nameController, icon: PhosphorIconsFill.vault),
          const SizedBox(height: 14),
          _fieldLabel("Tempat Simpan"),
          AppTextField(controller: locationController, icon: PhosphorIconsFill.bank),
          const SizedBox(height: 14),
          _fieldLabel("Catatan"),
          AppTextField(controller: notesController, maxLines: 2),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: "Simpan Perubahan",
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                await ref.read(savingsProvider.notifier).renameGroup(
                      oldName: oldName,
                      newName: nameController.text.trim(),
                      location: locationController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  AppNotification.success(context, "Berhasil diupdate!");
                }
              } catch (e) {
                if (context.mounted) AppNotification.error(context, "Gagal update tabungan.");
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String groupName) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Tabungan?",
      message:
          "Anda yakin ingin menghapus '$groupName'? Semua riwayat di tabungan ini akan hilang (Saldo dompet TIDAK akan dikembalikan otomatis).",
    );
    if (!confirmed || !mounted) return;
    await ref.read(savingsProvider.notifier).deleteGroup(groupName);
    if (mounted) AppNotification.success(context, "Tabungan dihapus");
  }

  void _showTransactionSheet(String groupName, bool isDeposit) {
    final amountController = TextEditingController();
    final initialWallets = ref.read(savingsProvider).wallets;
    int? selectedWalletId = initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null;
    final actionColor = isDeposit ? AppColors.primary : AppColors.tintOrange;
    var busy = false;

    showAppFormSheet<void>(
      context: context,
      title: isDeposit ? "Setor ke $groupName" : "Tarik dari $groupName",
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final wallets = ref.read(savingsProvider).wallets;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGroupedSection(
                header: isDeposit ? "Tarik dari Dompet" : "Simpan ke Dompet",
                children: [
                  AppSelectRow<int>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                    title: "Dompet",
                    placeholder: "Pilih Dompet",
                    value: selectedWalletId,
                    options: [for (final w in wallets) AppSelectOption(w['id'] as int, _walletOptionLabel(w), shortLabel: "${w['name']}")],
                    onChanged: (v) => setSheetState(() => selectedWalletId = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(controller: amountController, label: "Nominal", color: actionColor),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: isDeposit ? "Konfirmasi Setoran" : "Konfirmasi Penarikan",
                color: actionColor,
                loading: busy,
                onPressed: () async {
                  if (busy) return;
                  if (amountController.text.isEmpty || selectedWalletId == null) {
                    AppNotification.error(context, "Isi nominal dengan benar!");
                    return;
                  }
                  final double amt = parseRupiah(amountController.text).toDouble();
                  // Hasil server ditunggu (tolakan "Saldo tabungan tidak cukup!" harus
                  // terlihat); sheet ditutup hanya bila berhasil.
                  busy = true;
                  setSheetState(() {});
                  final error = await ref.read(savingsProvider.notifier).processSavingTransaction(
                        isDeposit: isDeposit,
                        savingName: groupName,
                        amount: amt,
                        walletId: selectedWalletId!,
                      );
                  busy = false;
                  if (!context.mounted) return;
                  if (error != null) {
                    setSheetState(() {});
                    AppNotification.error(context, error);
                    return;
                  }
                  Navigator.pop(context);
                  AppNotification.success(context, isDeposit ? "Berhasil Menabung!" : "Berhasil Dicairkan!");
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(String groupName, List<SavingModel> items) {
    final double groupTotal = items.fold(0, (sum, item) => sum + item.amount);
    final String loc = items.last.location ?? '';
    final String note = items.last.notes ?? '';

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SavingDetailScreen(savingName: groupName)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconTile(icon: PhosphorIconsFill.vault, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupName, style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (loc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsFill.bank, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(loc, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.pencilSimple,
                  color: AppColors.textSecondary,
                  onPressed: () => _showEditSheet(groupName, loc, note),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.trash,
                  color: AppColors.textSecondary,
                  onPressed: () => _confirmDelete(groupName),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(formatRupiah(groupTotal), style: AppTextStyles.title.copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppPillButton(
                  label: "Setor",
                  icon: PhosphorIconsFill.downloadSimple,
                  onPressed: () => _showTransactionSheet(groupName, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPillButton(
                  label: "Tarik",
                  icon: PhosphorIconsFill.uploadSimple,
                  color: AppColors.tintOrange,
                  onPressed: () => _showTransactionSheet(groupName, false),
                ),
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
    final isLoading = savingsState.isLoading;
    final groupedSavings = savingsState.groupedSavings;
    final totalSavings = savingsState.totalSavings;

    return AppPageScaffold(
      title: 'Buku Tabungan',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: _showAddTitleSheet)],
      children: [
        AppHeroCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppHeroLabel("Total Semua Tabungan"),
                    const SizedBox(height: 6),
                    AppHeroAmount(formatRupiah(totalSavings), fontSize: 28),
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
        else if (groupedSavings.isEmpty)
          const AppEmptyState(icon: PhosphorIconsFill.vault, title: "Belum ada tabungan")
        else
          for (final entry in groupedSavings.entries) _buildGroupCard(entry.key, entry.value),
      ],
    );
  }
}
