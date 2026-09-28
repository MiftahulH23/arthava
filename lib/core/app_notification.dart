import 'dart:async';
import 'package:flutter/material.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum _ToastKind { success, error, info }

class AppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;
  static String? _currentMessage;
  static _ToastKind? _currentKind;

  // PESAN SUKSES (HIJAU)
  static void success(BuildContext context, String message) {
    _showTopToast(context, message, kind: _ToastKind.success);
  }

  // PESAN ERROR (MERAH)
  static void error(BuildContext context, String message) {
    _showTopToast(context, _translateError(message), kind: _ToastKind.error);
  }

  // PESAN INFO (BIRU), mis. fitur yang belum tersedia
  static void info(BuildContext context, String message) {
    _showTopToast(context, message, kind: _ToastKind.info);
  }

  // LOGIKA TAMPIL DI ATAS
  static void _showTopToast(
    BuildContext context,
    String message, {
    required _ToastKind kind,
  }) {
    // 0. Pesan yang sama masih tampil (mis. tombol diketuk berulang): cukup
    // perpanjang waktunya, jangan animasikan ulang.
    if (_currentEntry != null && _currentMessage == message && _currentKind == kind) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 3), _removeCurrentToast);
      return;
    }

    // 1. Hapus notifikasi lama jika masih ada (biar gak numpuk)
    _removeCurrentToast();
    _currentMessage = message;
    _currentKind = kind;

    final overlay = Overlay.of(context);

    // 2. Buat Entry Overlay Baru
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top:
            MediaQuery.of(context).padding.top +
            10, // Di atas (Safe Area + 10px)
        left: 20,
        right: 20,
        child: _ToastWidget(
          message: message,
          kind: kind,
          onDismiss: _removeCurrentToast,
        ),
      ),
    );

    // 3. Tampilkan
    overlay.insert(_currentEntry!);

    // 4. Timer Hilang Otomatis (3 Detik)
    _timer = Timer(const Duration(seconds: 3), () {
      _removeCurrentToast();
    });
  }

  static void _removeCurrentToast() {
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }
    _currentMessage = null;
    _currentKind = null;
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static String _translateError(String error) {
    final e = error.toLowerCase();
    if (e.contains("invalid login credentials"))
      return "Email atau Password salah.";
    if (e.contains("user already registered")) return "Email sudah terdaftar.";
    if (e.contains("socketexception") || e.contains("network"))
      return "Cek koneksi internetmu.";
    return error
        .replaceAll("AuthException:", "")
        .replaceAll("PostgrestException:", "")
        .trim();
  }
}

// WIDGET UI KEREN (SHADCN STYLE)
class _ToastWidget extends StatefulWidget {
  final String message;
  final _ToastKind kind;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.kind,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Animasi Slide dari Atas ke Bawah
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Animasi Fade In
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss, // Klik buat hilangin instan
            onVerticalDragEnd: (_) =>
                widget.onDismiss(), // Swipe ke atas buat buang
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: switch (widget.kind) {
                        _ToastKind.error => AppColors.expenseSoft,
                        _ToastKind.info => AppColors.primarySoft,
                        _ToastKind.success => AppColors.incomeSoft,
                      },
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      switch (widget.kind) {
                        _ToastKind.error => PhosphorIcons.warning(PhosphorIconsStyle.bold),
                        _ToastKind.info => PhosphorIcons.info(PhosphorIconsStyle.bold),
                        _ToastKind.success => PhosphorIcons.check(PhosphorIconsStyle.bold),
                      },
                      color: switch (widget.kind) {
                        _ToastKind.error => AppColors.expense,
                        _ToastKind.info => AppColors.primary,
                        _ToastKind.success => AppColors.income,
                      },
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
