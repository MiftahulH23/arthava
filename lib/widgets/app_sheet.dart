import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Form sheet gaya iOS (spec G4): grabber, header Batal · judul, isi dari [builder].
/// Dibangun di atas [showAppBottomSheet] (Material ancestor, batas tinggi & keyboard sudah ditangani).
Future<T?> showAppFormSheet<T>({
  required BuildContext context,
  required String title,
  String cancelLabel = 'Batal',
  Widget? trailing,
  required WidgetBuilder builder,
}) {
  return showAppBottomSheet<T>(
    context: context,
    builder: (sheetContext) => _AppFormSheet(title: title, cancelLabel: cancelLabel, trailing: trailing, builder: builder),
  );
}

class _AppFormSheet extends StatelessWidget {
  const _AppFormSheet({required this.title, required this.cancelLabel, required this.trailing, required this.builder});

  final String title;
  final String cancelLabel;

  /// Aksi opsional di kanan header (mis. "Reset"), sejajar "Batal" dan judul.
  final Widget? trailing;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              widthFactor: 1,
                              child: Text(cancelLabel, style: AppTextStyles.navLabel),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headline,
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: trailing == null ? null : Align(alignment: Alignment.centerRight, child: trailing),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            builder(context),
          ],
        ),
      ),
    );
  }
}
