import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
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
    this.valueColor,
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

  /// Warna teks [value]; default warna `AppTextStyles.subhead`.
  final Color? valueColor;
  final bool showChevron;
  final VoidCallback? onTap;

  /// Lebar maksimum nilai: minimal 40% baris (porsi lama 3:2, cukup untuk judul
  /// panjang dua baris), dan boleh memakai sisa lebar yang tidak dibutuhkan judul
  /// satu baris — jadi judul pendek ("Tanggal") tidak memotong nilai panjang.
  double _valueMaxWidth(BuildContext context, double rowWidth) {
    final painter = TextPainter(
      // Gaya yang sama dengan Text judul: termasuk turunan DefaultTextStyle (letterSpacing tema).
      text: TextSpan(text: title, style: DefaultTextStyle.of(context).style.merge(AppTextStyles.bodyStrong)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final titleWidth = painter.width;
    painter.dispose();
    // trailing (mis. centang 20 + jarak 8) lebarnya tak diketahui: sisihkan 32.
    final reserved = (leading != null ? 52.0 : 0) + (showChevron ? 22.0 : 0) + (trailing != null ? 32.0 : 0) + 8;
    final shared = rowWidth - reserved; // lebar yang dibagi judul & nilai
    final spare = shared - titleWidth - 1;
    return spare > shared * 0.4 ? spare : shared * 0.4;
  }

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            // Judul mengisi sisa lebar dan boleh turun ke baris kedua, supaya label
            // panjang (mis. "Tanggal Pembayaran") tidak "…".
            Expanded(
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _valueMaxWidth(context, constraints.maxWidth)),
                child: Text(
                  value!,
                  style: valueColor == null ? AppTextStyles.subhead : AppTextStyles.subhead.copyWith(color: valueColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
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
