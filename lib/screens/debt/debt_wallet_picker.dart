import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
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
    super.key,
  });

  final List<WalletModel> wallets;
  final int? selectedWalletId;
  final ValueChanged<int> onSelected;

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
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final w in wallets)
            AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: walletColorOf(w), filled: true),
              title: w.name,
              value: formatRupiah(w.balance),
              trailing: w.id == selectedWalletId
                  ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(sheetContext, w.id),
            ),
        ],
      ),
    );
    if (picked != null) onSelected(picked);
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
      title: selected == null ? 'Pilih Dompet' : selected.name,
      value: selected == null ? null : formatRupiah(selected.balance),
      showChevron: true,
      onTap: () => _pick(context),
    );
  }
}
