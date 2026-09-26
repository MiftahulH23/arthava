import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Kerangka halaman gaya iOS (spec G1, G2, G13): nav bar tipis, judul besar
/// rata kiri, isi yang discroll, dan bottom bar opsional.
///
/// `embedded: true` untuk tab di dalam Home (Scaffold Home memakai
/// `extendBody: true`): tanpa Scaffold, SafeArea(bottom: false), dan padding
/// bawah ditambah `MediaQuery.padding.bottom` supaya konten terakhir bisa
/// discroll keluar dari bawah navbar melayang.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,
    this.backLabel,
    this.actions = const [],
    required this.children,
    this.bottomBar,
    this.onRefresh,
    this.embedded = false,
    this.largeTitle = true,
    this.titleWidget,
    this.leading,
    super.key,
  });

  static const double horizontalPadding = 18;
  static const double blockGap = 14;

  final String title;
  final String? backLabel;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;
  final bool embedded;
  final bool largeTitle;
  final Widget? titleWidget;

  /// Pengganti tombol kembali di kiri nav bar (mis. `AppNavAction.text('Batal')`).
  /// Bila diisi, `backLabel` diabaikan.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final bottomInset = embedded ? MediaQuery.of(context).padding.bottom : 0.0;
    final hasNav = leading != null || backLabel != null || actions.isNotEmpty || !largeTitle;

    final items = <Widget>[
      if (largeTitle)
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: titleWidget ?? Text(title, style: AppTextStyles.largeTitle),
        )
      else if (titleWidget != null)
        titleWidget!,
      ...children,
    ];

    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        hasNav ? 4 : 12,
        horizontalPadding,
        24 + bottomInset,
      ),
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: blockGap),
          items[i],
        ],
      ],
    );

    if (onRefresh != null) {
      list = RefreshIndicator(color: AppColors.primary, onRefresh: onRefresh!, child: list);
    }

    final body = Column(
      children: [
        if (hasNav)
          _AppNavBar(leading: leading, backLabel: backLabel, title: largeTitle ? null : title, actions: actions),
        Expanded(child: list),
        if (bottomBar != null)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12 + bottomInset),
            child: bottomBar,
          ),
      ],
    );

    if (embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(child: body));
  }
}

class _AppNavBar extends StatelessWidget {
  const _AppNavBar({required this.leading, required this.backLabel, required this.title, required this.actions});

  final Widget? leading;
  final String? backLabel;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final back = backLabel == null
        ? const SizedBox.shrink()
        : Semantics(
            button: true,
            label: 'Kembali ke $backLabel',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.maybePop(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIconsRegular.caretLeft, size: 22, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(backLabel!, style: AppTextStyles.navLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    // NavigationToolbar (mekanisme AppBar): aksi kanan selalu dapat lebar
    // penuhnya, judul di tengah tanpa pernah menimpa kiri/kanan, dan label
    // kembali dibatasi 40% lebar supaya terpotong "…" (gaya iOS).
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) => NavigationToolbar(
          centerMiddle: true,
          middleSpacing: 8,
          leading: leading != null
              ? ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                  child: Padding(padding: const EdgeInsets.only(left: 6), child: leading),
                )
              : backLabel == null
                  ? null
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                      child: back,
                    ),
          middle: title == null
              ? null
              : Text(title!, textAlign: TextAlign.center, style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: actions.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        actions[i],
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Aksi di kanan nav bar: tombol "+" (spec G3), teks ("Edit"), atau ikon.
class AppNavAction extends StatelessWidget {
  const AppNavAction.add({required this.onPressed, super.key})
      : icon = PhosphorIconsRegular.plus,
        label = null,
        color = null,
        tooltip = 'Tambah';

  const AppNavAction.text(String this.label, {required this.onPressed, super.key})
      : icon = null,
        color = null,
        tooltip = null;

  const AppNavAction.icon(IconData this.icon, {required this.onPressed, this.color, this.tooltip, super.key})
      : label = null;

  final IconData? icon;
  final String? label;
  final Color? color;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                widthFactor: 1,
                child: Text(label!, style: AppTextStyles.navLabel.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
    }
    final button = Semantics(
      button: true,
      child: InkResponse(
      radius: 22,
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 24, color: color ?? AppColors.primary),
      ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
