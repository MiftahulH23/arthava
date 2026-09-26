import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/cupertino.dart';

/// Dialog konfirmasi gaya iOS. `true` hanya bila tombol konfirmasi ditekan.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel = 'Batal',
  bool destructive = true,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: _title(title),
      content: _message(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: _action(cancelLabel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: _action(confirmLabel, destructive: destructive, bold: !destructive),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Satu pilihan di [showAppChoiceDialog].
class AppDialogChoice<T> {
  const AppDialogChoice({required this.label, required this.value, this.destructive = false});

  final String label;
  final T value;
  final bool destructive;
}

/// Dialog iOS dengan beberapa pilihan (ditumpuk vertikal) + "Batal".
/// Pilihan pertama tebal (default). Mengembalikan `value` pilihan, atau null bila batal.
Future<T?> showAppChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<AppDialogChoice<T>> choices,
  String cancelLabel = 'Batal',
}) {
  return showCupertinoDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: _title(title),
      content: _message(message),
      actions: [
        for (var i = 0; i < choices.length; i++)
          CupertinoDialogAction(
            isDefaultAction: i == 0 && !choices[i].destructive,
            isDestructiveAction: choices[i].destructive,
            onPressed: () => Navigator.of(dialogContext).pop(choices[i].value),
            child: _action(
              choices[i].label,
              destructive: choices[i].destructive,
              bold: i == 0 && !choices[i].destructive,
            ),
          ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: _action(cancelLabel),
        ),
      ],
    ),
  );
}

// CupertinoAlertDialog memakai font sistem iOS ("CupertinoSystemText") yang tidak
// ada di Android/web; teks dialog diberi gaya aplikasi supaya tetap Plus Jakarta Sans.
Widget _title(String text) =>
    Text(text, style: AppTextStyles.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w700));

Widget _message(String text) =>
    Text(text, style: AppTextStyles.caption.copyWith(fontSize: 13, color: AppColors.textPrimary, height: 1.35));

Widget _action(String label, {bool destructive = false, bool bold = false}) => Text(
      label,
      textAlign: TextAlign.center,
      style: AppTextStyles.body.copyWith(
        fontSize: 17,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: destructive ? AppColors.expense : AppColors.primary,
      ),
    );

/// Loading gaya iOS (HUD) selama [task] berjalan. Tidak bisa ditutup pengguna;
/// selalu dilepas setelah [task] selesai atau gagal (error diteruskan).
/// Route dilepas lewat `removeRoute`, jadi aman walau [task] selesai sebelum
/// HUD sempat tampil atau ada route lain di atasnya.
Future<T> runWithAppLoading<T>(BuildContext context, Future<T> Function() task, {String? message}) async {
  final navigator = Navigator.of(context);
  final route = CupertinoDialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: _AppLoadingHud(message: message)),
  );
  navigator.push(route);
  try {
    return await task();
  } finally {
    if (route.isActive) navigator.removeRoute(route);
  }
}

class _AppLoadingHud extends StatelessWidget {
  const _AppLoadingHud({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, textAlign: TextAlign.center, style: AppTextStyles.subhead),
            ],
          ],
        ),
      ),
    );
  }
}
