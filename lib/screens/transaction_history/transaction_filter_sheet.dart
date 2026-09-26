import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';

/// Snapshot data filter yang dibaca ulang setiap kali sheet rebuild
/// (sama seperti `ref.read(provider)` di dalam StatefulBuilder lama).
class TransactionFilterData {
  const TransactionFilterData({
    required this.categories,
    required this.walletNames,
    required this.selectedCategoryIds,
    required this.selectedWalletIds,
  });

  final List<Map<String, dynamic>> categories;
  final Map<int, String> walletNames;
  final List<int> selectedCategoryIds;
  final List<int> selectedWalletIds;
}

/// Sheet "Filter Transaksi" dipakai tab Transaksi & Statistik. Perilaku
/// identik dengan `_showFilterSheet` lama: toggle langsung memanggil
/// notifier (tanpa fetch), "Reset" mengosongkan pilihan, "Terapkan Filter"
/// menutup sheet lalu memanggil applyFilters (fetch).
Future<void> showTransactionFilterSheet({
  required BuildContext context,
  required Color accentColor,
  required TransactionFilterData Function() readData,
  required void Function(int id, bool selected) onToggleCategory,
  required void Function(int id, bool selected) onToggleWallet,
  required VoidCallback onReset,
  required VoidCallback onApply,
}) {
  return showAppFormSheet<void>(
    context: context,
    title: 'Filter Transaksi',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final data = readData();

        Widget toggle({required String label, required bool selected, required VoidCallback onTap}) {
          return AppPillButton(
            label: label,
            color: selected ? accentColor : AppColors.textSecondary,
            filled: selected,
            onPressed: onTap,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AppPillButton(
                label: 'Reset',
                color: AppColors.expense,
                onPressed: () {
                  onReset();
                  setSheetState(() {});
                },
              ),
            ),
            const SizedBox(height: 14),
            Text('Kategori'.toUpperCase(), style: AppTextStyles.groupLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in data.categories)
                  toggle(
                    label: c['name'].toString(),
                    selected: data.selectedCategoryIds.contains(c['id'] as int),
                    onTap: () {
                      final id = c['id'] as int;
                      onToggleCategory(id, !data.selectedCategoryIds.contains(id));
                      setSheetState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Dompet'.toUpperCase(), style: AppTextStyles.groupLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in data.walletNames.entries)
                  toggle(
                    label: e.value,
                    selected: data.selectedWalletIds.contains(e.key),
                    onTap: () {
                      onToggleWallet(e.key, !data.selectedWalletIds.contains(e.key));
                      setSheetState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Terapkan Filter',
              color: accentColor,
              onPressed: () {
                Navigator.pop(sheetContext);
                onApply();
              },
            ),
          ],
        );
      },
    ),
  );
}
