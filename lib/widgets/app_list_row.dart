import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Satu baris grouped list (spec §4.2: min 56, padding 12/16).
class AppListRow extends StatelessWidget {
  const AppListRow({
    this.leading,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.value,
    this.showChevron = false,
    this.onTap,
    super.key,
  });

  final Widget? leading;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final String? value;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            // Judul mendapat porsi 3 : 2 dari nilai dan boleh turun ke baris
            // kedua, supaya label panjang (mis. "Tanggal Pembayaran") tidak "…".
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyStrong.copyWith(color: titleColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  if (subtitleWidget != null)
                    Padding(padding: const EdgeInsets.only(top: 4), child: subtitleWidget!),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                // Align mengisi porsi Flexible sehingga nilai pendek tetap
                // menempel ke kanan (bukan mulai di tengah baris).
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    value!,
                    style: AppTextStyles.subhead,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

/// Ikon bertinta (spec G10): tinted (latar 14%) atau filled (latar penuh, ikon putih).
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    required this.color,
    this.filled = false,
    this.round = false,
    this.size = 40,
    super.key,
  });

  final IconData icon;
  final Color color;
  final bool filled;
  final bool round;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = filled ? color : Color.alphaBlend(color.withValues(alpha: 0.14), AppColors.surface);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: filled ? Colors.white : color),
    );
  }
}
