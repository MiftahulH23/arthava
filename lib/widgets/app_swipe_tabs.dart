import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pindah tab dengan menggeser layar (spec 2026-10-10 §3.4). Membungkus
/// seluruh halaman: geser horizontal di mana saja memindah tab, kecuali di
/// atas `AppSwipeActions` (lebih dalam di arena gesture → baris yang menang).
/// Bagian yang berganti per tab dibungkus [AppSwipeTabBody] supaya ikut
/// tertarik jari; `AppSegmentedControl` di dalamnya otomatis mengikuti posisi.
class AppSwipeTabs extends StatefulWidget {
  const AppSwipeTabs({
    required this.index,
    required this.count,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final int index;
  final int count;
  final ValueChanged<int> onChanged;
  final Widget child;

  static const double switchFraction = 0.25;
  static const double switchVelocity = 400;
  static const double edgeResistance = 0.3;

  static _SwipeTabsScope? _scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwipeTabsScope>();

  /// Posisi (0..count-1, pecahan saat digeser) untuk penanda tab, atau null
  /// bila tidak berada di dalam [AppSwipeTabs] dengan jumlah tab yang sama.
  static ValueListenable<double>? maybePositionOf(BuildContext context, int count) {
    final scope = _scopeOf(context);
    return scope != null && scope.count == count ? scope.position : null;
  }

  @override
  State<AppSwipeTabs> createState() => _AppSwipeTabsState();
}

class _AppSwipeTabsState extends State<AppSwipeTabs> {
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);
  late final ValueNotifier<double> _position = ValueNotifier<double>(widget.index.toDouble());
  double _width = 1;
  int _direction = 1;

  @override
  void didUpdateWidget(AppSwipeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _drag.value = 0;
      _position.value = widget.index.toDouble();
    }
  }

  @override
  void dispose() {
    _drag.dispose();
    _position.dispose();
    super.dispose();
  }

  void _reset() {
    _drag.value = 0;
    _position.value = widget.index.toDouble();
  }

  void _onUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final next = _drag.value + delta;
    final pastStart = widget.index == 0 && next > 0;
    final pastEnd = widget.index == widget.count - 1 && next < 0;
    final value = (pastStart || pastEnd) ? _drag.value + delta * AppSwipeTabs.edgeResistance : next;
    _drag.value = value.clamp(-_width, _width);
    _position.value = (widget.index - _drag.value / _width).clamp(0, widget.count - 1).toDouble();
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dx = _drag.value;
    var target = widget.index;
    if ((dx < -_width * AppSwipeTabs.switchFraction || velocity < -AppSwipeTabs.switchVelocity) &&
        widget.index < widget.count - 1) {
      target = widget.index + 1;
    } else if ((dx > _width * AppSwipeTabs.switchFraction || velocity > AppSwipeTabs.switchVelocity) &&
        widget.index > 0) {
      target = widget.index - 1;
    }
    if (target == widget.index) {
      _reset();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onChanged(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          onHorizontalDragCancel: _reset,
          child: _SwipeTabsScope(
            index: widget.index,
            count: widget.count,
            direction: _direction,
            drag: _drag,
            position: _position,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _SwipeTabsScope extends InheritedWidget {
  const _SwipeTabsScope({
    required this.index,
    required this.count,
    required this.direction,
    required this.drag,
    required this.position,
    required super.child,
  });

  final int index;
  final int count;
  final int direction;
  final ValueListenable<double> drag;
  final ValueListenable<double> position;

  @override
  bool updateShouldNotify(_SwipeTabsScope old) =>
      old.index != index || old.count != count || old.direction != direction;
}

/// Bagian halaman yang berganti per tab: ikut tertarik saat layar digeser,
/// dan (bila [keyByIndex]) meluncur masuk dari sisi yang sesuai saat tab
/// berganti. [keyByIndex] false untuk isi yang state-nya harus bertahan
/// (mis. form Masuk/Daftar yang keduanya tetap ter-mount).
class AppSwipeTabBody extends StatelessWidget {
  const AppSwipeTabBody({required this.child, this.keyByIndex = true, super.key});

  final Widget child;
  final bool keyByIndex;

  @override
  Widget build(BuildContext context) {
    final scope = AppSwipeTabs._scopeOf(context);
    if (scope == null) return child;
    final content = keyByIndex
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: Offset(0.35 * scope.direction, 0), end: Offset.zero).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: KeyedSubtree(key: ValueKey<int>(scope.index), child: child),
          )
        : child;
    return ValueListenableBuilder<double>(
      valueListenable: scope.drag,
      builder: (context, dx, inner) => Transform.translate(offset: Offset(dx, 0), child: inner),
      child: content,
    );
  }
}
