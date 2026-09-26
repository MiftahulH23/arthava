import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_chip.dart';
import 'package:flutter/material.dart';

/// Tombol aksi utama lebar penuh (spec §4.2: tinggi 52 radius 16).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: base,
          foregroundColor: Colors.white,
          disabledBackgroundColor: base.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTextStyles.button,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Flexible(child: Text(label, style: AppTextStyles.button, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Tombol kecil (Setor/Tarik, + Nabung, Transfer/Tambah).
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.filled = false,
    this.large = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool filled;

  /// Varian besar untuk pill aksi melayang (mis. Transfer · Tambah di Dompet):
  /// tinggi 44, bulat penuh, isi lebih lega.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final fg = filled ? Colors.white : c;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: filled ? c : Color.alphaBlend(c.withValues(alpha: 0.13), AppColors.surface),
        borderRadius: BorderRadius.circular(large ? 999 : 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          // Tanpa `alignment` di Container: Container beralignment melebar penuh
          // di Wrap/Align. Center(widthFactor: 1) memusatkan tanpa melebar.
          child: Container(
            height: large ? 44 : 36,
            padding: EdgeInsets.symmetric(horizontal: large ? 20 : 14),
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: large ? 18 : 16, color: fg), SizedBox(width: large ? 8 : 6)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subhead.copyWith(fontSize: large ? 15 : 14, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill putih untuk pemilih tanggal dan tombol "Filter".
class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.icon,
    this.trailing,
    this.badgeCount = 0,
    this.expand = false,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;
  final int badgeCount;
  final bool expand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: AppColors.textPrimary), const SizedBox(width: 6)],
              if (expand) Expanded(child: text) else Flexible(child: text),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              if (badgeCount > 0) ...[const SizedBox(width: 6), AppCountBadge(badgeCount)],
            ],
          ),
        ),
      ),
    );
  }
}
