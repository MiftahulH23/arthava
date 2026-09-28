import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/widgets/app_create_row.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_searchable_group.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Warna dompet disimpan sebagai teks "#RRGGBB" (pola sama dengan
/// stats_provider/wallet_screen). Nilai rusak jatuh ke primary.
Color walletColorOf(WalletModel wallet) {
  final hex = wallet.color;
  if (hex == null || hex.isEmpty) return AppColors.primary;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.primary;
  }
}

class DebtWalletPickerRow extends StatelessWidget {
  const DebtWalletPickerRow({
    required this.wallets,
    required this.selectedWalletId,
    required this.onSelected,
    this.onCreate,
    super.key,
  });

  final List<WalletModel> wallets;
  final int? selectedWalletId;
  final ValueChanged<int> onSelected;

  /// Membuat dompet baru dan mengembalikan id-nya (baris "+ Dompet Baru").
  final Future<int?> Function()? onCreate;

  Future<void> _create() async {
    final id = await onCreate!();
    if (id != null) onSelected(id);
  }

  WalletModel? get _selected {
    for (final w in wallets) {
      if (w.id == selectedWalletId) return w;
    }
    return null;
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppFormSheet<int>(
      context: context,
      title: 'Pilih Dompet',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchableGroup<WalletModel>(
            items: wallets,
            searchText: (w) => w.name,
            hint: 'Cari dompet',
            rowBuilder: (_, w) =>
              AppListRow(
                leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: walletColorOf(w), filled: true),
                title: w.name,
                value: formatRupiah(w.balance),
                trailing: w.id == selectedWalletId
                    ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                    : null,
                onTap: () => Navigator.pop(sheetContext, w.id),
              ),
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 12),
            AppGroupedSection(children: [
              AppCreateRow(label: 'Dompet Baru', onTap: () => Navigator.pop(sheetContext, -1)),
            ]),
          ],
        ],
      ),
    );
    if (picked == -1) {
      await _create();
    } else if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AppListRow(
      leading: AppIconTile(
        icon: PhosphorIconsFill.wallet,
        color: selected == null ? AppColors.tintGray : walletColorOf(selected),
        filled: selected != null,
      ),
      title: selected == null ? (wallets.isEmpty && onCreate != null ? 'Buat Dompet' : 'Pilih Dompet') : selected.name,
      titleColor: selected == null && wallets.isEmpty && onCreate != null ? AppColors.primary : null,
      value: selected == null ? null : formatRupiah(selected.balance),
      showChevron: true,
      onTap: wallets.isEmpty && onCreate != null ? _create : () => _pick(context),
    );
  }
}
