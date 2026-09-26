import 'dart:async';
import 'package:flutter/material.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  // PESAN SUKSES (HIJAU)
  static void success(BuildContext context, String message) {
    _showTopToast(context, message, isError: false);
  }

  // PESAN ERROR (MERAH)
  static void error(BuildContext context, String message) {
    _showTopToast(context, _translateError(message), isError: true);
  }

  // LOGIKA TAMPIL DI ATAS
  static void _showTopToast(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    // 1. Hapus notifikasi lama jika masih ada (biar gak numpuk)
    _removeCurrentToast();

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
          isError: isError,
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
  final bool isError;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isError,
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
                      color: widget.isError
                          ? AppColors.expenseSoft
                          : AppColors.incomeSoft, // Merah Muda / Hijau Muda
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isError
                          ? PhosphorIcons.warning(PhosphorIconsStyle.bold)
                          : PhosphorIcons.check(PhosphorIconsStyle.bold),
                      color: widget.isError
                          ? AppColors.expense
                          : AppColors.income,
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
