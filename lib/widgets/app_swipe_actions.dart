import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Geser kiri untuk Edit/Hapus (spec G12). Tanpa dependency: GestureDetector + AnimationController.
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({
    required this.child,
    this.onEdit,
    this.onDelete,
    this.deleteConfirmTitle = 'Hapus?',
    this.deleteConfirmMessage = 'Data ini akan dihapus permanen.',
    this.borderRadius,
    this.confirmDelete = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String deleteConfirmTitle;
  final String deleteConfirmMessage;

  /// Potong baris mengikuti radius kartu (`AppSurfaceCard` = 24); null = siku
  /// (baris grouped list).
  final BorderRadius? borderRadius;

  /// false = [onDelete] dipanggil langsung; pemanggil menampilkan dialognya
  /// sendiri (mis. hapus utang dengan pilihan kembalikan saldo).
  final bool confirmDelete;

  @override
  State<AppSwipeActions> createState() => _AppSwipeActionsState();
}

// Baris yang sedang digeser/terbuka; baris lain menutup diri saat ini berganti.
final ValueNotifier<Object?> _activeSwipeRow = ValueNotifier<Object?>(null);

class _AppSwipeActionsState extends State<AppSwipeActions> with SingleTickerProviderStateMixin {
  static const double _actionWidth = 72;

  // Dibuat di initState (bukan late lazy): bila tanpa aksi controller tak pernah
  // dipakai di build, dan membuatnya pertama kali di dispose() memicu assertion.
  late final AnimationController _controller;

  int get _actionCount => (widget.onEdit != null ? 1 : 0) + (widget.onDelete != null ? 1 : 0);
  double get _maxOffset => _actionWidth * _actionCount;
  bool get _isOpen => _controller.value > 0.01;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _activeSwipeRow.addListener(_onActiveRowChanged);
  }

  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
      _scrollPosition = position;
      _scrollPosition?.isScrollingNotifier.addListener(_onScroll);
    }
  }

  void _onActiveRowChanged() {
    if (_activeSwipeRow.value != this && _isOpen) _controller.animateTo(0, curve: Curves.easeOut);
  }

  void _onScroll() {
    if ((_scrollPosition?.isScrollingNotifier.value ?? false) && _isOpen) _close();
  }

  @override
  void dispose() {
    _activeSwipeRow.removeListener(_onActiveRowChanged);
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
    if (_activeSwipeRow.value == this) _activeSwipeRow.value = null;
    _controller.dispose();
    super.dispose();
  }

  void _close() => _controller.animateTo(0, curve: Curves.easeOut);

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value = (_controller.value - details.primaryDelta! / _maxOffset).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300 || (velocity <= 300 && _controller.value > 0.4)) {
      _controller.animateTo(1, curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  Future<void> _handleDelete() async {
    if (!widget.confirmDelete) {
      _close();
      widget.onDelete?.call();
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: widget.deleteConfirmTitle,
      message: widget.deleteConfirmMessage,
    );
    if (!mounted) return;
    _close();
    if (confirmed) widget.onDelete?.call();
  }

  void _handleEdit() {
    _close();
    widget.onEdit?.call();
  }

  Widget _action({required Color color, required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: _actionWidth,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_actionCount == 0) return widget.child;

    // Pembaca layar tidak bisa menggeser: Edit/Hapus diekspos sebagai aksi kustom.
    return Semantics(
      customSemanticsActions: {
        if (widget.onEdit != null) const CustomSemanticsAction(label: 'Edit'): _handleEdit,
        if (widget.onDelete != null) const CustomSemanticsAction(label: 'Hapus'): _handleDelete,
      },
      child: _clip(
        Stack(
          children: [
            // Tombol aksi hanya dilukis saat baris bergeser: bila selalu ada di
            // belakang, tepi anti-alias sudut kartu memperlihatkan garis merah tipis.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => _controller.value == 0 ? const SizedBox.shrink() : child!,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.onEdit != null)
                        _action(
                          color: AppColors.tintBlue,
                          icon: PhosphorIconsRegular.pencilSimple,
                          label: 'Edit',
                          onTap: _handleEdit,
                        ),
                      if (widget.onDelete != null)
                        _action(
                          color: AppColors.expense,
                          icon: PhosphorIconsRegular.trash,
                          label: 'Hapus',
                          onTap: _handleDelete,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(-_controller.value * _maxOffset, 0), child: child),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _activeSwipeRow.value = this,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                // Dievaluasi saat tap, bukan saat build: child GestureDetector ini tidak
                // di-rebuild ketika controller bergerak. Saat tertutup, tap anak (baris)
                // tetap menang karena berada lebih dalam di arena gesture.
                onTap: () {
                  if (_isOpen) _close();
                },
                // Material (bukan ColoredBox): tetap opaque supaya tombol aksi tidak
                // tembus, dan menjadi kanvas ink sehingga ripple InkWell baris terlihat.
                child: Material(
                  // Kartu sudah putih sendiri: latar transparan supaya sudutnya
                  // tidak memperlihatkan kotak putih di atas latar abu.
                  type: widget.borderRadius == null ? MaterialType.canvas : MaterialType.transparency,
                  color: widget.borderRadius == null ? AppColors.surface : null,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => AbsorbPointer(absorbing: _isOpen, child: child),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clip(Widget child) => widget.borderRadius == null
      ? ClipRect(child: child)
      : ClipRRect(borderRadius: widget.borderRadius!, child: child);
}
