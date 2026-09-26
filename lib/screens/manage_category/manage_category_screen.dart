import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/category_provider.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ManageCategoryScreen extends ConsumerWidget {
  const ManageCategoryScreen({super.key});

  // [UPDATE: Fungsi pintar untuk membaca icon_name atau menebak dari namanya]
  IconData _getCategoryIcon(String categoryName, String? iconName) {
    final name = categoryName.toLowerCase();

    // 1. Prioritaskan jika iconName dari database cocok dengan string
    if (iconName == 'food' || name.contains('makan'))
      return PhosphorIcons.bowlFood(PhosphorIconsStyle.fill);
    if (iconName == 'drink' ||
        name.contains('minum') ||
        name.contains('kopi') ||
        name.contains('cafe'))
      return PhosphorIcons.coffee(PhosphorIconsStyle.fill);
    if (iconName == 'transport' ||
        name.contains('transport') ||
        name.contains('bensin'))
      return PhosphorIcons.bus(PhosphorIconsStyle.fill);
    if (iconName == 'shopping' ||
        name.contains('belanja') ||
        name.contains('mart'))
      return PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill);
    if (iconName == 'entertainment' ||
        name.contains('hiburan') ||
        name.contains('nonton'))
      return PhosphorIcons.gameController(PhosphorIconsStyle.fill);
    if (iconName == 'health' ||
        name.contains('kesehatan') ||
        name.contains('obat'))
      return PhosphorIcons.firstAid(PhosphorIconsStyle.fill);
    if (iconName == 'bill' ||
        name.contains('tagihan') ||
        name.contains('listrik'))
      return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
    if (iconName == 'salary' || name.contains('gaji'))
      return PhosphorIcons.money(PhosphorIconsStyle.fill);
    if (iconName == 'gift' || name.contains('bonus'))
      return PhosphorIcons.gift(PhosphorIconsStyle.fill);
    if (iconName == 'bank' || name.contains('tabung'))
      return PhosphorIcons.bank(PhosphorIconsStyle.fill);

    // Default Icon
    return PhosphorIcons.tag(PhosphorIconsStyle.fill);
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(categoryProvider.notifier).deleteCategory(id);
      if (context.mounted)
        AppNotification.success(context, "Kategori berhasil dihapus!");
    } catch (e) {
      if (context.mounted)
        AppNotification.error(
          context,
          "Gagal hapus. Kategori sedang digunakan.",
        );
    }
  }

  void _showInputSheet(
    BuildContext context,
    WidgetRef ref, {
    CategoryModel? categoryToEdit,
  }) {
    final isEditing = categoryToEdit != null;
    final isExpense = ref.read(categoryProvider).isExpense;
    final controller = TextEditingController(
      text: isEditing ? categoryToEdit.name : '',
    );
    bool isSaving = false;

    showAppFormSheet(
      context: context,
      title: isEditing
          ? "Edit Kategori"
          : (isExpense ? "Tambah Pengeluaran" : "Tambah Pemasukan"),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: controller,
              hint: "Nama Kategori (Contoh: Bensin)",
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              readOnly: isSaving,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: "Simpan",
              loading: isSaving,
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                setSheetState(() => isSaving = true);
                try {
                  if (isEditing) {
                    await ref
                        .read(categoryProvider.notifier)
                        .editCategory(categoryToEdit.id, controller.text.trim());
                  } else {
                    await ref
                        .read(categoryProvider.notifier)
                        .addCategory(controller.text.trim());
                  }
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                  if (context.mounted) {
                    AppNotification.success(
                      context,
                      isEditing ? "Berhasil diubah!" : "Berhasil ditambah!",
                    );
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSaving = false);
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
    final state = ref.watch(categoryProvider);
    final isExpense = state.isExpense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return AppPageScaffold(
      title: 'Kelola Kategori',
      backLabel: 'Beranda',
      actions: [AppNavAction.add(onPressed: () => _showInputSheet(context, ref))],
      children: [
        AppSegmentedControl(
          labels: const ['Pengeluaran', 'Pemasukan'],
          selectedIndex: isExpense ? 0 : 1,
          selectedLabelColors: const [AppColors.expense, AppColors.income],
          onChanged: (index) {
            final wantExpense = index == 0;
            if (isExpense != wantExpense) {
              ref.read(categoryProvider.notifier).fetchCategories(isExpense: wantExpense);
            }
          },
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (state.categories.isEmpty)
          const AppEmptyState(icon: PhosphorIconsRegular.tag, title: 'Belum ada kategori')
        else
          AppGroupedSection(
            children: [
              for (final cat in state.categories) _buildCategoryRow(context, ref, cat, color),
            ],
          ),
      ],
    );
  }

  Widget _buildCategoryRow(BuildContext context, WidgetRef ref, CategoryModel cat, Color color) {
    final isSystem = cat.userId == null;
    return AppListRow(
      leading: AppIconTile(icon: _getCategoryIcon(cat.name, cat.iconName), color: color),
      title: cat.name,
      subtitle: isSystem ? "Bawaan Aplikasi" : null,
      trailing: isSystem
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(PhosphorIconsFill.pencilSimple, color: AppColors.tintBlue, size: 20),
                  onPressed: () => _showInputSheet(context, ref, categoryToEdit: cat),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(PhosphorIconsFill.trash, color: AppColors.expense, size: 20),
                  onPressed: () async {
                    final confirmed = await showAppConfirmDialog(
                      context: context,
                      title: "Hapus Kategori?",
                      message: "Yakin mau hapus '${cat.name}'?",
                    );
                    if (confirmed && context.mounted) {
                      _deleteCategory(context, ref, cat.id);
                    }
                  },
                ),
              ],
            ),
    );
  }
}
