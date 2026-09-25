import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Chip kecil (chip dompet, badge LUNAS/Terlambat/Tempo, "Mutasi Internal").
class AppChip extends StatelessWidget {
  const AppChip({required this.label, this.color, this.icon, super.key});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.13), AppColors.surface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: c), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge angka merah (jumlah filter aktif). 0 = tidak tampil.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(9)),
      child: Text(
        '$count',
        style: AppTextStyles.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}
