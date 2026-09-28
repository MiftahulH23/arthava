import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/widgets/app_create_row.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_searchable_group.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Warna dompet dari data (`wallets.color`, format `#RRGGBB`); aturan fallback
/// sama dengan [AppColors.fromWalletHex].
Color walletColorOf(Map<String, dynamic> wallet) => AppColors.fromWalletHex(wallet['color']?.toString());

/// Baris pemilih dompet gaya iOS (pengganti DropdownButton): menampilkan
/// dompet terpilih + saldo; ketuk membuka sheet daftar dompet (G17), dengan
/// kolom cari bila dompetnya lebih dari 8.
class AppWalletSelectRow extends StatelessWidget {
  const AppWalletSelectRow({
    required this.wallets,
    required this.selectedId,
    required this.onChanged,
    this.header,
    this.placeholder = 'Pilih Dompet...',
    this.emptyLabel = 'Belum ada dompet',
    this.onCreate,
    super.key,
  });

  final List<Map<String, dynamic>> wallets;
  final int? selectedId;
  final ValueChanged<int> onChanged;
  final String? header;
  final String placeholder;
  final String emptyLabel;

  /// Membuat dompet baru (form bersama) dan mengembalikan id-nya; bila diisi,
  /// sheet pemilih mendapat baris "+ Dompet Baru" dan baris kosong menjadi
  /// "Buat Dompet". Dompet baru langsung dipilih.
  final Future<int?> Function()? onCreate;

  Future<void> _create() async {
    final id = await runCreateOnce(onCreate!);
    if (id != null) onChanged(id);
  }

  Map<String, dynamic>? get _selected {
    for (final w in wallets) {
      if (w['id'] == selectedId) return w;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showAppFormSheet<int>(
      context: context,
      title: 'Pilih Dompet',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchableGroup<Map<String, dynamic>>(
            items: wallets,
            searchText: (w) => w['name'].toString(),
            hint: 'Cari dompet',
            rowBuilder: (_, w) => AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: walletColorOf(w), filled: true),
              title: w['name'].toString(),
              value: formatRupiah(w['balance'] as num),
              trailing: w['id'] == selectedId
                  ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(sheetContext, w['id'] as int),
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
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final isEmpty = wallets.isEmpty;
    return AppGroupedSection(
      header: header,
      children: [
        AppListRow(
          leading: AppIconTile(
            icon: PhosphorIconsFill.wallet,
            color: selected != null ? walletColorOf(selected) : AppColors.tintGray,
            filled: selected != null,
          ),
          title: selected?['name']?.toString() ??
              (isEmpty ? (onCreate != null ? 'Buat Dompet' : emptyLabel) : placeholder),
          titleColor: selected != null
              ? null
              : (isEmpty && onCreate != null ? AppColors.primary : AppColors.textSecondary),
          value: selected != null ? formatRupiah(selected['balance'] as num) : null,
          showChevron: !isEmpty || onCreate != null,
          onTap: isEmpty ? (onCreate != null ? _create : null) : () => _openPicker(context),
        ),
      ],
    );
  }
}
