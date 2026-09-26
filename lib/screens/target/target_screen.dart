import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/target_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
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

String _plainAmount(num value) => NumberFormat.decimalPattern('id_ID').format(value.round());

class TargetScreen extends ConsumerStatefulWidget {
  const TargetScreen({super.key});

  @override
  ConsumerState<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends ConsumerState<TargetScreen> {
  String _getRecommendation(TargetModel target) {
    if (target.savedAmount >= target.targetAmount) return "Target tercapai! Mantap! 🎉";
    if (target.deadline == null) return "Set deadline agar dapat rekomendasi nabung.";

    final now = DateTime.now();
    final difference = target.deadline!.difference(now).inDays;
    final remainingAmount = target.targetAmount - target.savedAmount;

    if (difference <= 0) return "Deadline sudah terlewat!";

    if (difference < 60) {
      final double dailySave = remainingAmount / difference;
      return "Nabung ${formatRupiah(dailySave)} / hari agar tercapai.";
    } else {
      final double months = difference / 30;
      final double monthlySave = remainingAmount / months;
      return "Nabung ${formatRupiah(monthlySave)} / bulan agar tercapai.";
    }
  }

  /// Field lokasi dengan saran nama tabungan. Controller & focusNode eksternal
  /// supaya teks langsung tersimpan di [controller] tanpa listener tambahan.
  Widget _locationField(TextEditingController controller, FocusNode focusNode, List<String> savingNames) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return savingNames;
        return savingNames.where(
          (option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selection) => controller.text = selection,
      fieldViewBuilder: (context, textController, fieldFocus, onFieldSubmitted) => AppTextField(
        controller: textController,
        focusNode: fieldFocus,
        hint: "Pilih / Ketik Nama Tabungan",
        icon: PhosphorIconsFill.link,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: AppColors.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options) AppListRow(title: option, onTap: () => onSelected(option)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSheet() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final locationController = TextEditingController();
    final locationFocus = FocusNode();
    DateTime? selectedDate;

    showAppFormSheet<void>(
      context: context,
      title: 'Target Baru',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final savingNames = ref.read(targetProvider).savingNames;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel("Nama Target"),
              AppTextField(controller: nameController, hint: "Misal: Beli iPhone 15", icon: PhosphorIconsFill.target),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(controller: targetController, label: "Target Dana", color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              _fieldLabel("Lokasi Penyimpanan Sementara"),
              _locationField(locationController, locationFocus, savingNames),
              const SizedBox(height: 14),
              AppGroupedSection(
                children: [
                  AppListRow(
                    leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.primary),
                    title: "Tenggat Waktu (Opsional)",
                    value: selectedDate == null
                        ? "Pilih Tanggal"
                        : DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate!),
                    showChevron: true,
                    onTap: () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: "Simpan Target",
                onPressed: () async {
                  if (nameController.text.isEmpty || targetController.text.isEmpty) return;
                  try {
                    await ref.read(targetProvider.notifier).addTarget(
                          name: nameController.text,
                          targetAmount: parseRupiah(targetController.text).toDouble(),
                          storageLocation: locationController.text.isNotEmpty ? locationController.text : null,
                          deadline: selectedDate,
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.success(context, "Target berhasil dibuat!");
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSheet(TargetModel target) {
    final nameController = TextEditingController(text: target.name);
    final targetController = TextEditingController(text: _plainAmount(target.targetAmount));
    final savedController = TextEditingController(text: _plainAmount(target.savedAmount));
    final locationController = TextEditingController(text: target.storageLocation ?? "");
    final locationFocus = FocusNode();
    DateTime? selectedDate = target.deadline;

    showAppFormSheet<void>(
      context: context,
      title: 'Edit Target',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final savingNames = ref.read(targetProvider).savingNames;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel("Nama Target"),
              AppTextField(controller: nameController),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(controller: targetController, label: "Target Dana", color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              AppSurfaceCard(
                child: AppAmountField(controller: savedController, label: "Terkumpul", color: AppColors.income),
              ),
              const SizedBox(height: 14),
              _fieldLabel("Lokasi Penyimpanan"),
              _locationField(locationController, locationFocus, savingNames),
              const SizedBox(height: 14),
              AppGroupedSection(
                children: [
                  AppListRow(
                    leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.primary),
                    title: "Tenggat Waktu",
                    value: selectedDate == null
                        ? "Pilih Tanggal"
                        : DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate!),
                    showChevron: true,
                    onTap: () async {
                      final now = DateTime.now();
                      // [LOGIKA] Deadline lama bisa sudah lewat; initialDate tidak
                      // boleh sebelum firstDate (showAppDatePicker juga menjepit, tapi nilai tampilan tetap dijaga di sini).
                      final initial = (selectedDate != null && selectedDate!.isAfter(now)) ? selectedDate! : now;
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: now,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: "Simpan Perubahan",
                onPressed: () async {
                  if (nameController.text.isEmpty || targetController.text.isEmpty) return;
                  try {
                    await ref.read(targetProvider.notifier).editTarget(
                          id: target.id,
                          name: nameController.text,
                          targetAmount: parseRupiah(targetController.text).toDouble(),
                          savedAmount: parseRupiah(savedController.text).toDouble(),
                          storageLocation: locationController.text.isNotEmpty ? locationController.text : null,
                          deadline: selectedDate,
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.success(context, "Target berhasil diupdate!");
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDepositSheet(TargetModel target) {
    final amountController = TextEditingController();
    final initialWallets = ref.read(targetProvider).wallets;
    int? selectedWalletId = initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null;
    var busy = false; // cegah ketuk ganda memotong dompet dua kali

    showAppFormSheet<void>(
      context: context,
      title: "Nabung: ${target.name}",
      // Consumer: daftar dompet ikut ter-update bila fetchWallets baru selesai.
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final wallets = ref.watch(targetProvider.select((s) => s.wallets));
          if (selectedWalletId == null && wallets.isNotEmpty) selectedWalletId = wallets.first['id'] as int;
          return StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                target.storageLocation != null
                    ? "Disimpan di: ${target.storageLocation}"
                    : "Lokasi penyimpanan belum ditentukan.",
                style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 14),
            AppGroupedSection(
              header: "Tarik Dana Dari Dompet Mana?",
              children: [
                AppSelectRow<int>(
                  leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                  title: "Dompet",
                  placeholder: wallets.isEmpty ? "Belum ada dompet" : "Pilih Dompet",
                  value: selectedWalletId,
                  options: [
                    for (final w in wallets)
                      AppSelectOption(
                        w['id'] as int,
                        "${w['name']} (Sisa: ${formatRupiah(w['balance'] as num)})",
                        shortLabel: "${w['name']}",
                      ),
                  ],
                  onChanged: (val) => setSheetState(() => selectedWalletId = val),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              child: AppAmountField(
                controller: amountController,
                label: "Mau nabung berapa hari ini?",
                color: AppColors.income,
              ),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: "Setor Tabungan",
              color: AppColors.income,
              loading: busy,
              onPressed: () async {
                if (busy || amountController.text.isEmpty || selectedWalletId == null) return;
                busy = true;
                setSheetState(() {});
                try {
                  final rawAmount = parseRupiah(amountController.text).toDouble();
                  final result = await ref.read(targetProvider.notifier).depositToTarget(
                        target: target,
                        rawAmount: rawAmount,
                        walletId: selectedWalletId!,
                      );
                  if (result != null) {
                    if (context.mounted) AppNotification.error(context, result);
                    return;
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppNotification.success(context, "Berhasil nabung Rp ${amountController.text}!");
                  }
                } catch (e) {
                  debugPrint(e.toString());
                } finally {
                  busy = false;
                  if (context.mounted) setSheetState(() {});
                }
              },
            ),
          ],
        ),
      );
        },
      ),
    );
  }

  Future<void> _confirmDelete(int id, String name) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Target?",
      message:
          "Anda yakin ingin menghapus target '$name'? Saldo di target ini akan hilang (Catatan: Saldo dompet Anda TIDAK akan dikembalikan otomatis karena ini dihapus paksa).",
    );
    if (!confirmed || !mounted) return;
    await ref.read(targetProvider.notifier).deleteTarget(id);
    if (mounted) AppNotification.success(context, "Target dihapus");
  }

  Widget _buildTargetCard(TargetModel item) {
    final progress = item.targetAmount == 0 ? 0.0 : item.savedAmount / item.targetAmount;
    final percent = (progress * 100).clamp(0, 100).toInt();
    final remaining = item.targetAmount - item.savedAmount;
    final recommendation = _getRecommendation(item);

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (item.storageLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsFill.wallet, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                item.storageLocation!,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (item.deadline != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsRegular.calendarBlank, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                "Deadline: ${DateFormat('dd MMM yyyy').format(item.deadline!)}",
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                onPressed: () => _showEditSheet(item),
              ),
              AppNavAction.icon(
                PhosphorIconsRegular.trash,
                color: AppColors.textSecondary,
                onPressed: () => _confirmDelete(item.id, item.name),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(value: progress, color: AppColors.income),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "${formatRupiah(item.savedAmount)} / ${formatRupiah(item.targetAmount)}",
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              Text("$percent%", style: AppTextStyles.bodyStrong.copyWith(color: AppColors.income)),
            ],
          ),
          if (remaining > 0 && item.deadline != null) ...[
            const SizedBox(height: 12),
            AppCallout(
              icon: PhosphorIconsFill.lightbulb,
              tone: AppCalloutTone.accent,
              child: Text(recommendation, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  remaining <= 0 ? "Tercapai! 🎉" : "Kurang ${formatRupiah(remaining)}",
                  style: remaining <= 0
                      ? AppTextStyles.bodyStrong.copyWith(color: AppColors.income)
                      : AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              AppPillButton(
                label: "Nabung",
                icon: PhosphorIconsBold.plus,
                filled: true,
                onPressed: remaining <= 0 ? null : () => _showDepositSheet(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetState = ref.watch(targetProvider);
    final isLoading = targetState.isLoading;
    final targets = targetState.targets;
    final totalSavings = targetState.totalSavings;

    return AppPageScaffold(
      title: 'Target Keuangan',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: _showAddSheet)],
      children: [
        AppSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Semua Target", style: AppTextStyles.subhead),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(totalSavings),
                      style: AppTextStyles.title.copyWith(fontSize: 26, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const AppIconTile(icon: PhosphorIconsFill.target, color: AppColors.primary, round: true, size: 52),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (targets.isEmpty)
          const AppEmptyState(icon: PhosphorIconsFill.target, title: "Belum ada target")
        else
          for (final item in targets) _buildTargetCard(item),
      ],
    );
  }
}
