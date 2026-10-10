import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Grup pilihan untuk sheet pemilih (kategori, dompet, tabungan). Bila isinya
/// lebih dari [searchThreshold], kolom "Cari" muncul di atas daftar dan
/// menyaring baris tanpa peka huruf besar (keputusan user 2026-09-26).
class AppSearchableGroup<T> extends StatefulWidget {
  const AppSearchableGroup({
    required this.items,
    required this.searchText,
    required this.rowBuilder,
    this.hint = 'Cari',
    this.searchThreshold = 8,
    super.key,
  });

  final List<T> items;

  /// Teks yang dicocokkan dengan kata kunci, mis. nama kategori.
  final String Function(T item) searchText;
  final Widget Function(BuildContext context, T item) rowBuilder;
  final String hint;
  final int searchThreshold;

  @override
  State<AppSearchableGroup<T>> createState() => _AppSearchableGroupState<T>();
}

class _AppSearchableGroupState<T> extends State<AppSearchableGroup<T>> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchable = widget.items.length > widget.searchThreshold;
    final q = _query.text.trim().toLowerCase();
    final visible = !searchable || q.isEmpty
        ? widget.items
        : widget.items.where((item) => widget.searchText(item).toLowerCase().contains(q)).toList();

    final list = visible.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Tidak ditemukan', textAlign: TextAlign.center, style: AppTextStyles.subhead),
          )
        : AppGroupedSection(children: [for (final item in visible) widget.rowBuilder(context, item)]);

    if (!searchable) return list;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _query,
          hint: widget.hint,
          icon: PhosphorIconsRegular.magnifyingGlass,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        list,
      ],
    );
  }
}
