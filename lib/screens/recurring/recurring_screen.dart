import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/providers/recurring_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_select_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
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

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  Future<void> _toggleActive(RecurringTransactionModel item, bool value) async {
    try {
      await ref.read(recurringProvider.notifier).toggleActive(item, value);
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal mengubah status");
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await ref.read(recurringProvider.notifier).deleteItem(id);
      if (mounted) AppNotification.success(context, "Jadwal otomatis dihapus");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data");
    }
  }

  Future<void> _confirmDelete(RecurringTransactionModel item) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: "Hapus Jadwal?",
      message: "Jadwal otomatis ini akan dihentikan dan dihapus dari daftar.",
    );
    if (!confirmed || !mounted) return;
    _deleteItem(item.id);
  }

  void _showAddEditSheet({RecurringTransactionModel? item}) {
    final isEdit = item != null;
    final initialWallets = ref.read(recurringProvider).wallets;
    bool isExpense = isEdit ? (item.category?['is_expense'] ?? true) : true;
    int? selectedCatId = isEdit ? item.categoryId : null;
    int? selectedWalletId = isEdit
        ? item.walletId
        : (initialWallets.isNotEmpty ? initialWallets.first['id'] as int : null);
    String selectedFreq = isEdit ? item.frequency : 'Bulanan';
    DateTime selectedDate = isEdit ? item.startDate : DateTime.now();

    final amountController = TextEditingController(
      text: isEdit ? NumberFormat.decimalPattern('id_ID').format(item.amount.round()) : '',
    );
    final noteController = TextEditingController(text: isEdit ? item.note ?? '' : '');
    final frequencies = ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'];

    showAppFormSheet<void>(
      context: context,
      title: isEdit ? "Edit Jadwal Tagihan" : "Buat Jadwal Tagihan",
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = ref.read(recurringProvider).categories;
          final wallets = ref.read(recurringProvider).wallets;
          final filteredCats = categories.where((c) => c['is_expense'] == isExpense).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmentedControl(
                labels: const ['Pemasukan', 'Pengeluaran'],
                selectedIndex: isExpense ? 1 : 0,
                selectedLabelColors: const [AppColors.income, AppColors.expense],
                onChanged: (index) => setSheetState(() {
                  isExpense = index == 1;
                  selectedCatId = null;
                }),
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: AppAmountField(
                  controller: amountController,
                  label: "Nominal",
                  color: isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
              const SizedBox(height: 14),
              AppGroupedSection(
                children: [
                  AppSelectRow<int>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
                    title: isExpense ? "Potong Dari Dompet Mana?" : "Masuk Ke Dompet Mana?",
                    placeholder: wallets.isEmpty ? "Belum ada dompet" : "Pilih Dompet",
                    value: selectedWalletId,
                    options: [for (final w in wallets) AppSelectOption(w['id'] as int, "${w['name']}")],
                    onChanged: (val) => setSheetState(() => selectedWalletId = val),
                  ),
                  AppSelectRow<int>(
                    leading: AppIconTile(
                      icon: PhosphorIconsFill.tag,
                      color: isExpense ? AppColors.expense : AppColors.income,
                    ),
                    title: "Kategori",
                    placeholder: "Pilih Kategori",
                    value: filteredCats.any((c) => c['id'] == selectedCatId) ? selectedCatId : null,
                    options: [for (final cat in filteredCats) AppSelectOption(cat['id'] as int, "${cat['name']}")],
                    onChanged: (val) => setSheetState(() => selectedCatId = val),
                  ),
                  AppSelectRow<String>(
                    leading: const AppIconTile(icon: PhosphorIconsFill.repeat, color: AppColors.tintBlue),
                    title: "Diulang Setiap",
                    value: selectedFreq,
                    options: [for (final f in frequencies) AppSelectOption(f, f)],
                    onChanged: (val) => setSheetState(() => selectedFreq = val),
                  ),
                  AppListRow(
                    leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.tintRed),
                    title: "Mulai Tanggal",
                    subtitle: "Jatuh Tempo Pertama",
                    value: DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate),
                    showChevron: true,
                    onTap: () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSheetState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _fieldLabel("Catatan (Cth: Bayar Kos / Tagihan WiFi)"),
              AppTextField(controller: noteController, hint: "Tulis catatan..."),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: isEdit ? "Perbarui Jadwal" : "Simpan Jadwal",
                onPressed: () async {
                  // Id lama milik dompet/kategori yang sudah dihapus dianggap kosong.
                  final walletExists = ref.read(recurringProvider).wallets.any((w) => w['id'] == selectedWalletId);
                  final categoryExists = filteredCats.any((c) => c['id'] == selectedCatId);
                  if (amountController.text.isEmpty || !categoryExists || !walletExists) {
                    AppNotification.error(context, "Nominal, Kategori, dan Dompet wajib diisi!");
                    return;
                  }

                  final double amount = parseRupiah(amountController.text).toDouble();
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                  try {
                    final data = {
                      'user_id': userId,
                      'category_id': selectedCatId,
                      'wallet_id': selectedWalletId,
                      'amount': amount,
                      'note': noteController.text.trim(),
                      'frequency': selectedFreq,
                      'start_date': dateStr,
                      'next_run_date': isEdit ? item.nextRunDate.toIso8601String() : dateStr,
                    };

                    if (isEdit) {
                      await ref.read(recurringProvider.notifier).updateRecurring(item.id, data);
                    } else {
                      await ref.read(recurringProvider.notifier).addRecurring(data);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.success(context, isEdit ? "Jadwal diperbarui!" : "Jadwal berhasil dibuat!");
                    }
                  } catch (e) {
                    if (context.mounted) AppNotification.error(context, "Gagal menyimpan jadwal");
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(RecurringTransactionModel item, Map<int, String> walletNames) {
    final bool isExpense = item.category?['is_expense'] ?? true;
    final String catName = item.category?['name'] ?? 'Umum';
    final color = isExpense ? AppColors.expense : AppColors.income;
    final walletName = walletNames[item.walletId] ?? 'Dompet Dihapus';

    return Opacity(
      opacity: item.isActive ? 1 : 0.55,
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconTile(
                  icon: isExpense ? PhosphorIcons.arrowUp() : PhosphorIcons.arrowDown(),
                  color: item.isActive ? color : AppColors.tintGray,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catName,
                        style: AppTextStyles.headline.copyWith(
                          color: item.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.note != null && item.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(item.note!, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          AppChip(label: "Per ${item.frequency}", color: AppColors.tintBlue),
                          AppChip(label: walletName, icon: PhosphorIconsFill.wallet),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRupiahSigned(item.amount, isIncome: !isExpense),
                      style: AppTextStyles.amountRow.copyWith(
                        color: item.isActive ? color : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppSwitch(value: item.isActive, onChanged: (val) => _toggleActive(item, val)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5, color: AppColors.separator),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(PhosphorIconsRegular.clock, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: "Lanjut: ", style: AppTextStyles.caption),
                        TextSpan(
                          text: DateFormat('dd MMM yyyy', 'id_ID').format(item.nextRunDate),
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: item.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.pencilSimple,
                  color: AppColors.tintBlue,
                  onPressed: () => _showAddEditSheet(item: item),
                ),
                AppNavAction.icon(
                  PhosphorIconsRegular.trash,
                  color: AppColors.expense,
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recurringState = ref.watch(recurringProvider);
    final isLoading = recurringState.isLoading;
    final recurringList = recurringState.recurringList;
    final walletNames = recurringState.walletNames;

    return AppPageScaffold(
      title: 'Tagihan & Pemasukan Rutin',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: () => _showAddEditSheet())],
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (recurringList.isEmpty)
          const AppEmptyState(icon: PhosphorIconsFill.calendarPlus, title: "Belum ada jadwal otomatis")
        else
          for (final item in recurringList) _buildCard(item, walletNames),
      ],
    );
  }
}
