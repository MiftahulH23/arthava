import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Kartu standar aplikasi, membungkus [FCard] milik forui.
///
/// Warna/border mengikuti [appForuiTheme] secara global — lihat
/// lib/theme/app_forui_theme.dart. Jangan override warna di sini
/// kecuali screen tertentu benar-benar butuh varian berbeda.
class AppCard extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget child;

  const AppCard({this.title, this.subtitle, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return FCard(
      title: title,
      subtitle: subtitle,
      child: child,
    );
  }
}
