import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Baris "+ …" di bawah daftar pemilih (mis. "Dompet Baru").
class AppCreateRow extends StatelessWidget {
  const AppCreateRow({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsBold.plus, color: AppColors.primary),
      title: label,
      titleColor: AppColors.primary,
      onTap: onTap,
    );
  }
}

bool _createInFlight = false;

/// Menjalankan [create] (mis. membuka form "Dompet Baru") sekali pada satu
/// waktu: ketukan kedua selagi form pertama belum selesai diabaikan.
Future<T?> runCreateOnce<T>(Future<T?> Function() create) async {
  if (_createInFlight) return null;
  _createInFlight = true;
  try {
    return await create();
  } finally {
    _createInFlight = false;
  }
}
