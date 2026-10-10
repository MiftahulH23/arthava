import 'dart:math' as math;

import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Kotak logo kecil di hero auth (putih 18% di atas gradasi).
class AuthLogo extends StatelessWidget {
  /// Tanpa [icon], tampil logo Arthava (`assets/icon_foreground.png`).
  const AuthLogo({this.icon, super.key});
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon != null
          ? Icon(icon, size: 24, color: AppColors.white)
          : Image.asset('assets/icon_foreground.png', width: 40, height: 40),
    );
  }
}

/// Garis — "atau masuk dengan" — garis.
class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.track, thickness: 1, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider(color: AppColors.track, thickness: 1, height: 1)),
      ],
    );
  }
}

/// Tombol "Lanjut dengan Google" bergaris tepi.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.track, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoogleLogo(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo "G" empat warna, digambar tanpa aset atau paket SVG.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({this.size = 18, super.key});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final center = size.center(Offset.zero);
    final radius = (s - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Sudut searah jarum jam dari arah jam 3; celah "G" di kanan atas.
    canvas.drawArc(rect, _rad(220), _rad(100), false, arc(AppColors.googleRed));
    canvas.drawArc(rect, _rad(145), _rad(75), false, arc(AppColors.googleYellow));
    canvas.drawArc(rect, _rad(40), _rad(105), false, arc(AppColors.googleGreen));
    canvas.drawArc(rect, _rad(0), _rad(40), false, arc(AppColors.googleBlue));
    canvas.drawRect(
      Rect.fromLTRB(center.dx, center.dy - stroke / 2, center.dx + radius + stroke / 2, center.dy + stroke / 2),
      Paint()..color = AppColors.googleBlue,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
