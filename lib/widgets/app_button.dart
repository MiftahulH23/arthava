import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Tombol standar aplikasi, membungkus [FButton] milik forui.
///
/// Warna mengikuti [appForuiTheme] secara global. Pakai
/// [AppButton.destructive] untuk aksi berbahaya (hapus, dsb) supaya
/// selalu memakai warna destructive dari tema, bukan warna primary.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool _destructive;

  const AppButton({required this.label, required this.onPressed, super.key}) : _destructive = false;

  const AppButton.destructive({required this.label, required this.onPressed, super.key}) : _destructive = true;

  @override
  Widget build(BuildContext context) {
    return FButton(
      style: _destructive ? FButtonStyle.destructive() : FButtonStyle.primary(),
      onPress: onPressed,
      child: Text(label),
    );
  }
}
