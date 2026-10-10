import 'package:arthava/screens/all_features/app_feature.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AllFeaturesScreen extends StatefulWidget {
  const AllFeaturesScreen({required this.onOpen, super.key});

  /// Dipanggil saat baris diketuk. HomeScreen yang melakukan navigasi + refresh
  /// supaya perilaku setelah kembali sama persis dengan grid lama.
  final ValueChanged<AppFeature> onOpen;

  @override
  State<AllFeaturesScreen> createState() => _AllFeaturesScreenState();
}

class _AllFeaturesScreenState extends State<AllFeaturesScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Semua Fitur',
      backLabel: 'Beranda',
      children: [
        AppTextField(
          controller: _search,
          hint: 'Cari fitur',
          icon: PhosphorIconsRegular.magnifyingGlass,
          onChanged: (_) => setState(() {}),
        ),
        AllFeaturesSections(query: _search.text, onOpen: widget.onOpen),
      ],
    );
  }
}

/// Grup-grup fitur tanpa scaffold — dipakai AllFeaturesScreen (mobile) dan
/// langsung di kolom Beranda web.
class AllFeaturesSections extends StatelessWidget {
  const AllFeaturesSections({required this.query, required this.onOpen, super.key});

  final String query;
  final ValueChanged<AppFeature> onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = filterFeatures(query);
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AppEmptyState(
          icon: PhosphorIconsRegular.magnifyingGlass,
          title: 'Fitur tidak ditemukan',
          subtitle: 'Coba kata kunci lain.',
        ),
      );
    }
    final entries = groups.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppPageScaffold.blockGap),
          AppGroupedSection(
            header: entries[i].key.label,
            children: [
              for (final f in entries[i].value)
                AppListRow(
                  leading: AppIconTile(icon: f.icon, color: f.color, filled: true),
                  title: f.label,
                  showChevron: true,
                  onTap: () => onOpen(f),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
