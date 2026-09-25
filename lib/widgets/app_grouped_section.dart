import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Grouped list ala Settings iPhone (spec G5): label grup HURUF BESAR di atas,
/// kartu putih radius 20, pemisah tipis antar baris yang menjorok setelah ikon.
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({
    this.header,
    this.headerAction,
    this.onHeaderAction,
    required this.children,
    this.insetSeparators = true,
    super.key,
  });

  final String? header;
  final String? headerAction;
  final VoidCallback? onHeaderAction;
  final List<Widget> children;
  final bool insetSeparators;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null || headerAction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: header == null
                      ? const SizedBox.shrink()
                      : Text(header!.toUpperCase(), style: AppTextStyles.groupLabel),
                ),
                if (headerAction != null)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onHeaderAction,
                      // Target sentuh min 44 tanpa mengubah posisi teks label.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: 1,
                          child: Text(
                            headerAction!,
                            style: AppTextStyles.subhead.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: insetSeparators ? 68 : 16),
                    child: Container(
                      key: ValueKey('grouped-separator-$i'),
                      height: 0.5,
                      color: AppColors.separator,
                    ),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
