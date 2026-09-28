import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_create_row.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_searchable_group.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Satu opsi untuk [AppSelectRow].
class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label, {this.shortLabel});
  final T value;

  /// Teks di daftar sheet pemilih.
  final String label;

  /// Teks ringkas di baris saat terpilih (mis. nama dompet tanpa "(Sisa: …)"
  /// yang terpotong); default [label].
  final String? shortLabel;
}

/// Baris grouped list yang membuka sheet pemilih (G17: daftar = sheet bawah).
/// Pengganti `DropdownButton` di dalam sheet form. Label opsi terpilih
/// tampil sebagai `value` abu di kanan; bila belum ada pilihan tampil
/// [placeholder]. Lebih dari 8 opsi → kolom cari ([AppSearchableGroup]).
class AppSelectRow<T> extends StatelessWidget {
  const AppSelectRow({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Pilih',
    this.leading,
    this.createLabel = 'Dompet Baru',
    this.onCreate,
    super.key,
  });

  final String title;
  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String placeholder;
  final Widget? leading;

  /// Bila [onCreate] diisi, sheet pemilih mendapat baris "+ [createLabel]";
  /// hasil non-null langsung dipilih. Tanpa opsi sama sekali, baris ini
  /// langsung membuat (placeholder menjadi "Buat …").
  final String createLabel;
  final Future<T?> Function()? onCreate;

  static const int _createIndex = -1;

  Future<void> _create() async {
    final created = await runCreateOnce(onCreate!);
    if (created != null) onChanged(created);
  }

  Future<void> _open(BuildContext context) async {
    // Indeks opsi dikembalikan (bukan value) supaya null selalu berarti "Batal".
    final index = await showAppFormSheet<int>(
      context: context,
      title: title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchableGroup<int>(
            items: [for (var i = 0; i < options.length; i++) i],
            searchText: (i) => options[i].label,
            rowBuilder: (_, i) => AppListRow(
              title: options[i].label,
              trailing: options[i].value == value
                  ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(sheetContext, i),
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 12),
            AppGroupedSection(children: [
              AppCreateRow(label: createLabel, onTap: () => Navigator.pop(sheetContext, _createIndex)),
            ]),
          ],
        ],
      ),
    );
    if (index == _createIndex) {
      await _create();
    } else if (index != null) {
      onChanged(options[index].value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    if (options.isEmpty && onCreate != null) {
      return AppListRow(
        leading: leading,
        title: title,
        value: 'Buat ${createLabel.replaceFirst(' Baru', '')}',
        valueColor: AppColors.primary,
        showChevron: true,
        onTap: _create,
      );
    }
    return AppListRow(
      leading: leading,
      title: title,
      value: selected == null ? placeholder : (selected.shortLabel ?? selected.label),
      showChevron: true,
      onTap: options.isEmpty ? null : () => _open(context),
    );
  }
}
